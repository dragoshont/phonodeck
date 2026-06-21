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
}
