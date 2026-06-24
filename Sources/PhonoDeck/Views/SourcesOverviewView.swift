import SwiftUI

/// Drives connect/disconnect for the source adapters and refreshes the overview.
@MainActor
final class SourcesOverviewModel: ObservableObject {
    let registry: SourceRegistry
    @Published var busyKind: MediaSourceKind?
    @Published var lastError: String?
    @Published private(set) var readinessByKind: [MediaSourceKind: SourceProviderReadiness] = [:]
    /// Bumped after connect/disconnect so the (value-type) capability cards refresh.
    @Published private(set) var tick = 0

    init(registry: SourceRegistry) {
        self.registry = registry
    }

    func connect(_ kind: MediaSourceKind) {
        guard let adapter = registry.adapter(for: kind) else { return }
        busyKind = kind
        lastError = nil
        Task {
            do { _ = try await adapter.connect() }
            catch { lastError = error.localizedDescription }
            await refreshReadiness(for: kind)
            busyKind = nil
            tick += 1
        }
    }

    func disconnect(_ kind: MediaSourceKind) {
        guard let adapter = registry.adapter(for: kind) else { return }
        busyKind = kind
        Task {
            do { try await adapter.disconnect() }
            catch { lastError = error.localizedDescription }
            await refreshReadiness(for: kind)
            busyKind = nil
            tick += 1
        }
    }

    func refreshReadiness() {
        Task {
            for adapter in registry.ordered {
                await adapter.restore()
                let kind = adapter.kind
                await refreshReadiness(for: kind)
            }
            tick += 1
        }
    }

    func refreshReadiness(for kind: MediaSourceKind) async {
        guard let adapter = registry.adapter(for: kind) else { return }
        let feature: SourceFeature = switch kind {
        case .youtube, .youtubeMusic, .spotify, .plex, .ownFiles: .playback
        }
        readinessByKind[kind] = localReadiness(for: adapter, feature: feature)
    }

    func localReadiness(for adapter: MusicSourceAdapter, feature: SourceFeature) -> SourceProviderReadiness {
        let status: SourceProviderStatus
        switch adapter.kind {
        case .ownFiles:
            status = .ready
        case .spotify, .plex:
            switch adapter.connectionState {
            case .connected:
                status = .partial
            case .connecting:
                status = .partial
            case .failed(let reason):
                status = .failed(reason)
            case .notConnected:
                status = .notConnected
            }
        case .youtube, .youtubeMusic:
            switch adapter.connectionState {
            case .connected:
                status = .partial
            case .connecting:
                status = .partial
            case .failed(let reason):
                status = .failed(reason)
            case .notConnected:
                status = .notConnected
            }
        }
        return SourceProviderReadiness(source: adapter.kind, feature: feature, status: status, account: adapter.connectionState.account)
    }

    func readinessStatus(for kind: MediaSourceKind) -> SourceProviderStatus? {
        readinessByKind[kind]?.status
    }
}

/// A real, viewable surface that proves the source-abstraction foundation: every
/// configured source with its discrete badge, connection/tier, per-feature
/// capability (resolved honestly, free vs paid), and a Connect/Disconnect control
/// for sources whose account flow is wired. Driven entirely by the registry and
/// the portable capability resolver — no per-source UI branching.
struct SourcesOverviewView: View {
    @StateObject private var model: SourcesOverviewModel

    init(registry: SourceRegistry) {
        _model = StateObject(wrappedValue: SourcesOverviewModel(registry: registry))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(model.registry.ordered, id: \.kind) { adapter in
                SourceCapabilityCard(adapter: adapter, model: model)
            }
            if let error = model.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .id(model.tick)
    }
}

private struct SourceCapabilityCard: View {
    let adapter: MusicSourceAdapter
    @ObservedObject var model: SourcesOverviewModel

    /// Account flows wired today: Spotify (Web API) and Plex (PIN sign-in).
    /// YouTube uses its own existing Google account flow; Own Files has no account.
    private var isConnectable: Bool { adapter.kind == .spotify || adapter.kind == .plex }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                SourceBadge(source: adapter.kind, style: .pill)
                Spacer()
                Text(connectionLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if isConnectable { connectControl }
            }
            Text(adapter.descriptor.nativeRole)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                ForEach(SourceFeature.allCases, id: \.self) { feature in
                    CapabilityChip(feature: feature, status: adapter.capabilityStatus(feature))
                }
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder private var connectControl: some View {
        if model.busyKind == adapter.kind {
            ProgressView().controlSize(.small)
        } else if adapter.connectionState.isConnected {
            Button("Disconnect") { model.disconnect(adapter.kind) }
                .buttonStyle(.borderless)
                .controlSize(.small)
        } else {
            Button("Connect") { model.connect(adapter.kind) }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
    }

    private var connectionLabel: String {
        switch adapter.connectionState {
        case .notConnected: "Not connected"
        case .connecting: "Connecting…"
        case let .connected(summary):
            summary.tier == .none
                ? summary.displayName
                : "\(summary.displayName) · \(summary.tier.displayName)"
        case let .failed(reason): "Failed: \(reason)"
        }
    }
}

private struct CapabilityChip: View {
    let feature: SourceFeature
    let status: MusicSourceCapabilityStatus

    var body: some View {
        VStack(spacing: 3) {
            Circle()
                .fill(status.uiColor)
                .frame(width: 7, height: 7)
            Text(feature.displayName)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .help("\(feature.displayName): \(status.rawValue)")
        .accessibilityLabel("\(feature.displayName): \(status.rawValue)")
    }
}

#Preview("Sources overview") {
    SourcesOverviewView(registry: SourceRegistry.makeDefault())
        .frame(width: 460)
        .padding()
}
