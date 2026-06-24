import Foundation

/// Talks to a Plex Media Server (and plex.tv for server discovery). Returns
/// SOURCE-NEUTRAL models. Track `sourceURL` is a directly playable, token-bearing
/// media-part URL for native AVFoundation playback.
struct PlexServerClient: Sendable {
    private let urlSession: URLSession

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    // MARK: Discovery (plex.tv)

    func resources(token: String) async throws -> [PlexResource] {
        try await get("https://plex.tv/api/v2/resources?includeHttps=1&includeRelay=1", token: token)
    }

    /// The first owned music server and a reachable (HTTPS, ATS-safe) base URL.
    func firstServer(token: String) async throws -> (name: String, baseURL: String)? {
        let servers = (try await resources(token: token)).filter { $0.provides.contains("server") }
        for server in servers {
            if let base = server.bestConnection { return (server.name, base) }
        }
        return nil
    }

    // MARK: Library (server)

    func musicSections(baseURL: String, token: String) async throws -> [PlexSection] {
        let response: PlexDirectoryResponse = try await get(baseURL + "/library/sections", token: token)
        return (response.mediaContainer.directory ?? []).filter { $0.type == "artist" }
    }

    func sectionTracks(baseURL: String, token: String, sectionKey: String, limit: Int = 100) async throws -> [MusicTrack] {
        let response: PlexMetadataResponse = try await get(
            baseURL + "/library/sections/\(sectionKey)/all?type=10&X-Plex-Container-Start=0&X-Plex-Container-Size=\(limit)",
            token: token
        )
        return (response.mediaContainer.metadata ?? []).compactMap { $0.toMusicTrack(baseURL: baseURL, token: token) }
    }

    func search(baseURL: String, token: String, query: String, limit: Int = 30) async throws -> SourceSearchResults {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let response: PlexHubResponse = try await get(baseURL + "/hubs/search?query=\(encoded)&limit=\(limit)", token: token)
        var results = SourceSearchResults()
        for hub in response.mediaContainer.hub ?? [] {
            let metadata = hub.metadata ?? []
            switch hub.type {
            case "track": results.tracks += metadata.compactMap { $0.toMusicTrack(baseURL: baseURL, token: token) }
            case "album": results.albums += metadata.compactMap { $0.toMusicAlbum(baseURL: baseURL, token: token) }
            case "artist": results.artists += metadata.compactMap { $0.toMusicArtist(baseURL: baseURL, token: token) }
            default: break
            }
        }
        return results
    }

    func playlists(baseURL: String, token: String) async throws -> [MusicPlaylist] {
        let response: PlexMetadataResponse = try await get(baseURL + "/playlists?playlistType=audio", token: token)
        return (response.mediaContainer.metadata ?? []).compactMap { $0.toMusicPlaylist(baseURL: baseURL, token: token) }
    }

    func playlistItems(baseURL: String, token: String, ratingKey: String) async throws -> [MusicTrack] {
        let response: PlexMetadataResponse = try await get(baseURL + "/playlists/\(ratingKey)/items", token: token)
        return (response.mediaContainer.metadata ?? []).compactMap { $0.toMusicTrack(baseURL: baseURL, token: token) }
    }

    // MARK: Plumbing

    private func get<T: Decodable>(_ urlString: String, token: String) async throws -> T {
        guard let url = URL(string: urlString) else { throw PlexAPIError.invalidURL }
        var request = URLRequest(url: url)
        PlexClient.apply(headers: token, to: &request)

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw PlexAPIError.invalidResponse }
        switch http.statusCode {
        case 200..<300: break
        case 401: throw PlexAPIError.authorizationExpired
        default: throw PlexAPIError.requestFailed(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw PlexAPIError.decodingFailed(String(describing: error))
        }
    }
}

enum PlexAPIError: LocalizedError, Equatable {
    case invalidURL
    case invalidResponse
    case authorizationExpired
    case requestFailed(Int, String)
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid Plex URL."
        case .invalidResponse: "Plex returned an invalid response."
        case .authorizationExpired: "Plex session expired. Reconnect Plex."
        case .requestFailed(let status, let body): "Plex request failed (HTTP \(status)): \(body)"
        case .decodingFailed(let detail): "Could not read Plex response: \(detail)"
        }
    }
}

// MARK: - DTOs

struct PlexResource: Decodable {
    let name: String
    let provides: String
    let connections: [PlexConnection]?

    /// Prefer a secure local connection, then secure remote, then relay. App
    /// Transport Security blocks arbitrary http, so only `https` URIs are used
    /// (Plex provides these via *.plex.direct certificates).
    var bestConnection: String? {
        let conns = connections ?? []
        if let localHTTPS = conns.first(where: { $0.local == true && $0.uri.hasPrefix("https") && $0.relay != true }) {
            return localHTTPS.uri
        }
        if let anyHTTPS = conns.first(where: { $0.uri.hasPrefix("https") && $0.relay != true }) {
            return anyHTTPS.uri
        }
        if let relayHTTPS = conns.first(where: { $0.uri.hasPrefix("https") }) {
            return relayHTTPS.uri
        }
        return nil
    }
}

struct PlexConnection: Decodable {
    let uri: String
    let local: Bool?
    let relay: Bool?
}

struct PlexSection: Decodable {
    let key: String
    let title: String
    let type: String
}

struct PlexMedia: Decodable {
    let part: [PlexPart]?
    enum CodingKeys: String, CodingKey { case part = "Part" }
}

struct PlexPart: Decodable {
    let key: String?
    let container: String?
}

/// One flexible Plex metadata item (track / album / artist / playlist).
struct PlexMetadata: Decodable {
    let ratingKey: String?
    let type: String?
    let title: String?
    let grandparentTitle: String?  // artist (for a track)
    let parentTitle: String?       // album (for a track) / artist (for an album)
    let year: Int?
    let duration: Int?             // ms (track)
    let leafCount: Int?            // child count (album/playlist)
    let thumb: String?
    let composite: String?         // playlist artwork
    let media: [PlexMedia]?

    enum CodingKeys: String, CodingKey {
        case ratingKey, type, title, grandparentTitle, parentTitle, year, duration, leafCount, thumb, composite
        case media = "Media"
    }

    func toMusicTrack(baseURL: String, token: String) -> MusicTrack? {
        guard let ratingKey, let partKey = media?.first?.part?.first?.key else { return nil }
        return MusicTrack(
            id: MusicProviderEntityID(source: .plex, rawValue: ratingKey),
            title: title ?? "Unknown",
            artistName: grandparentTitle ?? "",
            albumTitle: parentTitle,
            durationSeconds: duration.map { TimeInterval($0) / 1000 },
            releaseYear: year.map(String.init),
            recordLabel: nil,
            artworkURL: Self.assetURL(baseURL: baseURL, path: thumb, token: token),
            source: .plex,
            sourceURL: Self.assetURL(baseURL: baseURL, path: partKey, token: token)
        )
    }

    func toMusicAlbum(baseURL: String, token: String) -> MusicAlbum? {
        guard let ratingKey else { return nil }
        return MusicAlbum(
            id: MusicProviderEntityID(source: .plex, rawValue: ratingKey),
            title: title ?? "",
            artistName: parentTitle ?? "",
            releaseYear: year.map(String.init),
            recordLabel: nil,
            artworkURL: Self.assetURL(baseURL: baseURL, path: thumb, token: token),
            source: .plex,
            trackCount: leafCount,
            durationSeconds: nil,
            sourceURL: nil
        )
    }

    func toMusicArtist(baseURL: String, token: String) -> MusicArtist? {
        guard let ratingKey else { return nil }
        return MusicArtist(
            id: MusicProviderEntityID(source: .plex, rawValue: ratingKey),
            name: title ?? "",
            artworkURL: Self.assetURL(baseURL: baseURL, path: thumb, token: token),
            source: .plex,
            albumCount: nil,
            trackCount: leafCount,
            localPlayTimeSeconds: 0,
            sourceURL: nil
        )
    }

    func toMusicPlaylist(baseURL: String, token: String) -> MusicPlaylist? {
        guard let ratingKey else { return nil }
        return MusicPlaylist(
            id: MusicProviderEntityID(source: .plex, rawValue: ratingKey),
            title: title ?? "Playlist",
            ownerName: nil,
            trackCount: leafCount,
            artworkURL: Self.assetURL(baseURL: baseURL, path: composite ?? thumb, token: token),
            source: .plex,
            sourceURL: nil
        )
    }

    static func assetURL(baseURL: String, path: String?, token: String) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        let separator = path.contains("?") ? "&" : "?"
        return URL(string: baseURL + path + separator + "X-Plex-Token=" + token)
    }
}

// MARK: - MediaContainer response wrappers

struct PlexDirectoryResponse: Decodable {
    let mediaContainer: Container
    struct Container: Decodable {
        let directory: [PlexSection]?
        enum CodingKeys: String, CodingKey { case directory = "Directory" }
    }
    enum CodingKeys: String, CodingKey { case mediaContainer = "MediaContainer" }
}

struct PlexMetadataResponse: Decodable {
    let mediaContainer: Container
    struct Container: Decodable {
        let metadata: [PlexMetadata]?
        enum CodingKeys: String, CodingKey { case metadata = "Metadata" }
    }
    enum CodingKeys: String, CodingKey { case mediaContainer = "MediaContainer" }
}

struct PlexHubResponse: Decodable {
    let mediaContainer: Container
    struct Container: Decodable {
        let hub: [PlexHub]?
        enum CodingKeys: String, CodingKey { case hub = "Hub" }
    }
    enum CodingKeys: String, CodingKey { case mediaContainer = "MediaContainer" }
}

struct PlexHub: Decodable {
    let type: String?
    let metadata: [PlexMetadata]?
    enum CodingKeys: String, CodingKey {
        case type
        case metadata = "Metadata"
    }
}
