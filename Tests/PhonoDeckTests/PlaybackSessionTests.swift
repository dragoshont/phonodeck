import XCTest
@testable import PhonoDeck

@MainActor
final class PlaybackSessionTests: XCTestCase {
    private struct FixturePlexCredentialStore: PlexCredentialStoring {
        var credentials: PlexCredentials?

        func load() throws -> PlexCredentials? { credentials }
        func save(_ credentials: PlexCredentials) throws {}
        func disconnect() throws {}
    }

    private func track(_ source: MediaSourceKind, id: String, url: URL? = nil, duration: TimeInterval? = 180) -> MusicTrack {
        MusicTrack(
            id: MusicProviderEntityID(source: source, rawValue: id),
            title: "Track \(id)",
            artistName: "Artist",
            albumTitle: "Album",
            durationSeconds: duration,
            releaseYear: nil,
            recordLabel: nil,
            artworkURL: nil,
            source: source,
            sourceURL: url
        )
    }

    private func temporaryAudioFile() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        FileManager.default.createFile(atPath: url.path, contents: Data([0, 1, 2, 3]))
        return url
    }

    private func plexURL(id: String = "one") -> URL {
        URL(string: "https://plex.example/library/parts/\(id)/file.flac?X-Plex-Token=token")!
    }

    private func fixtureSourceRegistry() -> SourceRegistry {
        SourceRegistry(adapters: [
            YouTubeMusicAdapter(),
            YouTubeAdapter(),
            SpotifyAdapter(),
            PlexAdapter(accountStore: FixturePlexCredentialStore(credentials: PlexCredentials(token: "token", serverName: "Home", serverBaseURL: "https://plex.example", hasPlexPass: true))),
            OwnFilesAdapter()
        ])
    }

    func testReplacingQueueStartsRequestedNativeItem() async {
        let publisher = CapturingNowPlayingPublisher()
        let coordinator = PlaybackCoordinator(nativeEngine: ImmediatePlaybackEngine(), nowPlayingPublisher: publisher)
        let plexTrack = track(.plex, id: "one", url: plexURL())
        let secondURL = try! temporaryAudioFile()
        defer { try? FileManager.default.removeItem(at: secondURL) }
        let secondTrack = track(.ownFiles, id: "two", url: secondURL)

        await coordinator.replaceQueue(with: [plexTrack, secondTrack], startAt: 1)

        XCTAssertEqual(coordinator.queueSnapshot.items.count, 2)
        XCTAssertEqual(coordinator.queueSnapshot.currentItem?.track, secondTrack)
        XCTAssertEqual(coordinator.currentTrack.title, secondTrack.title)
        XCTAssertEqual(coordinator.state, .playing)
        XCTAssertTrue(coordinator.ownsSystemNowPlaying)
        XCTAssertEqual(publisher.publishedMusicTrack?.id, secondTrack.id)
        XCTAssertTrue(publisher.commandsEnabled)
    }

    func testInvalidStartIndexBlocksWithoutCrashing() async {
        let publisher = CapturingNowPlayingPublisher()
        let coordinator = PlaybackCoordinator(nativeEngine: ImmediatePlaybackEngine(), nowPlayingPublisher: publisher)
        let plexTrack = track(.plex, id: "one", url: plexURL())

        await coordinator.replaceQueue(with: [plexTrack], startAt: 5)

        guard case .blocked(let blockedState) = coordinator.sessionState else {
            return XCTFail("Expected blocked session state")
        }
        XCTAssertEqual(blockedState, .unavailable(reason: "Invalid queue index."))
        XCTAssertFalse(coordinator.ownsSystemNowPlaying)
        XCTAssertTrue(publisher.didClear)
    }

    func testEnqueuePreservesCurrentItem() async {
        let coordinator = PlaybackCoordinator(sourceRegistry: fixtureSourceRegistry(), nativeEngine: ImmediatePlaybackEngine(), nowPlayingPublisher: CapturingNowPlayingPublisher())
        let first = track(.plex, id: "one", url: plexURL())
        let secondURL = try! temporaryAudioFile()
        defer { try? FileManager.default.removeItem(at: secondURL) }
        let second = track(.ownFiles, id: "two", url: secondURL)

        await coordinator.play(track: first)
        await coordinator.enqueue(second)

        XCTAssertEqual(coordinator.queueSnapshot.items.count, 2)
        XCTAssertEqual(coordinator.queueSnapshot.currentItem?.track, first)
    }

    func testNextPreviousAndClearAreDeterministic() async {
        let publisher = CapturingNowPlayingPublisher()
        let coordinator = PlaybackCoordinator(sourceRegistry: fixtureSourceRegistry(), nativeEngine: ImmediatePlaybackEngine(), nowPlayingPublisher: publisher)
        let first = track(.plex, id: "one", url: plexURL())
        let secondURL = try! temporaryAudioFile()
        defer { try? FileManager.default.removeItem(at: secondURL) }
        let second = track(.ownFiles, id: "two", url: secondURL)

        await coordinator.replaceQueue(with: [first, second], startAt: 0)
        coordinator.nextTrack()
        await Task.yield()
        XCTAssertEqual(coordinator.queueSnapshot.currentItem?.track, second)

        coordinator.previousTrack()
        await Task.yield()
        XCTAssertEqual(coordinator.queueSnapshot.currentItem?.track, first)

        coordinator.clearQueue()
        XCTAssertNil(coordinator.queueSnapshot.currentItem)
        XCTAssertEqual(coordinator.sessionState, .idle)
        XCTAssertFalse(coordinator.ownsSystemNowPlaying)
        XCTAssertTrue(publisher.didClear)
    }

    func testPlayFromEndedReloadsNativeItemBeforePublishing() async {
        let publisher = CapturingNowPlayingPublisher()
        let engine = CountingPlaybackEngine()
        let coordinator = PlaybackCoordinator(sourceRegistry: fixtureSourceRegistry(), nativeEngine: engine, nowPlayingPublisher: publisher)
        let plexTrack = track(.plex, id: "one", url: plexURL())

        await coordinator.play(track: plexTrack)
        XCTAssertEqual(engine.loadCount, 1)

        coordinator.nextTrack()
        guard case .ended = coordinator.sessionState else { return XCTFail("Expected ended state") }
        XCTAssertFalse(coordinator.ownsSystemNowPlaying)

        coordinator.play()
        await Task.yield()

        XCTAssertEqual(engine.loadCount, 2)
        XCTAssertEqual(coordinator.state, .playing)
        XCTAssertTrue(coordinator.ownsSystemNowPlaying)
        XCTAssertEqual(publisher.publishedMusicTrack?.id, plexTrack.id)
    }

    func testPreviousAtFirstItemRefreshesSessionElapsedState() async {
        let coordinator = PlaybackCoordinator(sourceRegistry: fixtureSourceRegistry(), nativeEngine: ImmediatePlaybackEngine(), nowPlayingPublisher: CapturingNowPlayingPublisher())
        let plexTrack = track(.plex, id: "one", url: plexURL())

        await coordinator.play(track: plexTrack)
        coordinator.seek(to: 42)
        coordinator.previousTrack()

        guard case .playing(_, let elapsed, _) = coordinator.sessionState else {
            return XCTFail("Expected playing state")
        }
        XCTAssertEqual(elapsed, 0)
        XCTAssertEqual(coordinator.elapsedTime, 0)
    }

    func testMixedQueuePreservesPerItemRouteDecisions() async {
        let coordinator = PlaybackCoordinator(sourceRegistry: fixtureSourceRegistry(), nativeEngine: ImmediatePlaybackEngine(), nowPlayingPublisher: CapturingNowPlayingPublisher())
        let plexTrack = track(.plex, id: "plex", url: plexURL())
        let youtubeTrack = track(.youtubeMusic, id: "yt")
        let spotifyTrack = track(.spotify, id: "11dFghVXANMlKmJXsNCbNl")

        await coordinator.replaceQueue(with: [plexTrack, youtubeTrack, spotifyTrack], startAt: 0)

        XCTAssertEqual(coordinator.queueSnapshot.items.map(\.source), [.plex, .youtubeMusic, .spotify])
        XCTAssertEqual(coordinator.queueSnapshot.items.map(\.routeDecision.engine), [.nativeAV, .webEmbed, .webEmbed])
        XCTAssertEqual(coordinator.queueSnapshot.items.map(\.routeDecision.requiresVisiblePlayer), [false, true, true])
    }

    func testEmbeddedTrackBlocksNativeSessionAndClearsSystemOwnership() async {
        let publisher = CapturingNowPlayingPublisher()
        let coordinator = PlaybackCoordinator(nativeEngine: ImmediatePlaybackEngine(), nowPlayingPublisher: publisher)
        let youtubeTrack = track(.youtubeMusic, id: "dQw4w9WgXcQ")

        await coordinator.play(track: youtubeTrack)

        XCTAssertEqual(coordinator.routeDecision?.engine, .webEmbed)
        XCTAssertTrue(coordinator.routeDecision?.requiresVisiblePlayer == true)
        guard case .blocked(let blockedState) = coordinator.sessionState else {
            return XCTFail("Expected blocked state for embed handoff")
        }
        XCTAssertEqual(blockedState, .unsupportedEngine(engine: .webEmbed, reason: "YouTube plays through the visible official embed only."))
        XCTAssertFalse(coordinator.ownsSystemNowPlaying)
        XCTAssertNil(publisher.publishedMusicTrack)
        XCTAssertTrue(publisher.didClear)
    }

    func testInsecurePlexURLIsBlockedBeforeNativeEngineLoad() async {
        let publisher = CapturingNowPlayingPublisher()
        let engine = CountingPlaybackEngine()
        let coordinator = PlaybackCoordinator(nativeEngine: engine, nowPlayingPublisher: publisher)
        let plexTrack = track(.plex, id: "insecure", url: URL(string: "http://plex.local/one.flac")!)

        await coordinator.play(track: plexTrack)

        XCTAssertEqual(engine.loadCount, 0)
        XCTAssertEqual(coordinator.routeDecision?.engine, PlaybackEngineKind.none)
        guard case .blocked(let blockedState) = coordinator.sessionState else {
            return XCTFail("Expected blocked state")
        }
        XCTAssertEqual(blockedState, .unavailable(reason: "Plex playback requires a secure media URL."))
        XCTAssertFalse(coordinator.ownsSystemNowPlaying)
        XCTAssertTrue(publisher.didClear)
    }

    func testNativeEngineFailureLeavesQueueAndDisablesSystemOwnership() async {
        let publisher = CapturingNowPlayingPublisher()
        let engine = ImmediatePlaybackEngine(loadFailure: .engineFailed(reason: "load failed"))
        let coordinator = PlaybackCoordinator(sourceRegistry: fixtureSourceRegistry(), nativeEngine: engine, nowPlayingPublisher: publisher)
        let plexTrack = track(.plex, id: "one", url: plexURL())

        await coordinator.play(track: plexTrack)

        XCTAssertEqual(coordinator.queueSnapshot.currentItem?.track, plexTrack)
        XCTAssertEqual(coordinator.sessionState, .failed(.engineFailed(reason: "load failed")))
        XCTAssertFalse(coordinator.ownsSystemNowPlaying)
        XCTAssertTrue(publisher.didClear)
    }

    func testActiveSourceChangeDoesNotOverrideNativeSessionOwnership() async {
        let publisher = CapturingNowPlayingPublisher()
        let playback = PlaybackCoordinator(sourceRegistry: fixtureSourceRegistry(), nativeEngine: ImmediatePlaybackEngine(), nowPlayingPublisher: publisher)
        let plexTrack = track(.plex, id: "one", url: plexURL())

        await playback.play(track: plexTrack)
        XCTAssertTrue(playback.ownsSystemNowPlaying)
        XCTAssertTrue(publisher.commandsEnabled)

        playback.refreshRemoteCommandAvailability()

        XCTAssertTrue(playback.ownsSystemNowPlaying)
        XCTAssertTrue(publisher.commandsEnabled)
    }

    func testEmptyQueueCommandsAreNoOps() {
        let coordinator = PlaybackCoordinator(nativeEngine: ImmediatePlaybackEngine(), nowPlayingPublisher: CapturingNowPlayingPublisher())

        coordinator.play()
        coordinator.pause()
        coordinator.nextTrack()
        coordinator.previousTrack()
        coordinator.seek(to: 42)

        XCTAssertEqual(coordinator.sessionState, .idle)
        XCTAssertNil(coordinator.queueSnapshot.currentItem)
        XCTAssertFalse(coordinator.ownsSystemNowPlaying)
    }

    func testEngineTimeEventUpdatesCoordinatorState() async {
        let engine = EventPlaybackEngine()
        let publisher = CapturingNowPlayingPublisher()
        let coordinator = PlaybackCoordinator(sourceRegistry: fixtureSourceRegistry(), nativeEngine: engine, nowPlayingPublisher: publisher)
        let plexTrack = track(.plex, id: "one", url: plexURL(), duration: 200)

        await coordinator.play(track: plexTrack)
        engine.emitTime(elapsed: 42, duration: 200)

        XCTAssertEqual(coordinator.elapsedTime, 42)
        guard case .playing(_, let elapsed, let duration) = coordinator.sessionState else { return XCTFail("Expected playing") }
        XCTAssertEqual(elapsed, 42)
        XCTAssertEqual(duration, 200)
        XCTAssertEqual(publisher.publishedElapsedTime, 42)
    }

    func testEngineFinishedEventEndsCurrentItemAndClearsOwnership() async {
        let engine = EventPlaybackEngine()
        let publisher = CapturingNowPlayingPublisher()
        let coordinator = PlaybackCoordinator(sourceRegistry: fixtureSourceRegistry(), nativeEngine: engine, nowPlayingPublisher: publisher)
        let plexTrack = track(.plex, id: "one", url: plexURL())

        await coordinator.play(track: plexTrack)
        guard let item = coordinator.queueSnapshot.currentItem else { return XCTFail("Expected current item") }
        engine.emitFinished(item)

        XCTAssertEqual(coordinator.sessionState, .ended(item))
        XCTAssertFalse(coordinator.ownsSystemNowPlaying)
        XCTAssertTrue(publisher.didClear)
    }

    func testEngineFailureEventFailsSessionAndClearsOwnership() async {
        let engine = EventPlaybackEngine()
        let publisher = CapturingNowPlayingPublisher()
        let coordinator = PlaybackCoordinator(sourceRegistry: fixtureSourceRegistry(), nativeEngine: engine, nowPlayingPublisher: publisher)
        let plexTrack = track(.plex, id: "one", url: plexURL())

        await coordinator.play(track: plexTrack)
        engine.emitFailure(.engineFailed(reason: "post-load failure"))

        XCTAssertEqual(coordinator.sessionState, .failed(.engineFailed(reason: "post-load failure")))
        XCTAssertFalse(coordinator.ownsSystemNowPlaying)
        XCTAssertTrue(publisher.didClear)
    }

    func testStaleEngineEventDoesNotChangeCurrentItem() async {
        let engine = EventPlaybackEngine()
        let coordinator = PlaybackCoordinator(sourceRegistry: fixtureSourceRegistry(), nativeEngine: engine, nowPlayingPublisher: CapturingNowPlayingPublisher())
        let first = track(.plex, id: "one", url: plexURL())
        let secondURL = try! temporaryAudioFile()
        defer { try? FileManager.default.removeItem(at: secondURL) }
        let second = track(.ownFiles, id: "two", url: secondURL)

        await coordinator.replaceQueue(with: [first, second], startAt: 0)
        guard let staleItem = coordinator.queueSnapshot.currentItem else { return XCTFail("Expected current item") }
        coordinator.nextTrack()
        await Task.yield()

        engine.emitFinished(staleItem)

        XCTAssertEqual(coordinator.queueSnapshot.currentItem?.track, second)
        XCTAssertNotEqual(coordinator.sessionState, .ended(staleItem))
    }

    func testAVFoundationEngineRejectsEmbeddedPlan() async {
        let engine = AVFoundationPlaybackEngine()
        let youtubeTrack = track(.youtubeMusic, id: "yt")
        let route = PlaybackRouteDecision(
            plan: .embedded(WebEmbed(provider: .youtube, url: URL(string: "https://www.youtube.com/embed/yt")!, contentID: "yt")),
            engine: .webEmbed,
            systemIntegration: .forbidden(reason: "embed"),
            requiresVisiblePlayer: true,
            blockedState: .unsupportedEngine(engine: .webEmbed, reason: "embed")
        )
        let item = PlaybackQueueItem(track: youtubeTrack, routeDecision: route)

        do {
            try await engine.load(item)
            XCTFail("Expected AV engine to reject embedded plan")
        } catch {
            XCTAssertTrue(String(describing: error).contains("engineFailed"))
        }
    }

    func testAVFoundationEngineLoadsNativeStreamPlan() async throws {
        let engine = AVFoundationPlaybackEngine()
        let plexTrack = track(.plex, id: "one", url: plexURL())
        let route = PlaybackRouteDecision(plan: .nativeStream(url: plexTrack.sourceURL!), engine: .nativeAV, systemIntegration: .eligibleNative, requiresVisiblePlayer: false, blockedState: nil)
        let item = PlaybackQueueItem(track: plexTrack, routeDecision: route)

        try await engine.load(item)

        XCTAssertEqual(engine.loadedItem, item)
        XCTAssertEqual(engine.kind, .nativeAV)
    }

    func testAVFoundationEngineLoadsLocalFilePlan() async throws {
        let engine = AVFoundationPlaybackEngine()
        let localURL = try! temporaryAudioFile()
        defer { try? FileManager.default.removeItem(at: localURL) }
        let localTrack = track(.ownFiles, id: "local", url: localURL)
        let route = PlaybackRouteDecision(plan: .localFile(url: localURL), engine: .nativeAV, systemIntegration: .eligibleNative, requiresVisiblePlayer: false, blockedState: nil)
        let item = PlaybackQueueItem(track: localTrack, routeDecision: route)

        try await engine.load(item)

        XCTAssertEqual(engine.loadedItem, item)
    }

    func testAVFoundationEngineRejectsConnectAndUnavailablePlans() async {
        let engine = AVFoundationPlaybackEngine()
        let spotifyTrack = track(.spotify, id: "spotify")
        let connect = PlaybackQueueItem(track: spotifyTrack, routeDecision: .init(plan: .connectRemote(reason: "remote only"), engine: .connectRemote, systemIntegration: .forbidden(reason: "remote only"), requiresVisiblePlayer: false, blockedState: .unsupportedEngine(engine: .connectRemote, reason: "remote only")))
        let unavailable = PlaybackQueueItem(track: spotifyTrack, routeDecision: .init(plan: .unavailable(reason: "not available"), engine: .none, systemIntegration: .unavailable(reason: "not available"), requiresVisiblePlayer: false, blockedState: .unavailable(reason: "not available")))

        for item in [connect, unavailable] {
            do {
                try await engine.load(item)
                XCTFail("Expected native engine to reject non-native plan")
            } catch {
                XCTAssertTrue(String(describing: error).contains("engineFailed"))
            }
        }
    }

    func testAVFoundationEngineRejectsInvalidLocalURL() async {
        let engine = AVFoundationPlaybackEngine()
        let invalidURL = URL(string: "https://example.com/not-local.m4a")!
        let localTrack = track(.ownFiles, id: "bad", url: invalidURL)
        let item = PlaybackQueueItem(track: localTrack, routeDecision: .init(plan: .localFile(url: invalidURL), engine: .nativeAV, systemIntegration: .eligibleNative, requiresVisiblePlayer: false, blockedState: nil))

        do {
            try await engine.load(item)
            XCTFail("Expected invalid file URL")
        } catch {
            XCTAssertTrue(String(describing: error).contains("invalidMediaURL"))
        }
    }

    func testAVFoundationEngineControlsAreSafeBeforeAndAfterLoad() async throws {
        let engine = AVFoundationPlaybackEngine()
        engine.play()
        engine.pause()
        engine.seek(to: -20)
        XCTAssertEqual(engine.elapsedTime, 0)

        let url = plexURL()
        let plexTrack = track(.plex, id: "one", url: url)
        let item = PlaybackQueueItem(track: plexTrack, routeDecision: .init(plan: .nativeStream(url: url), engine: .nativeAV, systemIntegration: .eligibleNative, requiresVisiblePlayer: false, blockedState: nil))
        try await engine.load(item)
        engine.play()
        engine.pause()
        engine.seek(to: -1)
        engine.stop()

        XCTAssertNil(engine.loadedItem)
        XCTAssertEqual(engine.elapsedTime, 0)
    }

    func testPlaybackCoordinatorDefaultsToAVFoundationEngine() {
        let coordinator = PlaybackCoordinator(nowPlayingPublisher: CapturingNowPlayingPublisher())
        XCTAssertFalse(coordinator.ownsSystemNowPlaying)
    }

    func testStaleTimeAndFailureEventsDoNotChangeCurrentItem() async {
        let engine = EventPlaybackEngine()
        let coordinator = PlaybackCoordinator(sourceRegistry: fixtureSourceRegistry(), nativeEngine: engine, nowPlayingPublisher: CapturingNowPlayingPublisher())
        let first = track(.plex, id: "one", url: plexURL())
        let secondURL = try! temporaryAudioFile()
        defer { try? FileManager.default.removeItem(at: secondURL) }
        let second = track(.ownFiles, id: "two", url: secondURL)

        await coordinator.replaceQueue(with: [first, second], startAt: 0)
        guard let staleItem = coordinator.queueSnapshot.currentItem else { return XCTFail("Expected current item") }
        coordinator.nextTrack()
        await Task.yield()

        engine.emitTime(elapsed: 99, duration: 100)
        engine.emitFailure(.engineFailed(reason: "stale failure"), item: staleItem)

        XCTAssertEqual(coordinator.queueSnapshot.currentItem?.track, second)
        XCTAssertNotEqual(coordinator.sessionState, .failed(.engineFailed(reason: "stale failure")))
    }
}

@MainActor
private final class CapturingNowPlayingPublisher: NowPlayingPublishing {
    private(set) var commandsEnabled = false
    private(set) var didClear = false
    private(set) var publishedMusicTrack: MusicTrack?
    private(set) var publishedLegacyTrack: Track?
    private(set) var publishedElapsedTime: TimeInterval?

    func configure(
        play: @escaping @MainActor () -> Void,
        pause: @escaping @MainActor () -> Void,
        next: @escaping @MainActor () -> Void,
        previous: @escaping @MainActor () -> Void
    ) {}

    func setCommandsEnabled(_ isEnabled: Bool) {
        commandsEnabled = isEnabled
    }

    func publish(track: Track, state: PlaybackState, elapsedTime: TimeInterval) {
        publishedLegacyTrack = track
        publishedElapsedTime = elapsedTime
        didClear = false
    }

    func publish(track: MusicTrack, state: PlaybackState, elapsedTime: TimeInterval, duration: TimeInterval?) {
        publishedMusicTrack = track
        publishedElapsedTime = elapsedTime
        didClear = false
    }

    func clear() {
        commandsEnabled = false
        didClear = true
        publishedMusicTrack = nil
        publishedLegacyTrack = nil
    }
}

@MainActor
private final class EventPlaybackEngine: PlaybackEngine, PlaybackEngineEventEmitting {
    let kind: PlaybackEngineKind = .nativeAV
    weak var eventObserver: PlaybackEngineEventObserving?
    private(set) var loadedItem: PlaybackQueueItem?
    private(set) var elapsedTime: TimeInterval = 0
    private(set) var duration: TimeInterval?
    private(set) var isPlaying = false

    func load(_ item: PlaybackQueueItem) async throws {
        loadedItem = item
        elapsedTime = 0
        duration = item.track.durationSeconds
        isPlaying = false
    }

    func play() { isPlaying = true }
    func pause() { isPlaying = false }
    func stop() { isPlaying = false; loadedItem = nil; elapsedTime = 0; duration = nil }
    func seek(to seconds: TimeInterval) { elapsedTime = max(seconds, 0) }

    func emitTime(elapsed: TimeInterval, duration: TimeInterval?) {
        elapsedTime = elapsed
        self.duration = duration
        eventObserver?.playbackEngineDidUpdateTime(elapsed: elapsed, duration: duration)
    }

    func emitFinished(_ item: PlaybackQueueItem) {
        eventObserver?.playbackEngineDidFinishItem(item)
    }

    func emitFailure(_ failure: PlaybackFailure) {
        eventObserver?.playbackEngineDidFail(failure)
    }

    func emitFailure(_ failure: PlaybackFailure, item: PlaybackQueueItem) {
        guard loadedItem?.id == item.id else { return }
        eventObserver?.playbackEngineDidFail(failure)
    }
}

@MainActor
private final class CountingPlaybackEngine: PlaybackEngine {
    let kind: PlaybackEngineKind = .nativeAV
    private(set) var loadedItem: PlaybackQueueItem?
    private(set) var elapsedTime: TimeInterval = 0
    private(set) var duration: TimeInterval?
    private(set) var isPlaying = false
    private(set) var loadCount = 0

    func load(_ item: PlaybackQueueItem) async throws {
        loadCount += 1
        loadedItem = item
        elapsedTime = 0
        duration = item.track.durationSeconds
        isPlaying = false
    }

    func play() {
        guard loadedItem != nil else { return }
        isPlaying = true
    }

    func pause() { isPlaying = false }

    func stop() {
        loadedItem = nil
        elapsedTime = 0
        duration = nil
        isPlaying = false
    }

    func seek(to seconds: TimeInterval) {
        elapsedTime = max(seconds, 0)
    }
}