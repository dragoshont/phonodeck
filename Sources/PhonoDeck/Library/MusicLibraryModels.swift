import Foundation

struct MusicProviderEntityID: Codable, Hashable, Equatable {
    let source: MediaSourceKind
    let rawValue: String

    var stableID: String { "\(source.rawValue):\(rawValue)" }
}

struct MusicTrack: Identifiable, Codable, Hashable, Equatable {
    let id: MusicProviderEntityID
    let title: String
    let artistName: String
    let albumTitle: String?
    let durationSeconds: TimeInterval?
    let releaseYear: String?
    let recordLabel: String?
    let artworkURL: URL?
    let source: MediaSourceKind
    let sourceURL: URL?

    var displayDuration: String {
        guard let durationSeconds else { return "--:--" }
        let totalSeconds = max(Int(durationSeconds), 0)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct MusicAlbum: Identifiable, Codable, Hashable, Equatable {
    let id: MusicProviderEntityID
    let title: String
    let artistName: String
    let releaseYear: String?
    let recordLabel: String?
    let artworkURL: URL?
    let source: MediaSourceKind
    let trackCount: Int?
    let durationSeconds: TimeInterval?
    let sourceURL: URL?

    var displayDuration: String {
        guard let durationSeconds else { return "Not exposed by this source" }
        let totalSeconds = max(Int(durationSeconds), 0)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct MusicArtist: Identifiable, Codable, Hashable, Equatable {
    let id: MusicProviderEntityID
    let name: String
    let artworkURL: URL?
    let source: MediaSourceKind
    let albumCount: Int?
    let trackCount: Int?
    let localPlayTimeSeconds: TimeInterval
    let sourceURL: URL?
}

struct MusicStorageAsset: Identifiable, Codable, Hashable, Equatable {
    let id: String
    let source: MediaSourceKind
    let title: String
    let kind: MusicStorageAssetKind
    let status: MusicStorageAssetStatus
    let byteCount: Int64
    let localURL: URL?
    let sourceURL: URL?
}

enum MusicStorageAssetKind: String, Codable, Hashable, Equatable {
    case metadata
    case artwork
    case ownedMedia
}

enum MusicStorageAssetStatus: String, Codable, Hashable, Equatable {
    case cached
    case local
    case downloading
    case unavailable
    case failed
}

protocol MusicLibraryProviding {
    var source: MediaSourceKind { get }

    func tracks() async throws -> [MusicTrack]
    func albums() async throws -> [MusicAlbum]
    func artists() async throws -> [MusicArtist]
}

protocol MusicStorageProviding {
    var source: MediaSourceKind { get }

    func storageAssets() async throws -> [MusicStorageAsset]
}