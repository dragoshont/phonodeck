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

    func testResetAuthorizedLocalStateClearsVisibleLibraryAndPlaybackState() async {
        let result = YouTubeVideoSearchResult(id: "song-id", title: "Song", channelTitle: "Artist", thumbnailURL: nil, sourceLabel: "Music")
        let playlist = YouTubePlaylist(id: "playlist-id", snippet: .init(title: "Library", channelTitle: nil, thumbnails: nil), contentDetails: nil, status: nil)
        let viewModel = YouTubeSearchViewModel(
            accountStore: FixtureAccountStore(tokens: .fixture),
            dataClient: FixtureYouTubeOfficialProvider(searchPage: .init(items: [result], nextPageToken: nil), playlists: [playlist]),
            metadataProvider: FixtureYouTubeMusicMetadataProvider()
        )

        await viewModel.search("Song", preference: .songFirst, engine: .experimental)
        await viewModel.loadLibraryData()
        viewModel.addToQueue(result)

        XCTAssertFalse(viewModel.results.isEmpty)
        XCTAssertFalse(viewModel.playlists.isEmpty)
        XCTAssertFalse(viewModel.queue.isEmpty)

        viewModel.resetAuthorizedLocalState()

        XCTAssertTrue(viewModel.results.isEmpty)
        XCTAssertNil(viewModel.selectedVideo)
        XCTAssertTrue(viewModel.activityVideos.isEmpty)
        XCTAssertTrue(viewModel.playlists.isEmpty)
        XCTAssertNil(viewModel.selectedPlaylist)
        XCTAssertTrue(viewModel.playlistVideos.isEmpty)
        XCTAssertTrue(viewModel.subscriptions.isEmpty)
        XCTAssertNil(viewModel.selectedVideoDetails)
        XCTAssertTrue(viewModel.playbackHistory.isEmpty)
        XCTAssertTrue(viewModel.musicDiscoveryVideos.isEmpty)
        XCTAssertTrue(viewModel.queue.isEmpty)
        XCTAssertEqual(viewModel.status, "Signed out. Local YouTube Music library cache cleared.")
    }

    func testInFlightSearchCannotRepopulateAfterReset() async {
        let result = YouTubeVideoSearchResult(id: "late", title: "Late Result", channelTitle: "Artist", thumbnailURL: nil, sourceLabel: "Music")
        let service = DelayedSearchService(result: .init(
            request: .init(query: "Late", preference: .songFirst, engine: .official),
            page: .init(items: [result], nextPageToken: nil),
            resolvedEngine: .official,
            status: .ready,
            cacheState: .none,
            nextPageToken: nil,
            requestCountDeltas: [:]
        ))
        let viewModel = YouTubeSearchViewModel(
            accountStore: FixtureAccountStore(tokens: .fixture),
            dataClient: FixtureYouTubeOfficialProvider(),
            metadataProvider: FixtureYouTubeMusicMetadataProvider(),
            injectedSearchService: service
        )

        let searchTask = Task { await viewModel.search("Late", preference: .songFirst, engine: .official) }
        await Task.yield()
        viewModel.resetAuthorizedLocalState()
        service.resume()
        await searchTask.value

        XCTAssertTrue(viewModel.results.isEmpty)
        XCTAssertNil(viewModel.selectedVideo)
        XCTAssertTrue(viewModel.queue.isEmpty)
        XCTAssertEqual(viewModel.status, "Signed out. Local YouTube Music library cache cleared.")
    }

    func testSearchCacheClearDropsInFlightTaskForSameKey() async {
        let result = YouTubeVideoSearchResult(id: "late", title: "Late Result", channelTitle: "Artist", thumbnailURL: nil, sourceLabel: "Music")
        let provider = DelayedOfficialProvider(searchPage: .init(items: [result], nextPageToken: nil))
        let service = YouTubeSearchService(
            accountStore: FixtureAccountStore(tokens: .fixture),
            dataClient: provider,
            metadataProvider: FixtureYouTubeMusicMetadataProvider(),
            searchCacheKey: "testSearchCacheClearDropsInFlightTaskForSameKey",
            searchCacheLimit: 10,
            searchDebounceInterval: 0
        )
        let request = YouTubeSearchRequest(query: "Late", preference: .songFirst, engine: .official)

        let firstTask = Task { await service.search(request) }
        while provider.searchCallCount < 1 {
            await Task.yield()
        }
        service.clearSearchCache()
        let secondTask = Task { await service.search(request) }
        while provider.searchCallCount < 2 {
            await Task.yield()
        }
        provider.resumeAllSearches()
        let firstResult = await firstTask.value
        let secondResult = await secondTask.value

        XCTAssertEqual(firstResult.page.items, [result])
        XCTAssertEqual(secondResult.page.items, [result])
        XCTAssertEqual(provider.searchCallCount, 2)
        UserDefaults.standard.removeObject(forKey: "testSearchCacheClearDropsInFlightTaskForSameKey")
    }

    func testInFlightLibraryLoadCannotRepopulateAfterReset() async {
        let video = YouTubeVideoSearchResult(id: "activity", title: "Activity", channelTitle: "Artist", thumbnailURL: nil, sourceLabel: "Music")
        let playlist = YouTubePlaylist(id: "playlist-id", snippet: .init(title: "Library", channelTitle: nil, thumbnails: nil), contentDetails: nil, status: nil)
        let service = DelayedPlaylistService(snapshot: .init(
            activityVideos: [video],
            playlists: [playlist],
            subscriptions: [],
            selectedPlaylist: playlist,
            playlistVideos: [video],
            nextPlaylistPageToken: nil,
            warnings: [],
            status: .ready,
            requestCountDeltas: [:]
        ))
        let viewModel = YouTubeSearchViewModel(
            accountStore: FixtureAccountStore(tokens: .fixture),
            dataClient: FixtureYouTubeOfficialProvider(),
            metadataProvider: FixtureYouTubeMusicMetadataProvider(),
            injectedPlaylistService: service
        )

        let loadTask = Task { await viewModel.loadLibraryData() }
        await Task.yield()
        viewModel.resetAuthorizedLocalState()
        service.resume()
        await loadTask.value

        XCTAssertTrue(viewModel.activityVideos.isEmpty)
        XCTAssertTrue(viewModel.playlists.isEmpty)
        XCTAssertNil(viewModel.selectedPlaylist)
        XCTAssertTrue(viewModel.playlistVideos.isEmpty)
        XCTAssertTrue(viewModel.queue.isEmpty)
        XCTAssertEqual(viewModel.status, "Signed out. Local YouTube Music library cache cleared.")
    }

    func testPlaylistCacheClearDropsServiceOwnedLibraryState() async {
        let video = YouTubeVideoSearchResult(id: "activity", title: "Activity", channelTitle: "Artist", thumbnailURL: nil, sourceLabel: "Music")
        let playlist = YouTubePlaylist(id: "playlist-id", snippet: .init(title: "Library", channelTitle: nil, thumbnails: nil), contentDetails: nil, status: nil)
        let accountStore = FixtureAccountStore(tokens: .fixture)
        let service = YouTubePlaylistService(
            accountStore: accountStore,
            dataClient: FixtureYouTubeOfficialProvider(playlists: [playlist], playlistPage: .init(items: [video], nextPageToken: nil), activityVideos: [video]),
            selectedPlaylistDefaultsKey: "testPlaylistCacheClearDropsServiceOwnedLibraryState.selected",
            playlistItemCacheDefaultsKey: "testPlaylistCacheClearDropsServiceOwnedLibraryState.cache",
            playlistItemCacheLimit: 10
        )

        let loaded = await service.loadLibrary()
        XCTAssertFalse(loaded.playlists.isEmpty)
        service.clearPlaylistCache()
        accountStore.tokens = nil
        let signedOut = await service.loadLibrary()

        XCTAssertTrue(signedOut.playlists.isEmpty)
        XCTAssertTrue(signedOut.playlistVideos.isEmpty)
        XCTAssertNil(signedOut.selectedPlaylist)
        UserDefaults.standard.removeObject(forKey: "testPlaylistCacheClearDropsServiceOwnedLibraryState.selected")
        UserDefaults.standard.removeObject(forKey: "testPlaylistCacheClearDropsServiceOwnedLibraryState.cache")
    }

    func testInFlightVideoDetailsCannotRepopulateAfterReset() async {
        let video = YouTubeVideoSearchResult(id: "details", title: "Details", channelTitle: "Artist", thumbnailURL: nil, sourceLabel: "Music")
        let provider = DelayedOfficialProvider(details: YouTubeFixtureFactory.details(id: video.id))
        let viewModel = YouTubeSearchViewModel(
            accountStore: FixtureAccountStore(tokens: .fixture),
            dataClient: provider,
            metadataProvider: FixtureYouTubeMusicMetadataProvider()
        )

        viewModel.select(video)
        await Task.yield()
        viewModel.resetAuthorizedLocalState()
        while !provider.hasPendingDetails {
            await Task.yield()
        }
        provider.resumeDetails()

        try? await Task.sleep(nanoseconds: 10_000_000)

        XCTAssertNil(viewModel.selectedVideo)
        XCTAssertNil(viewModel.selectedVideoDetails)
        XCTAssertEqual(viewModel.status, "Signed out. Local YouTube Music library cache cleared.")
    }

    func testAllYouTubeLogoutButtonsUseSharedDisconnectResetHelper() throws {
        let source = try String(contentsOf: repoRoot().appendingPathComponent("Sources/PhonoDeck/Features/YouTubeMusic/YouTubeMusicNativeConceptView.swift"), encoding: .utf8)
        XCTAssertEqual(source.components(separatedBy: "accountViewModel.disconnect()").count - 1, 1)
        XCTAssertTrue(source.contains("disconnectYouTube: { disconnectYouTubeAccount() }"))
        XCTAssertTrue(source.contains("Button(\"Log Out of Google\", role: .destructive) {\n                    disconnectYouTubeAccount()"))
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

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
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
