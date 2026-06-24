import Foundation

struct SpotifySource: MediaSource {
    let descriptor = MediaSourceKind.spotify.descriptor

    func search(query: String) async throws -> [MediaItem] {
        throw MediaSourceError.notConfigured
    }

    func librarySnapshot() async throws -> [MediaItem] {
        throw MediaSourceError.notConfigured
    }
}
