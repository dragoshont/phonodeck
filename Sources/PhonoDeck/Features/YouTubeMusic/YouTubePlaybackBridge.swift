import Foundation

@MainActor
final class YouTubePlaybackBridge: ObservableObject {
    @Published private(set) var canPlayPrevious = false
    @Published private(set) var canPlayNext = false
    @Published private(set) var playerState: YouTubeEmbeddedPlayerState = .idle
    @Published private(set) var volume: Double = 100
    @Published private(set) var isMuted = false
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double = 0

    private var playPauseHandler: (() -> Void)?
    private var muteHandler: (() -> Void)?
    private var volumeHandler: ((Double) -> Void)?

    func setHandlers(
        playPause: @escaping () -> Void,
        mute: @escaping () -> Void,
        volume: @escaping (Double) -> Void
    ) {
        playPauseHandler = playPause
        muteHandler = mute
        volumeHandler = volume
    }

    func update(canPlayPrevious: Bool, canPlayNext: Bool, playerState: YouTubeEmbeddedPlayerState, volume: Double, isMuted: Bool, currentTime: Double, duration: Double) {
        self.canPlayPrevious = canPlayPrevious
        self.canPlayNext = canPlayNext
        self.playerState = playerState
        self.volume = volume
        self.isMuted = isMuted
        self.currentTime = currentTime
        self.duration = duration
    }

    func reset() {
        canPlayPrevious = false
        canPlayNext = false
        playerState = .idle
        volume = 100
        isMuted = false
        currentTime = 0
        duration = 0
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
}