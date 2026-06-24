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
        case .experimental: "Disabled"
        }
    }

    var detail: String {
        switch self {
        case .automatic:
            "Use documented YouTube Data API metadata and the visible official player."
        case .official:
            "Use documented YouTube Data API metadata and the visible official player."
        case .experimental:
            "Undocumented YouTube Music web metadata is disabled by policy; use Official mode."
        }
    }
}

struct YouTubeProviderComparisonResult: Identifiable, Equatable {
    let id: YouTubeMusicEngine
    let title: String
    let status: String
    let items: [YouTubeVideoSearchResult]
    let cacheState: YouTubeCacheState
    let errorMessage: String?
    let riskLabel: String

    init(
        id: YouTubeMusicEngine,
        title: String,
        status: String,
        items: [YouTubeVideoSearchResult],
        cacheState: YouTubeCacheState = .none,
        errorMessage: String? = nil,
        riskLabel: String? = nil
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.items = items
        self.cacheState = cacheState
        self.errorMessage = errorMessage
        self.riskLabel = riskLabel ?? (id == .official ? "Documented API" : "Disabled")
    }
}

extension YouTubeCacheState {
    var evidenceLabel: String {
        switch self {
        case .none: "none"
        case .warm(let updatedAt): "warm \(updatedAt.formatted(date: .abbreviated, time: .shortened))"
        case .stale(let updatedAt): "stale \(updatedAt.formatted(date: .abbreviated, time: .shortened))"
        case .refreshed(let updatedAt): "refreshed \(updatedAt.formatted(date: .abbreviated, time: .shortened))"
        }
    }
}