import SwiftUI

/// One music-service row for the Settings "Music Services" section, matching the
/// Storybook `.srow` design: a subtle brand-tinted SF Symbol tile + name + a
/// one-line description (or the connected account) + a single right-aligned
/// action. No saturated fills, no capability grid — restrained, Apple-native.
struct ServiceAccountRow: View {
    let title: String
    let kind: MediaSourceKind
    /// One-line description of what the source offers (shown when not connected).
    let detail: String
    let state: SourceConnectionState
    let busy: Bool
    let canConnect: Bool
    var readinessStatus: SourceProviderStatus? = nil
    let connect: () -> Void
    let disconnect: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            iconTile
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(statusText)
                    .font(.system(size: 11.5))
                    .foregroundStyle(statusColor)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.vertical, 3)
    }

    /// 30×30 rounded tile, brand tint at 16% with a brand-colored SF Symbol —
    /// the same restrained treatment as the Storybook `.srow .ic`.
    private var iconTile: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(kind.tint.opacity(0.16))
            .frame(width: 30, height: 30)
            .overlay(
                Image(systemName: kind.descriptor.symbolName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(kind.tint)
            )
            .accessibilityHidden(true)
    }

    @ViewBuilder private var trailing: some View {
        if busy {
            ProgressView().controlSize(.small)
        } else if state.isConnected {
            Button("Disconnect", action: disconnect)
                .buttonStyle(.bordered)
                .controlSize(.small)
        } else if canConnect {
            Button(connectLabel, action: connect)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        } else {
            Text("Coming soon")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(.quaternary, in: Capsule())
        }
    }

    private var connectLabel: String {
        if case .failed = state { return "Try Again" }
        return "Connect"
    }

    private var statusText: String {
        if let readinessStatus {
            return SourceReadinessPresentation.make(source: kind, status: readinessStatus).detail
        }
        switch state {
        case .notConnected:
            return detail
        case .connecting:
            return "Connecting… continue in your browser"
        case let .connected(summary):
            if summary.tier != .none, summary.tier != .unknown {
                return "Connected · \(summary.displayName) · \(summary.tier.displayName)"
            }
            return "Connected · \(summary.displayName)"
        case let .failed(reason):
            return reason
        }
    }

    private var statusColor: Color {
        if let readinessStatus {
            return SourceReadinessPresentation.make(source: kind, status: readinessStatus).severity.color
        }
        if case .failed = state { return .red }
        return .secondary
    }
}

#Preview("Service rows") {
    Form {
        Section("Music Services") {
            ServiceAccountRow(title: "YouTube & YouTube Music", kind: .youtubeMusic, detail: "Search, playlists, likes, and the visible official player.",
                              state: .connected(SourceAccountSummary(displayName: "Dragos Hont", tier: .none, detail: nil)),
                              busy: false, canConnect: true, connect: {}, disconnect: {})
            ServiceAccountRow(title: "Spotify", kind: .spotify, detail: "Metadata, library surfaces, and Spotify Connect control.",
                              state: .notConnected, busy: false, canConnect: true, connect: {}, disconnect: {})
            ServiceAccountRow(title: "Plex", kind: .plex, detail: "Native playback, your library, and downloads.",
                              state: .notConnected, busy: false, canConnect: true, connect: {}, disconnect: {})
            ServiceAccountRow(title: "Own Files", kind: .ownFiles, detail: "User-owned files, imports, and iTunes XML.",
                              state: .notConnected, busy: false, canConnect: false, connect: {}, disconnect: {})
        }
    }
    .formStyle(.grouped)
    .frame(width: 560, height: 320)
}
