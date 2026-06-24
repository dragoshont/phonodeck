import Foundation
import OSLog

@MainActor
final class YouTubeSearchViewModel: ObservableObject {
    private static let youtubeWriteScope = "https://www.googleapis.com/auth/youtube"
    private static let playbackHistoryDefaultsKey = "youtubePlaybackHistory"
    private static let selectedPlaylistIDDefaultsKey = "youtubeSelectedPlaylistID"
    private static let searchCacheDefaultsKey = "youtubeMusicSearchCache"
    private static let playlistItemCacheDefaultsKey = "youtubePlaylistItemCache"
    private static let musicDiscoveryDefaultsKey = "youtubeMusicDiscovery"
    private static let musicDiscoveryRefreshDefaultsKey = "youtubeMusicDiscoveryRefreshedAt"
    private static let searchCacheLimit = 48
    private static let playlistItemCacheLimit = 10
    private static let musicDiscoveryLimit = 60
    private static let musicDiscoveryRefreshInterval: TimeInterval = 10 * 60
    private static let searchDebounceInterval: TimeInterval = 0.35
    private static let musicDiscoverySeedQueries = ["top songs", "new music", "chill songs"]

    @Published private(set) var results: [YouTubeVideoSearchResult] = []
    @Published private(set) var selectedVideo: YouTubeVideoSearchResult?
    @Published private(set) var status: String = ""
    @Published private(set) var isSearching = false
    @Published private(set) var activityVideos: [YouTubeVideoSearchResult] = []
    @Published private(set) var playlists: [YouTubePlaylist] = []
    @Published private(set) var selectedPlaylist: YouTubePlaylist?
    @Published private(set) var playlistVideos: [YouTubeVideoSearchResult] = []
    @Published private(set) var isLoadingLibrary = false
    @Published private(set) var queue: [YouTubeVideoSearchResult] = []
    @Published private(set) var subscriptions: [YouTubeSubscription] = []
    @Published private(set) var selectedVideoDetails: YouTubeVideoDetails?
    @Published private(set) var playbackHistory: [YouTubeVideoSearchResult] = []
    @Published private(set) var providerComparisons: [YouTubeProviderComparisonResult] = []
    @Published private(set) var providerComparisonRun: ProviderComparisonRun?
    @Published private(set) var isComparingProviders = false
    @Published private(set) var musicDiscoveryVideos: [YouTubeVideoSearchResult] = []
    @Published private(set) var isRefreshingMusicDiscovery = false
    @Published private(set) var isCreatingPlaylist = false
    @Published private(set) var providerRequestCounts: [String: Int] = [:]

    private let accountStore: any YouTubeAccountTokenProviding
    private let dataClient: any YouTubeOfficialProviding
    private let metadataProvider: any YouTubeMusicMetadataProviding
    private let discoveryCoalescer: RequestCoalescer<String>
    private let searchService: any YouTubeSearchServicing
    private let discoveryService: any YouTubeDiscoveryServicing
    private let playlistService: any YouTubePlaylistServicing
    private var lastSearchQuery = ""
    private var lastSearchPreference: YouTubePlaybackPreference = .songFirst
    private var lastSearchEngine: YouTubeMusicEngine = .automatic
    private var nextSearchPageToken: String?
    private var nextPlaylistPageToken: String?
    private var skippedVideoIDs = Set<String>()
    private var searchCache: [String: YouTubeCachedSearchPage] = [:]
    private var playlistItemCache: [String: YouTubeCachedPlaylistPage] = [:]
    private var activeSearchKey: String?
    private var activeSearchRequestID: UUID?
    private var lastSearchSubmittedAtByKey: [String: Date] = [:]
    private var lastMusicDiscoveryRefreshDate: Date?
    private var selectedPlaylistID: String?

    init(
        accountStore: any YouTubeAccountTokenProviding = GoogleAccountStore(),
        dataClient: any YouTubeOfficialProviding = YouTubeDataClient(),
        metadataProvider: any YouTubeMusicMetadataProviding = OfficialOnlyYouTubeMusicMetadataProvider(),
        discoveryCoalescer: RequestCoalescer<String> = RequestCoalescer(),
        injectedSearchService: (any YouTubeSearchServicing)? = nil,
        injectedDiscoveryService: (any YouTubeDiscoveryServicing)? = nil,
        injectedPlaylistService: (any YouTubePlaylistServicing)? = nil
    ) {
        self.accountStore = accountStore
        self.dataClient = dataClient
        self.metadataProvider = metadataProvider
        self.discoveryCoalescer = discoveryCoalescer
        let initialSearchCache = Self.loadSearchCache()
        let initialPlaylistItemCache = Self.loadPlaylistItemCache()
        let initialPlaybackHistory = Self.loadPlaybackHistory()
        let initialMusicDiscoveryVideos = Self.loadMusicDiscoveryVideos()
        let initialMusicDiscoveryRefreshDate = Self.loadMusicDiscoveryRefreshDate()
        let initialSelectedPlaylistID = UserDefaults.standard.string(forKey: Self.selectedPlaylistIDDefaultsKey)
        let resolvedSearchService: any YouTubeSearchServicing = injectedSearchService ?? YouTubeSearchService(
            accountStore: accountStore,
            dataClient: dataClient,
            metadataProvider: metadataProvider,
            searchCacheKey: Self.searchCacheDefaultsKey,
            searchCacheLimit: Self.searchCacheLimit,
            searchDebounceInterval: Self.searchDebounceInterval,
            initialCache: initialSearchCache
        )
        let resolvedDiscoveryService: any YouTubeDiscoveryServicing
        if let injectedDiscoveryService {
            resolvedDiscoveryService = injectedDiscoveryService
        } else {
            resolvedDiscoveryService = YouTubeDiscoveryService(
                searchService: resolvedSearchService,
                coalescer: discoveryCoalescer,
                discoveryDefaultsKey: Self.musicDiscoveryDefaultsKey,
                discoveryRefreshDefaultsKey: Self.musicDiscoveryRefreshDefaultsKey,
                discoveryLimit: Self.musicDiscoveryLimit,
                refreshInterval: Self.musicDiscoveryRefreshInterval,
                initialVideos: initialMusicDiscoveryVideos,
                lastRefreshDate: initialMusicDiscoveryRefreshDate
            )
        }
        let resolvedPlaylistService: any YouTubePlaylistServicing = injectedPlaylistService ?? YouTubePlaylistService(
            accountStore: accountStore,
            dataClient: dataClient,
            selectedPlaylistDefaultsKey: Self.selectedPlaylistIDDefaultsKey,
            playlistItemCacheDefaultsKey: Self.playlistItemCacheDefaultsKey,
            playlistItemCacheLimit: Self.playlistItemCacheLimit,
            initialCache: initialPlaylistItemCache
        )
        self.searchService = resolvedSearchService
        self.discoveryService = resolvedDiscoveryService
        self.playlistService = resolvedPlaylistService
        searchCache = initialSearchCache
        playlistItemCache = initialPlaylistItemCache
        playbackHistory = initialPlaybackHistory
        musicDiscoveryVideos = initialMusicDiscoveryVideos
        lastMusicDiscoveryRefreshDate = initialMusicDiscoveryRefreshDate
        selectedPlaylistID = initialSelectedPlaylistID
        AppLog.search.info("Search view model initialized; search cache=\(self.searchCache.count, privacy: .public), playlist cache=\(self.playlistItemCache.count, privacy: .public), history=\(self.playbackHistory.count, privacy: .public), discovery=\(self.musicDiscoveryVideos.count, privacy: .public)")
    }

    func search(_ query: String, preference: YouTubePlaybackPreference = .songFirst, engine: YouTubeMusicEngine = .automatic) async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }
        guard trimmedQuery.count <= 100 else {
            status = "Search query is too long. Keep it under 100 characters."
            AppLog.search.warning("Rejected overlong search query; length=\(trimmedQuery.count, privacy: .public)")
            return
        }

        let cacheKey = Self.searchCacheKey(query: trimmedQuery, preference: preference, engine: engine)
        let request = YouTubeSearchRequest(query: trimmedQuery, preference: preference, engine: engine)
        let cachedResult = searchService.cachedPage(for: request)
        if let cachedResult, !cachedResult.page.items.isEmpty {
            AppLog.search.info("Publishing cached search page; query=\(trimmedQuery, privacy: .private), engine=\(engine.rawValue, privacy: .public), preference=\(preference.rawValue, privacy: .public), items=\(cachedResult.page.items.count, privacy: .public)")
            publishSearchResult(cachedResult)
        }

        if let lastSubmittedAt = lastSearchSubmittedAtByKey[cacheKey],
           Date().timeIntervalSince(lastSubmittedAt) < Self.searchDebounceInterval {
            AppLog.search.debug("Debounced duplicate search; query=\(trimmedQuery, privacy: .private)")
            return
        }
        lastSearchSubmittedAtByKey[cacheKey] = Date()

        if isSearching, activeSearchKey == cacheKey {
            AppLog.search.debug("Search already active for same key; query=\(trimmedQuery, privacy: .private)")
            return
        }

        isSearching = true
        activeSearchKey = cacheKey
        let requestID = UUID()
        activeSearchRequestID = requestID
        status = ""
        AppLog.search.info("Search started; query=\(trimmedQuery, privacy: .private), engine=\(engine.rawValue, privacy: .public), preference=\(preference.rawValue, privacy: .public), hadCache=\((cachedResult != nil).description, privacy: .public)")
        defer {
            isSearching = false
            if activeSearchKey == cacheKey {
                activeSearchKey = nil
            }
            if activeSearchRequestID == requestID {
                activeSearchRequestID = nil
            }
            AppLog.search.info("Search finished; query=\(trimmedQuery, privacy: .private), result count=\(self.results.count, privacy: .public), status=\(self.status, privacy: .public)")
        }

        let result = await searchService.search(request)
        guard activeSearchRequestID == requestID else {
            AppLog.search.debug("Ignoring stale search response; query=\(trimmedQuery, privacy: .private)")
            return
        }
        publishSearchResult(result)
        applyRequestCountDeltas(result.requestCountDeltas)
        rememberMusicDiscovery(result.page.items)
    }

    var canLoadMoreSearchResults: Bool {
        nextSearchPageToken != nil && !lastSearchQuery.isEmpty
    }

    func loadMoreSearchResults() async {
        guard let nextSearchPageToken else { return }
        let continuation = YouTubeSearchContinuation(
            query: lastSearchQuery,
            preference: lastSearchPreference,
            engine: lastSearchEngine,
            pageToken: nextSearchPageToken
        )
        let result = await searchService.loadMore(continuation)
        self.nextSearchPageToken = result.nextPageToken
        results.append(contentsOf: result.page.items.filter { pageItem in !results.contains { $0.id == pageItem.id } })
        results = results.deduplicatedByVideoID()
        rememberMusicDiscovery(results)
        adoptQueue(results)
        applyRequestCountDeltas(result.requestCountDeltas)
        if result.status != .ready, !result.status.message.isEmpty { status = result.status.message }
    }

    func refreshMusicDiscovery(engine: YouTubeMusicEngine, force: Bool = false) async {
        AppLog.search.info("Music discovery refresh requested; engine=\(engine.rawValue, privacy: .public), force=\(force.description, privacy: .public), existing=\(self.musicDiscoveryVideos.count, privacy: .public)")
        let cachedSnapshot = discoveryService.cachedDiscovery(engine: engine, seedQueries: Self.musicDiscoverySeedQueries, currentItems: playbackHistory + results)
        if !cachedSnapshot.items.isEmpty { musicDiscoveryVideos = cachedSnapshot.items }

        guard !isRefreshingMusicDiscovery else {
            AppLog.search.debug("Music discovery refresh ignored because one is already running")
            return
        }

        isRefreshingMusicDiscovery = true
        let previousStatus = status
        defer {
            isRefreshingMusicDiscovery = false
            if status.contains("fallback") || status.contains("unavailable") {
                status = previousStatus
            }
        }

        let snapshot = await discoveryService.refreshDiscovery(.init(engine: engine, force: force, seedQueries: Self.musicDiscoverySeedQueries), currentItems: playbackHistory + results)
        musicDiscoveryVideos = snapshot.items
        applyRequestCountDeltas(snapshot.requestCountDeltas)
        AppLog.search.info("Music discovery refreshed; published=\(self.musicDiscoveryVideos.count, privacy: .public)")
    }

    var metadataCacheUsageBytes: Int {
        Self.defaultsDataSize(forKeys: [
            Self.searchCacheDefaultsKey,
            Self.musicDiscoveryDefaultsKey,
            Self.musicDiscoveryRefreshDefaultsKey,
            Self.playbackHistoryDefaultsKey
        ])
    }

    func clearMetadataCaches() {
        let previousBytes = metadataCacheUsageBytes
        let previousSearchCount = searchCache.count
        let previousDiscoveryCount = musicDiscoveryVideos.count
        searchService.clearSearchCache()
        discoveryService.clearDiscoveryCache()
        playlistService.clearPlaylistCache()
        searchCache.removeAll()
        playlistItemCache.removeAll()
        musicDiscoveryVideos = []
        lastMusicDiscoveryRefreshDate = nil
        UserDefaults.standard.removeObject(forKey: Self.searchCacheDefaultsKey)
        UserDefaults.standard.removeObject(forKey: Self.playlistItemCacheDefaultsKey)
        UserDefaults.standard.removeObject(forKey: Self.musicDiscoveryDefaultsKey)
        UserDefaults.standard.removeObject(forKey: Self.musicDiscoveryRefreshDefaultsKey)
        status = "Cleared local metadata cache."
        AppLog.cache.info("Metadata caches cleared; previous bytes=\(previousBytes, privacy: .public), search entries=\(previousSearchCount, privacy: .public), discovery entries=\(previousDiscoveryCount, privacy: .public)")
    }

    func compareProviders(query: String, preference: YouTubePlaybackPreference) async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            providerComparisons = []
            status = "Enter a search query to compare providers."
            return
        }
        guard !isComparingProviders else { return }

        let startedAt = Date()
        let requestCountsBefore = searchService.providerRequestCounts
        isComparingProviders = true
        defer { isComparingProviders = false }

        let comparisons = await searchService.compareProviders(query: trimmedQuery, preference: preference)
        providerComparisons = comparisons
        providerRequestCounts = searchService.providerRequestCounts
        providerComparisonRun = Self.makeComparisonRun(
            query: trimmedQuery,
            preference: preference,
            startedAt: startedAt,
            completedAt: Date(),
            comparisons: comparisons,
            requestCountsBefore: requestCountsBefore,
            requestCountsAfter: searchService.providerRequestCounts
        )
    }

    private static func makeComparisonRun(
        query: String,
        preference: YouTubePlaybackPreference,
        startedAt: Date,
        completedAt: Date,
        comparisons: [YouTubeProviderComparisonResult],
        requestCountsBefore: [String: Int],
        requestCountsAfter: [String: Int]
    ) -> ProviderComparisonRun {
        let deltas: [String: Int] = requestCountsAfter.reduce(into: [String: Int]()) { result, pair in
            let delta = pair.value - (requestCountsBefore[pair.key] ?? 0)
            if delta != 0 { result[pair.key] = delta }
        }
        let providerResults = comparisons.map { comparison in
            let requestKey: String = switch comparison.id {
            case .official: "official.search"
            case .experimental: "experimental.search"
            case .automatic: "automatic.search"
            }
            return ProviderComparisonProviderResult(
                id: comparison.id,
                title: comparison.title,
                status: comparison.items.isEmpty ? "No results" : comparison.status,
                itemCount: comparison.items.count,
                cacheState: comparison.cacheState.evidenceLabel,
                requestDelta: deltas[requestKey] ?? 0,
                errorMessage: comparison.errorMessage ?? (comparison.items.isEmpty ? comparison.status : nil),
                riskLabel: comparison.riskLabel,
                items: comparison.items
            )
        }
        return ProviderComparisonRun(
            id: "ytlab-\(Int(startedAt.timeIntervalSince1970))",
            query: query,
            preference: preference,
            startedAt: startedAt,
            completedAt: completedAt,
            providerResults: providerResults,
            requestCountDeltas: deltas
        )
    }

    func loadLibraryData() async {
        guard !isLoadingLibrary else {
            AppLog.playlist.debug("Library load ignored because another load is active")
            return
        }
        isLoadingLibrary = true
        AppLog.playlist.info("Library load started")
        defer { isLoadingLibrary = false }

        let snapshot = await playlistService.loadLibrary()
        applyLibrarySnapshot(snapshot)
        AppLog.playlist.info("Library load finished; activity=\(self.activityVideos.count, privacy: .public), playlists=\(self.playlists.count, privacy: .public), subscriptions=\(self.subscriptions.count, privacy: .public), warnings=\(snapshot.warnings.map(\.rawValue).joined(separator: ","), privacy: .public)")
    }

    func selectPlaylist(_ playlist: YouTubePlaylist) async {
        AppLog.playlist.info("Playlist selected; id=\(playlist.id, privacy: .public), title=\(playlist.snippet.title, privacy: .private)")
        applyLibrarySnapshot(await playlistService.selectPlaylist(playlist))
    }

    var canLoadMorePlaylistVideos: Bool {
        selectedPlaylist != nil && nextPlaylistPageToken != nil
    }

    func loadMorePlaylistVideos() async {
        guard let selectedPlaylist, let nextPlaylistPageToken else { return }
        AppLog.playlist.info("Playlist pagination started; id=\(selectedPlaylist.id, privacy: .public)")
        let snapshot = await playlistService.loadMorePlaylistItems(playlist: selectedPlaylist, pageToken: nextPlaylistPageToken)
        applyLibrarySnapshot(snapshot)
        AppLog.playlist.info("Playlist pagination finished; id=\(selectedPlaylist.id, privacy: .public), total=\(self.playlistVideos.count, privacy: .public), hasNext=\((self.nextPlaylistPageToken != nil).description, privacy: .public)")
    }

    func select(_ video: YouTubeVideoSearchResult) {
        let source = video.sourceLabel ?? (video.isSongLike ? "Music" : "YouTube")
        AppLog.playback.info("Selected video changed; id=\(video.id, privacy: .public), title=\(video.title, privacy: .private), source=\(source, privacy: .public)")
        selectedVideo = video
        selectedVideoDetails = nil
        status = ""
        Task { await loadVideoDetails(video) }
    }

    func select(_ video: YouTubeVideoSearchResult, queue: [YouTubeVideoSearchResult]) {
        adoptQueue(queue)
        select(video)
    }

    func play(_ video: YouTubeVideoSearchResult, queue: [YouTubeVideoSearchResult]) {
        self.queue = queue.deduplicatedByVideoID()
        skippedVideoIDs.removeAll()
        AppLog.playback.info("Now playing requested; id=\(video.id, privacy: .public), title=\(video.title, privacy: .private), queue=\(self.queue.count, privacy: .public)")
        recordPlayback(video)
        select(video)
    }

    func createDefaultPlaylist(adding video: YouTubeVideoSearchResult? = nil) async {
        guard !isCreatingPlaylist else {
            status = "Playlist creation is already in progress."
            AppLog.playlist.debug("Playlist creation ignored because one is already active")
            return
        }
        isCreatingPlaylist = true
        AppLog.playlist.info("Playlist creation started; adding video=\((video != nil).description, privacy: .public)")
        defer { isCreatingPlaylist = false }

        let result = await playlistService.createDefaultPlaylist(adding: video)
        applyPlaylistWriteResult(result)
        AppLog.playlist.info("Playlist creation finished; selected=\(self.selectedPlaylist?.id ?? "none", privacy: .public), total playlists=\(self.playlists.count, privacy: .public)")
    }

    func add(_ video: YouTubeVideoSearchResult, to playlist: YouTubePlaylist) async {
        AppLog.playlist.info("Playlist add started; video=\(video.id, privacy: .public), playlist=\(playlist.id, privacy: .public), title=\(playlist.snippet.title, privacy: .private)")

        applyPlaylistWriteResult(await playlistService.add(video, to: playlist))
        AppLog.playlist.info("Playlist add finished; video=\(video.id, privacy: .public), playlist=\(playlist.id, privacy: .public)")
    }

    func remove(_ video: YouTubeVideoSearchResult, from playlist: YouTubePlaylist) async {
        guard let playlistItemID = video.playlistItemID else {
            status = "This playlist item cannot be removed because the official item ID was not loaded yet."
            AppLog.playlist.warning("Playlist remove blocked because item id is missing; video=\(video.id, privacy: .public), playlist=\(playlist.id, privacy: .public)")
            return
        }
        AppLog.playlist.info("Playlist remove started; item=\(playlistItemID, privacy: .public), video=\(video.id, privacy: .public), playlist=\(playlist.id, privacy: .public), title=\(playlist.snippet.title, privacy: .private)")

        applyPlaylistWriteResult(await playlistService.remove(video, from: playlist))
        AppLog.playlist.info("Playlist remove finished; item=\(playlistItemID, privacy: .public), playlist=\(playlist.id, privacy: .public), remaining=\(self.playlistVideos.count, privacy: .public)")
    }

    func isAdding(_ video: YouTubeVideoSearchResult, to playlist: YouTubePlaylist) -> Bool {
        playlistService.isAdding(video, to: playlist)
    }

    func isRemoving(_ video: YouTubeVideoSearchResult) -> Bool {
        playlistService.isRemoving(video)
    }

    func addToQueue(_ video: YouTubeVideoSearchResult) {
        if queue.contains(where: { $0.id == video.id }) {
            status = "Already in queue."
            AppLog.playback.debug("Queue add ignored; already queued; id=\(video.id, privacy: .public)")
            return
        }
        queue.append(video)
        status = "Added to queue."
        AppLog.playback.info("Queue add; id=\(video.id, privacy: .public), queue=\(self.queue.count, privacy: .public)")
    }

    func removeFromQueue(_ video: YouTubeVideoSearchResult) {
        queue.removeAll { $0.id == video.id }
        if selectedVideo?.id == video.id {
            selectedVideo = queue.first
        }
        status = "Removed from queue."
        AppLog.playback.info("Queue remove; id=\(video.id, privacy: .public), queue=\(self.queue.count, privacy: .public), selected=\(self.selectedVideo?.id ?? "none", privacy: .public)")
    }

    func clearQueue() {
        let previousCount = queue.count
        queue.removeAll()
        status = "Queue cleared."
        AppLog.playback.info("Queue cleared; previous count=\(previousCount, privacy: .public)")
    }

    func restoreLastSelection(_ video: YouTubeVideoSearchResult) {
        guard selectedVideo == nil else { return }
        selectedVideo = video
        queue = [video]
        AppLog.playback.info("Restored last selection; id=\(video.id, privacy: .public), title=\(video.title, privacy: .private)")
    }

    var queuePositionText: String? {
        guard let selectedVideo, let index = queue.firstIndex(where: { $0.id == selectedVideo.id }), queue.count > 1 else { return nil }
        return "\(index + 1) of \(queue.count)"
    }

    var canPlayPrevious: Bool {
        guard let selectedVideo, let index = queue.firstIndex(where: { $0.id == selectedVideo.id }) else { return false }
        return index > 0
    }

    var canPlayNext: Bool {
        guard let selectedVideo, let index = queue.firstIndex(where: { $0.id == selectedVideo.id }) else { return false }
        return index < queue.count - 1
    }

    @discardableResult
    func playPrevious() -> YouTubeVideoSearchResult? {
        guard let selectedVideo, let index = queue.firstIndex(where: { $0.id == selectedVideo.id }), index > 0 else { return nil }
        let previousVideo = queue[index - 1]
        AppLog.playback.info("Queue previous; from=\(selectedVideo.id, privacy: .public), to=\(previousVideo.id, privacy: .public), position=\(index, privacy: .public)")
        recordPlayback(previousVideo)
        select(previousVideo)
        return previousVideo
    }

    @discardableResult
    func playNext() -> YouTubeVideoSearchResult? {
        guard let selectedVideo, let index = queue.firstIndex(where: { $0.id == selectedVideo.id }), index < queue.count - 1 else { return nil }
        let nextVideo = queue[index + 1]
        AppLog.playback.info("Queue next; from=\(selectedVideo.id, privacy: .public), to=\(nextVideo.id, privacy: .public), position=\(index + 2, privacy: .public)")
        recordPlayback(nextVideo)
        select(nextVideo)
        return nextVideo
    }

    @discardableResult
    func skipFailedSelectedVideo(reason: String) -> YouTubeVideoSearchResult? {
        guard let selectedVideo else { return nil }
        skippedVideoIDs.insert(selectedVideo.id)
        AppLog.playback.warning("Skipping failed selected video; id=\(selectedVideo.id, privacy: .public), reason=\(reason, privacy: .public)")

        guard let currentIndex = queue.firstIndex(where: { $0.id == selectedVideo.id }) else {
            status = "YouTube could not play this embed. Choose another result."
            return nil
        }

        let followingVideos = queue.suffix(from: min(currentIndex + 1, queue.count))
        if let replacement = followingVideos.first(where: { !skippedVideoIDs.contains($0.id) }) {
            status = "Skipped an unavailable YouTube embed."
            recordPlayback(replacement)
            select(replacement)
            return replacement
        }

        if let replacement = queue.first(where: { !skippedVideoIDs.contains($0.id) }) {
            status = "Skipped unavailable embeds and resumed from the queue."
            recordPlayback(replacement)
            select(replacement)
            return replacement
        }

        status = "YouTube could not play the queued embeds. Try another search result."
        return nil
    }

    private func adoptQueue(_ videos: [YouTubeVideoSearchResult]) {
        let deduplicatedVideos = videos.deduplicatedByVideoID()
        guard !deduplicatedVideos.isEmpty else { return }
        guard let selectedVideo else {
            queue = deduplicatedVideos
            return
        }
        if deduplicatedVideos.contains(where: { $0.id == selectedVideo.id }) {
            queue = deduplicatedVideos
        } else {
            queue = ([selectedVideo] + deduplicatedVideos).deduplicatedByVideoID()
        }
    }

    private func loadVideoDetails(_ video: YouTubeVideoSearchResult) async {
        do {
            guard let tokens = try await accountStore.loadFreshTokens() else { return }
            selectedVideoDetails = try await dataClient.videoDetails(videoID: video.id, accessToken: tokens.accessToken)
        } catch {
            selectedVideoDetails = nil
        }
    }

    private func recordPlayback(_ video: YouTubeVideoSearchResult) {
        playbackHistory = ([video] + playbackHistory)
            .deduplicatedByVideoID()
            .prefix(50)
            .map { $0 }
        Self.savePlaybackHistory(playbackHistory)
        rememberMusicDiscovery([video])
    }

    private func publishSearchPage(_ page: YouTubeVideoPage, query: String, preference: YouTubePlaybackPreference, engine: YouTubeMusicEngine, providerStatus: String) {
        lastSearchQuery = query
        lastSearchPreference = preference
        lastSearchEngine = engine
        nextSearchPageToken = page.nextPageToken
        results = page.items.deduplicatedByVideoID()
        let finalStatus = if results.isEmpty, preference == .songFirst {
            "No YouTube Music song results found. Switch to Video for clips."
        } else if results.isEmpty {
            "No playable YouTube results found."
        } else if !providerStatus.isEmpty {
            providerStatus
        } else {
            ""
        }
        adoptQueue(results)
        if selectedVideo == nil, let firstResult = results.first {
            select(firstResult)
        }
        status = finalStatus
    }

    private func publishSearchResult(_ result: YouTubeSearchServiceResult) {
        let providerStatus = result.status.message
        publishSearchPage(
            result.page,
            query: result.request.query,
            preference: result.request.preference,
            engine: result.request.engine,
            providerStatus: providerStatus
        )
        nextSearchPageToken = result.nextPageToken
    }

    private func applyLibrarySnapshot(_ snapshot: YouTubeLibrarySnapshot) {
        activityVideos = snapshot.activityVideos.deduplicatedByVideoID()
        playlists = snapshot.playlists.deduplicatedByPlaylistID()
        subscriptions = snapshot.subscriptions
        selectedPlaylist = snapshot.selectedPlaylist
        selectedPlaylistID = snapshot.selectedPlaylist?.id ?? selectedPlaylistID
        playlistVideos = snapshot.playlistVideos.deduplicatedByVideoID()
        nextPlaylistPageToken = snapshot.nextPlaylistPageToken
        if !playlistVideos.isEmpty { adoptQueue(playlistVideos) }
        applyRequestCountDeltas(snapshot.requestCountDeltas)
        if snapshot.warnings.count == 3, musicDiscoveryVideos.isEmpty, playbackHistory.isEmpty {
            status = "Connect Google to load account playlists, subscriptions, and activity."
        } else if snapshot.status != .ready, !snapshot.status.message.isEmpty {
            status = snapshot.status.message
        }
    }

    private func applyPlaylistWriteResult(_ result: YouTubePlaylistWriteResult) {
        playlists = result.playlists.deduplicatedByPlaylistID()
        selectedPlaylist = result.selectedPlaylist
        selectedPlaylistID = result.selectedPlaylist?.id ?? selectedPlaylistID
        playlistVideos = result.playlistVideos.deduplicatedByVideoID()
        nextPlaylistPageToken = result.nextPlaylistPageToken
        if !playlistVideos.isEmpty { adoptQueue(playlistVideos) }
        status = result.statusMessage
        applyRequestCountDeltas(result.requestCountDeltas)
    }

    private func applyRequestCountDeltas(_ deltas: [String: Int]) {
        for (key, value) in deltas {
            providerRequestCounts[key, default: 0] += value
        }
    }

    private func rememberMusicDiscovery(_ videos: [YouTubeVideoSearchResult]) {
        let musicItems = Self.musicItems(from: videos + musicDiscoveryVideos)
        guard !musicItems.isEmpty else { return }
        musicDiscoveryVideos = Array(musicItems.prefix(Self.musicDiscoveryLimit))
        Self.saveMusicDiscoveryVideos(musicDiscoveryVideos)
    }

    static func playlistStatusMessage(for error: Error) -> String {
        if let googleError = error as? GoogleOAuthError {
            switch googleError {
            case .missingRequiredScope:
                return "Reconnect Google to allow playlist changes."
            case .missingRefreshToken:
                return "Reconnect Google; the saved refresh token is missing."
            default:
                return googleError.localizedDescription
            }
        }

        if let dataError = error as? YouTubeDataError {
            switch dataError {
            case .authorizationExpired:
                return "Reconnect Google; YouTube authorization expired."
            case .quotaExceeded:
                return "YouTube API quota is exhausted. Try again later or use cached playlist data."
            case .requestFailed(let statusCode, let body):
                return "Playlist request failed (HTTP \(statusCode)): \(body)"
            case .invalidResponse:
                return "YouTube returned an invalid playlist response. Try again."
            }
        }

        return error.localizedDescription
    }

    private static func musicItems(from videos: [YouTubeVideoSearchResult]) -> [YouTubeVideoSearchResult] {
        let deduplicatedVideos = videos.deduplicatedByVideoID()
        let songLikeVideos = deduplicatedVideos.filter(\.isSongLike)
        return songLikeVideos.isEmpty ? deduplicatedVideos : songLikeVideos
    }

    private static func searchCacheKey(query: String, preference: YouTubePlaybackPreference, engine: YouTubeMusicEngine) -> String {
        "\(engine.rawValue)|\(preference.rawValue)|\(normalizedCacheQuery(query))"
    }

    private static func normalizedCacheQuery(_ query: String) -> String {
        query
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    private static func loadSearchCache() -> [String: YouTubeCachedSearchPage] {
        guard let data = UserDefaults.standard.data(forKey: searchCacheDefaultsKey) else { return [:] }
        return (try? JSONDecoder().decode([String: YouTubeCachedSearchPage].self, from: data)) ?? [:]
    }

    private static func saveSearchCache(_ cache: [String: YouTubeCachedSearchPage]) {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        UserDefaults.standard.set(data, forKey: searchCacheDefaultsKey)
    }

    private static func loadPlaylistItemCache() -> [String: YouTubeCachedPlaylistPage] {
        guard let data = UserDefaults.standard.data(forKey: playlistItemCacheDefaultsKey) else { return [:] }
        return (try? JSONDecoder().decode([String: YouTubeCachedPlaylistPage].self, from: data)) ?? [:]
    }

    private static func savePlaylistItemCache(_ cache: [String: YouTubeCachedPlaylistPage]) {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        UserDefaults.standard.set(data, forKey: playlistItemCacheDefaultsKey)
    }

    private static func loadMusicDiscoveryVideos() -> [YouTubeVideoSearchResult] {
        guard let data = UserDefaults.standard.data(forKey: musicDiscoveryDefaultsKey) else { return [] }
        return (try? JSONDecoder().decode([YouTubeVideoSearchResult].self, from: data)) ?? []
    }

    private static func saveMusicDiscoveryVideos(_ videos: [YouTubeVideoSearchResult]) {
        guard let data = try? JSONEncoder().encode(videos) else { return }
        UserDefaults.standard.set(data, forKey: musicDiscoveryDefaultsKey)
    }

    private static func loadMusicDiscoveryRefreshDate() -> Date? {
        let timeInterval = UserDefaults.standard.double(forKey: musicDiscoveryRefreshDefaultsKey)
        guard timeInterval > 0 else { return nil }
        return Date(timeIntervalSince1970: timeInterval)
    }

    private static func saveMusicDiscoveryRefreshDate(_ date: Date?) {
        guard let date else { return }
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: musicDiscoveryRefreshDefaultsKey)
    }

    private static func loadPlaybackHistory() -> [YouTubeVideoSearchResult] {
        guard let data = UserDefaults.standard.data(forKey: playbackHistoryDefaultsKey) else { return [] }
        return (try? JSONDecoder().decode([YouTubeVideoSearchResult].self, from: data)) ?? []
    }

    private static func savePlaybackHistory(_ history: [YouTubeVideoSearchResult]) {
        guard let data = try? JSONEncoder().encode(history) else { return }
        UserDefaults.standard.set(data, forKey: playbackHistoryDefaultsKey)
    }

    private static func defaultsDataSize(forKeys keys: [String]) -> Int {
        keys.reduce(0) { total, key in
            if let data = UserDefaults.standard.data(forKey: key) {
                return total + data.count
            }
            if UserDefaults.standard.object(forKey: key) != nil {
                return total + MemoryLayout<Double>.size
            }
            return total
        }
    }
}
