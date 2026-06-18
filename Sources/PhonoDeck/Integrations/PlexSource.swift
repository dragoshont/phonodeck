import Foundation

struct PlexSource: MediaSource {
    let descriptor = MediaSourceKind.plex.descriptor

    func search(query: String) async throws -> [MediaItem] {
        throw MediaSourceError.notConfigured
    }

    func librarySnapshot() async throws -> [MediaItem] {
        throw MediaSourceError.notConfigured
    }
}
