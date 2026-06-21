import Foundation

/// Identifies the playback engine that should execute a `PlaybackPlan`.
enum PlaybackEngineKind: String, Equatable, Sendable {
    case webEmbed          // WKWebView official embed (YouTube IFrame / Spotify iFrame)
    case nativeAV          // AVFoundation (Plex / own files)
    case connectRemote     // external device control (Spotify Connect)
    case none
}

/// Routes a `PlaybackPlan` to the correct engine. The decision logic is portable;
/// only the engine implementations are platform-specific (the YouTube embed exists
/// today; the AVFoundation engine lands with Plex).
///
/// Crucially, this is where the HONEST system-integration rule lives: only the
/// native engine owns the system Now Playing, media keys, headset/remote, and
/// AirPlay. The YouTube embed and remote-control plans do not.
@MainActor
final class PlaybackRouter: ObservableObject {
    @Published private(set) var activeEngine: PlaybackEngineKind = .none

    func engineKind(for plan: PlaybackPlan) -> PlaybackEngineKind {
        switch plan {
        case .embedded: .webEmbed
        case .nativeStream, .localFile: .nativeAV
        case .connectRemote: .connectRemote
        case .unavailable: .none
        }
    }

    /// Whether the host should enable system media keys / `MPRemoteCommandCenter`
    /// and publish `MPNowPlayingInfoCenter` for this plan. Only the native engine
    /// may — the visible YouTube embed and Connect remote cannot own them.
    func ownsSystemNowPlaying(for plan: PlaybackPlan) -> Bool {
        engineKind(for: plan) == .nativeAV
    }

    @discardableResult
    func route(_ plan: PlaybackPlan) -> PlaybackEngineKind {
        let engine = engineKind(for: plan)
        activeEngine = engine
        return engine
    }
}
