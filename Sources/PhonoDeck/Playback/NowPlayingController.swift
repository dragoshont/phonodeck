import Foundation
import MediaPlayer

@MainActor
protocol NowPlayingPublishing: AnyObject {
    func configure(
        play: @escaping @MainActor () -> Void,
        pause: @escaping @MainActor () -> Void,
        next: @escaping @MainActor () -> Void,
        previous: @escaping @MainActor () -> Void
    )
    func setCommandsEnabled(_ isEnabled: Bool)
    func publish(track: Track, state: PlaybackState, elapsedTime: TimeInterval)
    func publish(track: MusicTrack, state: PlaybackState, elapsedTime: TimeInterval, duration: TimeInterval?)
    func clear()
}

@MainActor
final class NowPlayingController: NSObject, NowPlayingPublishing {
    private var playHandler: (@MainActor () -> Void)?
    private var pauseHandler: (@MainActor () -> Void)?
    private var nextHandler: (@MainActor () -> Void)?
    private var previousHandler: (@MainActor () -> Void)?

    func configure(
        play: @escaping @MainActor () -> Void,
        pause: @escaping @MainActor () -> Void,
        next: @escaping @MainActor () -> Void,
        previous: @escaping @MainActor () -> Void
    ) {
        playHandler = play
        pauseHandler = pause
        nextHandler = next
        previousHandler = previous

        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.isEnabled = true

        commandCenter.playCommand.addTarget(self, action: #selector(handlePlayCommand(_:)))
        commandCenter.pauseCommand.addTarget(self, action: #selector(handlePauseCommand(_:)))
        commandCenter.togglePlayPauseCommand.addTarget(self, action: #selector(handleToggleCommand(_:)))
        commandCenter.nextTrackCommand.addTarget(self, action: #selector(handleNextCommand(_:)))
        commandCenter.previousTrackCommand.addTarget(self, action: #selector(handlePreviousCommand(_:)))
    }

    func setCommandsEnabled(_ isEnabled: Bool) {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.isEnabled = isEnabled
        commandCenter.pauseCommand.isEnabled = isEnabled
        commandCenter.togglePlayPauseCommand.isEnabled = isEnabled
        commandCenter.nextTrackCommand.isEnabled = isEnabled
        commandCenter.previousTrackCommand.isEnabled = isEnabled
    }

    func clear() {
        setCommandsEnabled(false)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        MPNowPlayingInfoCenter.default().playbackState = .stopped
    }

    func publish(track: Track, state: PlaybackState, elapsedTime: TimeInterval) {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPMediaItemPropertyAlbumTitle: track.album,
            MPMediaItemPropertyPlaybackDuration: track.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsedTime,
            MPNowPlayingInfoPropertyPlaybackRate: state == .playing ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue
        ]
        MPNowPlayingInfoCenter.default().playbackState = state.nowPlayingState
    }

    func publish(track: MusicTrack, state: PlaybackState, elapsedTime: TimeInterval, duration: TimeInterval?) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artistName,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsedTime,
            MPNowPlayingInfoPropertyPlaybackRate: state == .playing ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue
        ]
        if let albumTitle = track.albumTitle { info[MPMediaItemPropertyAlbumTitle] = albumTitle }
        if let duration { info[MPMediaItemPropertyPlaybackDuration] = duration }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = state.nowPlayingState
    }

    @objc private func handlePlayCommand(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        playHandler?()
        return .success
    }

    @objc private func handlePauseCommand(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        pauseHandler?()
        return .success
    }

    @objc private func handleToggleCommand(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        if MPNowPlayingInfoCenter.default().playbackState == .playing {
            pauseHandler?()
        } else {
            playHandler?()
        }
        return .success
    }

    @objc private func handleNextCommand(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        nextHandler?()
        return .success
    }

    @objc private func handlePreviousCommand(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        previousHandler?()
        return .success
    }
}

private extension PlaybackState {
    var nowPlayingState: MPNowPlayingPlaybackState {
        switch self {
        case .playing: .playing
        case .paused: .paused
        case .stopped: .stopped
        }
    }
}
