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
    @Published private(set) var isComparingProviders = false
    @Published private(set) var musicDiscoveryVideos: [YouTubeVideoSearchResult] = []
    @Published private(set) var isRefreshingMusicDiscovery = false
    @Published private(set) var isCreatingPlaylist = false
    @Published private(set) var activePlaylistWriteIDs = Set<String>()
    @Published private(set) var activePlaylistDeleteIDs = Set<String>()
    @Published private(set) var providerRequestCounts: [String: Int] = [:]

    private let accountStore: any YouTubeAccountTokenProviding
    private let dataClient: any YouTubeOfficialProviding
    private let innerTubeClient: any YouTubeMusicMetadataProviding
    private let discoveryCoalescer: RequestCoalescer<String>
    private var lastSearchQuery = ""
    private var lastSearchPreference: YouTubePlaybackPreference = .songFirst
    private var lastSearchEngine: YouTubeMusicEngine = .automatic
    private var nextSearchPageToken: String?
    private var nextPlaylistPageToken: String?
    private var skippedVideoIDs = Set<String>()
    private var searchCache: [String: CachedYouTubeSearchPage] = [:]
    private var playlistItemCache: [String: CachedYouTubePlaylistPage] = [:]
    private var activeSearchKey: String?
    private var lastSearchSubmittedAtByKey: [String: Date] = [:]
    private var lastMusicDiscoveryRefreshDate: Date?
    private var selectedPlaylistID: String?

    init(
        accountStore: any YouTubeAccountTokenProviding = GoogleAccountStore(),
        dataClient: any YouTubeOfficialProviding = YouTubeDataClient(),
        innerTubeClient: any YouTubeMusicMetadataProviding = YouTubeMusicInnerTubeClient(),
        discoveryCoalescer: RequestCoalescer<String> = RequestCoalescer()
    ) {
        self.accountStore = accountStore
        self.dataClient = dataClient
        self.innerTubeClient = innerTubeClient
        self.discoveryCoalescer = discoveryCoalescer
        searchCache = Self.loadSearchCache()
        playlistItemCache = Self.loadPlaylistItemCache()
        playbackHistory = Self.loadPlaybackHistory()
        musicDiscoveryVideos = Self.loadMusicDiscoveryVideos()
        lastMusicDiscoveryRefreshDate = Self.loadMusicDiscoveryRefreshDate()
        selectedPlaylistID = UserDefaults.standard.string(forKey: Self.selectedPlaylistIDDefaultsKey)
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
        let cachedPage = searchCache[cacheKey]
        if let cachedPage, !cachedPage.items.isEmpty {
            AppLog.search.info("Publishing cached search page; query=\(trimmedQuery, privacy: .private), engine=\(engine.rawValue, privacy: .public), preference=\(preference.rawValue, privacy: .public), items=\(cachedPage.items.count, privacy: .public)")
            publishSearchPage(cachedPage.page, query: trimmedQuery, preference: preference, engine: engine, providerStatus: "")
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
        status = ""
        AppLog.search.info("Search started; query=\(trimmedQuery, privacy: .private), engine=\(engine.rawValue, privacy: .public), preference=\(preference.rawValue, privacy: .public), hadCache=\((cachedPage != nil).description, privacy: .public)")
        defer {
            isSearching = false
            if activeSearchKey == cacheKey {
                activeSearchKey = nil
            }
            AppLog.search.info("Search finished; query=\(trimmedQuery, privacy: .private), result count=\(self.results.count, privacy: .public), status=\(self.status, privacy: .public)")
        }

        do {
            let page = try await searchPage(query: trimmedQuery, preference: preference, engine: engine)
            let providerStatus = status
            cache(page, key: cacheKey)
            publishSearchPage(page, query: trimmedQuery, preference: preference, engine: engine, providerStatus: providerStatus)
            rememberMusicDiscovery(page.items)
        } catch {
            if let cachedPage, !cachedPage.items.isEmpty {
                publishSearchPage(cachedPage.page, query: trimmedQuery, preference: preference, engine: engine, providerStatus: "")
                status = "Showing cached YouTube Music results while the provider refresh is unavailable."
                AppLog.search.warning("Search provider failed; served cached results for query=\(trimmedQuery, privacy: .private): \(error.localizedDescription, privacy: .public)")
            } else {
                status = Self.providerStatusMessage(for: error)
                results = []
                AppLog.search.error("Search failed without cache; query=\(trimmedQuery, privacy: .private): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    var canLoadMoreSearchResults: Bool {
        nextSearchPageToken != nil && !lastSearchQuery.isEmpty
    }

    func loadMoreSearchResults() async {
        guard let nextSearchPageToken else { return }
        do {
            guard let tokens = try await accountStore.loadFreshTokens() else {
                status = "Connect Google to search YouTube Music."
                return
            }

            let page = try await dataClient.searchVideoPage(
                query: lastSearchQuery,
                accessToken: tokens.accessToken,
                maxResults: 12,
                preference: lastSearchPreference,
                pageToken: nextSearchPageToken
            )
            self.nextSearchPageToken = page.nextPageToken
            results.append(contentsOf: page.items.filter { pageItem in !results.contains { $0.id == pageItem.id } })
            results = results.deduplicatedByVideoID()
            cache(YouTubeVideoPage(items: results, nextPageToken: page.nextPageToken), key: Self.searchCacheKey(query: lastSearchQuery, preference: lastSearchPreference, engine: lastSearchEngine))
            rememberMusicDiscovery(results)
            adoptQueue(results)
        } catch {
            status = Self.providerStatusMessage(for: error)
        }
    }

    func refreshMusicDiscovery(engine: YouTubeMusicEngine, force: Bool = false) async {
        AppLog.search.info("Music discovery refresh requested; engine=\(engine.rawValue, privacy: .public), force=\(force.description, privacy: .public), existing=\(self.musicDiscoveryVideos.count, privacy: .public)")
        publishCachedMusicDiscovery(engine: engine)

        if !force,
           let lastMusicDiscoveryRefreshDate,
           Date().timeIntervalSince(lastMusicDiscoveryRefreshDate) < Self.musicDiscoveryRefreshInterval,
           !musicDiscoveryVideos.isEmpty {
            AppLog.search.info("Music discovery refresh skipped because cached data is fresh; count=\(self.musicDiscoveryVideos.count, privacy: .public)")
            return
        }
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

        async let firstSeed = discoveryItems(query: Self.musicDiscoverySeedQueries[0], engine: engine)
        async let secondSeed = discoveryItems(query: Self.musicDiscoverySeedQueries[1], engine: engine)
        async let thirdSeed = discoveryItems(query: Self.musicDiscoverySeedQueries[2], engine: engine)

        let (firstItems, secondItems, thirdItems) = await (firstSeed, secondSeed, thirdSeed)
        let fetchedItems = firstItems + secondItems + thirdItems
        guard !fetchedItems.isEmpty else { return }

        let refreshedItems = Self.musicItems(from: playbackHistory + results + fetchedItems + musicDiscoveryVideos)
        guard !refreshedItems.isEmpty else {
            AppLog.search.warning("Music discovery refresh produced no music items")
            return
        }
        musicDiscoveryVideos = Array(refreshedItems.prefix(Self.musicDiscoveryLimit))
        lastMusicDiscoveryRefreshDate = Date()
        Self.saveMusicDiscoveryVideos(musicDiscoveryVideos)
        Self.saveMusicDiscoveryRefreshDate(lastMusicDiscoveryRefreshDate)
        AppLog.search.info("Music discovery refreshed; fetched=\(fetchedItems.count, privacy: .public), published=\(self.musicDiscoveryVideos.count, privacy: .public)")
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
        searchCache.removeAll()
        musicDiscoveryVideos = []
        lastMusicDiscoveryRefreshDate = nil
        UserDefaults.standard.removeObject(forKey: Self.searchCacheDefaultsKey)
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

        isComparingProviders = true
        defer { isComparingProviders = false }

        var comparisons: [YouTubeProviderComparisonResult] = []

        do {
            let officialPage = try await officialSearchPage(query: trimmedQuery, preference: preference)
            comparisons.append(.init(id: .official, title: "Official", status: "\(officialPage.items.count) results", items: officialPage.items))
        } catch {
            comparisons.append(.init(id: .official, title: "Official", status: error.localizedDescription, items: []))
        }

        do {
            let experimentalItems = try await innerTubeClient.search(query: trimmedQuery, preference: preference, maxResults: 12)
            comparisons.append(.init(id: .experimental, title: "Experimental", status: "\(experimentalItems.count) music results", items: experimentalItems))
        } catch {
            comparisons.append(.init(id: .experimental, title: "Experimental", status: error.localizedDescription, items: []))
        }

        providerComparisons = comparisons
    }

    private func searchPage(query: String, preference: YouTubePlaybackPreference, engine: YouTubeMusicEngine) async throws -> YouTubeVideoPage {
        AppLog.search.debug("Resolving search provider; engine=\(engine.rawValue, privacy: .public), preference=\(preference.rawValue, privacy: .public), query=\(query, privacy: .private)")
        switch engine {
        case .official:
            return try await officialSearchPage(query: query, preference: preference)
        case .experimental:
            return try await experimentalSearchPage(query: query, preference: preference, allowsFallback: true)
        case .automatic:
            do {
                return try await officialSearchPage(query: query, preference: preference)
            } catch {
                AppLog.search.warning("Official search failed in automatic mode; considering fallback: \(error.localizedDescription, privacy: .public)")
                guard preference == .songFirst || preference == .balanced else {
                    throw YouTubeMusicProviderError.officialRequiredForVideo
                }
                let fallbackPage = try await experimentalSearchPage(query: query, preference: preference, allowsFallback: false)
                status = "Official YouTube API was unavailable; using no-cookie YouTube Music metadata fallback."
                AppLog.search.warning("Automatic search used experimental fallback; items=\(fallbackPage.items.count, privacy: .public)")
                return fallbackPage
            }
        }
    }

    private func officialSearchPage(query: String, preference: YouTubePlaybackPreference) async throws -> YouTubeVideoPage {
        guard let tokens = try await accountStore.loadFreshTokens() else {
            AppLog.auth.warning("Official search requested without fresh Google tokens")
            throw YouTubeMusicProviderError.connectGoogle
        }
        recordProviderRequest("official.search")
        AppLog.search.info("Official YouTube search request; query=\(query, privacy: .private), preference=\(preference.rawValue, privacy: .public)")
        let page = try await dataClient.searchVideoPage(query: query, accessToken: tokens.accessToken, preference: preference)
        AppLog.search.info("Official YouTube search response; query=\(query, privacy: .private), items=\(page.items.count, privacy: .public), hasNext=\((page.nextPageToken != nil).description, privacy: .public)")
        return page
    }

    private func experimentalSearchPage(query: String, preference: YouTubePlaybackPreference, allowsFallback: Bool) async throws -> YouTubeVideoPage {
        do {
            recordProviderRequest("experimental.search")
            AppLog.search.info("Experimental YouTube Music search request; query=\(query, privacy: .private), preference=\(preference.rawValue, privacy: .public), allowsFallback=\(allowsFallback.description, privacy: .public)")
            let items = try await innerTubeClient.search(query: query, preference: preference, maxResults: 12)
            guard !items.isEmpty else { throw YouTubeMusicProviderError.noExperimentalResults }
            status = ""
            AppLog.search.info("Experimental YouTube Music search response; query=\(query, privacy: .private), items=\(items.count, privacy: .public)")
            return YouTubeVideoPage(items: items, nextPageToken: nil)
        } catch {
            guard allowsFallback else { throw error }
            AppLog.search.warning("Experimental search failed; falling back to official: \(error.localizedDescription, privacy: .public)")
            let officialPage = try await officialSearchPage(query: query, preference: preference)
            status = "Experimental YouTube Music metadata was unavailable; using official fallback."
            return officialPage
        }
    }

    func loadLibraryData() async {
        guard !isLoadingLibrary else {
            AppLog.playlist.debug("Library load ignored because another load is active")
            return
        }
        isLoadingLibrary = true
        AppLog.playlist.info("Library load started")
        defer { isLoadingLibrary = false }

        do {
            guard let tokens = try await accountStore.loadFreshTokens() else {
                AppLog.auth.warning("Library load requested without fresh Google tokens")
                return
            }
            var libraryWarnings: [String] = []

            async let activityResult = fetchRecentActivity(accessToken: tokens.accessToken)
            async let playlistsResult = fetchPlaylists(accessToken: tokens.accessToken)
            async let subscriptionsResult = fetchSubscriptions(accessToken: tokens.accessToken)

            let (activityAttempt, playlistsAttempt, subscriptionsAttempt) = await (activityResult, playlistsResult, subscriptionsResult)

            switch activityAttempt {
            case .success(let videos):
                activityVideos = videos.deduplicatedByVideoID()
            case .failure:
                activityVideos = []
                libraryWarnings.append("activity")
            }

            switch playlistsAttempt {
            case .success(let loadedPlaylists):
                playlists = loadedPlaylists
                restoreSelectedPlaylistIfPossible()
            case .failure:
                playlists = []
                libraryWarnings.append("playlists")
            }

            switch subscriptionsAttempt {
            case .success(let loadedSubscriptions):
                subscriptions = loadedSubscriptions
            case .failure:
                subscriptions = []
                libraryWarnings.append("subscriptions")
            }

            if let selectedPlaylist {
                try await loadPlaylist(selectedPlaylist, accessToken: tokens.accessToken)
            }
            if libraryWarnings.count == 3, musicDiscoveryVideos.isEmpty, playbackHistory.isEmpty {
                status = "Connect Google to load account playlists, subscriptions, and activity."
            }
            AppLog.playlist.info("Library load finished; activity=\(self.activityVideos.count, privacy: .public), playlists=\(self.playlists.count, privacy: .public), subscriptions=\(self.subscriptions.count, privacy: .public), warnings=\(libraryWarnings.joined(separator: ","), privacy: .public)")
        } catch {
            if musicDiscoveryVideos.isEmpty, playbackHistory.isEmpty {
                status = "Connect Google to load account playlists, subscriptions, and activity."
            }
            AppLog.playlist.error("Library load failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func selectPlaylist(_ playlist: YouTubePlaylist) async {
        AppLog.playlist.info("Playlist selected; id=\(playlist.id, privacy: .public), title=\(playlist.snippet.title, privacy: .private)")
        do {
            guard let tokens = try await accountStore.loadFreshTokens() else {
                AppLog.auth.warning("Playlist selection requested without fresh Google tokens")
                return
            }
            try await loadPlaylist(playlist, accessToken: tokens.accessToken)
        } catch {
            status = Self.playlistStatusMessage(for: error)
            AppLog.playlist.error("Playlist selection failed; id=\(playlist.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private func loadPlaylist(_ playlist: YouTubePlaylist, accessToken: String) async throws {
        AppLog.playlist.info("Playlist load started; id=\(playlist.id, privacy: .public), title=\(playlist.snippet.title, privacy: .private)")
        selectedPlaylist = playlist
        selectedPlaylistID = playlist.id
        UserDefaults.standard.set(playlist.id, forKey: Self.selectedPlaylistIDDefaultsKey)
        if let cachedPage = playlistItemCache[playlist.id] {
            playlistVideos = cachedPage.items
            nextPlaylistPageToken = cachedPage.nextPageToken
            AppLog.playlist.info("Playlist cache published; id=\(playlist.id, privacy: .public), cached items=\(cachedPage.items.count, privacy: .public), hasNext=\((cachedPage.nextPageToken != nil).description, privacy: .public)")
        }
        let page = try await dataClient.playlistItemPage(playlistID: playlist.id, accessToken: accessToken)
        playlistVideos = page.items
        nextPlaylistPageToken = page.nextPageToken
        cachePlaylist(page: page, playlistID: playlist.id)
        adoptQueue(playlistVideos)
        AppLog.playlist.info("Playlist load finished; id=\(playlist.id, privacy: .public), items=\(page.items.count, privacy: .public), hasNext=\((page.nextPageToken != nil).description, privacy: .public)")
    }

    var canLoadMorePlaylistVideos: Bool {
        selectedPlaylist != nil && nextPlaylistPageToken != nil
    }

    func loadMorePlaylistVideos() async {
        guard let selectedPlaylist, let nextPlaylistPageToken else { return }
        AppLog.playlist.info("Playlist pagination started; id=\(selectedPlaylist.id, privacy: .public)")
        do {
            guard let tokens = try await accountStore.loadFreshTokens() else {
                AppLog.auth.warning("Playlist pagination requested without fresh Google tokens")
                return
            }
            let page = try await dataClient.playlistItemPage(
                playlistID: selectedPlaylist.id,
                accessToken: tokens.accessToken,
                maxResults: 25,
                pageToken: nextPlaylistPageToken
            )
            self.nextPlaylistPageToken = page.nextPageToken
            playlistVideos.append(contentsOf: page.items.filter { pageItem in !playlistVideos.contains { $0.stableListID == pageItem.stableListID } })
            cachePlaylist(page: YouTubeVideoPage(items: playlistVideos, nextPageToken: page.nextPageToken), playlistID: selectedPlaylist.id)
            adoptQueue(playlistVideos)
            AppLog.playlist.info("Playlist pagination finished; id=\(selectedPlaylist.id, privacy: .public), added=\(page.items.count, privacy: .public), total=\(self.playlistVideos.count, privacy: .public), hasNext=\((page.nextPageToken != nil).description, privacy: .public)")
        } catch {
            status = Self.playlistStatusMessage(for: error)
            AppLog.playlist.error("Playlist pagination failed; id=\(selectedPlaylist.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
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

        do {
            guard let tokens = try await accountStore.loadFreshTokens(requiredScope: Self.youtubeWriteScope) else {
                status = "Connect Google to create YouTube Music playlists."
                AppLog.auth.warning("Playlist creation requested without write-scope tokens")
                return
            }
            let playlist = try await dataClient.createPlaylist(
                title: "Saved Songs",
                description: "Created from the Music app using the official YouTube playlist API.",
                privacyStatus: .private,
                accessToken: tokens.accessToken
            )
            playlists = ([playlist] + playlists).deduplicatedByPlaylistID()
            selectedPlaylist = playlist
            selectedPlaylistID = playlist.id
            UserDefaults.standard.set(playlist.id, forKey: Self.selectedPlaylistIDDefaultsKey)
            playlistVideos = []
            nextPlaylistPageToken = nil
            if let video {
                let writeID = Self.playlistWriteID(videoID: video.id, playlistID: playlist.id)
                guard activePlaylistWriteIDs.insert(writeID).inserted else {
                    status = "Already adding this song."
                    AppLog.playlist.debug("Playlist creation add skipped; video already active; video=\(video.id, privacy: .public), playlist=\(playlist.id, privacy: .public)")
                    return
                }
                defer { activePlaylistWriteIDs.remove(writeID) }
                AppLog.playlist.info("Adding initial video to newly created playlist; video=\(video.id, privacy: .public), playlist=\(playlist.id, privacy: .public)")
                _ = try await dataClient.addVideoToPlaylist(videoID: video.id, playlistID: playlist.id, accessToken: tokens.accessToken)
                try await loadPlaylist(playlist, accessToken: tokens.accessToken)
                status = "Created private playlist and added song."
            } else {
                status = "Created private YouTube Music playlist."
            }
            playlists = try await dataClient.playlists(accessToken: tokens.accessToken).deduplicatedByPlaylistID()
            restoreSelectedPlaylistIfPossible()
            AppLog.playlist.info("Playlist creation finished; id=\(playlist.id, privacy: .public), total playlists=\(self.playlists.count, privacy: .public)")
        } catch {
            status = Self.playlistStatusMessage(for: error)
            AppLog.playlist.error("Playlist creation failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func add(_ video: YouTubeVideoSearchResult, to playlist: YouTubePlaylist) async {
        let writeID = Self.playlistWriteID(videoID: video.id, playlistID: playlist.id)
        guard activePlaylistWriteIDs.insert(writeID).inserted else {
            status = "Already adding this song."
            AppLog.playlist.debug("Playlist add ignored because operation is already active; video=\(video.id, privacy: .public), playlist=\(playlist.id, privacy: .public)")
            return
        }
        defer { activePlaylistWriteIDs.remove(writeID) }

        AppLog.playlist.info("Playlist add started; video=\(video.id, privacy: .public), playlist=\(playlist.id, privacy: .public), title=\(playlist.snippet.title, privacy: .private)")

        do {
            guard let tokens = try await accountStore.loadFreshTokens(requiredScope: Self.youtubeWriteScope) else {
                status = "Connect Google to add songs to YouTube Music playlists."
                AppLog.auth.warning("Playlist add requested without write-scope tokens")
                return
            }
            _ = try await dataClient.addVideoToPlaylist(videoID: video.id, playlistID: playlist.id, accessToken: tokens.accessToken)
            status = "Added to \(playlist.snippet.title)."
            if selectedPlaylist?.id == playlist.id {
                try await loadPlaylist(playlist, accessToken: tokens.accessToken)
            } else {
                playlistItemCache.removeValue(forKey: playlist.id)
                Self.savePlaylistItemCache(playlistItemCache)
            }
            AppLog.playlist.info("Playlist add finished; video=\(video.id, privacy: .public), playlist=\(playlist.id, privacy: .public)")
        } catch {
            status = Self.playlistStatusMessage(for: error)
            AppLog.playlist.error("Playlist add failed; video=\(video.id, privacy: .public), playlist=\(playlist.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    func remove(_ video: YouTubeVideoSearchResult, from playlist: YouTubePlaylist) async {
        guard let playlistItemID = video.playlistItemID else {
            status = "This playlist item cannot be removed because the official item ID was not loaded yet."
            AppLog.playlist.warning("Playlist remove blocked because item id is missing; video=\(video.id, privacy: .public), playlist=\(playlist.id, privacy: .public)")
            return
        }
        guard activePlaylistDeleteIDs.insert(playlistItemID).inserted else {
            status = "Already removing this song."
            AppLog.playlist.debug("Playlist remove ignored because operation is already active; item=\(playlistItemID, privacy: .public), playlist=\(playlist.id, privacy: .public)")
            return
        }
        defer { activePlaylistDeleteIDs.remove(playlistItemID) }

        AppLog.playlist.info("Playlist remove started; item=\(playlistItemID, privacy: .public), video=\(video.id, privacy: .public), playlist=\(playlist.id, privacy: .public), title=\(playlist.snippet.title, privacy: .private)")

        do {
            guard let tokens = try await accountStore.loadFreshTokens(requiredScope: Self.youtubeWriteScope) else {
                status = "Connect Google to remove songs from YouTube Music playlists."
                AppLog.auth.warning("Playlist remove requested without write-scope tokens")
                return
            }
            try await dataClient.deletePlaylistItem(playlistItemID: playlistItemID, accessToken: tokens.accessToken)
            playlistVideos.removeAll { $0.playlistItemID == playlistItemID }
            cachePlaylist(page: YouTubeVideoPage(items: playlistVideos, nextPageToken: nextPlaylistPageToken), playlistID: playlist.id)
            playlists = try await dataClient.playlists(accessToken: tokens.accessToken).deduplicatedByPlaylistID()
            restoreSelectedPlaylistIfPossible()
            adoptQueue(playlistVideos)
            status = "Removed from \(playlist.snippet.title)."
            AppLog.playlist.info("Playlist remove finished; item=\(playlistItemID, privacy: .public), playlist=\(playlist.id, privacy: .public), remaining=\(self.playlistVideos.count, privacy: .public)")
        } catch {
            status = Self.playlistStatusMessage(for: error)
            AppLog.playlist.error("Playlist remove failed; item=\(playlistItemID, privacy: .public), playlist=\(playlist.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    func isAdding(_ video: YouTubeVideoSearchResult, to playlist: YouTubePlaylist) -> Bool {
        activePlaylistWriteIDs.contains(Self.playlistWriteID(videoID: video.id, playlistID: playlist.id))
    }

    func isRemoving(_ video: YouTubeVideoSearchResult) -> Bool {
        guard let playlistItemID = video.playlistItemID else { return false }
        return activePlaylistDeleteIDs.contains(playlistItemID)
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

    private func discoveryItems(query: String, engine: YouTubeMusicEngine) async -> [YouTubeVideoSearchResult] {
        let cacheKey = Self.searchCacheKey(query: query, preference: .songFirst, engine: engine)
        guard await discoveryCoalescer.begin(cacheKey) else {
            return searchCache[cacheKey]?.items ?? []
        }
        defer {
            Task { await discoveryCoalescer.end(cacheKey) }
        }
        do {
            let page = try await searchPage(query: query, preference: .songFirst, engine: engine)
            cache(page, key: cacheKey)
            return page.items
        } catch {
            return searchCache[cacheKey]?.items ?? []
        }
    }

    private func publishCachedMusicDiscovery(engine: YouTubeMusicEngine) {
        let cachedSeedItems = Self.musicDiscoverySeedQueries.flatMap { seed -> [YouTubeVideoSearchResult] in
            searchCache[Self.searchCacheKey(query: seed, preference: .songFirst, engine: engine)]?.items ?? []
        }
        let items = Self.musicItems(from: playbackHistory + results + musicDiscoveryVideos + cachedSeedItems)
        guard !items.isEmpty else { return }
        musicDiscoveryVideos = Array(items.prefix(Self.musicDiscoveryLimit))
    }

    private func rememberMusicDiscovery(_ videos: [YouTubeVideoSearchResult]) {
        let musicItems = Self.musicItems(from: videos + musicDiscoveryVideos)
        guard !musicItems.isEmpty else { return }
        musicDiscoveryVideos = Array(musicItems.prefix(Self.musicDiscoveryLimit))
        Self.saveMusicDiscoveryVideos(musicDiscoveryVideos)
    }

    private func cache(_ page: YouTubeVideoPage, key: String) {
        guard !page.items.isEmpty else { return }
        searchCache[key] = CachedYouTubeSearchPage(items: page.items.deduplicatedByVideoID(), nextPageToken: page.nextPageToken, updatedAt: Date())
        if searchCache.count > Self.searchCacheLimit {
            let keysToKeep = Set(searchCache.sorted { $0.value.updatedAt > $1.value.updatedAt }.prefix(Self.searchCacheLimit).map { $0.key })
            searchCache = searchCache.filter { keysToKeep.contains($0.key) }
        }
        Self.saveSearchCache(searchCache)
    }

    private func cachePlaylist(page: YouTubeVideoPage, playlistID: String) {
        playlistItemCache[playlistID] = CachedYouTubePlaylistPage(items: page.items.deduplicatedByVideoID(), nextPageToken: page.nextPageToken, updatedAt: Date())
        if playlistItemCache.count > Self.playlistItemCacheLimit {
            let keysToKeep = Set(playlistItemCache.sorted { $0.value.updatedAt > $1.value.updatedAt }.prefix(Self.playlistItemCacheLimit).map { $0.key })
            playlistItemCache = playlistItemCache.filter { keysToKeep.contains($0.key) }
        }
        Self.savePlaylistItemCache(playlistItemCache)
    }

    private func fetchRecentActivity(accessToken: String) async -> Result<[YouTubeVideoSearchResult], Error> {
        do {
            recordProviderRequest("official.activity")
            return .success(try await dataClient.recentActivityVideos(accessToken: accessToken))
        } catch {
            return .failure(error)
        }
    }

    private func fetchPlaylists(accessToken: String) async -> Result<[YouTubePlaylist], Error> {
        do {
            recordProviderRequest("official.playlists")
            return .success(try await dataClient.playlists(accessToken: accessToken))
        } catch {
            return .failure(error)
        }
    }

    private func fetchSubscriptions(accessToken: String) async -> Result<[YouTubeSubscription], Error> {
        do {
            recordProviderRequest("official.subscriptions")
            return .success(try await dataClient.subscriptions(accessToken: accessToken))
        } catch {
            return .failure(error)
        }
    }

    private func restoreSelectedPlaylistIfPossible() {
        guard selectedPlaylist == nil,
              let selectedPlaylistID,
              let restoredPlaylist = playlists.first(where: { $0.id == selectedPlaylistID }) else { return }
        selectedPlaylist = restoredPlaylist
    }

    private static func playlistWriteID(videoID: String, playlistID: String) -> String {
        "\(playlistID)|\(videoID)"
    }

    private func recordProviderRequest(_ key: String) {
        providerRequestCounts[key, default: 0] += 1
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

    private static func providerStatusMessage(for error: Error) -> String {
        if error is DecodingError {
            return "Some YouTube account data was missing or changed shape. Showing cached source data where available."
        }
        if let dataError = error as? YouTubeDataError {
            switch dataError {
            case .authorizationExpired:
                return "Reconnect Google; YouTube authorization expired."
            case .quotaExceeded:
                return "YouTube API quota is exhausted. Try cached results or search again later."
            case .requestFailed(let statusCode, let body):
                return "YouTube request failed (HTTP \(statusCode)): \(body)"
            case .invalidResponse:
                return "YouTube returned an invalid response. Try again."
            }
        }
        return error.localizedDescription
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

    private static func loadSearchCache() -> [String: CachedYouTubeSearchPage] {
        guard let data = UserDefaults.standard.data(forKey: searchCacheDefaultsKey) else { return [:] }
        return (try? JSONDecoder().decode([String: CachedYouTubeSearchPage].self, from: data)) ?? [:]
    }

    private static func saveSearchCache(_ cache: [String: CachedYouTubeSearchPage]) {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        UserDefaults.standard.set(data, forKey: searchCacheDefaultsKey)
    }

    private static func loadPlaylistItemCache() -> [String: CachedYouTubePlaylistPage] {
        guard let data = UserDefaults.standard.data(forKey: playlistItemCacheDefaultsKey) else { return [:] }
        return (try? JSONDecoder().decode([String: CachedYouTubePlaylistPage].self, from: data)) ?? [:]
    }

    private static func savePlaylistItemCache(_ cache: [String: CachedYouTubePlaylistPage]) {
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

private struct CachedYouTubeSearchPage: Codable, Equatable {
    let items: [YouTubeVideoSearchResult]
    let nextPageToken: String?
    let updatedAt: Date

    var page: YouTubeVideoPage {
        YouTubeVideoPage(items: items, nextPageToken: nextPageToken)
    }
}

private struct CachedYouTubePlaylistPage: Codable, Equatable {
    let items: [YouTubeVideoSearchResult]
    let nextPageToken: String?
    let updatedAt: Date
}

private enum YouTubeMusicProviderError: LocalizedError {
    case connectGoogle
    case noExperimentalResults
    case officialRequiredForVideo

    var errorDescription: String? {
        switch self {
        case .connectGoogle:
            "Connect Google to use the official YouTube Music fallback."
        case .noExperimentalResults:
            "Experimental YouTube Music metadata returned no results."
        case .officialRequiredForVideo:
            "Official YouTube API is unavailable. Experimental fallback is only available in Music or Mixed result modes."
        }
    }
}