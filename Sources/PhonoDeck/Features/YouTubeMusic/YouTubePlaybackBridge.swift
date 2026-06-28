import Foundation

@MainActor
final class YouTubePlaybackBridge: ObservableObject {
    @Published private(set) var playerState: YouTubeEmbeddedPlayerState = .idle
    @Published private(set) var volume: Double = 100
    @Published private(set) var isMuted = false
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var canPlayPrevious = false
    @Published private(set) var canPlayNext = false

    private var previousHandler: (() -> Void)?
    private var nextHandler: (() -> Void)?
    private var playPauseHandler: (() -> Void)?
    private var muteHandler: (() -> Void)?
    private var volumeHandler: ((Double) -> Void)?
    private var seekHandler: ((Double) -> Void)?

    func setHandlers(
        previous: @escaping () -> Void,
        next: @escaping () -> Void,
        playPause: @escaping () -> Void,
        mute: @escaping () -> Void,
        volume: @escaping (Double) -> Void,
        seek: @escaping (Double) -> Void
    ) {
        previousHandler = previous
        nextHandler = next
        playPauseHandler = playPause
        muteHandler = mute
        volumeHandler = volume
        seekHandler = seek
    }

    func update(
        playerState: YouTubeEmbeddedPlayerState,
        volume: Double,
        isMuted: Bool,
        currentTime: Double,
        duration: Double,
        canPlayPrevious: Bool = false,
        canPlayNext: Bool = false
    ) {
        self.playerState = playerState
        self.volume = volume
        self.isMuted = isMuted
        self.currentTime = currentTime
        self.duration = duration
        self.canPlayPrevious = canPlayPrevious
        self.canPlayNext = canPlayNext
    }

    func reset() {
        playerState = .idle
        volume = 100
        isMuted = false
        currentTime = 0
        duration = 0
        canPlayPrevious = false
        canPlayNext = false
    }

    func previous() {
        guard canPlayPrevious else { return }
        previousHandler?()
    }

    func next() {
        guard canPlayNext else { return }
        nextHandler?()
    }

    func playPause() {
        guard playerState.acceptsCommands else { return }
        playPauseHandler?()
    }

    func toggleMute() {
        guard playerState.acceptsCommands else { return }
        muteHandler?()
    }

    func setVolume(_ volume: Double) {
        guard playerState.acceptsCommands else { return }
        volumeHandler?(volume)
    }

    func seek(to seconds: Double) {
        guard playerState.acceptsCommands, duration > 0 else { return }
        seekHandler?(min(max(seconds, 0), duration))
    }
}