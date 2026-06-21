import Foundation

enum YouTubeMusicEngine: String, CaseIterable, Identifiable {
    case automatic
    case official
    case experimental

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: "Auto"
        case .official: "Official"
        case .experimental: "Experimental"
        }
    }

    var detail: String {
        switch self {
        case .automatic:
            "Use documented YouTube APIs first; fall back to no-cookie YouTube Music metadata only when official lookup is unavailable."
        case .official:
            "Use documented YouTube Data API metadata and the visible official player."
        case .experimental:
            "Use no-cookie YouTube Music web metadata for music search, with official fallback."
        }
    }
}

struct YouTubeProviderComparisonResult: Identifiable, Equatable {
    let id: YouTubeMusicEngine
    let title: String
    let status: String
    let items: [YouTubeVideoSearchResult]
}