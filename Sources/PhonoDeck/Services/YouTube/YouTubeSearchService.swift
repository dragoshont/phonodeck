import Foundation
import OSLog

@MainActor
final class YouTubeSearchService: YouTubeSearchServicing {
    private let accountStore: any YouTubeAccountTokenProviding
    private let dataClient: any YouTubeOfficialProviding
    private let searchCacheKey: String
    private let searchCacheLimit: Int
    private let searchDebounceInterval: TimeInterval
    private var searchCache: [String: YouTubeCachedSearchPage]
    private var activeSearchKey: String?
    private var inFlightSearchTasks: [String: Task<YouTubeSearchServiceResult, Never>] = [:]
    private var lastSearchSubmittedAtByKey: [String: Date] = [:]
    private(set) var providerRequestCounts: [String: Int] = [:]

    init(
        accountStore: any YouTubeAccountTokenProviding,
        dataClient: any YouTubeOfficialProviding,
        metadataProvider _: any YouTubeMusicMetadataProviding,
        searchCacheKey: String,
        searchCacheLimit: Int,
        searchDebounceInterval: TimeInterval,
        experimentalTimeout _: TimeInterval = 8,
        initialCache: [String: YouTubeCachedSearchPage] = [:]
    ) {
        self.accountStore = accountStore
        self.dataClient = dataClient
        self.searchCacheKey = searchCacheKey
        self.searchCacheLimit = searchCacheLimit
        self.searchDebounceInterval = searchDebounceInterval
        searchCache = initialCache
    }

    func cachedPage(for request: YouTubeSearchRequest) -> YouTubeSearchServiceResult? {
        let key = Self.cacheKey(query: request.query, preference: request.preference, engine: request.engine)
        guard let cachedPage = searchCache[key], !cachedPage.items.isEmpty else { return nil }
        return YouTubeSearchServiceResult(
            request: request,
            page: cachedPage.page,
            resolvedEngine: request.engine,
            status: .ready,
            cacheState: .warm(updatedAt: cachedPage.updatedAt),
            nextPageToken: cachedPage.nextPageToken,
            requestCountDeltas: [:]
        )
    }

    func search(_ request: YouTubeSearchRequest) async -> YouTubeSearchServiceResult {
        let key = Self.cacheKey(query: request.query, preference: request.preference, engine: request.engine)
        if let lastSubmittedAt = lastSearchSubmittedAtByKey[key], Date().timeIntervalSince(lastSubmittedAt) < searchDebounceInterval {
            if let cached = cachedPage(for: request) { return cached }
        }
        lastSearchSubmittedAtByKey[key] = Date()
        if activeSearchKey == key, let cached = cachedPage(for: request) { return cached }
        if let inFlightSearchTask = inFlightSearchTasks[key] { return await inFlightSearchTask.value }

        activeSearchKey = key
        let task = Task { [weak self] in
            guard let self else {
                return YouTubeSearchServiceResult(request: request, page: YouTubeVideoPage(items: [], nextPageToken: nil), resolvedEngine: request.engine, status: .failed("Search service was released."), cacheState: .none, nextPageToken: nil, requestCountDeltas: [:])
            }
            return await self.performSearch(request, key: key)
        }
        inFlightSearchTasks[key] = task
        let result = await task.value
        inFlightSearchTasks.removeValue(forKey: key)
        if activeSearchKey == key { activeSearchKey = nil }
        return result
    }

    private func performSearch(_ request: YouTubeSearchRequest, key: String) async -> YouTubeSearchServiceResult {
        let before = providerRequestCounts
        do {
            let (page, resolvedEngine, status) = try await searchPage(query: request.query, preference: request.preference, engine: request.engine, maxResults: request.maxResults)
            cache(page, key: key)
            return YouTubeSearchServiceResult(
                request: request,
                page: page,
                resolvedEngine: resolvedEngine,
                status: status,
                cacheState: .refreshed(updatedAt: Date()),
                nextPageToken: page.nextPageToken,
                requestCountDeltas: deltas(since: before)
            )
        } catch {
            if let cachedPage = searchCache[key], !cachedPage.items.isEmpty {
                return YouTubeSearchServiceResult(
                    request: request,
                    page: cachedPage.page,
                    resolvedEngine: request.engine,
                    status: .cachedFallback,
                    cacheState: .stale(updatedAt: cachedPage.updatedAt),
                    nextPageToken: cachedPage.nextPageToken,
                    requestCountDeltas: deltas(since: before)
                )
            }
            return YouTubeSearchServiceResult(
                request: request,
                page: YouTubeVideoPage(items: [], nextPageToken: nil),
                resolvedEngine: request.engine,
                status: YouTubeServiceMapper.status(for: error),
                cacheState: .none,
                nextPageToken: nil,
                requestCountDeltas: deltas(since: before)
            )
        }
    }

    func loadMore(_ continuation: YouTubeSearchContinuation) async -> YouTubeSearchServiceResult {
        let request = YouTubeSearchRequest(query: continuation.query, preference: continuation.preference, engine: continuation.engine, maxResults: continuation.maxResults)
        let cacheKey = Self.cacheKey(query: continuation.query, preference: continuation.preference, engine: continuation.engine)
        let before = providerRequestCounts
        do {
            guard let tokens = try await accountStore.loadFreshTokens() else { throw YouTubeMusicProviderError.connectGoogle }
            recordProviderRequest("official.search")
            let page = try await dataClient.searchVideoPage(
                query: continuation.query,
                accessToken: tokens.accessToken,
                maxResults: continuation.maxResults,
                preference: continuation.preference,
                pageToken: continuation.pageToken
            )
            let cachedItems = searchCache[cacheKey]?.items ?? []
            let mergedItems = (cachedItems + page.items).deduplicatedByVideoID()
            searchCache[cacheKey] = YouTubeCachedSearchPage(items: mergedItems, nextPageToken: page.nextPageToken, updatedAt: Date())
            saveSearchCache(searchCache)
            return YouTubeSearchServiceResult(request: request, page: page, resolvedEngine: .official, status: .ready, cacheState: .refreshed(updatedAt: Date()), nextPageToken: page.nextPageToken, requestCountDeltas: deltas(since: before))
        } catch {
            return YouTubeSearchServiceResult(request: request, page: YouTubeVideoPage(items: [], nextPageToken: nil), resolvedEngine: continuation.engine, status: YouTubeServiceMapper.status(for: error), cacheState: .none, nextPageToken: nil, requestCountDeltas: deltas(since: before))
        }
    }

    func compareProviders(query: String, preference: YouTubePlaybackPreference) async -> [YouTubeProviderComparisonResult] {
        var comparisons: [YouTubeProviderComparisonResult] = []
        let officialRequest = YouTubeSearchRequest(query: query, preference: preference, engine: .official)
        do {
            let page = try await officialSearchPage(query: query, preference: preference, maxResults: 12)
            comparisons.append(.init(id: .official, title: "Official", status: "\(page.items.count) results", items: page.items, cacheState: .refreshed(updatedAt: Date())))
        } catch {
            if let cached = cachedPage(for: officialRequest), !cached.page.items.isEmpty {
                comparisons.append(.init(id: .official, title: "Official", status: "Cached fallback", items: cached.page.items, cacheState: cached.cacheState, errorMessage: error.localizedDescription))
            } else {
                comparisons.append(.init(id: .official, title: "Official", status: error.localizedDescription, items: [], cacheState: .none, errorMessage: error.localizedDescription))
            }
        }

        comparisons.append(.init(
            id: .experimental,
            title: "Undocumented metadata",
            status: "Disabled by policy",
            items: [],
            cacheState: .none,
            errorMessage: YouTubeMusicProviderError.undocumentedMetadataDisabled.localizedDescription,
            riskLabel: "Disabled"
        ))
        return comparisons
    }

    func clearSearchCache() {
        searchCache.removeAll()
        UserDefaults.standard.removeObject(forKey: searchCacheKey)
    }

    func mergeCache(_ page: YouTubeVideoPage, request: YouTubeSearchRequest) {
        cache(page, key: Self.cacheKey(query: request.query, preference: request.preference, engine: request.engine))
    }

    private func searchPage(query: String, preference: YouTubePlaybackPreference, engine: YouTubeMusicEngine, maxResults: Int) async throws -> (YouTubeVideoPage, YouTubeMusicEngine, YouTubeProviderStatus) {
        switch engine {
        case .official:
            return (try await officialSearchPage(query: query, preference: preference, maxResults: maxResults), .official, .ready)
        case .experimental:
            return (try await officialSearchPage(query: query, preference: preference, maxResults: maxResults), .official, .undocumentedMetadataDisabledOfficialOnly)
        case .automatic:
            return (try await officialSearchPage(query: query, preference: preference, maxResults: maxResults), .official, .ready)
        }
    }

    private func officialSearchPage(query: String, preference: YouTubePlaybackPreference, maxResults: Int) async throws -> YouTubeVideoPage {
        guard let tokens = try await accountStore.loadFreshTokens() else { throw YouTubeMusicProviderError.connectGoogle }
        recordProviderRequest("official.search")
        return try await dataClient.searchVideoPage(query: query, accessToken: tokens.accessToken, maxResults: maxResults, preference: preference, pageToken: nil)
    }

    private func cache(_ page: YouTubeVideoPage, key: String) {
        guard !page.items.isEmpty else { return }
        searchCache[key] = YouTubeCachedSearchPage(items: page.items.deduplicatedByVideoID(), nextPageToken: page.nextPageToken, updatedAt: Date())
        if searchCache.count > searchCacheLimit {
            let keysToKeep = Set(searchCache.sorted { $0.value.updatedAt > $1.value.updatedAt }.prefix(searchCacheLimit).map { $0.key })
            searchCache = searchCache.filter { keysToKeep.contains($0.key) }
        }
        saveSearchCache(searchCache)
    }

    private func saveSearchCache(_ cache: [String: YouTubeCachedSearchPage]) {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        UserDefaults.standard.set(data, forKey: searchCacheKey)
    }

    private func recordProviderRequest(_ key: String) {
        providerRequestCounts[key, default: 0] += 1
    }

    private func deltas(since previous: [String: Int]) -> [String: Int] {
        providerRequestCounts.reduce(into: [:]) { result, pair in
            let delta = pair.value - (previous[pair.key] ?? 0)
            if delta != 0 { result[pair.key] = delta }
        }
    }

    static func cacheKey(query: String, preference: YouTubePlaybackPreference, engine: YouTubeMusicEngine) -> String {
        "\(engine.rawValue)|\(preference.rawValue)|\(normalizedCacheQuery(query))"
    }

    static func normalizedCacheQuery(_ query: String) -> String {
        query.lowercased().split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    static func loadSearchCache(defaultsKey: String) -> [String: YouTubeCachedSearchPage] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return [:] }
        return (try? JSONDecoder().decode([String: YouTubeCachedSearchPage].self, from: data)) ?? [:]
    }

}
