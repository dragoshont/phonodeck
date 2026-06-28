import SwiftUI

/// The discrete per-item source marker used across the unified library, lists, and
/// cards so provenance is never ambiguous (YouTube / YT Music / Spotify).
/// Three densities for different contexts.
struct SourceBadge: View {
    enum Style {
        case dot      // dense list rows
        case corner   // card corner overlay
        case pill     // detail / headers
    }

    let source: MediaSourceKind
    var style: Style = .pill

    private var label: String { "Source: \(source.descriptor.displayName)" }

    var body: some View {
        switch style {
        case .dot:
            Circle()
                .fill(source.tint)
                .frame(width: 8, height: 8)
                .accessibilityLabel(label)
        case .corner:
            Circle()
                .fill(source.tint)
                .frame(width: 12, height: 12)
                .overlay(Circle().strokeBorder(.black.opacity(0.35), lineWidth: 2))
                .accessibilityLabel(label)
        case .pill:
            HStack(spacing: 5) {
                Image(systemName: source.descriptor.symbolName)
                    .font(.system(size: 9, weight: .semibold))
                Text(source.descriptor.displayName)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(source.tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(source.tint.opacity(0.16), in: Capsule())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
        }
    }
}

#Preview("Source badges") {
    VStack(alignment: .leading, spacing: 12) {
        ForEach(MediaSourceKind.allCases) { kind in
            HStack(spacing: 16) {
                SourceBadge(source: kind, style: .dot)
                SourceBadge(source: kind, style: .corner)
                SourceBadge(source: kind, style: .pill)
            }
        }
    }
    .padding()
}
