import SwiftUI

struct NowPlayingBar: View {
    @ObservedObject var playback: PlaybackCoordinator

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: DesignTokens.comfortableSpacing) {
                artwork
                metadata
                Spacer(minLength: DesignTokens.standardSpacing)
                controls
                Spacer(minLength: DesignTokens.standardSpacing)
                routing
            }
            .padding(.horizontal, DesignTokens.comfortableSpacing)
            .frame(height: DesignTokens.playerHeight)
            .background(.bar)
        }
    }

    private var artwork: some View {
        RoundedRectangle(cornerRadius: DesignTokens.artworkCornerRadius, style: .continuous)
            .fill(playback.currentTrack.source.tint.gradient)
            .frame(width: 54, height: 54)
            .overlay {
                Image(systemName: "music.note")
                    .foregroundStyle(.white)
            }
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(playback.currentTrack.title)
                .font(.headline)
                .lineLimit(1)
            Text("\(playback.currentTrack.artist) - \(playback.currentTrack.album)")
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 280, alignment: .leading)
    }

    private var controls: some View {
        VStack(spacing: 8) {
            HStack(spacing: DesignTokens.standardSpacing) {
                Button(action: playback.previousTrack) {
                    Image(systemName: "backward.fill")
                }
                Button(action: playback.togglePlayPause) {
                    Image(systemName: playback.state == .playing ? "pause.fill" : "play.fill")
                        .frame(width: 26)
                }
                .keyboardShortcut(.space, modifiers: [])
                Button(action: playback.nextTrack) {
                    Image(systemName: "forward.fill")
                }
            }
            .buttonStyle(.borderless)
            ProgressView(value: playback.progress)
                .frame(width: 260)
        }
    }

    private var routing: some View {
        HStack(spacing: DesignTokens.standardSpacing) {
            Button(action: {}) {
                Image(systemName: "airplayaudio")
            }
            .help("AirPlay routes for supported native playback")
            Button(action: {}) {
                Image(systemName: "speaker.wave.2")
            }
            .help("Output devices")
        }
        .buttonStyle(.borderless)
        .font(.title3)
    }
}
