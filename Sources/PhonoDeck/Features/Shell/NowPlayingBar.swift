import SwiftUI

struct NowPlayingBar: View {
    let activeSource: MediaSourceKind
    @ObservedObject var playback: PlaybackCoordinator
    let youtubeNowPlaying: YouTubeVideoSearchResult?
    @ObservedObject var youtubePlayback: YouTubePlaybackBridge
    let openQueue: () -> Void

    var body: some View {
        HStack(spacing: 18) {
            artwork
            metadata
            controls
            routing
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .frame(maxWidth: 860)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.separator.opacity(0.35), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.18), radius: 24, y: 8)
    }

    private var isYouTubeMode: Bool {
        activeSource.isYouTubePlayerBacked && !isNativeSessionActive
    }

    private var isNativeSessionActive: Bool {
        playback.queueSnapshot.currentItem != nil && playback.routeDecision?.engine == .nativeAV
    }

    private var youtubeDisplaySource: MediaSourceKind {
        guard let youtubeNowPlaying else { return activeSource.isYouTubePlayerBacked ? activeSource : .youtubeMusic }
        return youtubeNowPlaying.sourceLabel == "Music" || youtubeNowPlaying.isSongLike ? .youtubeMusic : .youtube
    }

    private var displaySource: MediaSourceKind {
        isYouTubeMode ? youtubeDisplaySource : playback.currentTrack.source
    }

    private var artwork: some View {
        Group {
            if isYouTubeMode, let youtubeNowPlaying {
                CachedArtworkImage(url: youtubeNowPlaying.thumbnailURL) {
                        fallbackArtwork(symbol: youtubeDisplaySource.descriptor.symbolName, source: youtubeDisplaySource)
                }
                .scaledToFill()
            } else {
                fallbackArtwork(symbol: "music.note", source: playback.currentTrack.source)
            }
        }
        .frame(width: 46, height: 46)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.artworkCornerRadius, style: .continuous))
    }

    private func fallbackArtwork(symbol: String, source: MediaSourceKind) -> some View {
        RoundedRectangle(cornerRadius: DesignTokens.artworkCornerRadius, style: .continuous)
            .fill(source.tint.gradient)
            .overlay {
                Image(systemName: symbol)
                    .foregroundStyle(.white)
            }
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.headline)
                .lineLimit(2)
                .truncationMode(.tail)
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
            Label(displaySource.shortDisplayName, systemImage: displaySource.descriptor.symbolName)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(displaySource.tint)
        }
        .frame(minWidth: 170, maxWidth: 260, alignment: .leading)
        .layoutPriority(1)
    }

    private var title: String {
        if isYouTubeMode {
            youtubeNowPlaying?.title ?? "Select a song"
        } else {
            playback.currentTrack.title
        }
    }

    private var subtitle: String {
        if isYouTubeMode {
            if let youtubeNowPlaying {
                return youtubeNowPlaying.channelTitle
            }
            return "Choose a song to start playback"
        }
        return "\(playback.currentTrack.artist) - \(playback.currentTrack.album)"
    }

    private var controls: some View {
        VStack(spacing: 7) {
            HStack(spacing: DesignTokens.standardSpacing) {
                Button(action: previousAction) {
                    Image(systemName: "backward.fill")
                }
                .disabled(isYouTubeMode ? !youtubePlayback.canPlayPrevious : false)
                .help(isYouTubeMode ? "Previous song in the current PhonoDeck list" : "Previous")

                Button(action: playPauseAction) {
                    Image(systemName: playPauseSymbol)
                        .frame(width: 26)
                }
                .disabled(isYouTubeMode ? !canControlYouTubePlayer : false)
                .help(isYouTubeMode ? "Play or pause the visible YouTube player" : "Play or pause")

                Button(action: nextAction) {
                    Image(systemName: "forward.fill")
                }
                .disabled(isYouTubeMode ? !youtubePlayback.canPlayNext : false)
                .help(isYouTubeMode ? "Next song in the current PhonoDeck list" : "Next")
            }
            .buttonStyle(.borderless)
            .font(.title3)

            if isYouTubeMode {
                VStack(spacing: 3) {
                    ProgressView(value: youtubeProgress)
                        .frame(width: 260)
                    HStack(spacing: 8) {
                        Text(formatTime(youtubePlayback.currentTime))
                        Spacer(minLength: 0)
                        Text(playerStateText)
                        Spacer(minLength: 0)
                        Text(remainingTimeText)
                    }
                    .frame(width: 260)
                    .monospacedDigit()
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            } else {
                ProgressView(value: playback.progress)
                    .frame(width: 260)
            }
        }
        .frame(width: 300)
    }

    private var playPauseSymbol: String {
        if isYouTubeMode {
            youtubePlayback.playerState == .playing ? "pause.fill" : "play.fill"
        } else {
            playback.state == .playing ? "pause.fill" : "play.fill"
        }
    }

    private var canControlYouTubePlayer: Bool {
        guard youtubeNowPlaying != nil else { return false }
        if case .failed = youtubePlayback.playerState { return false }
        return true
    }

    private var playerStateText: String {
        if case .failed = youtubePlayback.playerState {
            return "Try another song"
        }
        return youtubePlayback.playerState.title
    }

    private func previousAction() {
        isYouTubeMode ? youtubePlayback.previous() : playback.previousTrack()
    }

    private func playPauseAction() {
        isYouTubeMode ? youtubePlayback.playPause() : playback.togglePlayPause()
    }

    private func nextAction() {
        isYouTubeMode ? youtubePlayback.next() : playback.nextTrack()
    }

    private var timeText: String {
        guard youtubePlayback.duration > 0 else { return "--:--" }
        return "\(formatTime(youtubePlayback.currentTime)) / \(formatTime(youtubePlayback.duration))"
    }

    private var remainingTimeText: String {
        guard youtubePlayback.duration > 0 else { return "--:--" }
        let remaining = max(youtubePlayback.duration - youtubePlayback.currentTime, 0)
        return "-\(formatTime(remaining))"
    }

    private var youtubeProgress: Double {
        guard youtubePlayback.duration > 0 else { return 0 }
        return min(max(youtubePlayback.currentTime / youtubePlayback.duration, 0), 1)
    }

    private func formatTime(_ seconds: Double) -> String {
        let totalSeconds = max(Int(seconds), 0)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var routing: some View {
        HStack(spacing: DesignTokens.standardSpacing) {
            Button(action: openQueue) {
                Image(systemName: "list.bullet")
            }
            .help("Show Up Next")

            if isYouTubeMode {
                VStack(alignment: .trailing, spacing: 4) {
                    Label(youtubeDisplaySource.descriptor.displayName, systemImage: youtubeDisplaySource.descriptor.symbolName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(youtubeDisplaySource.tint)
                    Text(timeText)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .help("Playback uses the official visible YouTube player")
            } else {
                Button(action: {}) {
                    Image(systemName: "airplayaudio")
                }
                .help("AirPlay routes for supported native playback")

                Button(action: muteAction) {
                    Image(systemName: "speaker.wave.2")
                }
                .disabled(true)
                .help("Native source volume will be enabled with source playback integrations")
            }
        }
        .buttonStyle(.borderless)
        .font(.title3)
    }

    private func muteAction() {
    }
}

private extension MediaSourceKind {
    var shortDisplayName: String {
        switch self {
        case .youtubeMusic: "YT Music"
        case .youtube: "YouTube"
        case .plex: "Plex"
        case .spotify: "Spotify"
        case .ownFiles: "Files"
        }
    }
}
