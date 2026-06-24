import Foundation

/// Holds the live source adapters and resolves them by kind. This is the single
/// place the app (and a future backend gateway) asks "give me the Spotify
/// adapter". `@MainActor` because the app drives it from the UI layer.
@MainActor
final class SourceRegistry: ObservableObject {
    @Published private(set) var adapters: [MediaSourceKind: MusicSourceAdapter]

    init(adapters: [MusicSourceAdapter]) {
        var map: [MediaSourceKind: MusicSourceAdapter] = [:]
        for adapter in adapters { map[adapter.kind] = adapter }
        self.adapters = map
    }

    func adapter(for kind: MediaSourceKind) -> MusicSourceAdapter? {
        adapters[kind]
    }

    /// All adapters in a stable, display-friendly order.
    var ordered: [MusicSourceAdapter] {
        MediaSourceKind.allCases.compactMap { adapters[$0] }
    }

    /// Adapters whose playback feature is usable right now (at their current tier).
    var playableNow: [MusicSourceAdapter] {
        ordered.filter { $0.canPlayInApp }
    }

    /// Adapters with a connected account.
    var connected: [MusicSourceAdapter] {
        ordered.filter { $0.connectionState.isConnected }
    }

    /// The default registry with all five source adapters.
    static func makeDefault() -> SourceRegistry {
        SourceRegistry(adapters: [
            YouTubeMusicAdapter(),
            YouTubeAdapter(),
            SpotifyAdapter(),
            PlexAdapter(),
            OwnFilesAdapter()
        ])
    }
}
