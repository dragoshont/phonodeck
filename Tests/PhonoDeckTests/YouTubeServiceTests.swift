import XCTest
@testable import PhonoDeck

@MainActor
final class YouTubeServiceTests: XCTestCase {
    override func setUp() {
        super.setUp()
        clearYouTubeLocalState()
    }

    override func tearDown() {
        clearYouTubeLocalState()
        super.tearDown()
    }

    func testSearchServiceExperimentalModeRequiresOfficialGoogleTokens() async {
        let metadataProvider = FixtureYouTubeMusicMetadataProvider(results: [YouTubeFixtureFactory.song(id: "disabled")])
        let service = searchService(tokens: nil, official: FixtureYouTubeOfficialProvider(), experimental: metadataProvider)

        let result = await service.search(.init(query: "AC/DC Thunderstruck", preference: .songFirst, engine: .experimental))

        XCTAssertTrue(result.page.items.isEmpty)
        XCTAssertEqual(result.resolvedEngine, .experimental)
        XCTAssertEqual(result.status, .connectRequired)
        XCTAssertNil(result.requestCountDeltas["experimental.search"])
        XCTAssertTrue(metadataProvider.searchedQueries.isEmpty)
    }

    func testSearchServiceExperimentalModeUsesOfficialOnlyProvider() async {
        let expected = YouTubeFixtureFactory.song(id: "official-song", title: "Sigur Ros - Svefn-g-englar")
        let metadataProvider = FixtureYouTubeMusicMetadataProvider(results: [YouTubeFixtureFactory.song(id: "disabled")])
        let service = searchService(tokens: .fixture, official: FixtureYouTubeOfficialProvider(searchPage: .init(items: [expected], nextPageToken: nil)), experimental: metadataProvider)

        let result = await service.search(.init(query: "Sigur Ros Svefn-g-englar", preference: .songFirst, engine: .experimental))

        XCTAssertEqual(result.page.items, [expected])
        XCTAssertEqual(result.resolvedEngine, .official)
        XCTAssertEqual(result.status, .undocumentedMetadataDisabledOfficialOnly)
        XCTAssertNil(result.requestCountDeltas["experimental.search"])
        XCTAssertEqual(result.requestCountDeltas["official.search"], 1)
        XCTAssertTrue(metadataProvider.searchedQueries.isEmpty)
    }

    func testSearchServiceAutomaticSurfacesOfficialFailureForVideoMode() async {
        let metadataProvider = FixtureYouTubeMusicMetadataProvider(results: [YouTubeFixtureFactory.song()])
        let service = searchService(tokens: .fixture, official: FixtureYouTubeOfficialProvider(error: YouTubeDataError.quotaExceeded), experimental: metadataProvider)

        let result = await service.search(.init(query: "video only", preference: .videoFirst, engine: .automatic))

        XCTAssertTrue(result.page.items.isEmpty)
        XCTAssertEqual(result.status, .quotaExceeded)
        XCTAssertNil(result.requestCountDeltas["experimental.search"])
        XCTAssertTrue(metadataProvider.searchedQueries.isEmpty)
    }

    func testSearchServiceAutomaticDoesNotFallbackWhenOfficialFails() async {
        let metadataProvider = FixtureYouTubeMusicMetadataProvider(results: [YouTubeFixtureFactory.song(id: "fallback")])
        let service = searchService(tokens: .fixture, official: FixtureYouTubeOfficialProvider(error: YouTubeDataError.quotaExceeded), experimental: metadataProvider)

        let result = await service.search(.init(query: "Rosalia DESPECHA", preference: .songFirst, engine: .automatic))

        XCTAssertTrue(result.page.items.isEmpty)
        XCTAssertEqual(result.resolvedEngine, .automatic)
        XCTAssertEqual(result.status, .quotaExceeded)
        XCTAssertEqual(result.requestCountDeltas["official.search"], 1)
        XCTAssertNil(result.requestCountDeltas["experimental.search"])
        XCTAssertTrue(metadataProvider.searchedQueries.isEmpty)
    }

    func testSearchServiceLoadMoreUsesOfficialProvider() async {
        let expected = YouTubeFixtureFactory.song(id: "page-two", title: "Oasis (What's The Story)")
        let service = searchService(tokens: .fixture, official: FixtureYouTubeOfficialProvider(searchPage: .init(items: [expected], nextPageToken: nil)), experimental: FixtureYouTubeMusicMetadataProvider())

        let result = await service.loadMore(.init(query: "Oasis (What's The Story)", preference: .songFirst, engine: .official, pageToken: "next"))

        XCTAssertEqual(result.page.items, [expected])
        XCTAssertEqual(result.resolvedEngine, .official)
        XCTAssertEqual(result.requestCountDeltas["official.search"], 1)
    }

    func testSearchServiceLoadMoreMergesServiceCache() async {
        let first = YouTubeFixtureFactory.song(id: "first")
        let second = YouTubeFixtureFactory.song(id: "second")
        let provider = FixtureYouTubeOfficialProvider(searchPage: .init(items: [first], nextPageToken: "next"))
        let service = searchService(tokens: .fixture, official: provider, experimental: FixtureYouTubeMusicMetadataProvider())

        _ = await service.search(.init(query: "Paged", preference: .songFirst, engine: .official))
        provider.searchPage = .init(items: [second], nextPageToken: nil)
        _ = await service.loadMore(.init(query: "Paged", preference: .songFirst, engine: .official, pageToken: "next"))

        let cached = service.cachedPage(for: .init(query: "Paged", preference: .songFirst, engine: .official))
        XCTAssertEqual(cached?.page.items.map(\.id), ["first", "second"])
    }

    func testProviderComparisonUsesCachedOfficialResultWhenOfficialFails() async throws {
        let cached = YouTubeFixtureFactory.song(id: "cached")
        let official = FixtureYouTubeOfficialProvider(searchPage: .init(items: [cached], nextPageToken: nil))
        let service = searchService(tokens: .fixture, official: official, experimental: FixtureYouTubeMusicMetadataProvider(results: []))

        _ = await service.search(.init(query: "Neon Skyline", preference: .songFirst, engine: .official))
        official.error = YouTubeDataError.quotaExceeded

        let comparisons = await service.compareProviders(query: "Neon Skyline", preference: .songFirst)
        let officialComparison = try XCTUnwrap(comparisons.first { $0.id == .official })

        XCTAssertEqual(officialComparison.status, "Cached fallback")
        XCTAssertEqual(officialComparison.items.map(\.id), ["cached"])
        XCTAssertNotEqual(officialComparison.cacheState, .none)
        XCTAssertNotNil(officialComparison.errorMessage)
    }

    func testSearchServiceWarmOfficialCacheSurvivesProviderFailure() async {
        let expected = YouTubeFixtureFactory.song(id: "warm")
        let official = FixtureYouTubeOfficialProvider(searchPage: .init(items: [expected], nextPageToken: nil))
        let service = searchService(tokens: .fixture, official: official, experimental: FixtureYouTubeMusicMetadataProvider(), debounceInterval: 0)

        _ = await service.search(.init(query: "Beyonce - Halo", preference: .songFirst, engine: .official))
        official.error = YouTubeDataError.quotaExceeded
        let failed = await service.search(.init(query: "Beyonce - Halo", preference: .songFirst, engine: .official))

        XCTAssertEqual(failed.page.items, [expected])
        XCTAssertEqual(failed.status, .cachedFallback)
        let cached = service.cachedPage(for: .init(query: "Beyonce - Halo", preference: .songFirst, engine: .official))
        XCTAssertEqual(cached?.page.items, [expected])
    }

    func testSearchServiceSurfacesOfficialFailureWithoutMetadataFallback() async {
        let metadataProvider = FixtureYouTubeMusicMetadataProvider(results: [YouTubeFixtureFactory.song(id: "unused")])
        let service = searchService(tokens: .fixture, official: FixtureYouTubeOfficialProvider(error: YouTubeDataError.quotaExceeded), experimental: metadataProvider)

        let result = await service.search(.init(query: "quota", preference: .songFirst, engine: .automatic))

        XCTAssertEqual(result.status, .quotaExceeded)
        XCTAssertTrue(metadataProvider.searchedQueries.isEmpty)
    }

    func testSearchViewModelPublishesLatestSearchResult() async {
        let older = YouTubeFixtureFactory.song(id: "older")
        let newer = YouTubeFixtureFactory.song(id: "newer")
        let service = ScriptedSearchService(results: [
            .init(request: .init(query: "older", preference: .songFirst, engine: .experimental), page: .init(items: [older], nextPageToken: nil), resolvedEngine: .experimental, status: .ready, cacheState: .none, nextPageToken: nil, requestCountDeltas: [:]),
            .init(request: .init(query: "newer", preference: .songFirst, engine: .experimental), page: .init(items: [newer], nextPageToken: nil), resolvedEngine: .experimental, status: .ready, cacheState: .none, nextPageToken: nil, requestCountDeltas: [:])
        ])
        let viewModel = YouTubeSearchViewModel(
            accountStore: FixtureAccountStore(tokens: nil),
            dataClient: FixtureYouTubeOfficialProvider(),
            metadataProvider: FixtureYouTubeMusicMetadataProvider(),
            injectedSearchService: service,
            injectedDiscoveryService: EmptyDiscoveryService(),
            injectedPlaylistService: EmptyPlaylistService()
        )

        await viewModel.search("older", preference: .songFirst, engine: .experimental)
        await viewModel.search("newer", preference: .songFirst, engine: .experimental)

        XCTAssertEqual(viewModel.results, [newer])
    }

    func testDiscoveryServiceCoalescesAndPublishesWarmCache() async {
        let expected = YouTubeFixtureFactory.song(id: "discovery")
        let search = searchService(tokens: .fixture, official: FixtureYouTubeOfficialProvider(searchPage: .init(items: [expected], nextPageToken: nil)), experimental: FixtureYouTubeMusicMetadataProvider())
        let service = YouTubeDiscoveryService(searchService: search, coalescer: RequestCoalescer(), discoveryDefaultsKey: "youtubeMusicDiscovery", discoveryRefreshDefaultsKey: "youtubeMusicDiscoveryRefreshedAt", discoveryLimit: 10, refreshInterval: 600)

        let snapshot = await service.refreshDiscovery(.init(engine: .official, force: true, seedQueries: ["top songs"]), currentItems: [])
        let cached = service.cachedDiscovery(engine: .official, seedQueries: ["top songs"], currentItems: [])

        XCTAssertEqual(snapshot.items, [expected])
        XCTAssertEqual(cached.items, [expected])
    }

    func testPlaylistServiceCreateAddAndRemoveUseFixtures() async {
        let playlist = YouTubeFixtureFactory.playlist(title: "Release Candidate")
        let video = YouTubeVideoSearchResult(id: "video-id", title: "Song", channelTitle: "Artist", thumbnailURL: nil, sourceLabel: "Playlist", playlistItemID: "playlist-item-id", playlistAddedAt: nil)
        let provider = FixtureYouTubeOfficialProvider(playlists: [playlist], createdPlaylist: playlist, playlistPage: .init(items: [video], nextPageToken: nil))
        let service = playlistService(tokens: .fixture, provider: provider)

        let create = await service.createDefaultPlaylist(adding: video)
        XCTAssertEqual(create.selectedPlaylist?.id, playlist.id)
        XCTAssertEqual(provider.addedPairs, ["playlist-id|video-id"])

        let remove = await service.remove(video, from: playlist)
        XCTAssertEqual(remove.statusMessage, "Removed from Release Candidate.")
        XCTAssertEqual(provider.deletedPlaylistItemIDs, ["playlist-item-id"])
    }

    func testPlaylistServiceMissingScopeIsFixtureBacked() async {
        let playlist = YouTubeFixtureFactory.playlist()
        let video = YouTubeFixtureFactory.song(id: "video-id")
        let service = playlistService(tokens: .readOnlyFixture, provider: FixtureYouTubeOfficialProvider(playlists: [playlist]))

        let result = await service.add(video, to: playlist)

        XCTAssertEqual(result.status, .missingWriteScope)
        XCTAssertEqual(result.statusMessage, "Reconnect Google to allow playlist changes.")
    }

    func testPlaylistServiceQuotaAndExpiredAuthAreFixtureBacked() async {
        let playlist = YouTubeFixtureFactory.playlist()
        let video = YouTubeFixtureFactory.song(id: "video-id")

        let quota = await playlistService(tokens: .fixture, provider: FixtureYouTubeOfficialProvider(playlists: [playlist], error: YouTubeDataError.quotaExceeded)).add(video, to: playlist)
        XCTAssertEqual(quota.status, .quotaExceeded)

        let expired = await playlistService(tokens: .fixture, provider: FixtureYouTubeOfficialProvider(playlists: [playlist], error: YouTubeDataError.authorizationExpired("expired"))).add(video, to: playlist)
        XCTAssertEqual(expired.status, .authorizationExpired)
    }

    func testPlaylistServiceMissingPlaylistItemIDIsFixtureBacked() async {
        let playlist = YouTubeFixtureFactory.playlist(title: "Editable")
        let video = YouTubeFixtureFactory.song(id: "video-id")
        let service = playlistService(tokens: .fixture, provider: FixtureYouTubeOfficialProvider(playlists: [playlist]))

        let result = await service.remove(video, from: playlist)

        XCTAssertEqual(result.status, .invalidProviderResponse)
        XCTAssertEqual(result.statusMessage, "This playlist item cannot be removed because the official item ID was not loaded yet.")
    }

    func testPlaylistServicePaginationErrorIsFixtureBacked() async {
        let playlist = YouTubeFixtureFactory.playlist(title: "Paged")
        let service = playlistService(tokens: .fixture, provider: FixtureYouTubeOfficialProvider(playlists: [playlist], error: YouTubeDataError.quotaExceeded))

        let snapshot = await service.loadMorePlaylistItems(playlist: playlist, pageToken: "next")

        XCTAssertEqual(snapshot.status, .quotaExceeded)
        XCTAssertTrue(snapshot.warnings.contains(.selectedPlaylist))
    }

    func testQAStatusScriptExitCodes() throws {
        let temporaryDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let passing = temporaryDirectory.appendingPathComponent("pass.md")
        try "| ID | Case | Status | Evidence |\n|---|---|---|---|\n| LN-001 | Opens | PASS | ok |\n".write(to: passing, atomically: true, encoding: .utf8)
        XCTAssertEqual(try runQAStatus(passing.path), 0)

        let failing = temporaryDirectory.appendingPathComponent("fail.md")
        try "| ID | Case | Status | Evidence |\n|---|---|---|---|\n| LN-001 | Opens | FAIL | missing |\n".write(to: failing, atomically: true, encoding: .utf8)
        XCTAssertEqual(try runQAStatus(failing.path), 1)

        let malformed = temporaryDirectory.appendingPathComponent("bad.md")
        try "no rows".write(to: malformed, atomically: true, encoding: .utf8)
        XCTAssertEqual(try runQAStatus(malformed.path), 2)
    }

    private func searchService(tokens: GoogleOAuthTokenSet?, official: FixtureYouTubeOfficialProvider, experimental: any YouTubeMusicMetadataProviding, debounceInterval: TimeInterval = 0.35) -> YouTubeSearchService {
        YouTubeSearchService(accountStore: FixtureAccountStore(tokens: tokens), dataClient: official, metadataProvider: experimental, searchCacheKey: "youtubeMusicSearchCache", searchCacheLimit: 20, searchDebounceInterval: debounceInterval)
    }

    private func playlistService(tokens: GoogleOAuthTokenSet?, provider: FixtureYouTubeOfficialProvider) -> YouTubePlaylistService {
        YouTubePlaylistService(accountStore: FixtureAccountStore(tokens: tokens), dataClient: provider, selectedPlaylistDefaultsKey: "youtubeSelectedPlaylistID", playlistItemCacheDefaultsKey: "youtubePlaylistItemCache", playlistItemCacheLimit: 10)
    }

    private func runQAStatus(_ path: String) throws -> Int32 {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", "scripts/qa-status.py", path]
        process.currentDirectoryURL = repoRoot
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }
}

@MainActor
private final class ScriptedSearchService: YouTubeSearchServicing {
    private var queuedResults: [YouTubeSearchServiceResult]
    var providerRequestCounts: [String: Int] = [:]

    init(results: [YouTubeSearchServiceResult]) {
        queuedResults = results
    }

    func cachedPage(for request: YouTubeSearchRequest) -> YouTubeSearchServiceResult? { nil }

    func search(_ request: YouTubeSearchRequest) async -> YouTubeSearchServiceResult {
        guard !queuedResults.isEmpty else {
            return .init(request: request, page: .init(items: [], nextPageToken: nil), resolvedEngine: request.engine, status: .failed("No scripted result."), cacheState: .none, nextPageToken: nil, requestCountDeltas: [:])
        }
        return queuedResults.removeFirst()
    }

    func loadMore(_ continuation: YouTubeSearchContinuation) async -> YouTubeSearchServiceResult {
        .init(request: .init(query: continuation.query, preference: continuation.preference, engine: continuation.engine), page: .init(items: [], nextPageToken: nil), resolvedEngine: continuation.engine, status: .ready, cacheState: .none, nextPageToken: nil, requestCountDeltas: [:])
    }

    func compareProviders(query: String, preference: YouTubePlaybackPreference) async -> [YouTubeProviderComparisonResult] { [] }
    func clearSearchCache() {}
}

@MainActor
private final class EmptyDiscoveryService: YouTubeDiscoveryServicing {
    func cachedDiscovery(engine: YouTubeMusicEngine, seedQueries: [String], currentItems: [YouTubeVideoSearchResult]) -> YouTubeDiscoverySnapshot { .init(items: [], status: .ready, cacheState: .none, requestCountDeltas: [:]) }
    func refreshDiscovery(_ request: YouTubeDiscoveryRequest, currentItems: [YouTubeVideoSearchResult]) async -> YouTubeDiscoverySnapshot { .init(items: [], status: .ready, cacheState: .none, requestCountDeltas: [:]) }
    func clearDiscoveryCache() {}
}

@MainActor
private final class EmptyPlaylistService: YouTubePlaylistServicing {
    func loadLibrary() async -> YouTubeLibrarySnapshot { snapshot }
    func selectPlaylist(_ playlist: YouTubePlaylist) async -> YouTubeLibrarySnapshot { snapshot }
    func loadMorePlaylistItems(playlist: YouTubePlaylist, pageToken: String) async -> YouTubeLibrarySnapshot { snapshot }
    func createDefaultPlaylist(adding video: YouTubeVideoSearchResult?) async -> YouTubePlaylistWriteResult { writeResult(kind: .createDefault(adding: video)) }
    func add(_ video: YouTubeVideoSearchResult, to playlist: YouTubePlaylist) async -> YouTubePlaylistWriteResult { writeResult(kind: .add(video: video, playlist: playlist)) }
    func remove(_ video: YouTubeVideoSearchResult, from playlist: YouTubePlaylist) async -> YouTubePlaylistWriteResult { writeResult(kind: .remove(video: video, playlist: playlist)) }
    func isAdding(_ video: YouTubeVideoSearchResult, to playlist: YouTubePlaylist) -> Bool { false }
    func isRemoving(_ video: YouTubeVideoSearchResult) -> Bool { false }
    func clearPlaylistCache() {}

    private var snapshot: YouTubeLibrarySnapshot {
        .init(activityVideos: [], playlists: [], subscriptions: [], selectedPlaylist: nil, playlistVideos: [], nextPlaylistPageToken: nil, warnings: [], status: .ready, requestCountDeltas: [:])
    }

    private func writeResult(kind: YouTubePlaylistWriteKind) -> YouTubePlaylistWriteResult {
        .init(kind: kind, status: .ready, statusMessage: "", playlists: [], selectedPlaylist: nil, playlistVideos: [], nextPlaylistPageToken: nil, requestCountDeltas: [:])
    }
}
