import Foundation

// MARK: - Source features + honest tier-aware capability resolution (portable)

/// The capability areas every source declares. Typed counterpart to the
/// string-named `MusicSourceCapability` entries on `MediaSourceDescriptor`.
enum SourceFeature: String, CaseIterable, Codable, Hashable, Sendable {
    case search
    case discovery
    case playlists
    case playback
    case downloads

    /// Matches the `name` used in `MediaSourceDescriptor.capabilities`.
    var displayName: String {
        switch self {
        case .search: "Search"
        case .discovery: "Discovery"
        case .playlists: "Playlists"
        case .playback: "Playback"
        case .downloads: "Downloads"
        }
    }
}

extension MediaSourceDescriptor {
    /// The statically declared capability for a feature (tier-independent baseline).
    func capability(_ feature: SourceFeature) -> MusicSourceCapability? {
        capabilities.first { $0.name == feature.displayName }
    }
}

/// Resolves the HONEST capability status for a `(source, feature, tier)` triple.
///
/// This encodes the free-vs-paid matrix documented in
/// `docs/design/phonodeck-ui-map.json` → `features.accountTiers`. It is pure
/// policy logic with no platform dependency, so it can be shared with the web
/// app's backend gateway unchanged.
enum SourceCapabilityResolver {
    static func status(
        for feature: SourceFeature,
        source: MediaSourceKind,
        tier: SourceAccountTier
    ) -> MusicSourceCapabilityStatus {
        switch source {
        case .youtube, .youtubeMusic:
            // The Data API is identical across tiers. Premium perks (ad-free /
            // background / offline) are first-party and not exposed to a
            // third-party embed, so they do not change what PhonoDeck can do.
            switch feature {
            case .search, .discovery, .playlists: return .active
            case .playback: return .limited        // visible official embed only
            case .downloads: return .unavailable   // not permitted via the API
            }

        case .spotify:
            switch feature {
            case .search, .discovery, .playlists: return .active // Web API, both tiers
            case .playback:
                // The official Spotify iFrame embed plays a visible player on
                // every tier (previews for all; full tracks when signed in to
                // Premium in the player), so playback is "limited", not absent.
                return .limited
            case .downloads: return .unavailable
            }

        case .plex:
            // Requires a configured Plex Media Server; basic music is free.
            switch feature {
            case .search, .discovery, .playlists, .playback: return .active
            case .downloads:
                // Offline downloads/sync require Plex Pass.
                return tier == .premium ? .active : .unavailable
            }

        case .ownFiles:
            // User-owned local media — everything is available.
            return .active
        }
    }

    /// Honest one-line explanation for a resolved status (tier-aware where it matters).
    static func detail(
        for feature: SourceFeature,
        source: MediaSourceKind,
        tier: SourceAccountTier
    ) -> String {
        switch (source, feature) {
        case (.spotify, .playback):
            return tier == .premium
                ? "Full tracks via the official Spotify player when you're signed in to Premium in it; 30-second previews otherwise."
                : "30-second previews via the official Spotify player; sign in to Spotify Premium in the player for full tracks."
        case (.plex, .downloads):
            return tier == .premium
                ? "Plex Pass: offline downloads and sync for your own media."
                : "Offline downloads require Plex Pass."
        default:
            return source.descriptor.capability(feature)?.detail ?? ""
        }
    }
}
