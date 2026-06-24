import Foundation

struct Track: Identifiable, Equatable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let source: MediaSourceKind
    let duration: TimeInterval

    static let placeholder = Track(
        id: "placeholder",
        title: "YouTube Music Ready",
        artist: "Official route pending",
        album: "PhonoDeck Preview",
        source: .youtubeMusic,
        duration: 240
    )

}

extension Track {
    init(musicTrack: MusicTrack) {
        self.init(
            id: musicTrack.id.stableID,
            title: musicTrack.title,
            artist: musicTrack.artistName,
            album: musicTrack.albumTitle ?? musicTrack.source.descriptor.displayName,
            source: musicTrack.source,
            duration: musicTrack.durationSeconds ?? 0
        )
    }
}

enum PlaybackState: Equatable {
    case playing
    case paused
    case stopped
}

@MainActor
final class PlaybackCoordinator: ObservableObject, PlaybackEngineEventObserving {
    @Published var currentTrack: Track = .placeholder
    @Published var state: PlaybackState = .paused
    @Published var elapsedTime: TimeInterval = 0
    @Published private(set) var queueSnapshot: PlaybackQueueSnapshot = .empty
    @Published private(set) var sessionState: PlaybackSessionState = .idle
    @Published private(set) var routeDecision: PlaybackRouteDecision?
    @Published private(set) var ownsSystemNowPlaying = false

    private let sourceRegistry: SourceRegistry
    private let router: PlaybackRouter
    private let nativeEngine: PlaybackEngine
    private let nowPlayingController: NowPlayingPublishing

    var progress: Double {
        guard currentTrack.duration > 0 else { return 0 }
        return min(max(elapsedTime / currentTrack.duration, 0), 1)
    }

    init(
        sourceRegistry: SourceRegistry = SourceRegistry.makeDefault(),
        router: PlaybackRouter = PlaybackRouter(),
        nativeEngine: PlaybackEngine = AVFoundationPlaybackEngine(),
        nowPlayingPublisher: NowPlayingPublishing = NowPlayingController()
    ) {
        self.sourceRegistry = sourceRegistry
        self.router = router
        self.nativeEngine = nativeEngine
        self.nowPlayingController = nowPlayingPublisher
        if let eventEngine = nativeEngine as? PlaybackEngineEventEmitting {
            eventEngine.eventObserver = self
        }
        nowPlayingController.configure(
            play: { [weak self] in self?.play() },
            pause: { [weak self] in self?.pause() },
            next: { [weak self] in self?.nextTrack() },
            previous: { [weak self] in self?.previousTrack() }
        )
        nowPlayingController.clear()
    }

    func setRemoteCommandsEnabled(_ isEnabled: Bool) {
        nowPlayingController.setCommandsEnabled(isEnabled && ownsSystemNowPlaying)
    }

    func refreshRemoteCommandAvailability() {
        nowPlayingController.setCommandsEnabled(ownsSystemNowPlaying)
    }

    func replaceQueue(with tracks: [MusicTrack], startAt index: Int) async {
        guard !tracks.isEmpty else {
            clearQueue()
            return
        }
        guard tracks.indices.contains(index) else {
            transitionToBlocked(.unavailable(reason: "Invalid queue index."))
            return
        }
        let items = await resolveQueueItems(for: tracks)
        queueSnapshot = queueSnapshot.replacing(items: items, currentIndex: index)
        await startCurrentItem()
    }

    func play(track: MusicTrack) async {
        await replaceQueue(with: [track], startAt: 0)
    }

    func enqueue(_ track: MusicTrack) async {
        let item = await resolveQueueItem(for: track)
        if queueSnapshot.currentIndex == nil {
            queueSnapshot = queueSnapshot.replacing(items: [item], currentIndex: 0)
            await startCurrentItem()
            return
        }
        queueSnapshot = queueSnapshot.replacing(items: queueSnapshot.items + [item], currentIndex: queueSnapshot.currentIndex)
    }

    func play() {
        guard let item = queueSnapshot.currentItem else { return }
        switch sessionState {
        case .paused:
            nativeEngine.play()
            transitionToPlaying(item, elapsed: nativeEngine.elapsedTime, duration: nativeEngine.duration)
        case .ended:
            Task { await startCurrentItem() }
        default:
            return
        }
    }

    func pause() {
        guard let item = queueSnapshot.currentItem else { return }
        if case .playing = sessionState {
            nativeEngine.pause()
            transitionToPaused(item, elapsed: nativeEngine.elapsedTime, duration: nativeEngine.duration)
        }
    }

    func togglePlayPause() {
        state == .playing ? pause() : play()
    }

    func nextTrack() {
        guard let currentIndex = queueSnapshot.currentIndex else { return }
        let nextIndex = currentIndex + 1
        guard queueSnapshot.items.indices.contains(nextIndex) else {
            if let item = queueSnapshot.currentItem {
                nativeEngine.stop()
                sessionState = .ended(item)
                state = .stopped
                elapsedTime = 0
                ownsSystemNowPlaying = false
                nowPlayingController.clear()
            }
            return
        }
        queueSnapshot = queueSnapshot.replacing(items: queueSnapshot.items, currentIndex: nextIndex)
        Task { await startCurrentItem() }
    }

    func previousTrack() {
        guard let currentIndex = queueSnapshot.currentIndex else { return }
        if currentIndex > 0 {
            queueSnapshot = queueSnapshot.replacing(items: queueSnapshot.items, currentIndex: currentIndex - 1)
            Task { await startCurrentItem() }
            return
        }
        nativeEngine.seek(to: 0)
        elapsedTime = 0
        if let item = queueSnapshot.currentItem {
            switch sessionState {
            case .playing:
                transitionToPlaying(item, elapsed: 0, duration: nativeEngine.duration)
            case .paused:
                transitionToPaused(item, elapsed: 0, duration: nativeEngine.duration)
            default:
                publishNowPlayingIfOwned()
            }
        } else {
            publishNowPlayingIfOwned()
        }
    }

    func seek(to seconds: TimeInterval) {
        nativeEngine.seek(to: seconds)
        elapsedTime = nativeEngine.elapsedTime
        guard let item = queueSnapshot.currentItem else { return }
        switch sessionState {
        case .playing:
            transitionToPlaying(item, elapsed: elapsedTime, duration: nativeEngine.duration)
        case .paused:
            transitionToPaused(item, elapsed: elapsedTime, duration: nativeEngine.duration)
        default:
            break
        }
    }

    func clearQueue() {
        nativeEngine.stop()
        queueSnapshot = .empty
        sessionState = .idle
        routeDecision = nil
        ownsSystemNowPlaying = false
        currentTrack = .placeholder
        state = .paused
        elapsedTime = 0
        nowPlayingController.clear()
    }

    private func resolveQueueItems(for tracks: [MusicTrack]) async -> [PlaybackQueueItem] {
        var items: [PlaybackQueueItem] = []
        for track in tracks {
            items.append(await resolveQueueItem(for: track))
        }
        return items
    }

    private func resolveQueueItem(for track: MusicTrack) async -> PlaybackQueueItem {
        guard let adapter = sourceRegistry.adapter(for: track.source) else {
            let plan = PlaybackPlan.unavailable(reason: "\(track.source.descriptor.displayName) is not available.")
            let decision = PlaybackRouteDecision(
                plan: plan,
                engine: .none,
                systemIntegration: .unavailable(reason: "\(track.source.descriptor.displayName) is not available."),
                requiresVisiblePlayer: false,
                blockedState: .sourceUnavailable(source: track.source, reason: "\(track.source.descriptor.displayName) is not available.")
            )
            return PlaybackQueueItem(track: track, routeDecision: decision)
        }
        let resolution = await adapter.resolvePlayback(for: track)
        let decision = router.decision(for: resolution.plan, source: track.source, trackID: track.id)
        return PlaybackQueueItem(track: track, routeDecision: decision)
    }

    private func startCurrentItem() async {
        guard let item = queueSnapshot.currentItem else {
            clearQueue()
            return
        }

        routeDecision = item.routeDecision
        _ = router.route(item.requestedPlan)
        currentTrack = Track(musicTrack: item.track)
        elapsedTime = 0
        sessionState = .loading(item)

        if let blockedState = item.routeDecision.blockedState {
            transitionToBlocked(blockedState)
            return
        }

        do {
            try await nativeEngine.load(item)
            nativeEngine.play()
            transitionToPlaying(item, elapsed: nativeEngine.elapsedTime, duration: nativeEngine.duration)
        } catch let failure as PlaybackFailure {
            transitionToFailed(failure)
        } catch {
            transitionToFailed(.engineFailed(reason: error.localizedDescription))
        }
    }

    private func transitionToPlaying(_ item: PlaybackQueueItem, elapsed: TimeInterval, duration: TimeInterval?) {
        currentTrack = Track(musicTrack: item.track)
        state = .playing
        elapsedTime = elapsed
        sessionState = .playing(item, elapsed: elapsed, duration: duration)
        ownsSystemNowPlaying = item.routeDecision.canOwnSystemNowPlaying
        if ownsSystemNowPlaying {
            nowPlayingController.setCommandsEnabled(true)
            nowPlayingController.publish(track: item.track, state: state, elapsedTime: elapsed, duration: duration)
        } else {
            nowPlayingController.clear()
        }
    }

    private func transitionToPaused(_ item: PlaybackQueueItem, elapsed: TimeInterval, duration: TimeInterval?) {
        state = .paused
        elapsedTime = elapsed
        sessionState = .paused(item, elapsed: elapsed, duration: duration)
        publishNowPlayingIfOwned()
    }

    private func transitionToBlocked(_ blockedState: PlaybackBlockedState) {
        nativeEngine.stop()
        sessionState = .blocked(blockedState)
        state = .stopped
        elapsedTime = 0
        ownsSystemNowPlaying = false
        nowPlayingController.clear()
    }

    private func transitionToFailed(_ failure: PlaybackFailure) {
        nativeEngine.stop()
        sessionState = .failed(failure)
        state = .stopped
        elapsedTime = 0
        ownsSystemNowPlaying = false
        nowPlayingController.clear()
    }

    private func publishNowPlayingIfOwned() {
        guard ownsSystemNowPlaying, let item = queueSnapshot.currentItem else {
            nowPlayingController.clear()
            return
        }
        nowPlayingController.publish(track: item.track, state: state, elapsedTime: elapsedTime, duration: nativeEngine.duration)
    }

    func playbackEngineDidUpdateTime(elapsed: TimeInterval, duration: TimeInterval?) {
        guard ownsSystemNowPlaying, let item = queueSnapshot.currentItem else { return }
        switch sessionState {
        case .playing:
            elapsedTime = max(elapsed, 0)
            sessionState = .playing(item, elapsed: elapsedTime, duration: duration)
            publishNowPlayingIfOwned()
        case .paused:
            elapsedTime = max(elapsed, 0)
            sessionState = .paused(item, elapsed: elapsedTime, duration: duration)
            publishNowPlayingIfOwned()
        default:
            break
        }
    }

    func playbackEngineDidFinishItem(_ item: PlaybackQueueItem) {
        guard queueSnapshot.currentItem?.id == item.id else { return }
        nativeEngine.stop()
        sessionState = .ended(item)
        state = .stopped
        elapsedTime = 0
        ownsSystemNowPlaying = false
        nowPlayingController.clear()
    }

    func playbackEngineDidFail(_ failure: PlaybackFailure) {
        transitionToFailed(failure)
    }
}
