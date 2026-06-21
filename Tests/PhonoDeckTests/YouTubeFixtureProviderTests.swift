import XCTest
@testable import PhonoDeck

@MainActor
final class YouTubeFixtureProviderTests: XCTestCase {
    override func setUp() {
        super.setUp()
        clearYouTubeLocalState()
    }

    override func tearDown() {
        clearYouTubeLocalState()
        super.tearDown()
    }

    func testSearchViewModelUsesInjectedExperimentalProviderWithoutGoogle() async {
        let expected = YouTubeVideoSearchResult(
            id: "fixture-song",
            title: "AC/DC - Thunderstruck",
            channelTitle: "AC/DC - The Razors Edge",
            thumbnailURL: nil,
            sourceLabel: "Music"
        )
        let viewModel = YouTubeSearchViewModel(
            accountStore: FixtureAccountStore(tokens: nil),
            dataClient: FixtureYouTubeOfficialProvider(),
            innerTubeClient: FixtureYouTubeMusicMetadataProvider(results: [expected])
        )

        await viewModel.search("AC/DC Thunderstruck", preference: .songFirst, engine: .experimental)

        XCTAssertEqual(viewModel.results, [expected])
        XCTAssertEqual(viewModel.queue, [expected])
        XCTAssertEqual(viewModel.status, "")
    }

    func testSearchViewModelFallsBackToOfficialProviderWhenExperimentalFails() async {
        let expected = YouTubeVideoSearchResult(
            id: "official-song",
            title: "Sigur Ros - Svefn-g-englar",
            channelTitle: "Sigur Ros - Topic",
            thumbnailURL: nil
        )
        let viewModel = YouTubeSearchViewModel(
            accountStore: FixtureAccountStore(tokens: .fixture),
            dataClient: FixtureYouTubeOfficialProvider(searchPage: .init(items: [expected], nextPageToken: nil)),
            innerTubeClient: FixtureYouTubeMusicMetadataProvider(error: YouTubeMusicInnerTubeError.requestFailed)
        )

        await viewModel.search("Sigur Ros Svefn-g-englar", preference: .songFirst, engine: .experimental)

        XCTAssertEqual(viewModel.results, [expected])
        XCTAssertEqual(viewModel.status, "Experimental YouTube Music metadata was unavailable; using official fallback.")
    }

    func testPlaylistCreateUsesInjectedOfficialProvider() async {
        let playlist = YouTubePlaylist(
            id: "playlist-id",
            snippet: .init(title: "PhonoDeck Songs", channelTitle: nil, thumbnails: nil),
            contentDetails: nil,
            status: .init(privacyStatus: "private")
        )
        let provider = FixtureYouTubeOfficialProvider(playlists: [playlist], createdPlaylist: playlist)
        let viewModel = YouTubeSearchViewModel(
            accountStore: FixtureAccountStore(tokens: .fixture),
            dataClient: provider,
            innerTubeClient: FixtureYouTubeMusicMetadataProvider()
        )

        await viewModel.createDefaultPlaylist()

        XCTAssertEqual(viewModel.playlists.map(\.id), ["playlist-id"])
        XCTAssertEqual(viewModel.selectedPlaylist?.id, "playlist-id")
        XCTAssertEqual(viewModel.status, "Created private YouTube Music playlist.")
    }

    func testPlaylistAddUsesInjectedOfficialProvider() async {
        let playlist = YouTubePlaylist(
            id: "playlist-id",
            snippet: .init(title: "Favorites", channelTitle: nil, thumbnails: nil),
            contentDetails: .init(itemCount: 1),
            status: .init(privacyStatus: "private")
        )
        let video = YouTubeVideoSearchResult(id: "video-id", title: "Song", channelTitle: "Artist", thumbnailURL: nil)
        let provider = FixtureYouTubeOfficialProvider(playlists: [playlist])
        let viewModel = YouTubeSearchViewModel(
            accountStore: FixtureAccountStore(tokens: .fixture),
            dataClient: provider,
            innerTubeClient: FixtureYouTubeMusicMetadataProvider()
        )

        await viewModel.add(video, to: playlist)

        XCTAssertEqual(provider.addedPairs, ["playlist-id|video-id"])
        XCTAssertEqual(viewModel.status, "Added to Favorites.")
    }

    func testQueueDeduplicatesRapidAdds() {
        let viewModel = YouTubeSearchViewModel(
            accountStore: FixtureAccountStore(tokens: nil),
            dataClient: FixtureYouTubeOfficialProvider(),
            innerTubeClient: FixtureYouTubeMusicMetadataProvider()
        )
        let video = YouTubeVideoSearchResult(id: "video-id", title: "Song", channelTitle: "Artist", thumbnailURL: nil)

        viewModel.addToQueue(video)
        viewModel.addToQueue(video)
        viewModel.addToQueue(video)

        XCTAssertEqual(viewModel.queue, [video])
        XCTAssertEqual(viewModel.status, "Already in queue.")
    }

    func testQueueRemoveAndClearAreLocalOnly() {
        let first = YouTubeVideoSearchResult(id: "first", title: "First", channelTitle: "Artist", thumbnailURL: nil)
        let second = YouTubeVideoSearchResult(id: "second", title: "Second", channelTitle: "Artist", thumbnailURL: nil)
        let viewModel = YouTubeSearchViewModel(
            accountStore: FixtureAccountStore(tokens: nil),
            dataClient: FixtureYouTubeOfficialProvider(),
            innerTubeClient: FixtureYouTubeMusicMetadataProvider()
        )

        viewModel.select(first, queue: [first, second])
        viewModel.removeFromQueue(first)

        XCTAssertEqual(viewModel.queue, [second])
        XCTAssertEqual(viewModel.selectedVideo, second)
        XCTAssertEqual(viewModel.status, "Removed from queue.")

        viewModel.clearQueue()

        XCTAssertTrue(viewModel.queue.isEmpty)
        XCTAssertEqual(viewModel.status, "Queue cleared.")
    }

    func testSelectingSongFromListAdoptsQueueForNextSong() {
        let first = YouTubeVideoSearchResult(id: "first", title: "First", channelTitle: "Artist", thumbnailURL: nil)
        let second = YouTubeVideoSearchResult(id: "second", title: "Second", channelTitle: "Artist", thumbnailURL: nil)
        let viewModel = YouTubeSearchViewModel(
            accountStore: FixtureAccountStore(tokens: nil),
            dataClient: FixtureYouTubeOfficialProvider(),
            innerTubeClient: FixtureYouTubeMusicMetadataProvider()
        )

        viewModel.select(first, queue: [first, second])

        XCTAssertEqual(viewModel.queue, [first, second])
        XCTAssertTrue(viewModel.canPlayNext)
        XCTAssertEqual(viewModel.queuePositionText, "1 of 2")
    }

    func testProviderRequestCountsTrackFixtureCalls() async {
        let result = YouTubeVideoSearchResult(id: "song-id", title: "Song", channelTitle: "Artist", thumbnailURL: nil, sourceLabel: "Music")
        let viewModel = YouTubeSearchViewModel(
            accountStore: FixtureAccountStore(tokens: nil),
            dataClient: FixtureYouTubeOfficialProvider(),
            innerTubeClient: FixtureYouTubeMusicMetadataProvider(results: [result])
        )

        await viewModel.search("Song", preference: .songFirst, engine: .experimental)
        await viewModel.search("Song", preference: .songFirst, engine: .experimental)

        XCTAssertEqual(viewModel.providerRequestCounts["experimental.search"], 1)
    }

    func testPlaylistCreateAddAndShareURLAreFixtureBacked() async {
        let playlist = YouTubePlaylist(
            id: "playlist-id",
            snippet: .init(title: "Release Candidate", channelTitle: nil, thumbnails: nil),
            contentDetails: .init(itemCount: 1),
            status: .init(privacyStatus: "private")
        )
        let video = YouTubeVideoSearchResult(id: "video-id", title: "Song", channelTitle: "Artist", thumbnailURL: nil)
        let provider = FixtureYouTubeOfficialProvider(playlists: [playlist], createdPlaylist: playlist)
        let viewModel = YouTubeSearchViewModel(
            accountStore: FixtureAccountStore(tokens: .fixture),
            dataClient: provider,
            innerTubeClient: FixtureYouTubeMusicMetadataProvider()
        )

        await viewModel.createDefaultPlaylist(adding: video)

        XCTAssertEqual(viewModel.selectedPlaylist?.id, "playlist-id")
        XCTAssertEqual(provider.addedPairs, ["playlist-id|video-id"])
        XCTAssertEqual(viewModel.selectedPlaylist?.shareURL.absoluteString, "https://www.youtube.com/playlist?list=playlist-id")
    }

    func testPlaylistRemoveUsesOfficialPlaylistItemID() async {
        let playlist = YouTubePlaylist(
            id: "playlist-id",
            snippet: .init(title: "Editable", channelTitle: nil, thumbnails: nil),
            contentDetails: .init(itemCount: 1),
            status: .init(privacyStatus: "private")
        )
        let video = YouTubeVideoSearchResult(
            id: "video-id",
            title: "Song",
            channelTitle: "Artist - Topic",
            thumbnailURL: nil,
            sourceLabel: "Playlist",
            playlistItemID: "playlist-item-id",
            playlistAddedAt: "2026-06-01T12:00:00Z"
        )
        let provider = FixtureYouTubeOfficialProvider(
            playlists: [playlist],
            playlistPage: .init(items: [video], nextPageToken: nil)
        )
        let viewModel = YouTubeSearchViewModel(
            accountStore: FixtureAccountStore(tokens: .fixture),
            dataClient: provider,
            innerTubeClient: FixtureYouTubeMusicMetadataProvider()
        )

        await viewModel.selectPlaylist(playlist)
        await viewModel.remove(video, from: playlist)

        XCTAssertEqual(provider.deletedPlaylistItemIDs, ["playlist-item-id"])
        XCTAssertTrue(viewModel.playlistVideos.isEmpty)
        XCTAssertEqual(viewModel.status, "Removed from Editable.")
    }

    func testPlaylistStatusMessagesAreTyped() {
        XCTAssertEqual(
            YouTubeSearchViewModel.playlistStatusMessage(for: YouTubeDataError.quotaExceeded),
            "YouTube API quota is exhausted. Try again later or use cached playlist data."
        )
        XCTAssertEqual(
            YouTubeSearchViewModel.playlistStatusMessage(for: YouTubeDataError.authorizationExpired("expired")),
            "Reconnect Google; YouTube authorization expired."
        )
        XCTAssertEqual(
            YouTubeSearchViewModel.playlistStatusMessage(for: GoogleOAuthError.missingRequiredScope("https://www.googleapis.com/auth/youtube")),
            "Reconnect Google to allow playlist changes."
        )
    }
}

private func clearYouTubeLocalState() {
    [
        "youtubePlaybackHistory",
        "youtubeSelectedPlaylistID",
        "youtubeMusicSearchCache",
        "youtubePlaylistItemCache",
        "youtubeMusicDiscovery",
        "youtubeMusicDiscoveryRefreshedAt"
    ].forEach { UserDefaults.standard.removeObject(forKey: $0) }
}

private struct FixtureAccountStore: YouTubeAccountTokenProviding {
    let tokens: GoogleOAuthTokenSet?

    func loadFreshTokens() async throws -> GoogleOAuthTokenSet? {
        tokens
    }

    func loadFreshTokens(requiredScope: String) async throws -> GoogleOAuthTokenSet? {
        guard let tokens else { return nil }
        guard tokens.scope.split(separator: " ").map(String.init).contains(requiredScope) else {
            throw GoogleOAuthError.missingRequiredScope(requiredScope)
        }
        return tokens
    }
}

private struct FixtureYouTubeMusicMetadataProvider: YouTubeMusicMetadataProviding {
    var results: [YouTubeVideoSearchResult] = []
    var error: YouTubeMusicInnerTubeError?

    func search(query: String, preference: YouTubePlaybackPreference, maxResults: Int) async throws -> [YouTubeVideoSearchResult] {
        if let error { throw error }
        return Array(results.prefix(maxResults))
    }
}

private final class FixtureYouTubeOfficialProvider: YouTubeOfficialProviding, @unchecked Sendable {
    var searchPage: YouTubeVideoPage
    var playlistPage: YouTubeVideoPage
    var playlistsValue: [YouTubePlaylist]
    var createdPlaylist: YouTubePlaylist?
    var addedPairs: [String] = []
    var deletedPlaylistItemIDs: [String] = []

    init(searchPage: YouTubeVideoPage = .init(items: [], nextPageToken: nil), playlists: [YouTubePlaylist] = [], createdPlaylist: YouTubePlaylist? = nil, playlistPage: YouTubeVideoPage = .init(items: [], nextPageToken: nil)) {
        self.searchPage = searchPage
        self.playlistPage = playlistPage
        self.playlistsValue = playlists
        self.createdPlaylist = createdPlaylist
    }

    func searchVideoPage(query: String, accessToken: String, maxResults: Int, preference: YouTubePlaybackPreference, pageToken: String?) async throws -> YouTubeVideoPage {
        searchPage
    }

    func playlists(accessToken: String, maxResults: Int) async throws -> [YouTubePlaylist] {
        playlistsValue
    }

    func playlistItemPage(playlistID: String, accessToken: String, maxResults: Int, pageToken: String?) async throws -> YouTubeVideoPage {
        playlistPage
    }

    func createPlaylist(title: String, description: String, privacyStatus: YouTubePlaylistPrivacyStatus, accessToken: String) async throws -> YouTubePlaylist {
        guard let createdPlaylist else {
            throw YouTubeDataError.invalidResponse
        }
        return createdPlaylist
    }

    func addVideoToPlaylist(videoID: String, playlistID: String, accessToken: String) async throws -> YouTubePlaylistItem {
        addedPairs.append("\(playlistID)|\(videoID)")
        return YouTubePlaylistItem(
            id: "playlist-item-id",
            snippet: .init(
                title: "Fixture Song",
                channelTitle: "Fixture Artist",
                publishedAt: "2026-06-01T12:00:00Z",
                thumbnails: .init(default: nil, medium: nil),
                resourceID: nil
            ),
            contentDetails: .init(videoID: videoID)
        )
    }

    func deletePlaylistItem(playlistItemID: String, accessToken: String) async throws {
        deletedPlaylistItemIDs.append(playlistItemID)
        playlistPage = .init(items: playlistPage.items.filter { $0.playlistItemID != playlistItemID }, nextPageToken: playlistPage.nextPageToken)
    }

    func recentActivityVideos(accessToken: String, maxResults: Int) async throws -> [YouTubeVideoSearchResult] {
        []
    }

    func subscriptions(accessToken: String, maxResults: Int) async throws -> [YouTubeSubscription] {
        []
    }

    func videoDetails(videoID: String, accessToken: String) async throws -> YouTubeVideoDetails? {
        nil
    }
}

private extension GoogleOAuthTokenSet {
    static var fixture: GoogleOAuthTokenSet {
        .init(
            accessToken: "access-token",
            expiresIn: 3600,
            refreshToken: "refresh-token",
            refreshTokenExpiresIn: nil,
            scope: "https://www.googleapis.com/auth/youtube",
            tokenType: "Bearer",
            obtainedAt: Date()
        )
    }
}