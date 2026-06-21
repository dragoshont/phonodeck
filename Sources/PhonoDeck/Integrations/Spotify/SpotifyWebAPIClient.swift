import Foundation

/// Spotify Web API client (https://api.spotify.com/v1). Takes a bearer access
/// token and returns SOURCE-NEUTRAL models (MusicTrack / MusicPlaylist / etc.),
/// so the rest of the app never sees Spotify DTOs.
struct SpotifyWebAPIClient: Sendable {
    private let baseURL = "https://api.spotify.com/v1"
    private let urlSession: URLSession

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    // MARK: Endpoints

    func currentUser(accessToken: String) async throws -> SpotifyUserProfile {
        try await get(makeURL("/me"), accessToken: accessToken)
    }

    func search(query: String, kinds: Set<SourceSearchKind>, accessToken: String, limit: Int = 25) async throws -> SourceSearchResults {
        var components = URLComponents(string: "\(baseURL)/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "type", value: Self.searchTypes(for: kinds).joined(separator: ",")),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        let response: SpotifySearchResponse = try await get(components.url!, accessToken: accessToken)
        return response.toResults()
    }

    func currentUserPlaylists(accessToken: String, limit: Int = 50) async throws -> [MusicPlaylist] {
        let page: SpotifyPaged<SpotifyPlaylist> = try await get(makeURL("/me/playlists?limit=\(limit)"), accessToken: accessToken)
        return page.items.map { $0.toMusicPlaylist() }
    }

    func savedTracks(accessToken: String, limit: Int = 50) async throws -> [MusicTrack] {
        let page: SpotifyPaged<SpotifySavedTrack> = try await get(makeURL("/me/tracks?limit=\(limit)"), accessToken: accessToken)
        return page.items.compactMap { $0.track?.toMusicTrack() }
    }

    func playlistTracks(playlistID: String, accessToken: String, limit: Int = 100) async throws -> [MusicTrack] {
        let page: SpotifyPaged<SpotifyPlaylistTrack> = try await get(makeURL("/playlists/\(playlistID)/tracks?limit=\(limit)"), accessToken: accessToken)
        return page.items.compactMap { $0.track?.toMusicTrack() }
    }

    // MARK: Plumbing

    private func makeURL(_ path: String) -> URL {
        URL(string: baseURL + path)!
    }

    private func get<T: Decodable>(_ url: URL, accessToken: String) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SpotifyAPIError.invalidResponse }
        switch http.statusCode {
        case 200..<300: break
        case 401: throw SpotifyAPIError.authorizationExpired
        case 429: throw SpotifyAPIError.rateLimited
        default: throw SpotifyAPIError.requestFailed(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw SpotifyAPIError.decodingFailed(String(describing: error))
        }
    }

    static func searchTypes(for kinds: Set<SourceSearchKind>) -> [String] {
        var types: [String] = []
        if kinds.contains(.songs) || kinds.contains(.videos) { types.append("track") }
        if kinds.contains(.albums) { types.append("album") }
        if kinds.contains(.artists) { types.append("artist") }
        if kinds.contains(.playlists) { types.append("playlist") }
        return types.isEmpty ? ["track"] : types
    }
}

enum SpotifyAPIError: LocalizedError, Equatable {
    case invalidResponse
    case authorizationExpired
    case rateLimited
    case requestFailed(Int, String)
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "Spotify returned an invalid response."
        case .authorizationExpired: "Spotify session expired. Reconnect Spotify."
        case .rateLimited: "Spotify rate limit reached. Try again shortly."
        case .requestFailed(let status, let body): "Spotify request failed (HTTP \(status)): \(body)"
        case .decodingFailed(let detail): "Could not read Spotify response: \(detail)"
        }
    }
}

// MARK: - DTOs + mapping to neutral models

struct SpotifyUserProfile: Decodable, Equatable {
    let id: String
    let displayName: String?
    let product: String?   // "premium" | "free" | "open"

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case product
    }

    var tier: SourceAccountTier { product == "premium" ? .premium : .free }
}

struct SpotifyPaged<Item: Decodable>: Decodable {
    let items: [Item]
}

struct SpotifyImage: Decodable { let url: String }

struct SpotifyArtistRef: Decodable {
    let id: String?
    let name: String
}

struct SpotifyAlbumRef: Decodable {
    let id: String?
    let name: String
    let images: [SpotifyImage]?
    let releaseDate: String?
    let artists: [SpotifyArtistRef]?

    enum CodingKeys: String, CodingKey {
        case id, name, images, artists
        case releaseDate = "release_date"
    }

    func toMusicAlbum() -> MusicAlbum? {
        guard let id else { return nil }
        return MusicAlbum(
            id: MusicProviderEntityID(source: .spotify, rawValue: id),
            title: name,
            artistName: (artists ?? []).map(\.name).joined(separator: ", "),
            releaseYear: releaseDate.map { String($0.prefix(4)) },
            recordLabel: nil,
            artworkURL: images?.first.flatMap { URL(string: $0.url) },
            source: .spotify,
            trackCount: nil,
            durationSeconds: nil,
            sourceURL: nil
        )
    }
}

struct SpotifyArtistFull: Decodable {
    let id: String?
    let name: String
    let images: [SpotifyImage]?

    func toMusicArtist() -> MusicArtist? {
        guard let id else { return nil }
        return MusicArtist(
            id: MusicProviderEntityID(source: .spotify, rawValue: id),
            name: name,
            artworkURL: images?.first.flatMap { URL(string: $0.url) },
            source: .spotify,
            albumCount: nil,
            trackCount: nil,
            localPlayTimeSeconds: 0,
            sourceURL: nil
        )
    }
}

struct SpotifyTrack: Decodable {
    let id: String?
    let name: String
    let artists: [SpotifyArtistRef]
    let album: SpotifyAlbumRef?
    let durationMs: Int?
    let externalUrls: [String: String]?

    enum CodingKeys: String, CodingKey {
        case id, name, artists, album
        case durationMs = "duration_ms"
        case externalUrls = "external_urls"
    }

    func toMusicTrack() -> MusicTrack? {
        guard let id else { return nil }
        return MusicTrack(
            id: MusicProviderEntityID(source: .spotify, rawValue: id),
            title: name,
            artistName: artists.map(\.name).joined(separator: ", "),
            albumTitle: album?.name,
            durationSeconds: durationMs.map { TimeInterval($0) / 1000 },
            releaseYear: album?.releaseDate.map { String($0.prefix(4)) },
            recordLabel: nil,
            artworkURL: album?.images?.first.flatMap { URL(string: $0.url) },
            source: .spotify,
            sourceURL: externalUrls?["spotify"].flatMap { URL(string: $0) }
        )
    }
}

struct SpotifySavedTrack: Decodable { let track: SpotifyTrack? }
struct SpotifyPlaylistTrack: Decodable { let track: SpotifyTrack? }

struct SpotifyPlaylist: Decodable {
    let id: String
    let name: String
    let owner: Owner?
    let images: [SpotifyImage]?
    let tracks: TrackCount?
    let externalUrls: [String: String]?

    enum CodingKeys: String, CodingKey {
        case id, name, owner, images, tracks
        case externalUrls = "external_urls"
    }

    struct Owner: Decodable {
        let displayName: String?
        enum CodingKeys: String, CodingKey { case displayName = "display_name" }
    }

    struct TrackCount: Decodable { let total: Int? }

    func toMusicPlaylist() -> MusicPlaylist {
        MusicPlaylist(
            id: MusicProviderEntityID(source: .spotify, rawValue: id),
            title: name,
            ownerName: owner?.displayName,
            trackCount: tracks?.total,
            artworkURL: images?.first.flatMap { URL(string: $0.url) },
            source: .spotify,
            sourceURL: externalUrls?["spotify"].flatMap { URL(string: $0) }
        )
    }
}

struct SpotifySearchResponse: Decodable {
    let tracks: SpotifyPaged<SpotifyTrack>?
    let artists: SpotifyPaged<SpotifyArtistFull>?
    let albums: SpotifyPaged<SpotifyAlbumRef>?
    let playlists: SpotifyPaged<SpotifyPlaylist>?

    func toResults() -> SourceSearchResults {
        SourceSearchResults(
            tracks: tracks?.items.compactMap { $0.toMusicTrack() } ?? [],
            albums: albums?.items.compactMap { $0.toMusicAlbum() } ?? [],
            artists: artists?.items.compactMap { $0.toMusicArtist() } ?? [],
            playlists: playlists?.items.map { $0.toMusicPlaylist() } ?? []
        )
    }
}
