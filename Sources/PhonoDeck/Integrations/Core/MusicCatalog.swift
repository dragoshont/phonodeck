import Foundation

// MARK: - Source-neutral catalog containers (portable)
//
// Builds on the existing neutral models in MusicLibraryModels.swift
// (MusicTrack / MusicAlbum / MusicArtist) by adding playlists and the
// bundles returned by adapters. No platform dependency.

/// Source-neutral playlist.
struct MusicPlaylist: Identifiable, Codable, Hashable, Equatable {
    let id: MusicProviderEntityID
    let title: String
    let ownerName: String?
    let trackCount: Int?
    let artworkURL: URL?
    let source: MediaSourceKind
    let sourceURL: URL?
    /// True when this playlist mixes items from multiple sources (a PhonoDeck playlist).
    let isMixedSource: Bool

    init(
        id: MusicProviderEntityID,
        title: String,
        ownerName: String? = nil,
        trackCount: Int? = nil,
        artworkURL: URL? = nil,
        source: MediaSourceKind,
        sourceURL: URL? = nil,
        isMixedSource: Bool = false
    ) {
        self.id = id
        self.title = title
        self.ownerName = ownerName
        self.trackCount = trackCount
        self.artworkURL = artworkURL
        self.source = source
        self.sourceURL = sourceURL
        self.isMixedSource = isMixedSource
    }
}

/// What a search should return — requested per source capability.
enum SourceSearchKind: String, CaseIterable, Codable, Hashable, Sendable {
    case songs
    case videos
    case albums
    case artists
    case playlists
}

/// Neutral search-results bundle returned by an adapter.
struct SourceSearchResults: Equatable {
    var tracks: [MusicTrack]
    var albums: [MusicAlbum]
    var artists: [MusicArtist]
    var playlists: [MusicPlaylist]

    init(
        tracks: [MusicTrack] = [],
        albums: [MusicAlbum] = [],
        artists: [MusicArtist] = [],
        playlists: [MusicPlaylist] = []
    ) {
        self.tracks = tracks
        self.albums = albums
        self.artists = artists
        self.playlists = playlists
    }

    var isEmpty: Bool {
        tracks.isEmpty && albums.isEmpty && artists.isEmpty && playlists.isEmpty
    }
}

/// Neutral library snapshot bundle returned by an adapter.
struct SourceLibrarySnapshot: Equatable {
    var tracks: [MusicTrack]
    var albums: [MusicAlbum]
    var artists: [MusicArtist]
    var playlists: [MusicPlaylist]

    init(
        tracks: [MusicTrack] = [],
        albums: [MusicAlbum] = [],
        artists: [MusicArtist] = [],
        playlists: [MusicPlaylist] = []
    ) {
        self.tracks = tracks
        self.albums = albums
        self.artists = artists
        self.playlists = playlists
    }
}
