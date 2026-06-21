import Foundation

struct YouTubeMusicInnerTubeClient: Sendable {
    private let urlSession: URLSession
    private let endpoint = URL(string: "https://music.youtube.com/youtubei/v1/search?prettyPrint=false")!

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    func search(query: String, preference: YouTubePlaybackPreference, maxResults: Int = 20) async throws -> [YouTubeVideoSearchResult] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://music.youtube.com", forHTTPHeaderField: "Origin")
        request.setValue("https://music.youtube.com/", forHTTPHeaderField: "Referer")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody(query: trimmedQuery, preference: preference))

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw YouTubeMusicInnerTubeError.requestFailed
        }

        return try Self.parseSearchResponse(data, maxResults: maxResults)
    }

    private func requestBody(query: String, preference: YouTubePlaybackPreference) -> [String: Any] {
        var body: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "WEB_REMIX",
                    "clientVersion": "1.20240603.01.00",
                    "hl": "en",
                    "gl": "US"
                ]
            ],
            "query": query
        ]

        if preference == .songFirst {
            body["params"] = "EgWKAQIIAWoKEAMQBBAJEAoQBQ%3D%3D"
        }

        return body
    }

    static func parseSearchResponse(_ data: Data, maxResults: Int = 20) throws -> [YouTubeVideoSearchResult] {
        let object = try JSONSerialization.jsonObject(with: data)
        let shelves = recursiveValues(named: "musicShelfRenderer", in: object)

        var results: [YouTubeVideoSearchResult] = []
        for shelf in shelves {
            guard let shelfDictionary = shelf as? [String: Any] else { continue }
            let shelfTitle = text(from: shelfDictionary["title"]).lowercased()
            guard shelfTitle.isEmpty || shelfTitle.contains("song") || shelfTitle.contains("top") || shelfTitle.contains("video") else { continue }

            let contents = shelfDictionary["contents"] as? [[String: Any]] ?? []
            for item in contents {
                guard let renderer = item["musicResponsiveListItemRenderer"] as? [String: Any],
                      let result = parseListItem(renderer) else { continue }
                results.append(result)
                if results.count >= maxResults { return results.deduplicatedByVideoID() }
            }
        }

        return results.deduplicatedByVideoID()
    }

    private static func parseListItem(_ renderer: [String: Any]) -> YouTubeVideoSearchResult? {
        guard let videoID = (renderer["playlistItemData"] as? [String: Any])?["videoId"] as? String ?? firstVideoID(in: renderer) else { return nil }

        let columns = renderer["flexColumns"] as? [[String: Any]] ?? []
        let columnTexts = columns.map { column -> [String] in
            let textObject = (column["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any])?["text"]
            return runs(from: textObject)
        }

        guard let title = columnTexts.first?.joined().trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else { return nil }

        let metadata = columnTexts.dropFirst().flatMap { $0 }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0 != "•" }

        let artist = metadata.first ?? "YouTube Music"
        let album = metadata.dropFirst().first
        let channelTitle = album.map { "\(artist) - \($0)" } ?? artist

        return YouTubeVideoSearchResult(
            id: videoID,
            title: title,
            channelTitle: channelTitle,
            thumbnailURL: thumbnailURL(from: renderer),
            sourceLabel: "Music"
        )
    }

    private static func text(from value: Any?) -> String {
        if let dictionary = value as? [String: Any] {
            if let simpleText = dictionary["simpleText"] as? String { return simpleText }
            return runs(from: dictionary).joined()
        }
        return ""
    }

    private static func runs(from value: Any?) -> [String] {
        guard let dictionary = value as? [String: Any], let runs = dictionary["runs"] as? [[String: Any]] else { return [] }
        return runs.compactMap { $0["text"] as? String }
    }

    private static func thumbnailURL(from renderer: [String: Any]) -> URL? {
        guard let musicThumbnailRenderer = (renderer["thumbnail"] as? [String: Any])?["musicThumbnailRenderer"] as? [String: Any],
              let thumbnail = musicThumbnailRenderer["thumbnail"] as? [String: Any],
              let thumbnails = thumbnail["thumbnails"] as? [[String: Any]],
              let urlString = thumbnails.last?["url"] as? String else { return nil }
        return URL(string: urlString)
    }

    private static func firstVideoID(in value: Any) -> String? {
        if let dictionary = value as? [String: Any] {
            if let videoID = dictionary["videoId"] as? String { return videoID }
            for nestedValue in dictionary.values {
                if let videoID = firstVideoID(in: nestedValue) { return videoID }
            }
        } else if let array = value as? [Any] {
            for nestedValue in array {
                if let videoID = firstVideoID(in: nestedValue) { return videoID }
            }
        }
        return nil
    }

    private static func recursiveValues(named key: String, in value: Any) -> [Any] {
        var values: [Any] = []
        if let dictionary = value as? [String: Any] {
            for (dictionaryKey, dictionaryValue) in dictionary {
                if dictionaryKey == key {
                    values.append(dictionaryValue)
                }
                values.append(contentsOf: recursiveValues(named: key, in: dictionaryValue))
            }
        } else if let array = value as? [Any] {
            for item in array {
                values.append(contentsOf: recursiveValues(named: key, in: item))
            }
        }
        return values
    }
}

enum YouTubeMusicInnerTubeError: LocalizedError {
    case requestFailed

    var errorDescription: String? {
        switch self {
        case .requestFailed:
            "YouTube Music experimental search failed."
        }
    }
}