import Foundation

enum MediaSourceKind: String, CaseIterable, Identifiable, Codable, Hashable {
    case youtube
    case youtubeMusic
    case plex
    case spotify
    case ownFiles = "localFiles"

    var id: String { rawValue }

    var descriptor: MediaSourceDescriptor {
        switch self {
        case .youtube:
            MediaSourceDescriptor(id: self, displayName: "YouTube", symbolName: "play.tv", nativeRole: "Videos, clips, and the visible official YouTube player")
        case .plex:
            MediaSourceDescriptor(id: self, displayName: "Plex", symbolName: "rectangle.stack.badge.play", nativeRole: "Primary native playback, library, and download source")
        case .youtubeMusic:
            MediaSourceDescriptor(id: self, displayName: "YouTube Music", symbolName: "music.note.tv", nativeRole: "Song-first discovery, playlists, and policy-compliant embedded playback")
        case .spotify:
            MediaSourceDescriptor(id: self, displayName: "Spotify", symbolName: "dot.radiowaves.left.and.right", nativeRole: "Metadata, library surfaces, and Spotify Connect control")
        case .ownFiles:
            MediaSourceDescriptor(id: self, displayName: "Own Files", symbolName: "externaldrive", nativeRole: "User-owned files, imports, and iTunes XML compatibility")
        }
    }

    var isYouTubePlayerBacked: Bool {
        self == .youtube || self == .youtubeMusic
    }
}

struct MediaSourceDescriptor: Identifiable, Equatable {
    let id: MediaSourceKind
    let displayName: String
    let symbolName: String
    let nativeRole: String

    var capabilities: [MusicSourceCapability] {
        switch id {
        case .youtube:
            [
                .init(name: "Search", status: .active, detail: "Official YouTube video search for clips and music videos."),
                .init(name: "Discovery", status: .active, detail: "YouTube-wide videos, activity, channels, subscriptions, and playlists where account scopes allow."),
                .init(name: "Playlists", status: .active, detail: "Read, create, add to, and share YouTube playlists using official account APIs."),
                .init(name: "Playback", status: .limited, detail: "Visible official YouTube player; no hidden audio/background player."),
                .init(name: "Downloads", status: .unavailable, detail: "YouTube audiovisual downloads are not allowed without approval.")
            ]
        case .youtubeMusic:
            [
                .init(name: "Search", status: .active, detail: "Official YouTube Data API search only; no undocumented YouTube Music metadata fallback."),
                .init(name: "Discovery", status: .active, detail: "Cached music searches, local PhonoDeck history, and account surfaces when connected."),
                .init(name: "Playlists", status: .active, detail: "Read, create, add to, and share the YouTube Music playlist surface using official YouTube account APIs."),
                .init(name: "Playback", status: .limited, detail: "Visible official YouTube player; no hidden audio/background player."),
                .init(name: "Downloads", status: .unavailable, detail: "YouTube audiovisual downloads are not allowed without approval.")
            ]
        case .plex:
            [
                .init(name: "Search", status: .planned, detail: "Search music libraries from a configured Plex Media Server."),
                .init(name: "Discovery", status: .planned, detail: "Albums, artists, playlists, ratings, and recent server activity."),
                .init(name: "Playlists", status: .planned, detail: "Plex playlist read/write after token-based server auth."),
                .init(name: "Playback", status: .planned, detail: "Native playback for user-owned media served by Plex."),
                .init(name: "Downloads", status: .planned, detail: "Offline copies only for user-owned Plex media when allowed by server permissions.")
            ]
        case .spotify:
            [
                .init(name: "Search", status: .planned, detail: "Spotify Web API metadata search."),
                .init(name: "Discovery", status: .planned, detail: "Recently played, top tracks/artists, saved library, and recommendations where scopes allow."),
                .init(name: "Playlists", status: .planned, detail: "Create and modify Spotify playlists with playlist scopes."),
                .init(name: "Playback", status: .limited, detail: "Visible official Spotify iFrame player — 30-second previews, full tracks when signed in to Premium in the player."),
                .init(name: "Downloads", status: .unavailable, detail: "Spotify offline downloads are not exposed for third-party app storage.")
            ]
        case .ownFiles:
            [
                .init(name: "Search", status: .planned, detail: "Index imported files and iTunes XML libraries."),
                .init(name: "Discovery", status: .planned, detail: "Albums, artists, genres, recently played, and smart lists."),
                .init(name: "Playlists", status: .planned, detail: "Local and imported playlist management."),
                .init(name: "Playback", status: .planned, detail: "Native AVFoundation playback."),
                .init(name: "Downloads", status: .active, detail: "Files are already user-owned local media.")
            ]
        }
    }
}

struct MusicSourceCapability: Identifiable, Equatable {
    let name: String
    let status: MusicSourceCapabilityStatus
    let detail: String

    var id: String { name }
}

enum MusicSourceCapabilityStatus: String, Equatable {
    case active = "Active"
    case planned = "Planned"
    case limited = "Limited"
    case unavailable = "Unavailable"
}

protocol MediaSource {
    var descriptor: MediaSourceDescriptor { get }

    func search(query: String) async throws -> [MediaItem]
    func librarySnapshot() async throws -> [MediaItem]
}

struct MediaItem: Identifiable, Equatable {
    let id: String
    let title: String
    let artist: String
    let album: String?
    let source: MediaSourceKind
    let playbackPolicy: PlaybackPolicy
}

enum PlaybackPolicy: Equatable {
    case nativeStream
    case embeddedPlayer
    case externalRemoteControl
    case localFile
    case unavailable(reason: String)
}

enum MediaSourceError: Error, Equatable {
    case notConfigured
    case notImplemented
    case unsupportedByPolicy(String)
}
