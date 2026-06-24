import Foundation

enum SourceProviderStatus: Equatable, Sendable {
    case ready
    case notConnected
    case notConfigured(String)
    case missingScope(String)
    case authorizationExpired
    case rateLimited(retryAfter: Date?)
    case providerUnavailable(String)
    case partial
    case policyBlocked(String)
    case invalidProviderResponse
    case failed(String)

    var message: String {
        switch self {
        case .ready: "Ready"
        case .notConnected: "Not connected"
        case .notConfigured(let reason): reason
        case .missingScope(let scope): "Missing required scope: \(scope)"
        case .authorizationExpired: "Authorization expired"
        case .rateLimited(let retryAfter): retryAfter.map { "Rate limited until \($0)" } ?? "Rate limited"
        case .providerUnavailable(let reason): reason
        case .partial: "Partially available"
        case .policyBlocked(let reason): reason
        case .invalidProviderResponse: "Provider returned an invalid response"
        case .failed(let reason): reason
        }
    }
}

enum SourceCacheState: Equatable, Sendable {
    case none
    case warm(updatedAt: Date)
    case stale(updatedAt: Date)
    case refreshed(updatedAt: Date)
}

struct SourceProviderIssue: Equatable, Sendable {
    let code: String
    let message: String
}

struct SourceProviderReadiness: Equatable, Sendable {
    let source: MediaSourceKind
    let feature: SourceFeature
    let status: SourceProviderStatus
    let checkedAt: Date
    let account: SourceAccountSummary?
    let cacheState: SourceCacheState
    let issues: [SourceProviderIssue]
    let requestCounts: [String: Int]

    init(
        source: MediaSourceKind,
        feature: SourceFeature,
        status: SourceProviderStatus,
        checkedAt: Date = Date(),
        account: SourceAccountSummary? = nil,
        cacheState: SourceCacheState = .none,
        issues: [SourceProviderIssue] = [],
        requestCounts: [String: Int] = [:]
    ) {
        self.source = source
        self.feature = feature
        self.status = status
        self.checkedAt = checkedAt
        self.account = account
        self.cacheState = cacheState
        self.issues = issues
        self.requestCounts = requestCounts
    }
}

enum MusicPlaybackLocator: Codable, Hashable, Sendable {
    case providerItem(MusicProviderEntityID)
    case plexMediaPart(path: String, serverID: String?)
    case securityScopedBookmark(id: String)
    case webEmbed(contentID: String)
}

struct SourcePlaybackResolution: Equatable, Sendable {
    let plan: PlaybackPlan
    let status: SourceProviderStatus
    let requiresVisiblePlayer: Bool
    let isShareableURL: Bool
}

@MainActor
protocol SourceProviderReadinessProviding: AnyObject {
    func readiness(for feature: SourceFeature) async -> SourceProviderReadiness
}

@MainActor
protocol SourcePlaybackResolving: AnyObject {
    func resolvePlayback(for track: MusicTrack) async -> SourcePlaybackResolution
}
