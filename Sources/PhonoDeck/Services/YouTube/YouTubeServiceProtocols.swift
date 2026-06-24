import Foundation

@MainActor
protocol YouTubeSearchServicing: AnyObject {
    var providerRequestCounts: [String: Int] { get }

    func cachedPage(for request: YouTubeSearchRequest) -> YouTubeSearchServiceResult?
    func search(_ request: YouTubeSearchRequest) async -> YouTubeSearchServiceResult
    func loadMore(_ continuation: YouTubeSearchContinuation) async -> YouTubeSearchServiceResult
    func compareProviders(query: String, preference: YouTubePlaybackPreference) async -> [YouTubeProviderComparisonResult]
    func clearSearchCache()
}

@MainActor
protocol YouTubeDiscoveryServicing: AnyObject {
    func cachedDiscovery(engine: YouTubeMusicEngine, seedQueries: [String], currentItems: [YouTubeVideoSearchResult]) -> YouTubeDiscoverySnapshot
    func refreshDiscovery(_ request: YouTubeDiscoveryRequest, currentItems: [YouTubeVideoSearchResult]) async -> YouTubeDiscoverySnapshot
    func clearDiscoveryCache()
}

@MainActor
protocol YouTubePlaylistServicing: AnyObject {
    func loadLibrary() async -> YouTubeLibrarySnapshot
    func selectPlaylist(_ playlist: YouTubePlaylist) async -> YouTubeLibrarySnapshot
    func loadMorePlaylistItems(playlist: YouTubePlaylist, pageToken: String) async -> YouTubeLibrarySnapshot
    func createDefaultPlaylist(adding video: YouTubeVideoSearchResult?) async -> YouTubePlaylistWriteResult
    func add(_ video: YouTubeVideoSearchResult, to playlist: YouTubePlaylist) async -> YouTubePlaylistWriteResult
    func remove(_ video: YouTubeVideoSearchResult, from playlist: YouTubePlaylist) async -> YouTubePlaylistWriteResult
    func isAdding(_ video: YouTubeVideoSearchResult, to playlist: YouTubePlaylist) -> Bool
    func isRemoving(_ video: YouTubeVideoSearchResult) -> Bool
    func clearPlaylistCache()
}
