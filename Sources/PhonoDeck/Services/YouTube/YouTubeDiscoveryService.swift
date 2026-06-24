import Foundation

@MainActor
final class YouTubeDiscoveryService: YouTubeDiscoveryServicing {
    private let searchService: any YouTubeSearchServicing
    private let coalescer: RequestCoalescer<String>
    private let discoveryDefaultsKey: String
    private let discoveryRefreshDefaultsKey: String
    private let discoveryLimit: Int
    private let refreshInterval: TimeInterval
    private var musicDiscoveryVideos: [YouTubeVideoSearchResult]
    private var lastRefreshDate: Date?

    init(
        searchService: any YouTubeSearchServicing,
        coalescer: RequestCoalescer<String>,
        discoveryDefaultsKey: String,
        discoveryRefreshDefaultsKey: String,
        discoveryLimit: Int,
        refreshInterval: TimeInterval,
        initialVideos: [YouTubeVideoSearchResult] = [],
        lastRefreshDate: Date? = nil
    ) {
        self.searchService = searchService
        self.coalescer = coalescer
        self.discoveryDefaultsKey = discoveryDefaultsKey
        self.discoveryRefreshDefaultsKey = discoveryRefreshDefaultsKey
        self.discoveryLimit = discoveryLimit
        self.refreshInterval = refreshInterval
        musicDiscoveryVideos = initialVideos
        self.lastRefreshDate = lastRefreshDate
    }

    func cachedDiscovery(engine: YouTubeMusicEngine, seedQueries: [String], currentItems: [YouTubeVideoSearchResult]) -> YouTubeDiscoverySnapshot {
        let cachedSeedItems = seedQueries.flatMap { seed -> [YouTubeVideoSearchResult] in
            let request = YouTubeSearchRequest(query: seed, preference: .songFirst, engine: engine)
            return searchService.cachedPage(for: request)?.page.items ?? []
        }
        let items = Self.musicItems(from: currentItems + musicDiscoveryVideos + cachedSeedItems)
        return YouTubeDiscoverySnapshot(items: Array(items.prefix(discoveryLimit)), status: .ready, cacheState: lastRefreshDate.map { .warm(updatedAt: $0) } ?? .none, requestCountDeltas: [:])
    }

    func refreshDiscovery(_ request: YouTubeDiscoveryRequest, currentItems: [YouTubeVideoSearchResult]) async -> YouTubeDiscoverySnapshot {
        let cached = cachedDiscovery(engine: request.engine, seedQueries: request.seedQueries, currentItems: currentItems)
        if !request.force, let lastRefreshDate, Date().timeIntervalSince(lastRefreshDate) < refreshInterval, !cached.items.isEmpty {
            return cached
        }

        var fetchedItems: [YouTubeVideoSearchResult] = []
        var requestDeltas: [String: Int] = [:]
        for query in request.seedQueries {
            let cacheKey = YouTubeSearchService.cacheKey(query: query, preference: .songFirst, engine: request.engine)
            guard await coalescer.begin(cacheKey) else {
                fetchedItems.append(contentsOf: searchService.cachedPage(for: .init(query: query, preference: .songFirst, engine: request.engine))?.page.items ?? [])
                continue
            }
            let result = await searchService.search(.init(query: query, preference: .songFirst, engine: request.engine))
            await coalescer.end(cacheKey)
            fetchedItems.append(contentsOf: result.page.items)
            for (key, value) in result.requestCountDeltas { requestDeltas[key, default: 0] += value }
        }

        let refreshedItems = Self.musicItems(from: currentItems + fetchedItems + musicDiscoveryVideos)
        guard !refreshedItems.isEmpty else {
            return YouTubeDiscoverySnapshot(items: cached.items, status: cached.items.isEmpty ? .failed("Music discovery returned no music items.") : .cachedFallback, cacheState: cached.cacheState, requestCountDeltas: requestDeltas)
        }
        musicDiscoveryVideos = Array(refreshedItems.prefix(discoveryLimit))
        lastRefreshDate = Date()
        saveMusicDiscoveryVideos(musicDiscoveryVideos)
        saveMusicDiscoveryRefreshDate(lastRefreshDate)
        return YouTubeDiscoverySnapshot(items: musicDiscoveryVideos, status: .ready, cacheState: .refreshed(updatedAt: lastRefreshDate ?? Date()), requestCountDeltas: requestDeltas)
    }

    func clearDiscoveryCache() {
        musicDiscoveryVideos = []
        lastRefreshDate = nil
        UserDefaults.standard.removeObject(forKey: discoveryDefaultsKey)
        UserDefaults.standard.removeObject(forKey: discoveryRefreshDefaultsKey)
    }

    func remember(_ videos: [YouTubeVideoSearchResult]) {
        let items = Self.musicItems(from: videos + musicDiscoveryVideos)
        guard !items.isEmpty else { return }
        musicDiscoveryVideos = Array(items.prefix(discoveryLimit))
        saveMusicDiscoveryVideos(musicDiscoveryVideos)
    }

    private func saveMusicDiscoveryVideos(_ videos: [YouTubeVideoSearchResult]) {
        guard let data = try? JSONEncoder().encode(videos) else { return }
        UserDefaults.standard.set(data, forKey: discoveryDefaultsKey)
    }

    private func saveMusicDiscoveryRefreshDate(_ date: Date?) {
        guard let date else { return }
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: discoveryRefreshDefaultsKey)
    }

    static func loadMusicDiscoveryVideos(defaultsKey: String) -> [YouTubeVideoSearchResult] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return [] }
        return (try? JSONDecoder().decode([YouTubeVideoSearchResult].self, from: data)) ?? []
    }

    static func loadMusicDiscoveryRefreshDate(defaultsKey: String) -> Date? {
        let interval = UserDefaults.standard.double(forKey: defaultsKey)
        guard interval > 0 else { return nil }
        return Date(timeIntervalSince1970: interval)
    }

    static func musicItems(from videos: [YouTubeVideoSearchResult]) -> [YouTubeVideoSearchResult] {
        let deduplicatedVideos = videos.deduplicatedByVideoID()
        let songLikeVideos = deduplicatedVideos.filter(\.isSongLike)
        return songLikeVideos.isEmpty ? deduplicatedVideos : songLikeVideos
    }
}
