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

final class FixtureAccountStore: YouTubeAccountTokenProviding, @unchecked Sendable {
    var tokens: GoogleOAuthTokenSet?

    init(tokens: GoogleOAuthTokenSet?) {
        self.tokens = tokens
    }

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

class FixtureYouTubeOfficialProvider: YouTubeOfficialProviding, @unchecked Sendable {
    var searchPage: YouTubeVideoPage
    var playlistPage: YouTubeVideoPage
    var playlistsValue: [YouTubePlaylist]
    var createdPlaylist: YouTubePlaylist?
    var activityVideos: [YouTubeVideoSearchResult]
    var subscriptionsValue: [YouTubeSubscription]
    var details: YouTubeVideoDetails?
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
        details: YouTubeVideoDetails? = nil,
        error: Error? = nil
    ) {
        self.searchPage = searchPage
        self.playlistPage = playlistPage
        playlistsValue = playlists
        self.createdPlaylist = createdPlaylist
        self.activityVideos = activityVideos
        subscriptionsValue = subscriptions
        self.details = details
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

    func videoDetails(videoID: String, accessToken: String) async throws -> YouTubeVideoDetails? {
        if let error { throw error }
        return details
    }
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

    static func details(id: String = "video-id") -> YouTubeVideoDetails {
        let data = Data("""
        {
          "id": "\(id)",
          "snippet": { "title": "Song", "channelTitle": "Artist", "description": "Description", "publishedAt": "2026-06-01T00:00:00Z", "tags": [], "categoryId": "10" },
          "contentDetails": { "duration": "PT3M", "caption": "false", "definition": "hd", "licensedContent": true },
          "recordingDetails": { "recordingDate": "2026-06-01" },
          "status": { "embeddable": true, "madeForKids": false, "privacyStatus": "public" },
          "statistics": { "viewCount": "1", "likeCount": "1", "commentCount": "0" }
        }
        """.utf8)
        return try! JSONDecoder().decode(YouTubeVideoDetails.self, from: data)
    }
}

@MainActor
final class DelayedOfficialProvider: FixtureYouTubeOfficialProvider {
    private var detailsContinuation: CheckedContinuation<Void, Never>?
    private var searchContinuations: [CheckedContinuation<Void, Never>] = []
    private(set) var searchCallCount = 0
    var hasPendingDetails: Bool { detailsContinuation != nil }

    override func searchVideoPage(query: String, accessToken: String, maxResults: Int, preference: YouTubePlaybackPreference, pageToken: String?) async throws -> YouTubeVideoPage {
        searchCallCount += 1
        await withCheckedContinuation { continuation in
            searchContinuations.append(continuation)
        }
        return try await super.searchVideoPage(query: query, accessToken: accessToken, maxResults: maxResults, preference: preference, pageToken: pageToken)
    }

    override func videoDetails(videoID: String, accessToken: String) async throws -> YouTubeVideoDetails? {
        await withCheckedContinuation { continuation in
            detailsContinuation = continuation
        }
        return try await super.videoDetails(videoID: videoID, accessToken: accessToken)
    }

    func resumeSearch() {
        guard !searchContinuations.isEmpty else { return }
        searchContinuations.removeFirst().resume()
    }

    func resumeAllSearches() {
        let continuations = searchContinuations
        searchContinuations.removeAll()
        continuations.forEach { $0.resume() }
    }

    func resumeDetails() {
        detailsContinuation?.resume()
        detailsContinuation = nil
    }
}

@MainActor
final class DelayedSearchService: YouTubeSearchServicing {
    var providerRequestCounts: [String: Int] = [:]
    private let result: YouTubeSearchServiceResult
    private var continuation: CheckedContinuation<Void, Never>?

    init(result: YouTubeSearchServiceResult) {
        self.result = result
    }

    func cachedPage(for request: YouTubeSearchRequest) -> YouTubeSearchServiceResult? { nil }

    func search(_ request: YouTubeSearchRequest) async -> YouTubeSearchServiceResult {
        await wait()
        return result
    }

    func loadMore(_ continuation: YouTubeSearchContinuation) async -> YouTubeSearchServiceResult {
        await wait()
        return result
    }

    func compareProviders(query: String, preference: YouTubePlaybackPreference) async -> [YouTubeProviderComparisonResult] { [] }
    func clearSearchCache() {}

    func resume() {
        continuation?.resume()
        continuation = nil
    }

    private func wait() async {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }
}

@MainActor
final class DelayedPlaylistService: YouTubePlaylistServicing {
    private let snapshot: YouTubeLibrarySnapshot
    private var continuation: CheckedContinuation<Void, Never>?

    init(snapshot: YouTubeLibrarySnapshot) {
        self.snapshot = snapshot
    }

    func loadLibrary() async -> YouTubeLibrarySnapshot {
        await wait()
        return snapshot
    }

    func selectPlaylist(_ playlist: YouTubePlaylist) async -> YouTubeLibrarySnapshot {
        await wait()
        return snapshot
    }

    func loadMorePlaylistItems(playlist: YouTubePlaylist, pageToken: String) async -> YouTubeLibrarySnapshot {
        await wait()
        return snapshot
    }

    func createDefaultPlaylist(adding video: YouTubeVideoSearchResult?) async -> YouTubePlaylistWriteResult {
        await wait()
        return .init(kind: .createDefault(adding: video), status: .ready, statusMessage: "Created.", playlists: snapshot.playlists, selectedPlaylist: snapshot.selectedPlaylist, playlistVideos: snapshot.playlistVideos, nextPlaylistPageToken: snapshot.nextPlaylistPageToken, requestCountDeltas: [:])
    }

    func add(_ video: YouTubeVideoSearchResult, to playlist: YouTubePlaylist) async -> YouTubePlaylistWriteResult {
        await wait()
        return .init(kind: .add(video: video, playlist: playlist), status: .ready, statusMessage: "Added.", playlists: snapshot.playlists, selectedPlaylist: snapshot.selectedPlaylist, playlistVideos: snapshot.playlistVideos, nextPlaylistPageToken: snapshot.nextPlaylistPageToken, requestCountDeltas: [:])
    }

    func remove(_ video: YouTubeVideoSearchResult, from playlist: YouTubePlaylist) async -> YouTubePlaylistWriteResult {
        await wait()
        return .init(kind: .remove(video: video, playlist: playlist), status: .ready, statusMessage: "Removed.", playlists: snapshot.playlists, selectedPlaylist: snapshot.selectedPlaylist, playlistVideos: snapshot.playlistVideos, nextPlaylistPageToken: snapshot.nextPlaylistPageToken, requestCountDeltas: [:])
    }

    func isAdding(_ video: YouTubeVideoSearchResult, to playlist: YouTubePlaylist) -> Bool { false }
    func isRemoving(_ video: YouTubeVideoSearchResult) -> Bool { false }
    func clearPlaylistCache() {}

    func resume() {
        continuation?.resume()
        continuation = nil
    }

    private func wait() async {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }
}
