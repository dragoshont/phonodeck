import Foundation
@testable import PhonoDeck

func clearYouTubeLocalState() {
    [
        "youtubePlaybackHistory",
        "youtubeSelectedPlaylistID",
        "youtubeMusicSearchCache",
        "youtubePlaylistItemCache",
        "youtubeMusicDiscovery",
        "youtubeMusicDiscoveryRefreshedAt"
    ].forEach { UserDefaults.standard.removeObject(forKey: $0) }
}

struct FixtureAccountStore: YouTubeAccountTokenProviding {
    let tokens: GoogleOAuthTokenSet?

    func loadFreshTokens() async throws -> GoogleOAuthTokenSet? { tokens }

    func loadFreshTokens(requiredScope: String) async throws -> GoogleOAuthTokenSet? {
        guard let tokens else { return nil }
        guard tokens.scope.split(separator: " ").map(String.init).contains(requiredScope) else {
            throw GoogleOAuthError.missingRequiredScope(requiredScope)
        }
        return tokens
    }
}

final class FixtureYouTubeMusicMetadataProvider: YouTubeMusicMetadataProviding, @unchecked Sendable {
    var results: [YouTubeVideoSearchResult] = []
    var error: Error?
    private(set) var searchedQueries: [String] = []

    init(results: [YouTubeVideoSearchResult] = [], error: Error? = nil) {
        self.results = results
        self.error = error
    }

    func search(query: String, preference: YouTubePlaybackPreference, maxResults: Int) async throws -> [YouTubeVideoSearchResult] {
        searchedQueries.append(query)
        if let error { throw error }
        return Array(results.prefix(maxResults))
    }
}

final class FixtureYouTubeOfficialProvider: YouTubeOfficialProviding, @unchecked Sendable {
    var searchPage: YouTubeVideoPage
    var playlistPage: YouTubeVideoPage
    var playlistsValue: [YouTubePlaylist]
    var createdPlaylist: YouTubePlaylist?
    var activityVideos: [YouTubeVideoSearchResult]
    var subscriptionsValue: [YouTubeSubscription]
    var error: Error?
    var addedPairs: [String] = []
    var deletedPlaylistItemIDs: [String] = []

    init(
        searchPage: YouTubeVideoPage = .init(items: [], nextPageToken: nil),
        playlists: [YouTubePlaylist] = [],
        createdPlaylist: YouTubePlaylist? = nil,
        playlistPage: YouTubeVideoPage = .init(items: [], nextPageToken: nil),
        activityVideos: [YouTubeVideoSearchResult] = [],
        subscriptions: [YouTubeSubscription] = [],
        error: Error? = nil
    ) {
        self.searchPage = searchPage
        self.playlistPage = playlistPage
        playlistsValue = playlists
        self.createdPlaylist = createdPlaylist
        self.activityVideos = activityVideos
        subscriptionsValue = subscriptions
        self.error = error
    }

    func searchVideoPage(query: String, accessToken: String, maxResults: Int, preference: YouTubePlaybackPreference, pageToken: String?) async throws -> YouTubeVideoPage {
        if let error { throw error }
        return searchPage
    }

    func playlists(accessToken: String, maxResults: Int) async throws -> [YouTubePlaylist] {
        if let error { throw error }
        return playlistsValue
    }

    func playlistItemPage(playlistID: String, accessToken: String, maxResults: Int, pageToken: String?) async throws -> YouTubeVideoPage {
        if let error { throw error }
        return playlistPage
    }

    func createPlaylist(title: String, description: String, privacyStatus: YouTubePlaylistPrivacyStatus, accessToken: String) async throws -> YouTubePlaylist {
        if let error { throw error }
        guard let createdPlaylist else { throw YouTubeDataError.invalidResponse }
        return createdPlaylist
    }

    func addVideoToPlaylist(videoID: String, playlistID: String, accessToken: String) async throws -> YouTubePlaylistItem {
        if let error { throw error }
        addedPairs.append("\(playlistID)|\(videoID)")
        return YouTubePlaylistItem(
            id: "playlist-item-id",
            snippet: .init(title: "Fixture Song", channelTitle: "Fixture Artist", publishedAt: "2026-06-01T12:00:00Z", thumbnails: .init(default: nil, medium: nil), resourceID: nil),
            contentDetails: .init(videoID: videoID)
        )
    }

    func deletePlaylistItem(playlistItemID: String, accessToken: String) async throws {
        if let error { throw error }
        deletedPlaylistItemIDs.append(playlistItemID)
        playlistPage = .init(items: playlistPage.items.filter { $0.playlistItemID != playlistItemID }, nextPageToken: playlistPage.nextPageToken)
    }

    func recentActivityVideos(accessToken: String, maxResults: Int) async throws -> [YouTubeVideoSearchResult] {
        if let error { throw error }
        return activityVideos
    }

    func subscriptions(accessToken: String, maxResults: Int) async throws -> [YouTubeSubscription] {
        if let error { throw error }
        return subscriptionsValue
    }

    func videoDetails(videoID: String, accessToken: String) async throws -> YouTubeVideoDetails? { nil }
}

extension GoogleOAuthTokenSet {
    static var fixture: GoogleOAuthTokenSet {
        .init(accessToken: "access-token", expiresIn: 3600, refreshToken: "refresh-token", refreshTokenExpiresIn: nil, scope: "https://www.googleapis.com/auth/youtube", tokenType: "Bearer", obtainedAt: Date())
    }

    static var readOnlyFixture: GoogleOAuthTokenSet {
        .init(accessToken: "access-token", expiresIn: 3600, refreshToken: "refresh-token", refreshTokenExpiresIn: nil, scope: "https://www.googleapis.com/auth/youtube.readonly", tokenType: "Bearer", obtainedAt: Date())
    }
}

enum YouTubeFixtureFactory {
    static func song(id: String = "song-id", title: String = "Song", channel: String = "Artist", sourceLabel: String? = "Music") -> YouTubeVideoSearchResult {
        YouTubeVideoSearchResult(id: id, title: title, channelTitle: channel, thumbnailURL: nil, sourceLabel: sourceLabel)
    }

    static func playlist(id: String = "playlist-id", title: String = "Favorites") -> YouTubePlaylist {
        YouTubePlaylist(id: id, snippet: .init(title: title, channelTitle: nil, thumbnails: nil), contentDetails: .init(itemCount: 1), status: .init(privacyStatus: "private"))
    }
}
