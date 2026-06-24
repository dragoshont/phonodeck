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

    func testSearchViewModelDoesNotUseInjectedMetadataProviderWithoutGoogle() async {
        let metadataProvider = FixtureYouTubeMusicMetadataProvider(results: [
            YouTubeVideoSearchResult(
                id: "fixture-song",
                title: "AC/DC - Thunderstruck",
                channelTitle: "AC/DC - The Razors Edge",
                thumbnailURL: nil,
                sourceLabel: "Music"
            )
        ])
        let viewModel = YouTubeSearchViewModel(
            accountStore: FixtureAccountStore(tokens: nil),
            dataClient: FixtureYouTubeOfficialProvider(),
            metadataProvider: metadataProvider
        )

        await viewModel.search("AC/DC Thunderstruck", preference: .songFirst, engine: .experimental)

        XCTAssertTrue(viewModel.results.isEmpty)
        XCTAssertTrue(viewModel.queue.isEmpty)
        XCTAssertEqual(viewModel.status, "No YouTube Music song results found. Switch to Video for clips.")
        XCTAssertTrue(metadataProvider.searchedQueries.isEmpty)
    }

    func testSearchViewModelExperimentalModeUsesOfficialOnlyProvider() async {
        let expected = YouTubeVideoSearchResult(
            id: "official-song",
            title: "Sigur Ros - Svefn-g-englar",
            channelTitle: "Sigur Ros - Topic",
            thumbnailURL: nil
        )
        let metadataProvider = FixtureYouTubeMusicMetadataProvider(error: YouTubeMusicProviderError.undocumentedMetadataDisabled)
        let viewModel = YouTubeSearchViewModel(
            accountStore: FixtureAccountStore(tokens: .fixture),
            dataClient: FixtureYouTubeOfficialProvider(searchPage: .init(items: [expected], nextPageToken: nil)),
            metadataProvider: metadataProvider
        )

        await viewModel.search("Sigur Ros Svefn-g-englar", preference: .songFirst, engine: .experimental)

        XCTAssertEqual(viewModel.results, [expected])
        XCTAssertEqual(viewModel.status, "Undocumented YouTube Music metadata is disabled by policy; using official YouTube API results.")
        XCTAssertTrue(metadataProvider.searchedQueries.isEmpty)
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
            metadataProvider: FixtureYouTubeMusicMetadataProvider()
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
            metadataProvider: FixtureYouTubeMusicMetadataProvider()
        )

        await viewModel.add(video, to: playlist)

        XCTAssertEqual(provider.addedPairs, ["playlist-id|video-id"])
        XCTAssertEqual(viewModel.status, "Added to Favorites.")
    }

    func testQueueDeduplicatesRapidAdds() {
        let viewModel = YouTubeSearchViewModel(
            accountStore: FixtureAccountStore(tokens: nil),
            dataClient: FixtureYouTubeOfficialProvider(),
            metadataProvider: FixtureYouTubeMusicMetadataProvider()
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
            metadataProvider: FixtureYouTubeMusicMetadataProvider()
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
            metadataProvider: FixtureYouTubeMusicMetadataProvider()
        )

        viewModel.select(first, queue: [first, second])

        XCTAssertEqual(viewModel.queue, [first, second])
        XCTAssertTrue(viewModel.canPlayNext)
        XCTAssertEqual(viewModel.queuePositionText, "1 of 2")
    }

    func testProviderRequestCountsTrackOfficialOnlySearchCalls() async {
        let result = YouTubeVideoSearchResult(id: "song-id", title: "Song", channelTitle: "Artist", thumbnailURL: nil, sourceLabel: "Music")
        let metadataProvider = FixtureYouTubeMusicMetadataProvider(results: [YouTubeFixtureFactory.song(id: "unused")])
        let viewModel = YouTubeSearchViewModel(
            accountStore: FixtureAccountStore(tokens: .fixture),
            dataClient: FixtureYouTubeOfficialProvider(searchPage: .init(items: [result], nextPageToken: nil)),
            metadataProvider: metadataProvider
        )

        await viewModel.search("Song", preference: .songFirst, engine: .experimental)
        await viewModel.search("Song", preference: .songFirst, engine: .experimental)

        XCTAssertEqual(viewModel.providerRequestCounts["official.search"], 1)
        XCTAssertNil(viewModel.providerRequestCounts["experimental.search"])
        XCTAssertTrue(metadataProvider.searchedQueries.isEmpty)
    }

    func testProviderComparisonPublishesDiagnosticRunEvidence() async throws {
        let official = YouTubeFixtureFactory.song(id: "official")
        let viewModel = YouTubeSearchViewModel(
            accountStore: FixtureAccountStore(tokens: .fixture),
            dataClient: FixtureYouTubeOfficialProvider(searchPage: .init(items: [official], nextPageToken: nil)),
            metadataProvider: FixtureYouTubeMusicMetadataProvider(results: [YouTubeFixtureFactory.song(id: "unused")])
        )

        await viewModel.compareProviders(query: "Neon Skyline", preference: .songFirst)

        let run = try XCTUnwrap(viewModel.providerComparisonRun)
        XCTAssertTrue(run.id.hasPrefix("ytlab-"))
        XCTAssertEqual(run.query, "Neon Skyline")
        XCTAssertEqual(run.preference, .songFirst)
        XCTAssertEqual(Set(run.providerResults.map(\.id)), Set([.official, .experimental]))
        XCTAssertEqual(run.requestCountDeltas["official.search"], 1)
        XCTAssertNil(run.requestCountDeltas["experimental.search"])
        XCTAssertEqual(run.providerResults.first { $0.id == .experimental }?.riskLabel, "Disabled")
        XCTAssertTrue(run.providerResults.allSatisfy { !$0.riskLabel.isEmpty })
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
            metadataProvider: FixtureYouTubeMusicMetadataProvider()
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
            metadataProvider: FixtureYouTubeMusicMetadataProvider()
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
