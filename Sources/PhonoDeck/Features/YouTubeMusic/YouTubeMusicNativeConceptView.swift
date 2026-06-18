import SwiftUI

struct YouTubeMusicNativeConceptView: View {
    @State private var searchText = ""

    private let featuredTracks = YouTubeMusicConceptTrack.featured
    private let queueTracks = YouTubeMusicConceptTrack.queue

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.comfortableSpacing) {
                header
                HStack(alignment: .top, spacing: DesignTokens.comfortableSpacing) {
                    VStack(alignment: .leading, spacing: DesignTokens.comfortableSpacing) {
                        heroPanel
                        shelf(title: "From YouTube Music", tracks: featuredTracks)
                        queuePanel
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    routePanel
                        .frame(width: 280)
                }
            }
            .padding(DesignTokens.comfortableSpacing)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("YouTube Music")
    }

    private var header: some View {
        HStack(spacing: DesignTokens.standardSpacing) {
            VStack(alignment: .leading, spacing: 6) {
                Label("YouTube Music", systemImage: "play.rectangle.fill")
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("Native library, queue, and control surface")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search YouTube Music", text: $searchText)
                    .textFieldStyle(.plain)
                    .frame(width: 230)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var heroPanel: some View {
        HStack(spacing: DesignTokens.comfortableSpacing) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.red.gradient)
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.title)
                    Text("Premium Session")
                        .font(.title2.weight(.semibold))
                    Text("Official YouTube route")
                        .font(.callout)
                        .opacity(0.82)
                }
                .foregroundStyle(.white)
                .padding(18)
            }
            .frame(width: 230, height: 230)

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Control Room")
                        .font(.title.weight(.semibold))
                    Text("Browse and organize in PhonoDeck; playback stays on an official YouTube surface until Google provides a native route.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    Button {
                        NSWorkspace.shared.open(URL(string: "https://music.youtube.com/")!)
                    } label: {
                        Label("Open YouTube Music", systemImage: "arrow.up.right.square")
                    }
                    Button {} label: {
                        Label("Connect Google", systemImage: "person.crop.circle.badge.checkmark")
                    }
                }

                HStack(spacing: 10) {
                    CapabilityChip(title: "Search", symbol: "magnifyingglass", color: .blue)
                    CapabilityChip(title: "Queue", symbol: "text.line.first.and.arrowtriangle.forward", color: .green)
                    CapabilityChip(title: "No downloads", symbol: "lock", color: .orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func shelf(title: String, tracks: [YouTubeMusicConceptTrack]) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.standardSpacing) {
            Text(title)
                .font(.title2.weight(.semibold))
            HStack(spacing: DesignTokens.standardSpacing) {
                ForEach(tracks) { track in
                    YouTubeTrackTile(track: track)
                }
            }
        }
    }

    private var queuePanel: some View {
        VStack(alignment: .leading, spacing: DesignTokens.standardSpacing) {
            HStack {
                Text("Up Next")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button {} label: {
                    Image(systemName: "ellipsis")
                }
                .buttonStyle(.borderless)
            }

            VStack(spacing: 0) {
                ForEach(queueTracks) { track in
                    YouTubeQueueRow(track: track)
                    if track.id != queueTracks.last?.id {
                        Divider().padding(.leading, 48)
                    }
                }
            }
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var routePanel: some View {
        VStack(alignment: .leading, spacing: DesignTokens.standardSpacing) {
            Text("Playback Route")
                .font(.headline)

            RouteStatusRow(symbol: "safari", title: "Official surface", status: "Ready", color: .green)
            RouteStatusRow(symbol: "keyboard", title: "Native controls", status: "Limited", color: .orange)
            RouteStatusRow(symbol: "arrow.down.circle", title: "Downloads", status: "Blocked", color: .red)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Target")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("A native command surface that hands playback to YouTube's permitted player instead of hiding it.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(minHeight: 420, alignment: .top)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct CapabilityChip: View {
    let title: String
    let symbol: String
    let color: Color

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.14), in: Capsule())
            .foregroundStyle(color)
    }
}

private struct RouteStatusRow: View {
    let symbol: String
    let title: String
    let status: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .frame(width: 26, height: 26)
                .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.medium))
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

private struct YouTubeTrackTile: View {
    let track: YouTubeMusicConceptTrack

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(track.color.gradient)
                .aspectRatio(1, contentMode: .fit)
                .overlay(alignment: .bottomLeading) {
                    Image(systemName: track.symbol)
                        .font(.title2)
                        .foregroundStyle(.white)
                        .padding(10)
                }
            Text(track.title)
                .font(.headline)
                .lineLimit(1)
            Text(track.artist)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 150, alignment: .leading)
    }
}

private struct YouTubeQueueRow: View {
    let track: YouTubeMusicConceptTrack

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(track.color.gradient)
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: track.symbol)
                        .font(.caption)
                        .foregroundStyle(.white)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.callout.weight(.medium))
                Text(track.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(track.duration)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }
}

private struct YouTubeMusicConceptTrack: Identifiable {
    let id: String
    let title: String
    let artist: String
    let duration: String
    let symbol: String
    let color: Color

    static let featured: [YouTubeMusicConceptTrack] = [
        YouTubeMusicConceptTrack(id: "ytm-featured-1", title: "Premium Mix", artist: "YouTube Music", duration: "3:41", symbol: "waveform", color: .red),
        YouTubeMusicConceptTrack(id: "ytm-featured-2", title: "Liked Songs", artist: "Your account", duration: "4:02", symbol: "heart.fill", color: .pink),
        YouTubeMusicConceptTrack(id: "ytm-featured-3", title: "Release Radar", artist: "Subscriptions", duration: "2:58", symbol: "sparkles", color: .blue),
        YouTubeMusicConceptTrack(id: "ytm-featured-4", title: "Focus Queue", artist: "PhonoDeck", duration: "5:14", symbol: "list.bullet", color: .green)
    ]

    static let queue: [YouTubeMusicConceptTrack] = [
        YouTubeMusicConceptTrack(id: "ytm-queue-1", title: "Premium Mix", artist: "YouTube Music", duration: "3:41", symbol: "waveform", color: .red),
        YouTubeMusicConceptTrack(id: "ytm-queue-2", title: "Evening Rotation", artist: "Official playback", duration: "4:20", symbol: "moon.fill", color: .indigo),
        YouTubeMusicConceptTrack(id: "ytm-queue-3", title: "Saved Track", artist: "Your account", duration: "3:08", symbol: "checkmark.circle.fill", color: .teal),
        YouTubeMusicConceptTrack(id: "ytm-queue-4", title: "Next Discovery", artist: "YouTube Music", duration: "2:47", symbol: "play.rectangle", color: .orange)
    ]
}