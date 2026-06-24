import Foundation

/// Shared account/catalog scaffolding for source adapters. Concrete adapters
/// override `kind`, the playback plan, and (per phase) the catalog methods.
/// UI-agnostic — safe to port to a backend gateway.
///
/// Default behaviour is HONEST: catalog calls that are not yet wired throw
/// `MediaSourceError.notImplemented` rather than returning fake data.
@MainActor
class BaseSourceAdapter: MusicSourceAdapter {
    let kind: MediaSourceKind
    private(set) var connectionState: SourceConnectionState

    init(kind: MediaSourceKind, connectionState: SourceConnectionState = .notConnected) {
        self.kind = kind
        self.connectionState = connectionState
    }

    var descriptor: MediaSourceDescriptor { kind.descriptor }
    var tier: SourceAccountTier { connectionState.tier }

    /// Internal hook for concrete adapters (and tests) to update the live state.
    func updateConnectionState(_ state: SourceConnectionState) {
        connectionState = state
    }

    // MARK: Account (overridden per source in later phases)

    func connect() async throws -> SourceAccountSummary {
        throw MediaSourceError.notConfigured
    }

    func disconnect() async throws {
        connectionState = .notConnected
    }

    func restore() async {}

    // MARK: Catalog (wired per phase; honest "not yet" by default)

    func search(_ query: String, kinds: Set<SourceSearchKind>) async throws -> SourceSearchResults {
        throw MediaSourceError.notImplemented
    }

    func librarySnapshot() async throws -> SourceLibrarySnapshot {
        throw MediaSourceError.notImplemented
    }

    func playlists() async throws -> [MusicPlaylist] {
        throw MediaSourceError.notImplemented
    }

    func tracks(in playlist: MusicProviderEntityID) async throws -> [MusicTrack] {
        throw MediaSourceError.notImplemented
    }

    // MARK: Playback policy

    func playbackPlan(for track: MusicTrack) -> PlaybackPlan {
        .unavailable(reason: "\(descriptor.displayName) playback is not configured yet.")
    }

    func readiness(for feature: SourceFeature) async -> SourceProviderReadiness {
        let status: SourceProviderStatus = switch capabilityStatus(feature) {
        case .active, .limited:
            connectionState.isConnected || kind == .ownFiles ? .ready : .notConnected
        case .planned:
            .notConfigured("\(descriptor.displayName) \(feature.displayName.lowercased()) is planned, not configured.")
        case .unavailable:
            .policyBlocked(capabilityDetail(feature))
        }
        return SourceProviderReadiness(source: kind, feature: feature, status: status, account: connectionState.account)
    }

    func resolvePlayback(for track: MusicTrack) async -> SourcePlaybackResolution {
        let plan = playbackPlan(for: track)
        let requiresVisiblePlayer: Bool = switch plan {
        case .embedded: true
        default: false
        }
        let status: SourceProviderStatus = switch plan {
        case .unavailable(let reason): .notConfigured(reason)
        case .connectRemote(let reason): .policyBlocked(reason)
        default: .ready
        }
        return SourcePlaybackResolution(plan: plan, status: status, requiresVisiblePlayer: requiresVisiblePlayer, isShareableURL: requiresVisiblePlayer)
    }
}
