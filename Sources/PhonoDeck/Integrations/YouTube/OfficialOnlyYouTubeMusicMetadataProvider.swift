import Foundation

struct OfficialOnlyYouTubeMusicMetadataProvider: YouTubeMusicMetadataProviding {
    func search(query: String, preference: YouTubePlaybackPreference, maxResults: Int) async throws -> [YouTubeVideoSearchResult] {
        throw YouTubeMusicProviderError.undocumentedMetadataDisabled
    }
}