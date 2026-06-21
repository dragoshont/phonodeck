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

enum PlaybackState: Equatable {
    case playing
    case paused
    case stopped
}

@MainActor
final class PlaybackCoordinator: ObservableObject {
    @Published var currentTrack: Track = .placeholder
    @Published var state: PlaybackState = .paused {
        didSet { publishNowPlaying() }
    }
    @Published var elapsedTime: TimeInterval = 0 {
        didSet { publishNowPlaying() }
    }

    private let nowPlayingController = NowPlayingController()

    var progress: Double {
        guard currentTrack.duration > 0 else { return 0 }
        return min(max(elapsedTime / currentTrack.duration, 0), 1)
    }

    init() {
        nowPlayingController.configure(
            play: { [weak self] in self?.play() },
            pause: { [weak self] in self?.pause() },
            next: { [weak self] in self?.nextTrack() },
            previous: { [weak self] in self?.previousTrack() }
        )
        publishNowPlaying()
    }

    func setRemoteCommandsEnabled(_ isEnabled: Bool) {
        nowPlayingController.setCommandsEnabled(isEnabled)
    }

    func play() {
        state = .playing
    }

    func pause() {
        state = .paused
    }

    func togglePlayPause() {
        state == .playing ? pause() : play()
    }

    func nextTrack() {
        elapsedTime = 0
    }

    func previousTrack() {
        elapsedTime = 0
    }

    private func publishNowPlaying() {
        nowPlayingController.publish(track: currentTrack, state: state, elapsedTime: elapsedTime)
    }
}
