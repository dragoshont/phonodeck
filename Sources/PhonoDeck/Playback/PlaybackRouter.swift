import Foundation

/// Identifies the playback engine that should execute a `PlaybackPlan`.
enum PlaybackEngineKind: String, Equatable, Sendable {
    case webEmbed          // WKWebView official embed (YouTube IFrame / Spotify iFrame)
    case nativeAV          // AVFoundation (Plex / own files)
    case connectRemote     // external device control (Spotify Connect)
    case none
}

enum PlaybackSystemIntegration: Equatable {
    case eligibleNative
    case forbidden(reason: String)
    case unavailable(reason: String)

    var canOwnSystemNowPlaying: Bool {
        if case .eligibleNative = self { return true }
        return false
    }
}

enum PlaybackBlockedState: Equatable {
    case unavailable(reason: String)
    case unsupportedEngine(engine: PlaybackEngineKind, reason: String)
    case missingMediaURL(source: MediaSourceKind, trackID: MusicProviderEntityID)
    case sourceUnavailable(source: MediaSourceKind, reason: String)
    case notConnected(source: MediaSourceKind)

    var reason: String {
        switch self {
        case .unavailable(let reason), .unsupportedEngine(_, let reason), .sourceUnavailable(_, let reason):
            return reason
        case .missingMediaURL(let source, _):
            return "Missing media URL for \(source.descriptor.displayName)."
        case .notConnected(let source):
            return "Connect \(source.descriptor.displayName) before playback."
        }
    }
}

enum PlaybackFailure: Error, Equatable {
    case invalidMediaURL(URL)
    case engineFailed(reason: String)
    case sourceResolutionFailed(source: MediaSourceKind, reason: String)

    var reason: String {
        switch self {
        case .invalidMediaURL(let url): "Invalid media URL: \(url.absoluteString)"
        case .engineFailed(let reason), .sourceResolutionFailed(_, let reason): reason
        }
    }
}

struct PlaybackRouteDecision: Equatable {
    let plan: PlaybackPlan
    let engine: PlaybackEngineKind
    let systemIntegration: PlaybackSystemIntegration
    let requiresVisiblePlayer: Bool
    let blockedState: PlaybackBlockedState?

    var canOwnSystemNowPlaying: Bool { systemIntegration.canOwnSystemNowPlaying }
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

    func decision(
        for plan: PlaybackPlan,
        source: MediaSourceKind? = nil,
        trackID: MusicProviderEntityID? = nil
    ) -> PlaybackRouteDecision {
        let engine = engineKind(for: plan)
        switch plan {
        case .nativeStream, .localFile:
            return PlaybackRouteDecision(
                plan: plan,
                engine: engine,
                systemIntegration: .eligibleNative,
                requiresVisiblePlayer: false,
                blockedState: nil
            )
        case .embedded(let embed):
            let reason = switch embed.provider {
            case .youtube: "YouTube plays through the visible official embed only."
            case .spotify: "Spotify plays through the visible official Spotify player; native macOS streaming is not available."
            }
            return PlaybackRouteDecision(
                plan: plan,
                engine: engine,
                systemIntegration: .forbidden(reason: reason),
                requiresVisiblePlayer: true,
                blockedState: .unsupportedEngine(engine: engine, reason: reason)
            )
        case .connectRemote(let reason):
            return PlaybackRouteDecision(
                plan: plan,
                engine: engine,
                systemIntegration: .forbidden(reason: reason),
                requiresVisiblePlayer: false,
                blockedState: .unsupportedEngine(engine: engine, reason: reason)
            )
        case .unavailable(let reason):
            let blocked: PlaybackBlockedState
            if let source, let trackID, reason.lowercased().contains("missing") {
                blocked = .missingMediaURL(source: source, trackID: trackID)
            } else {
                blocked = .unavailable(reason: reason)
            }
            return PlaybackRouteDecision(
                plan: plan,
                engine: engine,
                systemIntegration: .unavailable(reason: reason),
                requiresVisiblePlayer: false,
                blockedState: blocked
            )
        }
    }

    func canExecuteNatively(_ plan: PlaybackPlan) -> Bool {
        decision(for: plan).canOwnSystemNowPlaying
    }

    func blockedState(
        for plan: PlaybackPlan,
        source: MediaSourceKind? = nil,
        trackID: MusicProviderEntityID? = nil
    ) -> PlaybackBlockedState? {
        decision(for: plan, source: source, trackID: trackID).blockedState
    }

    /// Whether the host should enable system media keys / `MPRemoteCommandCenter`
    /// and publish `MPNowPlayingInfoCenter` for this plan. Only the native engine
    /// may — the visible YouTube embed and Connect remote cannot own them.
    func ownsSystemNowPlaying(for plan: PlaybackPlan) -> Bool {
        decision(for: plan).canOwnSystemNowPlaying
    }

    @discardableResult
    func route(_ plan: PlaybackPlan) -> PlaybackEngineKind {
        let engine = engineKind(for: plan)
        activeEngine = engine
        return engine
    }
}
