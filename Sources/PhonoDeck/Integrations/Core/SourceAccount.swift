import Foundation

// MARK: - Account tier + connection state (portable, UI-agnostic)
//
// These contracts are intentionally free of SwiftUI / AppKit so the same
// source-abstraction logic can later be re-implemented in the web app's
// backend gateway. Keep this layer pure data + policy.

/// The account tier for a source. `premium` maps to YouTube Premium,
/// Spotify Premium, or Plex Pass depending on the source.
enum SourceAccountTier: String, Codable, Hashable, Sendable, CaseIterable {
    case none      // not applicable (own files) or signed out
    case free
    case premium
    case unknown

    var displayName: String {
        switch self {
        case .none: "—"
        case .free: "Free"
        case .premium: "Premium"
        case .unknown: "Unknown"
        }
    }
}

/// A connected account summary, source-neutral.
struct SourceAccountSummary: Equatable, Codable, Hashable, Sendable {
    /// Channel title / Spotify display name / Plex server name.
    let displayName: String
    let tier: SourceAccountTier
    /// Optional human detail, e.g. "Premium · 12 new", "Free · library only".
    let detail: String?

    init(displayName: String, tier: SourceAccountTier, detail: String? = nil) {
        self.displayName = displayName
        self.tier = tier
        self.detail = detail
    }
}

/// Connection lifecycle for a source, source-neutral.
enum SourceConnectionState: Equatable, Sendable {
    case notConnected
    case connecting
    case connected(SourceAccountSummary)
    case failed(reason: String)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var account: SourceAccountSummary? {
        if case let .connected(summary) = self { return summary }
        return nil
    }

    /// Tier of the connected account, or `.none` when not connected.
    var tier: SourceAccountTier { account?.tier ?? .none }
}
