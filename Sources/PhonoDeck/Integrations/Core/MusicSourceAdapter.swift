import Foundation

// MARK: - Playback plan (portable policy)

/// A visible, official web embed playback target. Both YouTube (IFrame Player API)
/// and Spotify (iFrame API) expose an embeddable player the app can drive
/// (load / play / pause / seek) while keeping the official player visible — so
/// neither needs audio extraction or a heavyweight SDK.
struct WebEmbed: Equatable {
    enum Provider: String, Equatable, Sendable { case youtube, spotify }
    let provider: Provider
    /// The iframe document URL to load in the web view.
    let url: URL
    /// The provider content identifier used by the control API: a YouTube video
    /// id, or a Spotify URI like "spotify:track:...".
    let contentID: String
}

/// How a given track should be played on this platform. The adapter decides the
/// PLAN (policy); the `PlaybackRouter` executes it with the right engine. This is
/// a portable contract — a backend would map these cases to its own runtime.
enum PlaybackPlan: Equatable {
    /// Visible official embedded web player (YouTube IFrame API / Spotify iFrame API).
    case embedded(WebEmbed)
    /// Native streaming via AVFoundation (e.g. a Plex media part URL).
    case nativeStream(url: URL)
    /// Local file playback via AVFoundation.
    case localFile(url: URL)
    /// Control playback on an external device (Spotify Connect). No in-app audio.
    case connectRemote(reason: String)
    /// Not playable in this context, with an honest reason.
    case unavailable(reason: String)

    /// Bridges to the existing `PlaybackPolicy` vocabulary used elsewhere.
    var policy: PlaybackPolicy {
        switch self {
        case .embedded: .embeddedPlayer
        case .nativeStream: .nativeStream
        case .localFile: .localFile
        case .connectRemote: .externalRemoteControl
        case .unavailable(let reason): .unavailable(reason: reason)
        }
    }
}

// MARK: - The primary source abstraction

/// The PRIMARY abstraction over a music source. It is UI-agnostic and returns
/// source-neutral models (`MusicTrack` / `MusicAlbum` / `MusicArtist` /
/// `MusicPlaylist`), so the macOS app, an iOS/watch client, and the future web
/// backend can all rely on the same contract. Concrete adapters wrap the
/// per-service auth + API clients.
///
/// This supersedes the thin legacy `MediaSource` protocol (search/librarySnapshot
/// returning `MediaItem`), which remains only until callers migrate.
@MainActor
protocol MusicSourceAdapter: SourceProviderReadinessProviding, SourcePlaybackResolving, AnyObject {
    var kind: MediaSourceKind { get }
    var descriptor: MediaSourceDescriptor { get }

    // MARK: Account
    var connectionState: SourceConnectionState { get }
    var tier: SourceAccountTier { get }
    func connect() async throws -> SourceAccountSummary
    func disconnect() async throws
    /// Silently restore a previously connected account on launch.
    func restore() async

    // MARK: Catalog (source-neutral models)
    func search(_ query: String, kinds: Set<SourceSearchKind>) async throws -> SourceSearchResults
    func librarySnapshot() async throws -> SourceLibrarySnapshot
    func playlists() async throws -> [MusicPlaylist]
    func tracks(in playlist: MusicProviderEntityID) async throws -> [MusicTrack]

    // MARK: Capability + playback policy
    func capabilityStatus(_ feature: SourceFeature) -> MusicSourceCapabilityStatus
    func playbackPlan(for track: MusicTrack) -> PlaybackPlan
}

extension MusicSourceAdapter {
    var descriptor: MediaSourceDescriptor { kind.descriptor }

    /// Default tier-aware capability resolution using the honest free-vs-paid matrix.
    func capabilityStatus(_ feature: SourceFeature) -> MusicSourceCapabilityStatus {
        SourceCapabilityResolver.status(for: feature, source: kind, tier: tier)
    }

    /// Honest, tier-aware detail string for a feature.
    func capabilityDetail(_ feature: SourceFeature) -> String {
        SourceCapabilityResolver.detail(for: feature, source: kind, tier: tier)
    }

    /// Whether this source can currently play audio inside PhonoDeck at its tier.
    var canPlayInApp: Bool {
        switch capabilityStatus(.playback) {
        case .active, .limited: true
        case .planned, .unavailable: false
        }
    }

}

// MARK: - YouTube embed helper (shared by the YouTube adapters)

/// Builds the policy-compliant visible IFrame embed URL for a video id.
enum YouTubeEmbed {
    static func embedURL(forVideoID id: String) -> URL? {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: "https://www.youtube.com/embed/\(trimmed)?enablejsapi=1&origin=http://127.0.0.1&rel=0&modestbranding=1")
    }
}

// MARK: - Spotify embed helper (official iFrame API)

/// Builds the official Spotify embed URL + content URI used with the iFrame API
/// (https://open.spotify.com/embed/iframe-api/v1). The embed plays 30-second
/// previews for everyone and full tracks when the listener is signed in to
/// Spotify Premium in the player.
enum SpotifyEmbed {
    static func embedURL(forTrackID id: String) -> URL? {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: "https://open.spotify.com/embed/track/\(trimmed)")
    }

    static func trackURI(forTrackID id: String) -> String {
        "spotify:track:\(id.trimmingCharacters(in: .whitespacesAndNewlines))"
    }
}
