import Foundation

struct YouTubeMusicSource: MediaSource {
    let descriptor = MediaSourceKind.youtubeMusic.descriptor

    func search(query: String) async throws -> [MediaItem] {
        throw MediaSourceError.notConfigured
    }

    func librarySnapshot() async throws -> [MediaItem] {
        throw MediaSourceError.unsupportedByPolicy("There is no official YouTube Music library API for this native use case; use documented YouTube API Services only.")
    }
}
