import Foundation

@MainActor
final class YouTubePlaylistService: YouTubePlaylistServicing {
    private static let youtubeWriteScope = "https://www.googleapis.com/auth/youtube"

    private let accountStore: any YouTubeAccountTokenProviding
    private let dataClient: any YouTubeOfficialProviding
    private let selectedPlaylistDefaultsKey: String
    private let playlistItemCacheDefaultsKey: String
    private let playlistItemCacheLimit: Int
    private var playlistItemCache: [String: YouTubeCachedPlaylistPage]
    private var playlists: [YouTubePlaylist] = []
    private var selectedPlaylist: YouTubePlaylist?
    private var selectedPlaylistID: String?
    private var playlistVideos: [YouTubeVideoSearchResult] = []
    private var nextPlaylistPageToken: String?
    private var activePlaylistWriteIDs = Set<String>()
    private var activePlaylistDeleteIDs = Set<String>()
    private var providerRequestCounts: [String: Int] = [:]

    init(
        accountStore: any YouTubeAccountTokenProviding,
        dataClient: any YouTubeOfficialProviding,
        selectedPlaylistDefaultsKey: String,
        playlistItemCacheDefaultsKey: String,
        playlistItemCacheLimit: Int,
        initialCache: [String: YouTubeCachedPlaylistPage] = [:]
    ) {
        self.accountStore = accountStore
        self.dataClient = dataClient
        self.selectedPlaylistDefaultsKey = selectedPlaylistDefaultsKey
        self.playlistItemCacheDefaultsKey = playlistItemCacheDefaultsKey
        self.playlistItemCacheLimit = playlistItemCacheLimit
        playlistItemCache = initialCache
        selectedPlaylistID = UserDefaults.standard.string(forKey: selectedPlaylistDefaultsKey)
    }

    func loadLibrary() async -> YouTubeLibrarySnapshot {
        let before = providerRequestCounts
        do {
            guard let tokens = try await accountStore.loadFreshTokens() else {
                return snapshot(warnings: [.activity, .playlists, .subscriptions], status: .connectRequired, requestCountDeltas: deltas(since: before))
            }
            async let activity = fetchRecentActivity(accessToken: tokens.accessToken)
            async let playlistList = fetchPlaylists(accessToken: tokens.accessToken)
            async let subscriptionList = fetchSubscriptions(accessToken: tokens.accessToken)
            let (activityResult, playlistsResult, subscriptionsResult) = await (activity, playlistList, subscriptionList)

            var warnings = Set<YouTubeLibraryWarning>()
            let activityVideos = (try? activityResult.get())?.deduplicatedByVideoID() ?? []
            if activityVideos.isEmpty, case .failure = activityResult { warnings.insert(.activity) }
            playlists = (try? playlistsResult.get()) ?? []
            if playlists.isEmpty, case .failure = playlistsResult { warnings.insert(.playlists) }
            let subscriptions = (try? subscriptionsResult.get()) ?? []
            if subscriptions.isEmpty, case .failure = subscriptionsResult { warnings.insert(.subscriptions) }
            restoreSelectedPlaylistIfPossible()
            if let selectedPlaylist {
                let selectedSnapshot = await selectPlaylist(selectedPlaylist)
                return YouTubeLibrarySnapshot(activityVideos: activityVideos, playlists: playlists, subscriptions: subscriptions, selectedPlaylist: selectedSnapshot.selectedPlaylist, playlistVideos: selectedSnapshot.playlistVideos, nextPlaylistPageToken: selectedSnapshot.nextPlaylistPageToken, warnings: warnings.union(selectedSnapshot.warnings), status: selectedSnapshot.status, requestCountDeltas: deltas(since: before))
            }
            return YouTubeLibrarySnapshot(activityVideos: activityVideos, playlists: playlists, subscriptions: subscriptions, selectedPlaylist: selectedPlaylist, playlistVideos: playlistVideos, nextPlaylistPageToken: nextPlaylistPageToken, warnings: warnings, status: .ready, requestCountDeltas: deltas(since: before))
        } catch {
            return snapshot(warnings: [.activity, .playlists, .subscriptions], status: YouTubeServiceMapper.status(for: error), requestCountDeltas: deltas(since: before))
        }
    }

    func selectPlaylist(_ playlist: YouTubePlaylist) async -> YouTubeLibrarySnapshot {
        let before = providerRequestCounts
        selectedPlaylist = playlist
        selectedPlaylistID = playlist.id
        UserDefaults.standard.set(playlist.id, forKey: selectedPlaylistDefaultsKey)
        if let cached = playlistItemCache[playlist.id] {
            playlistVideos = cached.items
            nextPlaylistPageToken = cached.nextPageToken
        }
        do {
            guard let tokens = try await accountStore.loadFreshTokens() else {
                return snapshot(warnings: [.selectedPlaylist], status: .connectRequired, requestCountDeltas: deltas(since: before))
            }
            recordProviderRequest("official.playlistItems")
            let page = try await dataClient.playlistItemPage(playlistID: playlist.id, accessToken: tokens.accessToken)
            playlistVideos = page.items
            nextPlaylistPageToken = page.nextPageToken
            cachePlaylist(page: page, playlistID: playlist.id)
            return snapshot(status: .ready, requestCountDeltas: deltas(since: before))
        } catch {
            let status: YouTubeProviderStatus = playlistVideos.isEmpty ? YouTubeServiceMapper.status(for: error) : .cachedFallback
            return snapshot(warnings: [.selectedPlaylist], status: status, requestCountDeltas: deltas(since: before))
        }
    }

    func loadMorePlaylistItems(playlist: YouTubePlaylist, pageToken: String) async -> YouTubeLibrarySnapshot {
        let before = providerRequestCounts
        do {
            guard let tokens = try await accountStore.loadFreshTokens() else {
                return snapshot(warnings: [.selectedPlaylist], status: .connectRequired, requestCountDeltas: deltas(since: before))
            }
            recordProviderRequest("official.playlistItems")
            let page = try await dataClient.playlistItemPage(playlistID: playlist.id, accessToken: tokens.accessToken, maxResults: 25, pageToken: pageToken)
            nextPlaylistPageToken = page.nextPageToken
            playlistVideos.append(contentsOf: page.items.filter { pageItem in !playlistVideos.contains { $0.stableListID == pageItem.stableListID } })
            cachePlaylist(page: YouTubeVideoPage(items: playlistVideos, nextPageToken: page.nextPageToken), playlistID: playlist.id)
            return snapshot(status: .ready, requestCountDeltas: deltas(since: before))
        } catch {
            return snapshot(warnings: [.selectedPlaylist], status: YouTubeServiceMapper.status(for: error), requestCountDeltas: deltas(since: before))
        }
    }

    func createDefaultPlaylist(adding video: YouTubeVideoSearchResult?) async -> YouTubePlaylistWriteResult {
        let before = providerRequestCounts
        do {
            guard let tokens = try await accountStore.loadFreshTokens(requiredScope: Self.youtubeWriteScope) else {
                return writeResult(kind: .createDefault(adding: video), status: .connectRequired, message: "Connect Google to create YouTube Music playlists.", requestCountDeltas: deltas(since: before))
            }
            recordProviderRequest("official.playlists.create")
            let playlist = try await dataClient.createPlaylist(title: "Saved Songs", description: "Created from the Music app using the official YouTube playlist API.", privacyStatus: .private, accessToken: tokens.accessToken)
            playlists = ([playlist] + playlists).deduplicatedByPlaylistID()
            selectedPlaylist = playlist
            selectedPlaylistID = playlist.id
            UserDefaults.standard.set(playlist.id, forKey: selectedPlaylistDefaultsKey)
            playlistVideos = []
            nextPlaylistPageToken = nil
            var message = "Created private YouTube Music playlist."
            if let video {
                let writeID = Self.playlistWriteID(videoID: video.id, playlistID: playlist.id)
                guard activePlaylistWriteIDs.insert(writeID).inserted else {
                    return writeResult(kind: .createDefault(adding: video), status: .ready, message: "Already adding this song.", requestCountDeltas: deltas(since: before))
                }
                defer { activePlaylistWriteIDs.remove(writeID) }
                recordProviderRequest("official.playlistItems.add")
                _ = try await dataClient.addVideoToPlaylist(videoID: video.id, playlistID: playlist.id, accessToken: tokens.accessToken)
                _ = await selectPlaylist(playlist)
                message = "Created private playlist and added song."
            }
            recordProviderRequest("official.playlists")
            playlists = try await dataClient.playlists(accessToken: tokens.accessToken).deduplicatedByPlaylistID()
            restoreSelectedPlaylistIfPossible()
            return writeResult(kind: .createDefault(adding: video), status: .ready, message: message, requestCountDeltas: deltas(since: before))
        } catch {
            return writeResult(kind: .createDefault(adding: video), status: YouTubeServiceMapper.status(for: error), message: YouTubeServiceMapper.playlistMessage(for: error), requestCountDeltas: deltas(since: before))
        }
    }

    func add(_ video: YouTubeVideoSearchResult, to playlist: YouTubePlaylist) async -> YouTubePlaylistWriteResult {
        let before = providerRequestCounts
        let writeID = Self.playlistWriteID(videoID: video.id, playlistID: playlist.id)
        guard activePlaylistWriteIDs.insert(writeID).inserted else {
            return writeResult(kind: .add(video: video, playlist: playlist), status: .ready, message: "Already adding this song.", requestCountDeltas: [:])
        }
        defer { activePlaylistWriteIDs.remove(writeID) }
        do {
            guard let tokens = try await accountStore.loadFreshTokens(requiredScope: Self.youtubeWriteScope) else {
                return writeResult(kind: .add(video: video, playlist: playlist), status: .connectRequired, message: "Connect Google to add songs to YouTube Music playlists.", requestCountDeltas: deltas(since: before))
            }
            recordProviderRequest("official.playlistItems.add")
            _ = try await dataClient.addVideoToPlaylist(videoID: video.id, playlistID: playlist.id, accessToken: tokens.accessToken)
            let message = "Added to \(playlist.snippet.title)."
            if selectedPlaylist?.id == playlist.id {
                _ = await selectPlaylist(playlist)
            } else {
                playlistItemCache.removeValue(forKey: playlist.id)
                savePlaylistItemCache(playlistItemCache)
            }
            return writeResult(kind: .add(video: video, playlist: playlist), status: .ready, message: message, requestCountDeltas: deltas(since: before))
        } catch {
            return writeResult(kind: .add(video: video, playlist: playlist), status: YouTubeServiceMapper.status(for: error), message: YouTubeServiceMapper.playlistMessage(for: error), requestCountDeltas: deltas(since: before))
        }
    }

    func remove(_ video: YouTubeVideoSearchResult, from playlist: YouTubePlaylist) async -> YouTubePlaylistWriteResult {
        let before = providerRequestCounts
        guard let playlistItemID = video.playlistItemID else {
            return writeResult(kind: .remove(video: video, playlist: playlist), status: .invalidProviderResponse, message: "This playlist item cannot be removed because the official item ID was not loaded yet.", requestCountDeltas: [:])
        }
        guard activePlaylistDeleteIDs.insert(playlistItemID).inserted else {
            return writeResult(kind: .remove(video: video, playlist: playlist), status: .ready, message: "Already removing this song.", requestCountDeltas: [:])
        }
        defer { activePlaylistDeleteIDs.remove(playlistItemID) }
        do {
            guard let tokens = try await accountStore.loadFreshTokens(requiredScope: Self.youtubeWriteScope) else {
                return writeResult(kind: .remove(video: video, playlist: playlist), status: .connectRequired, message: "Connect Google to remove songs from YouTube Music playlists.", requestCountDeltas: deltas(since: before))
            }
            recordProviderRequest("official.playlistItems.delete")
            try await dataClient.deletePlaylistItem(playlistItemID: playlistItemID, accessToken: tokens.accessToken)
            playlistVideos.removeAll { $0.playlistItemID == playlistItemID }
            cachePlaylist(page: YouTubeVideoPage(items: playlistVideos, nextPageToken: nextPlaylistPageToken), playlistID: playlist.id)
            recordProviderRequest("official.playlists")
            playlists = try await dataClient.playlists(accessToken: tokens.accessToken).deduplicatedByPlaylistID()
            restoreSelectedPlaylistIfPossible()
            return writeResult(kind: .remove(video: video, playlist: playlist), status: .ready, message: "Removed from \(playlist.snippet.title).", requestCountDeltas: deltas(since: before))
        } catch {
            return writeResult(kind: .remove(video: video, playlist: playlist), status: YouTubeServiceMapper.status(for: error), message: YouTubeServiceMapper.playlistMessage(for: error), requestCountDeltas: deltas(since: before))
        }
    }

    func isAdding(_ video: YouTubeVideoSearchResult, to playlist: YouTubePlaylist) -> Bool {
        activePlaylistWriteIDs.contains(Self.playlistWriteID(videoID: video.id, playlistID: playlist.id))
    }

    func isRemoving(_ video: YouTubeVideoSearchResult) -> Bool {
        guard let playlistItemID = video.playlistItemID else { return false }
        return activePlaylistDeleteIDs.contains(playlistItemID)
    }

    func clearPlaylistCache() {
        playlistItemCache.removeAll()
        UserDefaults.standard.removeObject(forKey: playlistItemCacheDefaultsKey)
    }

    private func fetchRecentActivity(accessToken: String) async -> Result<[YouTubeVideoSearchResult], Error> {
        do { recordProviderRequest("official.activity"); return .success(try await dataClient.recentActivityVideos(accessToken: accessToken)) } catch { return .failure(error) }
    }

    private func fetchPlaylists(accessToken: String) async -> Result<[YouTubePlaylist], Error> {
        do { recordProviderRequest("official.playlists"); return .success(try await dataClient.playlists(accessToken: accessToken)) } catch { return .failure(error) }
    }

    private func fetchSubscriptions(accessToken: String) async -> Result<[YouTubeSubscription], Error> {
        do { recordProviderRequest("official.subscriptions"); return .success(try await dataClient.subscriptions(accessToken: accessToken)) } catch { return .failure(error) }
    }

    private func snapshot(warnings: Set<YouTubeLibraryWarning> = [], status: YouTubeProviderStatus, requestCountDeltas: [String: Int]) -> YouTubeLibrarySnapshot {
        YouTubeLibrarySnapshot(activityVideos: [], playlists: playlists, subscriptions: [], selectedPlaylist: selectedPlaylist, playlistVideos: playlistVideos, nextPlaylistPageToken: nextPlaylistPageToken, warnings: warnings, status: status, requestCountDeltas: requestCountDeltas)
    }

    private func writeResult(kind: YouTubePlaylistWriteKind, status: YouTubeProviderStatus, message: String, requestCountDeltas: [String: Int]) -> YouTubePlaylistWriteResult {
        YouTubePlaylistWriteResult(kind: kind, status: status, statusMessage: message, playlists: playlists, selectedPlaylist: selectedPlaylist, playlistVideos: playlistVideos, nextPlaylistPageToken: nextPlaylistPageToken, requestCountDeltas: requestCountDeltas)
    }

    private func restoreSelectedPlaylistIfPossible() {
        guard selectedPlaylist == nil,
              let selectedPlaylistID,
              let restoredPlaylist = playlists.first(where: { $0.id == selectedPlaylistID }) else { return }
        selectedPlaylist = restoredPlaylist
    }

    private func cachePlaylist(page: YouTubeVideoPage, playlistID: String) {
        playlistItemCache[playlistID] = YouTubeCachedPlaylistPage(items: page.items.deduplicatedByVideoID(), nextPageToken: page.nextPageToken, updatedAt: Date())
        if playlistItemCache.count > playlistItemCacheLimit {
            let keysToKeep = Set(playlistItemCache.sorted { $0.value.updatedAt > $1.value.updatedAt }.prefix(playlistItemCacheLimit).map { $0.key })
            playlistItemCache = playlistItemCache.filter { keysToKeep.contains($0.key) }
        }
        savePlaylistItemCache(playlistItemCache)
    }

    private func savePlaylistItemCache(_ cache: [String: YouTubeCachedPlaylistPage]) {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        UserDefaults.standard.set(data, forKey: playlistItemCacheDefaultsKey)
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

    private static func playlistWriteID(videoID: String, playlistID: String) -> String {
        "\(playlistID)|\(videoID)"
    }

    static func loadPlaylistItemCache(defaultsKey: String) -> [String: YouTubeCachedPlaylistPage] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return [:] }
        return (try? JSONDecoder().decode([String: YouTubeCachedPlaylistPage].self, from: data)) ?? [:]
    }
}
