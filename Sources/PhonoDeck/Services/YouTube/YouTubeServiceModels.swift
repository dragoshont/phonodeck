import Foundation

struct YouTubeSearchRequest: Hashable, Sendable {
    let query: String
    let preference: YouTubePlaybackPreference
    let engine: YouTubeMusicEngine
    let maxResults: Int

    init(query: String, preference: YouTubePlaybackPreference, engine: YouTubeMusicEngine, maxResults: Int = 12) {
        self.query = query
        self.preference = preference
        self.engine = engine
        self.maxResults = maxResults
    }
}

struct YouTubeSearchContinuation: Hashable, Sendable {
    let query: String
    let preference: YouTubePlaybackPreference
    let engine: YouTubeMusicEngine
    let pageToken: String
    let maxResults: Int

    init(query: String, preference: YouTubePlaybackPreference, engine: YouTubeMusicEngine, pageToken: String, maxResults: Int = 12) {
        self.query = query
        self.preference = preference
        self.engine = engine
        self.pageToken = pageToken
        self.maxResults = maxResults
    }
}

enum YouTubeProviderStatus: Equatable, Sendable {
    case ready
    case cachedFallback
    case experimentalUnavailableOfficialFallback
    case officialUnavailableExperimentalFallback
    case undocumentedMetadataDisabledOfficialOnly
    case connectRequired
    case missingWriteScope
    case authorizationExpired
    case quotaExceeded
    case unsupportedExperimentalVideoMode
    case invalidProviderResponse
    case failed(String)

    var message: String {
        switch self {
        case .ready: ""
        case .cachedFallback: "Showing cached YouTube Music results while the provider refresh is unavailable."
        case .experimentalUnavailableOfficialFallback: "Undocumented YouTube Music metadata is disabled; using official YouTube API results."
        case .officialUnavailableExperimentalFallback: "Official YouTube API was unavailable; no undocumented fallback is used."
        case .undocumentedMetadataDisabledOfficialOnly: "Undocumented YouTube Music metadata is disabled by policy; using official YouTube API results."
        case .connectRequired: "Connect Google to use the official YouTube API."
        case .missingWriteScope: "Reconnect Google to allow playlist changes."
        case .authorizationExpired: "Reconnect Google; YouTube authorization expired."
        case .quotaExceeded: "YouTube API quota is exhausted. Try cached results or search again later."
        case .unsupportedExperimentalVideoMode: "Official YouTube API is unavailable. No undocumented YouTube Music fallback is used."
        case .invalidProviderResponse: "YouTube could not load playable rows for this playlist. Private, deleted, unavailable, or unsupported playlist items are skipped."
        case .failed(let reason): reason
        }
    }
}

enum YouTubeCacheState: Equatable, Sendable {
    case none
    case warm(updatedAt: Date)
    case stale(updatedAt: Date)
    case refreshed(updatedAt: Date)
}

struct YouTubeSearchServiceResult: Equatable, Sendable {
    let request: YouTubeSearchRequest
    let page: YouTubeVideoPage
    let resolvedEngine: YouTubeMusicEngine
    let status: YouTubeProviderStatus
    let cacheState: YouTubeCacheState
    let nextPageToken: String?
    let requestCountDeltas: [String: Int]
}

struct YouTubeDiscoveryRequest: Hashable, Sendable {
    let engine: YouTubeMusicEngine
    let force: Bool
    let seedQueries: [String]
}

struct YouTubeDiscoverySnapshot: Equatable, Sendable {
    let items: [YouTubeVideoSearchResult]
    let status: YouTubeProviderStatus
    let cacheState: YouTubeCacheState
    let requestCountDeltas: [String: Int]
}

struct YouTubeLibrarySnapshot: Equatable, Sendable {
    let activityVideos: [YouTubeVideoSearchResult]
    let playlists: [YouTubePlaylist]
    let subscriptions: [YouTubeSubscription]
    let selectedPlaylist: YouTubePlaylist?
    let playlistVideos: [YouTubeVideoSearchResult]
    let nextPlaylistPageToken: String?
    let warnings: Set<YouTubeLibraryWarning>
    let status: YouTubeProviderStatus
    let requestCountDeltas: [String: Int]
}

enum YouTubeLibraryWarning: String, Equatable, Hashable, Sendable {
    case activity
    case playlists
    case subscriptions
    case selectedPlaylist
}

enum YouTubePlaylistWriteKind: Equatable, Sendable {
    case createDefault(adding: YouTubeVideoSearchResult?)
    case add(video: YouTubeVideoSearchResult, playlist: YouTubePlaylist)
    case remove(video: YouTubeVideoSearchResult, playlist: YouTubePlaylist)
}

struct YouTubePlaylistWriteResult: Equatable, Sendable {
    let kind: YouTubePlaylistWriteKind
    let status: YouTubeProviderStatus
    let statusMessage: String
    let playlists: [YouTubePlaylist]
    let selectedPlaylist: YouTubePlaylist?
    let playlistVideos: [YouTubeVideoSearchResult]
    let nextPlaylistPageToken: String?
    let requestCountDeltas: [String: Int]
}

struct YouTubeCachedSearchPage: Codable, Equatable, Sendable {
    let items: [YouTubeVideoSearchResult]
    let nextPageToken: String?
    let updatedAt: Date

    var page: YouTubeVideoPage { YouTubeVideoPage(items: items, nextPageToken: nextPageToken) }
}

struct YouTubeCachedPlaylistPage: Codable, Equatable, Sendable {
    let items: [YouTubeVideoSearchResult]
    let nextPageToken: String?
    let updatedAt: Date

    var page: YouTubeVideoPage { YouTubeVideoPage(items: items, nextPageToken: nextPageToken) }
}

enum YouTubeServiceMapper {
    static func status(for error: Error) -> YouTubeProviderStatus {
        if let googleError = error as? GoogleOAuthError {
            switch googleError {
            case .missingRequiredScope: return .missingWriteScope
            case .missingRefreshToken: return .authorizationExpired
            default: return .failed(googleError.localizedDescription)
            }
        }

        if let dataError = error as? YouTubeDataError {
            switch dataError {
            case .authorizationExpired: return .authorizationExpired
            case .quotaExceeded: return .quotaExceeded
            case .invalidResponse: return .invalidProviderResponse
            case .requestFailed(let statusCode, let body): return .failed("YouTube request failed (HTTP \(statusCode)): \(body)")
            }
        }

        if error is DecodingError { return .invalidProviderResponse }
        if let providerError = error as? YouTubeMusicProviderError { return providerError.status }
        return .failed(error.localizedDescription)
    }

    static func playlistMessage(for error: Error) -> String {
        if let googleError = error as? GoogleOAuthError {
            switch googleError {
            case .missingRequiredScope: return "Reconnect Google to allow playlist changes."
            case .missingRefreshToken: return "Reconnect Google; the saved refresh token is missing."
            default: return googleError.localizedDescription
            }
        }

        if let dataError = error as? YouTubeDataError {
            switch dataError {
            case .authorizationExpired: return "Reconnect Google; YouTube authorization expired."
            case .quotaExceeded: return "YouTube API quota is exhausted. Try again later or use cached playlist data."
            case .requestFailed(let statusCode, let body): return "Playlist request failed (HTTP \(statusCode)): \(body)"
            case .invalidResponse: return "YouTube returned an invalid playlist response. Try again."
            }
        }

        return error.localizedDescription
    }
}

enum YouTubeMusicProviderError: LocalizedError, Equatable {
    case connectGoogle
    case officialRequiredForVideo
    case undocumentedMetadataDisabled

    var errorDescription: String? {
        switch self {
        case .connectGoogle: "Connect Google to use the official YouTube API."
        case .officialRequiredForVideo: "Official YouTube API is unavailable. No undocumented YouTube Music fallback is used."
        case .undocumentedMetadataDisabled: "Undocumented YouTube Music metadata is disabled by policy."
        }
    }

    var status: YouTubeProviderStatus {
        switch self {
        case .connectGoogle: .connectRequired
        case .officialRequiredForVideo: .unsupportedExperimentalVideoMode
        case .undocumentedMetadataDisabled: .undocumentedMetadataDisabledOfficialOnly
        }
    }
}

extension YouTubeProviderStatus {
    var playlistMessage: String {
        switch self {
        case .missingWriteScope: "Reconnect Google to allow playlist changes."
        case .authorizationExpired: "Reconnect Google; YouTube authorization expired."
        case .quotaExceeded: "YouTube API quota is exhausted. Try again later or use cached playlist data."
        case .invalidProviderResponse: "YouTube returned an invalid playlist response. Try again."
        default: message
        }
    }
}

struct ProviderComparisonProviderResult: Identifiable, Equatable {
    let id: YouTubeMusicEngine
    let title: String
    let status: String
    let itemCount: Int
    let cacheState: String
    let requestDelta: Int
    let errorMessage: String?
    let riskLabel: String
    let items: [YouTubeVideoSearchResult]
}

struct ProviderComparisonRun: Identifiable, Equatable {
    let id: String
    let query: String
    let preference: YouTubePlaybackPreference
    let startedAt: Date
    let completedAt: Date
    let providerResults: [ProviderComparisonProviderResult]
    let requestCountDeltas: [String: Int]

    var durationMilliseconds: Int {
        max(Int(completedAt.timeIntervalSince(startedAt) * 1000), 0)
    }
}
