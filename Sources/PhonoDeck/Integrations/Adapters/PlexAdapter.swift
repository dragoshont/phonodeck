import Foundation
import OSLog

/// Plex adapter — the user's own Plex Media Server. The primary NATIVE playback
/// path: tracks resolve to a token-bearing media part URL played by AVFoundation,
/// which is what lets the system Now Playing, media keys, and headset controls
/// work. Offline downloads require Plex Pass (gated in the capability resolver).
final class PlexAdapter: BaseSourceAdapter {
    private let authClient = PlexAuthClient()
    private let serverClient = PlexServerClient()
    private let accountStore = PlexAccountStore()

    init() { super.init(kind: .plex) }

    // MARK: Account (PIN sign-in)

    override func connect() async throws -> SourceAccountSummary {
        updateConnectionState(.connecting)
        do {
            let token = try await authClient.authenticate()
            let user = try await authClient.currentUser(token: token)
            let server = try await serverClient.firstServer(token: token)
            let credentials = PlexCredentials(
                token: token,
                serverName: server?.name,
                serverBaseURL: server?.baseURL,
                hasPlexPass: user.hasPlexPass
            )
            try accountStore.save(credentials)

            let summary = Self.summary(name: user.displayName, server: server?.name, hasPlexPass: user.hasPlexPass)
            updateConnectionState(.connected(summary))
            AppLog.auth.info("Plex connected; server=\(server?.name ?? "none", privacy: .public); plexPass=\(user.hasPlexPass.description, privacy: .public)")
            return summary
        } catch {
            updateConnectionState(.failed(reason: error.localizedDescription))
            AppLog.auth.error("Plex connect failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    override func disconnect() async throws {
        try accountStore.disconnect()
        updateConnectionState(.notConnected)
        AppLog.auth.info("Plex disconnected")
    }

    override func restore() async {
        do {
            guard let credentials = try accountStore.load() else { return }
            let summary = Self.summary(
                name: credentials.serverName ?? "Plex",
                server: credentials.serverName,
                hasPlexPass: credentials.hasPlexPass
            )
            updateConnectionState(.connected(summary))
            AppLog.auth.info("Plex account restored; server=\(credentials.serverName ?? "none", privacy: .public)")
        } catch {
            AppLog.auth.error("Plex restore failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func summary(name: String, server: String?, hasPlexPass: Bool) -> SourceAccountSummary {
        let detail: String
        if let server {
            detail = hasPlexPass ? "\(server) · Plex Pass" : server
        } else {
            detail = "No server found"
        }
        return SourceAccountSummary(displayName: name, tier: hasPlexPass ? .premium : .free, detail: detail)
    }

    private func resolvedServer() async throws -> (baseURL: String, token: String) {
        guard let credentials = try accountStore.load(), let baseURL = credentials.serverBaseURL else {
            throw MediaSourceError.notConfigured
        }
        return (baseURL, credentials.token)
    }

    // MARK: Catalog (server -> source-neutral models)

    override func search(_ query: String, kinds: Set<SourceSearchKind>) async throws -> SourceSearchResults {
        let (baseURL, token) = try await resolvedServer()
        return try await serverClient.search(baseURL: baseURL, token: token, query: query)
    }

    override func librarySnapshot() async throws -> SourceLibrarySnapshot {
        let (baseURL, token) = try await resolvedServer()
        let sections = try await serverClient.musicSections(baseURL: baseURL, token: token)
        var tracks: [MusicTrack] = []
        if let first = sections.first {
            tracks = try await serverClient.sectionTracks(baseURL: baseURL, token: token, sectionKey: first.key)
        }
        let playlists = try await serverClient.playlists(baseURL: baseURL, token: token)
        return SourceLibrarySnapshot(tracks: tracks, playlists: playlists)
    }

    override func playlists() async throws -> [MusicPlaylist] {
        let (baseURL, token) = try await resolvedServer()
        return try await serverClient.playlists(baseURL: baseURL, token: token)
    }

    override func tracks(in playlist: MusicProviderEntityID) async throws -> [MusicTrack] {
        let (baseURL, token) = try await resolvedServer()
        return try await serverClient.playlistItems(baseURL: baseURL, token: token, ratingKey: playlist.rawValue)
    }

    // MARK: Playback (native AVFoundation stream)

    override func playbackPlan(for track: MusicTrack) -> PlaybackPlan {
        guard let url = track.sourceURL else {
            return .unavailable(reason: "Missing Plex media URL for \(track.title).")
        }
        return .nativeStream(url: url)
    }
}
