import Foundation

enum YouTubePlaybackPreference: String, CaseIterable, Identifiable {
    case songFirst
    case videoFirst
    case balanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .songFirst: "Music"
        case .videoFirst: "Video"
        case .balanced: "Mixed"
        }
    }
}

struct YouTubeDataClient: Sendable {
    private let urlSession: URLSession
    private let baseURL = URL(string: "https://www.googleapis.com/youtube/v3")!

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    func currentChannel(accessToken: String) async throws -> YouTubeChannel? {
        var components = URLComponents(url: baseURL.appendingPathComponent("channels"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "mine", value: "true")
        ]

        let data = try await performRequest(url: components.url!, accessToken: accessToken)
        let decoded = try JSONDecoder().decode(YouTubeChannelsResponse.self, from: data)
        return decoded.items.first
    }

    func searchVideos(query: String, accessToken: String, maxResults: Int = 12, preference: YouTubePlaybackPreference = .songFirst) async throws -> [YouTubeVideoSearchResult] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }

        let biasedQuery: String
        switch preference {
        case .songFirst:
            biasedQuery = "\(trimmedQuery) official audio"
        case .videoFirst:
            biasedQuery = "\(trimmedQuery) official music video"
        case .balanced:
            biasedQuery = trimmedQuery
        }

        var components = URLComponents(url: baseURL.appendingPathComponent("search"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "type", value: "video"),
            URLQueryItem(name: "q", value: biasedQuery),
            URLQueryItem(name: "maxResults", value: String(min(maxResults * 2, 25))),
            URLQueryItem(name: "order", value: "relevance"),
            URLQueryItem(name: "safeSearch", value: "none"),
            URLQueryItem(name: "videoCategoryId", value: "10"),
            URLQueryItem(name: "videoEmbeddable", value: "true")
        ]

        return try await searchVideoPage(query: query, accessToken: accessToken, maxResults: maxResults, preference: preference).items
    }

    func searchVideoPage(query: String, accessToken: String, maxResults: Int = 12, preference: YouTubePlaybackPreference = .songFirst, pageToken: String? = nil) async throws -> YouTubeVideoPage {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return YouTubeVideoPage(items: [], nextPageToken: nil) }

        let biasedQuery: String
        switch preference {
        case .songFirst:
            biasedQuery = "\(trimmedQuery) official audio"
        case .videoFirst:
            biasedQuery = "\(trimmedQuery) official music video"
        case .balanced:
            biasedQuery = trimmedQuery
        }

        var queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "type", value: "video"),
            URLQueryItem(name: "q", value: biasedQuery),
            URLQueryItem(name: "maxResults", value: String(min(maxResults * 2, 25))),
            URLQueryItem(name: "order", value: "relevance"),
            URLQueryItem(name: "safeSearch", value: "none"),
            URLQueryItem(name: "videoCategoryId", value: "10"),
            URLQueryItem(name: "videoEmbeddable", value: "true")
        ]
        if let pageToken {
            queryItems.append(URLQueryItem(name: "pageToken", value: pageToken))
        }

        var components = URLComponents(url: baseURL.appendingPathComponent("search"), resolvingAgainstBaseURL: false)!
        components.queryItems = queryItems

        let data = try await performRequest(url: components.url!, accessToken: accessToken)
        let decoded = try JSONDecoder().decode(YouTubeSearchResponse.self, from: data)
        let sortedItems = decoded.items
            .compactMap(YouTubeVideoSearchResult.init(item:))
            .sortedByPlaybackPriority(preference)

        let playableItems = switch preference {
        case .songFirst:
            sortedItems.filter(\.isSongLike).isEmpty ? sortedItems : sortedItems.filter(\.isSongLike)
        case .videoFirst, .balanced:
            sortedItems
        }

        let items = playableItems
            .prefix(maxResults)
            .map { $0 }
        return YouTubeVideoPage(items: try await enrichVideoResults(items, accessToken: accessToken), nextPageToken: decoded.nextPageToken)
    }

    func playlists(accessToken: String, maxResults: Int = 25) async throws -> [YouTubePlaylist] {
        var components = URLComponents(url: baseURL.appendingPathComponent("playlists"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet,contentDetails"),
            URLQueryItem(name: "mine", value: "true"),
            URLQueryItem(name: "maxResults", value: String(maxResults))
        ]

        let data = try await performRequest(url: components.url!, accessToken: accessToken)
        return try JSONDecoder().decode(YouTubePlaylistsResponse.self, from: data).items
    }

    func createPlaylist(title: String, description: String, privacyStatus: YouTubePlaylistPrivacyStatus, accessToken: String) async throws -> YouTubePlaylist {
        var components = URLComponents(url: baseURL.appendingPathComponent("playlists"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "part", value: "snippet,status")]

        let body = YouTubePlaylistCreateRequest(
            snippet: .init(title: title, description: description),
            status: .init(privacyStatus: privacyStatus.rawValue)
        )
        let data = try await performRequest(url: components.url!, accessToken: accessToken, method: "POST", body: body)
        return try JSONDecoder().decode(YouTubePlaylist.self, from: data)
    }

    func playlistItems(playlistID: String, accessToken: String, maxResults: Int = 25) async throws -> [YouTubeVideoSearchResult] {
        try await playlistItemPage(playlistID: playlistID, accessToken: accessToken, maxResults: maxResults).items
    }

    func playlistItemPage(playlistID: String, accessToken: String, maxResults: Int = 25, pageToken: String? = nil) async throws -> YouTubeVideoPage {
        var components = URLComponents(url: baseURL.appendingPathComponent("playlistItems"), resolvingAgainstBaseURL: false)!
        var queryItems = [
            URLQueryItem(name: "part", value: "snippet,contentDetails"),
            URLQueryItem(name: "playlistId", value: playlistID),
            URLQueryItem(name: "maxResults", value: String(maxResults))
        ]
        if let pageToken {
            queryItems.append(URLQueryItem(name: "pageToken", value: pageToken))
        }
        components.queryItems = queryItems

        let data = try await performRequest(url: components.url!, accessToken: accessToken)
        let decoded = try JSONDecoder().decode(YouTubePlaylistItemsResponse.self, from: data)
        let items = decoded.items.compactMap(YouTubeVideoSearchResult.init(playlistItem:))
        return YouTubeVideoPage(items: await enrichVideoResultsBestEffort(items, accessToken: accessToken), nextPageToken: decoded.nextPageToken)
    }

    func addVideoToPlaylist(videoID: String, playlistID: String, accessToken: String) async throws -> YouTubePlaylistItem {
        var components = URLComponents(url: baseURL.appendingPathComponent("playlistItems"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "part", value: "snippet")]

        let body = YouTubePlaylistItemInsertRequest(
            snippet: .init(
                playlistID: playlistID,
                resourceID: .init(kind: "youtube#video", videoID: videoID)
            )
        )
        let data = try await performRequest(url: components.url!, accessToken: accessToken, method: "POST", body: body)
        return try JSONDecoder().decode(YouTubePlaylistItem.self, from: data)
    }

    func deletePlaylistItem(playlistItemID: String, accessToken: String) async throws {
        var components = URLComponents(url: baseURL.appendingPathComponent("playlistItems"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "id", value: playlistItemID)]

        _ = try await performRequest(url: components.url!, accessToken: accessToken, method: "DELETE")
    }

    func recentActivityVideos(accessToken: String, maxResults: Int = 12) async throws -> [YouTubeVideoSearchResult] {
        var components = URLComponents(url: baseURL.appendingPathComponent("activities"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet,contentDetails"),
            URLQueryItem(name: "mine", value: "true"),
            URLQueryItem(name: "maxResults", value: String(maxResults))
        ]

        let data = try await performRequest(url: components.url!, accessToken: accessToken)
        let decoded = try JSONDecoder().decode(YouTubeActivitiesResponse.self, from: data)
        return decoded.items.compactMap(YouTubeVideoSearchResult.init(activity:))
    }

    func subscriptions(accessToken: String, maxResults: Int = 25) async throws -> [YouTubeSubscription] {
        var components = URLComponents(url: baseURL.appendingPathComponent("subscriptions"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet,contentDetails"),
            URLQueryItem(name: "mine", value: "true"),
            URLQueryItem(name: "maxResults", value: String(maxResults))
        ]

        let data = try await performRequest(url: components.url!, accessToken: accessToken)
        return try JSONDecoder().decode(YouTubeSubscriptionsResponse.self, from: data).items
    }

    func videoDetails(videoID: String, accessToken: String) async throws -> YouTubeVideoDetails? {
        var components = URLComponents(url: baseURL.appendingPathComponent("videos"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet,contentDetails,recordingDetails,status,statistics"),
            URLQueryItem(name: "id", value: videoID)
        ]

        let data = try await performRequest(url: components.url!, accessToken: accessToken)
        return try JSONDecoder().decode(YouTubeVideosResponse.self, from: data).items.first
    }

    private func enrichVideoResults(_ items: [YouTubeVideoSearchResult], accessToken: String) async throws -> [YouTubeVideoSearchResult] {
        guard !items.isEmpty else { return items }
        let ids = items.map(\.id).prefix(50).joined(separator: ",")
        var components = URLComponents(url: baseURL.appendingPathComponent("videos"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "part", value: "contentDetails,statistics,status"),
            URLQueryItem(name: "id", value: ids)
        ]

        let data = try await performRequest(url: components.url!, accessToken: accessToken)
        let detailsByID = Dictionary(uniqueKeysWithValues: try JSONDecoder().decode(YouTubeVideosResponse.self, from: data).items.map { ($0.id, $0) })
        return items.map { item in
            guard let details = detailsByID[item.id] else { return item }
            return item.withRowMetadata(durationText: details.formattedDuration, popularityText: details.popularitySummary)
        }
    }

    private func enrichVideoResultsBestEffort(_ items: [YouTubeVideoSearchResult], accessToken: String) async -> [YouTubeVideoSearchResult] {
        do {
            return try await enrichVideoResults(items, accessToken: accessToken)
        } catch {
            AppLog.playlist.info("Playlist metadata enrichment skipped; rows still loaded. error=\(error.localizedDescription, privacy: .public)")
            return items
        }
    }

    private func performRequest(url: URL, accessToken: String, method: String = "GET", body: Encodable? = nil) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw YouTubeDataError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let apiError = YouTubeDataErrorResponse.decode(from: data)
            if httpResponse.statusCode == 401 {
                throw YouTubeDataError.authorizationExpired(apiError.message)
            }
            if httpResponse.statusCode == 403, apiError.reason == "quotaExceeded" || apiError.reason == "dailyLimitExceeded" {
                throw YouTubeDataError.quotaExceeded
            }
            throw YouTubeDataError.requestFailed(httpResponse.statusCode, apiError.message)
        }
        return data
    }
}

private struct AnyEncodable: Encodable {
    private let encodeBody: (Encoder) throws -> Void

    init(_ value: Encodable) {
        encodeBody = value.encode(to:)
    }

    func encode(to encoder: Encoder) throws {
        try encodeBody(encoder)
    }
}

struct YouTubeVideoPage: Equatable {
    let items: [YouTubeVideoSearchResult]
    let nextPageToken: String?
}

extension Array where Element == YouTubeVideoSearchResult {
    func deduplicatedByVideoID() -> [YouTubeVideoSearchResult] {
        var seen = Set<String>()
        return filter { result in
            seen.insert(result.id).inserted
        }
    }

    func sortedBySongPlaybackPriority() -> [YouTubeVideoSearchResult] {
        sortedByPlaybackPriority(.songFirst)
    }

    func sortedByPlaybackPriority(_ preference: YouTubePlaybackPreference) -> [YouTubeVideoSearchResult] {
        sorted { left, right in
            if left.playbackScore(preference) == right.playbackScore(preference) {
                return left.title.localizedCaseInsensitiveCompare(right.title) == .orderedAscending
            }
            return left.playbackScore(preference) > right.playbackScore(preference)
        }
    }
}

extension Array where Element == YouTubePlaylist {
    func deduplicatedByPlaylistID() -> [YouTubePlaylist] {
        var seen = Set<String>()
        return filter { playlist in
            seen.insert(playlist.id).inserted
        }
    }
}

private extension YouTubeVideoSearchResult {
    func playbackScore(_ preference: YouTubePlaybackPreference) -> Int {
        let titleText = title.lowercased()
        let channelText = channelTitle.lowercased()
        let combinedText = "\(titleText) \(channelText)"

        var score = 0

        if combinedText.contains("official audio") { score += 120 }
        if combinedText.contains("audio only") { score += 90 }
        if combinedText.contains("provided to youtube") { score += 80 }
        if titleText.contains("lyric video") || titleText.contains("lyrics") { score += 40 }
        if channelText.hasSuffix(" - topic") { score += 100 }
        if channelText.contains("vevo") { score += 20 }

        if combinedText.contains("official music video") {
            score -= 50
        } else if titleText.contains("music video") {
            score -= 80
        }
        if combinedText.contains("live") { score -= 70 }
        if combinedText.contains("cover") { score -= 80 }
        if combinedText.contains("reaction") { score -= 80 }
        if combinedText.contains("karaoke") { score -= 60 }
        if combinedText.contains("instrumental") { score -= 35 }
        if combinedText.contains("guitar") { score -= 45 }
        if combinedText.contains("drum") { score -= 35 }
        if combinedText.contains("remix") { score -= 20 }

        switch preference {
        case .songFirst:
            break
        case .videoFirst:
            if combinedText.contains("official music video") { score += 170 }
            if titleText.contains("music video") { score += 120 }
            if combinedText.contains("official audio") { score -= 70 }
            if channelText.hasSuffix(" - topic") { score -= 40 }
        case .balanced:
            if combinedText.contains("official music video") { score += 65 }
            if titleText.contains("music video") { score += 40 }
        }

        return score
    }
}

struct YouTubeChannelsResponse: Decodable, Equatable {
    let items: [YouTubeChannel]
}

struct YouTubeChannel: Decodable, Equatable {
    let id: String
    let snippet: Snippet

    struct Snippet: Decodable, Equatable {
        let title: String
    }
}

struct YouTubeVideoSearchResult: Identifiable, Equatable, Codable {
    let id: String
    let title: String
    let channelTitle: String
    let thumbnailURL: URL?
    let sourceLabel: String?
    let playlistItemID: String?
    let playlistAddedAt: String?
    let durationText: String?
    let popularityText: String?

    var stableListID: String {
        playlistItemID ?? id
    }

    var embedURL: URL {
        var components = URLComponents(string: "https://www.youtube.com/embed/\(id)")!
        components.queryItems = [
            URLQueryItem(name: "enablejsapi", value: "1"),
            URLQueryItem(name: "playsinline", value: "1"),
            URLQueryItem(name: "origin", value: "http://127.0.0.1")
        ]
        return components.url!
    }

    var watchURL: URL {
        URL(string: "https://www.youtube.com/watch?v=\(id)")!
    }

    init(id: String, title: String, channelTitle: String, thumbnailURL: URL?, sourceLabel: String? = nil, playlistItemID: String? = nil, playlistAddedAt: String? = nil, durationText: String? = nil, popularityText: String? = nil) {
        self.id = id
        self.title = title
        self.channelTitle = channelTitle
        self.thumbnailURL = thumbnailURL
        self.sourceLabel = sourceLabel
        self.playlistItemID = playlistItemID
        self.playlistAddedAt = playlistAddedAt
        self.durationText = durationText
        self.popularityText = popularityText
    }

    func withRowMetadata(durationText: String?, popularityText: String?) -> YouTubeVideoSearchResult {
        YouTubeVideoSearchResult(
            id: id,
            title: title,
            channelTitle: channelTitle,
            thumbnailURL: thumbnailURL,
            sourceLabel: sourceLabel,
            playlistItemID: playlistItemID,
            playlistAddedAt: playlistAddedAt,
            durationText: durationText,
            popularityText: popularityText
        )
    }

    init?(item: YouTubeSearchItem) {
        guard item.id.kind == "youtube#video", let videoID = item.id.videoID else { return nil }
        self.id = videoID
        title = item.snippet.title.decodingHTMLEntities()
        channelTitle = item.snippet.channelTitle.decodingHTMLEntities()
        thumbnailURL = item.snippet.thumbnails.medium?.url ?? item.snippet.thumbnails.default?.url
        sourceLabel = nil
        playlistItemID = nil
        playlistAddedAt = nil
        durationText = nil
        popularityText = nil
    }

    init?(playlistItem: YouTubePlaylistItem) {
        guard let videoID = playlistItem.contentDetails?.videoID ?? playlistItem.snippet.resourceID?.videoID else { return nil }
        id = videoID
        title = playlistItem.snippet.title.decodingHTMLEntities()
        channelTitle = playlistItem.snippet.channelTitle.decodingHTMLEntities()
        thumbnailURL = playlistItem.snippet.thumbnails.medium?.url ?? playlistItem.snippet.thumbnails.default?.url
        sourceLabel = "Playlist"
        playlistItemID = playlistItem.id
        playlistAddedAt = playlistItem.snippet.publishedAt
        durationText = nil
        popularityText = nil
    }

    init?(activity: YouTubeActivity) {
        let videoID: String?
        let label: String
        if let uploadID = activity.contentDetails?.upload?.videoID {
            videoID = uploadID
            label = "Upload"
        } else if let likeID = activity.contentDetails?.like?.resourceID?.videoID {
            videoID = likeID
            label = "Liked"
        } else if let recommendationID = activity.contentDetails?.recommendation?.resourceID?.videoID {
            videoID = recommendationID
            label = "Recommended"
        } else {
            videoID = nil
            label = "Activity"
        }
        guard let videoID else { return nil }
        id = videoID
        title = activity.snippet.title.decodingHTMLEntities()
        channelTitle = activity.snippet.channelTitle.decodingHTMLEntities()
        thumbnailURL = activity.snippet.thumbnails.medium?.url ?? activity.snippet.thumbnails.default?.url
        sourceLabel = label
        playlistItemID = nil
        playlistAddedAt = nil
        durationText = nil
        popularityText = nil
    }
}

struct YouTubeSearchResponse: Decodable, Equatable {
    let nextPageToken: String?
    let items: [YouTubeSearchItem]
}

enum YouTubeResultKind: String, Equatable {
    case song = "Song"
    case lyrics = "Lyrics"
    case clip = "Clip"
    case live = "Live"
    case cover = "Cover"
    case video = "Video"
}

extension YouTubeVideoSearchResult {
    var resultKind: YouTubeResultKind {
        if sourceLabel == "Music" { return .song }

        let titleText = title.lowercased()
        let channelText = channelTitle.lowercased()
        let combinedText = "\(titleText) \(channelText)"

        if titleText.contains("official audio") || titleText.contains("audio only") || combinedText.contains("provided to youtube") || channelText.hasSuffix(" - topic") {
            return .song
        }
        if titleText.contains("lyrics") || titleText.contains("lyric video") {
            return .lyrics
        }
        if combinedText.contains("live") {
            return .live
        }
        if combinedText.contains("cover") || combinedText.contains("karaoke") {
            return .cover
        }
        if combinedText.contains("official music video") || titleText.contains("music video") {
            return .clip
        }
        return .video
    }

    var songBadge: String {
        resultKind.rawValue
    }

    var isSongLike: Bool {
        switch resultKind {
        case .song, .lyrics:
            true
        case .clip, .live, .cover, .video:
            false
        }
    }
}

struct YouTubePlaylist: Decodable, Identifiable, Equatable {
    let id: String
    let snippet: Snippet
    let contentDetails: ContentDetails?
    let status: Status?

    var shareURL: URL {
        URL(string: "https://www.youtube.com/playlist?list=\(id)")!
    }

    struct Snippet: Decodable, Equatable {
        let title: String
        let channelTitle: String?
        let thumbnails: YouTubeSearchItem.Thumbnails?
    }

    struct ContentDetails: Decodable, Equatable {
        let itemCount: Int
    }

    struct Status: Decodable, Equatable {
        let privacyStatus: String?
    }
}

enum YouTubePlaylistPrivacyStatus: String, CaseIterable, Identifiable {
    case `private`
    case unlisted
    case `public`

    var id: String { rawValue }

    var title: String {
        switch self {
        case .private: "Private"
        case .unlisted: "Unlisted"
        case .public: "Public"
        }
    }
}

private struct YouTubePlaylistCreateRequest: Encodable {
    let snippet: Snippet
    let status: Status

    struct Snippet: Encodable {
        let title: String
        let description: String
    }

    struct Status: Encodable {
        let privacyStatus: String
    }
}

struct YouTubePlaylistsResponse: Decodable, Equatable {
    let items: [YouTubePlaylist]
}

struct YouTubePlaylistItemsResponse: Decodable, Equatable {
    let nextPageToken: String?
    let items: [YouTubePlaylistItem]

    enum CodingKeys: String, CodingKey {
        case nextPageToken
        case items
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        nextPageToken = try container.decodeIfPresent(String.self, forKey: .nextPageToken)
        items = try container.decodeIfPresent([LossyYouTubePlaylistItem].self, forKey: .items)?.compactMap(\.item) ?? []
    }
}

private struct LossyYouTubePlaylistItem: Decodable, Equatable {
    let item: YouTubePlaylistItem?

    init(from decoder: Decoder) throws {
        item = try? YouTubePlaylistItem(from: decoder)
    }
}

private struct YouTubePlaylistItemInsertRequest: Encodable {
    let snippet: Snippet

    struct Snippet: Encodable {
        let playlistID: String
        let resourceID: ResourceID

        enum CodingKeys: String, CodingKey {
            case playlistID = "playlistId"
            case resourceID = "resourceId"
        }
    }

    struct ResourceID: Encodable {
        let kind: String
        let videoID: String

        enum CodingKeys: String, CodingKey {
            case kind
            case videoID = "videoId"
        }
    }
}

struct YouTubePlaylistItem: Decodable, Equatable {
    let id: String?
    let snippet: Snippet
    let contentDetails: ContentDetails?

    init(id: String?, snippet: Snippet, contentDetails: ContentDetails?) {
        self.id = id
        self.snippet = snippet
        self.contentDetails = contentDetails
    }

    enum CodingKeys: String, CodingKey {
        case id
        case snippet
        case contentDetails
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        snippet = try container.decodeIfPresent(Snippet.self, forKey: .snippet) ?? Snippet()
        contentDetails = try container.decodeIfPresent(ContentDetails.self, forKey: .contentDetails)
    }

    struct Snippet: Decodable, Equatable {
        let title: String
        let channelTitle: String
        let publishedAt: String?
        let thumbnails: YouTubeSearchItem.Thumbnails
        let resourceID: ResourceID?

        init(title: String = "Unavailable playlist item", channelTitle: String = "Unknown channel", publishedAt: String? = nil, thumbnails: YouTubeSearchItem.Thumbnails = .empty, resourceID: ResourceID? = nil) {
            self.title = title
            self.channelTitle = channelTitle
            self.publishedAt = publishedAt
            self.thumbnails = thumbnails
            self.resourceID = resourceID
        }

        enum CodingKeys: String, CodingKey {
            case title
            case channelTitle
            case publishedAt
            case thumbnails
            case resourceID = "resourceId"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Unavailable playlist item"
            channelTitle = try container.decodeIfPresent(String.self, forKey: .channelTitle) ?? "Unknown channel"
            publishedAt = try container.decodeIfPresent(String.self, forKey: .publishedAt)
            thumbnails = try container.decodeIfPresent(YouTubeSearchItem.Thumbnails.self, forKey: .thumbnails) ?? .empty
            resourceID = try container.decodeIfPresent(ResourceID.self, forKey: .resourceID)
        }
    }

    struct ContentDetails: Decodable, Equatable {
        let videoID: String?

        init(videoID: String?) {
            self.videoID = videoID
        }

        enum CodingKeys: String, CodingKey {
            case videoID = "videoId"
        }
    }
}

struct YouTubeSubscriptionsResponse: Decodable, Equatable {
    let items: [YouTubeSubscription]
}

struct YouTubeSubscription: Decodable, Identifiable, Equatable {
    let id: String
    let snippet: Snippet
    let contentDetails: ContentDetails?

    struct Snippet: Decodable, Equatable {
        let title: String
        let description: String?
        let resourceID: ResourceID?
        let thumbnails: YouTubeSearchItem.Thumbnails?

        enum CodingKeys: String, CodingKey {
            case title
            case description
            case resourceID = "resourceId"
            case thumbnails
        }
    }

    struct ResourceID: Decodable, Equatable {
        let channelID: String?

        enum CodingKeys: String, CodingKey {
            case channelID = "channelId"
        }
    }

    struct ContentDetails: Decodable, Equatable {
        let totalItemCount: Int?
        let newItemCount: Int?
    }
}

struct YouTubeVideosResponse: Decodable, Equatable {
    let items: [YouTubeVideoDetails]
}

struct YouTubeVideoDetails: Decodable, Equatable {
    let id: String
    let snippet: Snippet
    let contentDetails: ContentDetails?
    let recordingDetails: RecordingDetails?
    let status: Status?
    let statistics: Statistics?

    struct Snippet: Decodable, Equatable {
        let title: String
        let channelTitle: String
        let description: String?
        let publishedAt: String?
        let tags: [String]?
        let categoryID: String?

        enum CodingKeys: String, CodingKey {
            case title
            case channelTitle
            case description
            case publishedAt
            case tags
            case categoryID = "categoryId"
        }
    }

    struct ContentDetails: Decodable, Equatable {
        let duration: String?
        let caption: String?
        let definition: String?
        let licensedContent: Bool?
    }

    struct RecordingDetails: Decodable, Equatable {
        let recordingDate: String?
    }

    struct Status: Decodable, Equatable {
        let embeddable: Bool?
        let madeForKids: Bool?
        let privacyStatus: String?
    }

    struct Statistics: Decodable, Equatable {
        let viewCount: String?
        let likeCount: String?
        let commentCount: String?
    }
}

extension YouTubeVideoDetails {
    var formattedDuration: String? {
        guard let duration = contentDetails?.duration else { return nil }
        return Self.formatISODuration(duration)
    }

    var releaseYear: String? {
        if let recordingDate = recordingDetails?.recordingDate, let year = Self.year(from: recordingDate) {
            return year
        }
        if let publishedAt = snippet.publishedAt, let year = Self.year(from: publishedAt) {
            return year
        }
        return nil
    }

    var qualitySummary: String {
        let definition = switch contentDetails?.definition?.lowercased() {
        case "hd": "HD video"
        case "sd": "SD video"
        default: "Video definition unavailable"
        }
        return "\(definition); YouTube streams adaptively and exact audio bitrate is not exposed by the API."
    }

    var popularitySummary: String? {
        if let likeCount = statistics?.likeCount, let value = Int(likeCount) {
            return "\(Self.compactCount(value)) likes"
        }
        if let viewCount = statistics?.viewCount, let value = Int(viewCount) {
            return "\(Self.compactCount(value)) views"
        }
        return nil
    }

    var audioBitrateSummary: String {
        "Exact YouTube audio bitrate is not exposed. Navidrome, Plex, and local files can expose real file bitrate when those sources are connected."
    }

    var labelSummary: String {
        if contentDetails?.licensedContent == true {
            return "Licensed content; record label name is not exposed by the YouTube API."
        }
        return "Record label is not exposed by the YouTube API."
    }

    static func formatISODuration(_ duration: String) -> String? {
        guard let totalSeconds = durationSeconds(from: duration) else { return nil }
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    static func durationSeconds(from duration: String) -> Int? {
        var hours = 0
        var minutes = 0
        var seconds = 0
        var currentNumber = ""

        for character in duration {
            if character.isNumber {
                currentNumber.append(character)
                continue
            }

            guard let value = Int(currentNumber) else {
                currentNumber = ""
                continue
            }

            switch character {
            case "H": hours = value
            case "M": minutes = value
            case "S": seconds = value
            default: break
            }
            currentNumber = ""
        }

        return hours * 3600 + minutes * 60 + seconds
    }

    private static func compactCount(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000).replacingOccurrences(of: ".0", with: "")
        }
        if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000).replacingOccurrences(of: ".0", with: "")
        }
        return "\(value)"
    }

    private static func year(from dateString: String) -> String? {
        guard dateString.count >= 4 else { return nil }
        let prefix = String(dateString.prefix(4))
        return Int(prefix) == nil ? nil : prefix
    }
}

struct ResourceID: Decodable, Equatable {
    let kind: String?
    let videoID: String?
    let channelID: String?

    enum CodingKeys: String, CodingKey {
        case kind
        case videoID = "videoId"
        case channelID = "channelId"
    }
}

struct YouTubeActivitiesResponse: Decodable, Equatable {
    let items: [YouTubeActivity]
}

struct YouTubeActivity: Decodable, Equatable {
    let snippet: Snippet
    let contentDetails: ContentDetails?

    struct Snippet: Decodable, Equatable {
        let title: String
        let channelTitle: String
        let thumbnails: YouTubeSearchItem.Thumbnails
    }

    struct ContentDetails: Decodable, Equatable {
        let upload: Upload?
        let like: Like?
        let recommendation: Recommendation?

        struct Upload: Decodable, Equatable { let videoID: String?; enum CodingKeys: String, CodingKey { case videoID = "videoId" } }
        struct Like: Decodable, Equatable { let resourceID: ResourceID?; enum CodingKeys: String, CodingKey { case resourceID = "resourceId" } }
        struct Recommendation: Decodable, Equatable { let resourceID: ResourceID?; enum CodingKeys: String, CodingKey { case resourceID = "resourceId" } }
        struct ResourceID: Decodable, Equatable { let videoID: String?; enum CodingKeys: String, CodingKey { case videoID = "videoId" } }
    }
}

struct YouTubeSearchItem: Decodable, Equatable {
    let id: Identifier
    let snippet: Snippet

    struct Identifier: Decodable, Equatable {
        let kind: String
        let videoID: String?

        enum CodingKeys: String, CodingKey {
            case kind
            case videoID = "videoId"
        }
    }

    struct Snippet: Decodable, Equatable {
        let title: String
        let channelTitle: String
        let thumbnails: Thumbnails
    }

    struct Thumbnails: Decodable, Equatable {
        let `default`: Thumbnail?
        let medium: Thumbnail?

        static let empty = Thumbnails(default: nil, medium: nil)
    }

    struct Thumbnail: Decodable, Equatable {
        let url: URL
    }
}

private struct YouTubeDataErrorResponse: Decodable, Equatable {
    let error: ErrorBody

    struct ErrorBody: Decodable, Equatable {
        let message: String
        let errors: [Reason]?
    }

    struct Reason: Decodable, Equatable {
        let reason: String?
    }

    var message: String { error.message }
    var reason: String? { error.errors?.first?.reason }

    static func decode(from data: Data) -> DecodedError {
        if let decoded = try? JSONDecoder().decode(YouTubeDataErrorResponse.self, from: data) {
            return DecodedError(message: decoded.message, reason: decoded.reason)
        }
        let body = String(data: data, encoding: .utf8) ?? "Unknown YouTube Data API error."
        return DecodedError(message: body.count > 500 ? String(body.prefix(500)) : body, reason: nil)
    }

    struct DecodedError: Equatable {
        let message: String
        let reason: String?
    }
}

enum YouTubeDataError: LocalizedError, Equatable {
    case authorizationExpired(String)
    case invalidResponse
    case quotaExceeded
    case requestFailed(Int, String)

    var errorDescription: String? {
        switch self {
        case .authorizationExpired(let message):
            "YouTube authorization expired. Reconnect Google. \(message)"
        case .invalidResponse:
            "YouTube returned an invalid response."
        case .quotaExceeded:
            "YouTube API daily quota is exhausted. Try again later."
        case .requestFailed(let statusCode, let body):
            "YouTube request failed (HTTP \(statusCode)): \(body)"
        }
    }
}

private extension String {
    func decodingHTMLEntities() -> String {
        guard let data = data(using: .utf8) else { return self }
        let decoded = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue],
            documentAttributes: nil
        )
        return decoded?.string ?? self
    }
}
