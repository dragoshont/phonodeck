import Foundation

protocol YouTubeAccountTokenProviding: Sendable {
    func loadFreshTokens() async throws -> GoogleOAuthTokenSet?
    func loadFreshTokens(requiredScope: String) async throws -> GoogleOAuthTokenSet?
}

protocol YouTubeOfficialProviding: Sendable {
    func searchVideoPage(query: String, accessToken: String, maxResults: Int, preference: YouTubePlaybackPreference, pageToken: String?) async throws -> YouTubeVideoPage
    func playlists(accessToken: String, maxResults: Int) async throws -> [YouTubePlaylist]
    func playlistItemPage(playlistID: String, accessToken: String, maxResults: Int, pageToken: String?) async throws -> YouTubeVideoPage
    func createPlaylist(title: String, description: String, privacyStatus: YouTubePlaylistPrivacyStatus, accessToken: String) async throws -> YouTubePlaylist
    func addVideoToPlaylist(videoID: String, playlistID: String, accessToken: String) async throws -> YouTubePlaylistItem
    func deletePlaylistItem(playlistItemID: String, accessToken: String) async throws
    func recentActivityVideos(accessToken: String, maxResults: Int) async throws -> [YouTubeVideoSearchResult]
    func subscriptions(accessToken: String, maxResults: Int) async throws -> [YouTubeSubscription]
    func videoDetails(videoID: String, accessToken: String) async throws -> YouTubeVideoDetails?
}

protocol YouTubeMusicMetadataProviding: Sendable {
    func search(query: String, preference: YouTubePlaybackPreference, maxResults: Int) async throws -> [YouTubeVideoSearchResult]
}

extension GoogleAccountStore: YouTubeAccountTokenProviding {}
extension YouTubeDataClient: YouTubeOfficialProviding {}

extension YouTubeOfficialProviding {
    func searchVideoPage(query: String, accessToken: String, preference: YouTubePlaybackPreference, pageToken: String? = nil) async throws -> YouTubeVideoPage {
        try await searchVideoPage(query: query, accessToken: accessToken, maxResults: 12, preference: preference, pageToken: pageToken)
    }

    func playlists(accessToken: String) async throws -> [YouTubePlaylist] {
        try await playlists(accessToken: accessToken, maxResults: 25)
    }

    func playlistItemPage(playlistID: String, accessToken: String, pageToken: String? = nil) async throws -> YouTubeVideoPage {
        try await playlistItemPage(playlistID: playlistID, accessToken: accessToken, maxResults: 25, pageToken: pageToken)
    }

    func recentActivityVideos(accessToken: String) async throws -> [YouTubeVideoSearchResult] {
        try await recentActivityVideos(accessToken: accessToken, maxResults: 12)
    }

    func subscriptions(accessToken: String) async throws -> [YouTubeSubscription] {
        try await subscriptions(accessToken: accessToken, maxResults: 25)
    }
}