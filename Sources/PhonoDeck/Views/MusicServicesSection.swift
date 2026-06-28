import SwiftUI

/// The contents of the Settings "Music Services" section: one consistent
/// `ServiceAccountRow` per source. YouTube + YouTube Music share the single Google
/// account (state + actions injected from the host); Spotify is driven by its adapter.
struct MusicServicesSection: View {
    @StateObject private var model: SourcesOverviewModel
    private let youTubeState: SourceConnectionState
    private let connectYouTube: () -> Void
    private let disconnectYouTube: () -> Void

    init(
        registry: SourceRegistry,
        youTubeState: SourceConnectionState,
        connectYouTube: @escaping () -> Void,
        disconnectYouTube: @escaping () -> Void
    ) {
        _model = StateObject(wrappedValue: SourcesOverviewModel(registry: registry))
        self.youTubeState = youTubeState
        self.connectYouTube = connectYouTube
        self.disconnectYouTube = disconnectYouTube
    }

    var body: some View {
        Group {
            ServiceAccountRow(
                title: "YouTube & YouTube Music",
                kind: .youtubeMusic,
                detail: "Search, playlists, likes, and the visible official player.",
                state: youTubeState,
                busy: youTubeState == .connecting,
                canConnect: true,
                readinessStatus: readinessStatus(for: .youtubeMusic, state: youTubeState, canConnect: true),
                connect: connectYouTube,
                disconnect: disconnectYouTube
            )
            adapterRow(.spotify, canConnect: true)

            if let error = model.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .task {
            model.refreshReadiness()
        }
    }

    @ViewBuilder
    private func adapterRow(_ kind: MediaSourceKind, canConnect: Bool) -> some View {
        if let adapter = model.registry.adapter(for: kind) {
            ServiceAccountRow(
                title: adapter.descriptor.displayName,
                kind: kind,
                detail: adapter.descriptor.nativeRole,
                state: adapter.connectionState,
                busy: model.busyKind == kind,
                canConnect: canConnect,
                readinessStatus: model.readinessStatus(for: kind) ?? readinessStatus(for: kind, state: adapter.connectionState, canConnect: canConnect),
                connect: { model.connect(kind) },
                disconnect: { model.disconnect(kind) }
            )
            .id("\(kind.rawValue)-\(model.tick)")
        }
    }

    private func readinessStatus(for kind: MediaSourceKind, state: SourceConnectionState, canConnect: Bool) -> SourceProviderStatus {
        switch state {
        case .connected:
            return .ready
        case .connecting:
            return .partial
        case .failed(let reason):
            return .failed(reason)
        case .notConnected:
            return canConnect ? .notConnected : .notConfigured("Setup for \(kind.descriptor.displayName) is not available yet.")
        }
    }
}
