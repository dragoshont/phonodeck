import SwiftUI

/// The contents of the Settings "Music Services" section: one consistent
/// `ServiceAccountRow` per source. YouTube + YouTube Music share the single Google
/// account (state + actions injected from the host); Spotify and Plex are driven
/// by their adapters via `SourcesOverviewModel`; Own Files is a planned folder pick.
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
        ServiceAccountRow(
            title: "YouTube & YouTube Music",
            kind: .youtubeMusic,
            detail: "Search, playlists, likes, and the visible official player.",
            state: youTubeState,
            busy: youTubeState == .connecting,
            canConnect: true,
            connect: connectYouTube,
            disconnect: disconnectYouTube
        )
        adapterRow(.spotify, canConnect: true)
        adapterRow(.plex, canConnect: true)
        adapterRow(.ownFiles, canConnect: false)

        if let error = model.lastError {
            Text(error)
                .font(.caption)
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
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
                connect: { model.connect(kind) },
                disconnect: { model.disconnect(kind) }
            )
            .id("\(kind.rawValue)-\(model.tick)")
        }
    }
}
