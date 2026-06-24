import Foundation

enum LocalPrivacyDataStore {
    static let youtubeAuthorizedCacheKeys = [
        "youtubePlaybackHistory",
        "youtubeSelectedPlaylistID",
        "youtubeMusicSearchCache",
        "youtubePlaylistItemCache",
        "youtubeMusicDiscovery",
        "youtubeMusicDiscoveryRefreshedAt",
        "youtubeLastVideoID",
        "youtubeLastVideoTitle",
        "youtubeLastVideoChannel",
        "youtubeLastVideoThumbnailURL",
        "youtubeRecentSearches",
        "youtubeLocalPlayedSeconds"
    ]

    @discardableResult
    static func clearYouTubeAuthorizedData(defaults: UserDefaults = .standard) -> [String] {
        youtubeAuthorizedCacheKeys.forEach { defaults.removeObject(forKey: $0) }
        return youtubeAuthorizedCacheKeys
    }
}