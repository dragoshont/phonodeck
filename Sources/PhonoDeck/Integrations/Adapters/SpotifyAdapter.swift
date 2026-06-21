import Foundation
import OSLog

/// Spotify adapter — metadata, library, and playlists via the Web API (OAuth
/// Authorization Code + PKCE); playback via the official Spotify iFrame embed
/// (30-second previews for everyone, full tracks when signed in to Premium in the
/// player). Spotify Connect remote control of other devices is a Premium-only
/// enhancement layered on later.
final class SpotifyAdapter: BaseSourceAdapter {
    private let accountStore = SpotifyAccountStore()
    private let api = SpotifyWebAPIClient()

    init() { super.init(kind: .spotify) }

    // MARK: Account

    override func connect() async throws -> SourceAccountSummary {
        updateConnectionState(.connecting)
        do {
            let tokens = try await SpotifyOAuthClient.fromBundle().authorize()
            try accountStore.save(tokens: tokens)
            let summary = try await loadAccountSummary(accessToken: tokens.accessToken)
            updateConnectionState(.connected(summary))
            AppLog.auth.info("Spotify connected; tier=\(summary.tier.rawValue, privacy: .public)")
            return summary
        } catch {
            updateConnectionState(.failed(reason: error.localizedDescription))
            AppLog.auth.error("Spotify connect failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    override func disconnect() async throws {
        try accountStore.disconnect()
        updateConnectionState(.notConnected)
        AppLog.auth.info("Spotify disconnected")
    }

    override func restore() async {
        do {
            guard let tokens = try await accountStore.loadFreshTokens() else { return }
            let summary = try await loadAccountSummary(accessToken: tokens.accessToken)
            updateConnectionState(.connected(summary))
            AppLog.auth.info("Spotify account restored; tier=\(summary.tier.rawValue, privacy: .public)")
        } catch {
            AppLog.auth.error("Spotify restore failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func loadAccountSummary(accessToken: String) async throws -> SourceAccountSummary {
        let profile = try await api.currentUser(accessToken: accessToken)
        let detail = profile.tier == .premium ? "Premium" : "Free · library + previews"
        return SourceAccountSummary(displayName: profile.displayName ?? "Spotify", tier: profile.tier, detail: detail)
    }

    private func freshAccessToken() async throws -> String {
        guard let tokens = try await accountStore.loadFreshTokens() else {
            throw MediaSourceError.notConfigured
        }
        return tokens.accessToken
    }

    // MARK: Catalog (Web API -> source-neutral models)

    override func search(_ query: String, kinds: Set<SourceSearchKind>) async throws -> SourceSearchResults {
        let token = try await freshAccessToken()
        return try await api.search(query: query, kinds: kinds, accessToken: token)
    }

    override func librarySnapshot() async throws -> SourceLibrarySnapshot {
        let token = try await freshAccessToken()
        let api = self.api   // Sendable struct; avoid capturing self in async let
        async let tracks = api.savedTracks(accessToken: token)
        async let playlists = api.currentUserPlaylists(accessToken: token)
        return SourceLibrarySnapshot(tracks: try await tracks, playlists: try await playlists)
    }

    override func playlists() async throws -> [MusicPlaylist] {
        let token = try await freshAccessToken()
        return try await api.currentUserPlaylists(accessToken: token)
    }

    override func tracks(in playlist: MusicProviderEntityID) async throws -> [MusicTrack] {
        let token = try await freshAccessToken()
        return try await api.playlistTracks(playlistID: playlist.rawValue, accessToken: token)
    }

    // MARK: Playback (official Spotify iFrame embed — previews / full per login)

    override func playbackPlan(for track: MusicTrack) -> PlaybackPlan {
        // The official Spotify iFrame API plays a visible embed on every tier
        // (previews for all; full tracks when signed in to Premium in the
        // player), so this is the in-app playback path — parallel to YouTube.
        guard let url = SpotifyEmbed.embedURL(forTrackID: track.id.rawValue) else {
            return .unavailable(reason: "Missing Spotify track id for \(track.title).")
        }
        return .embedded(WebEmbed(
            provider: .spotify,
            url: url,
            contentID: SpotifyEmbed.trackURI(forTrackID: track.id.rawValue)
        ))
    }
}
