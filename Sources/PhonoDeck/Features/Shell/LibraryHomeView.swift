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
                sourceStatusPanel
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
            Text("Source-aware library surfaces appear here as each provider is connected. YouTube Music remains the active P0 music route.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var sourceStrip: some View {
        HStack(spacing: DesignTokens.standardSpacing) {
            ForEach(sources) { source in
                SourcePill(source: source, isActive: source.id == activeSource)
            }
        }
    }

    private var sourceStatusPanel: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: activeSource.descriptor.symbolName)
                .font(.title3)
                .frame(width: 34, height: 34)
                .background(activeSource.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .foregroundStyle(activeSource.tint)

            VStack(alignment: .leading, spacing: 4) {
                Text(activeSource.descriptor.displayName)
                    .font(.headline)
                Text(activeSource.descriptor.nativeRole)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(activeSource.isYouTubePlayerBacked ? "Active" : "Planned source")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(activeSource.isYouTubePlayerBacked ? .green : .secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                            .fixedSize(horizontal: false, vertical: true)
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
