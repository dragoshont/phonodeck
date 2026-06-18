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

    static let previewTracks: [Track] = [
        Track(id: "plex-1", title: "Local Signal", artist: "Plex Library", album: "Personal Media", source: .plex, duration: 284),
        Track(id: "ytm-1", title: "Embedded Light", artist: "YouTube Music", album: "Official Player", source: .youtubeMusic, duration: 213),
        Track(id: "spotify-1", title: "Remote Green", artist: "Spotify Connect", album: "External Device", source: .spotify, duration: 196),
        Track(id: "local-1", title: "Imported Groove", artist: "Local Files", album: "iTunes XML", source: .localFiles, duration: 247)
    ]
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
        let tracks = Track.previewTracks
        guard let index = tracks.firstIndex(where: { $0.id == currentTrack.id }) else {
            currentTrack = tracks.first ?? .placeholder
            elapsedTime = 0
            return
        }
        currentTrack = tracks[(index + 1) % tracks.count]
        elapsedTime = 0
    }

    func previousTrack() {
        let tracks = Track.previewTracks
        guard let index = tracks.firstIndex(where: { $0.id == currentTrack.id }) else {
            currentTrack = tracks.last ?? .placeholder
            elapsedTime = 0
            return
        }
        currentTrack = tracks[(index - 1 + tracks.count) % tracks.count]
        elapsedTime = 0
    }

    private func publishNowPlaying() {
        nowPlayingController.publish(track: currentTrack, state: state, elapsedTime: elapsedTime)
    }
}
