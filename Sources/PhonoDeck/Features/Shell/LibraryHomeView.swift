import SwiftUI

struct LibraryHomeView: View {
    let section: LibrarySection
    let sources: [MediaSourceDescriptor]
    let activeSource: MediaSourceKind

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.comfortableSpacing) {
                header
                sourceStrip
                recentlyPlayed
                libraryGrid
            }
            .padding(DesignTokens.comfortableSpacing)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(section.title)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(section.title)
                .font(.largeTitle.weight(.semibold))
            Text("Plex-first native playback with service-aware library surfaces.")
                .foregroundStyle(.secondary)
        }
    }

    private var sourceStrip: some View {
        HStack(spacing: DesignTokens.standardSpacing) {
            ForEach(sources) { source in
                SourcePill(source: source, isActive: source.id == activeSource)
            }
        }
    }

    private var recentlyPlayed: some View {
        VStack(alignment: .leading, spacing: DesignTokens.standardSpacing) {
            Text("Recently Played")
                .font(.title2.weight(.semibold))
            HStack(spacing: DesignTokens.standardSpacing) {
                ForEach(Track.previewTracks) { track in
                    TrackCard(track: track)
                }
            }
        }
    }

    private var libraryGrid: some View {
        VStack(alignment: .leading, spacing: DesignTokens.standardSpacing) {
            Text("Library Sources")
                .font(.title2.weight(.semibold))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: DesignTokens.standardSpacing)], spacing: DesignTokens.standardSpacing) {
                ForEach(sources) { source in
                    VStack(alignment: .leading, spacing: 8) {
                        Label(source.displayName, systemImage: source.symbolName)
                            .font(.headline)
                        Text(source.nativeRole)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }
}

private struct SourcePill: View {
    let source: MediaSourceDescriptor
    let isActive: Bool

    var body: some View {
        Label(source.displayName, systemImage: source.symbolName)
            .font(.callout.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isActive ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.10), in: Capsule())
            .foregroundStyle(isActive ? Color.accentColor : Color.primary)
    }
}

private struct TrackCard: View {
    let track: Track

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: DesignTokens.artworkCornerRadius, style: .continuous)
                .fill(track.source.tint.gradient)
                .aspectRatio(1, contentMode: .fit)
                .overlay(alignment: .bottomLeading) {
                    Image(systemName: track.source.descriptor.symbolName)
                        .font(.title)
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
        .frame(width: 160, alignment: .leading)
    }
}
