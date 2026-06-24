import Foundation

/// Shared policy-safe YouTube playback/readiness behavior for both the music-first
/// and video-first adapters. YouTube playback is always the visible official embed;
/// native audio, background playback, and downloads are not third-party capabilities.
@MainActor
class YouTubePlaybackAdapter: BaseSourceAdapter {
    override func readiness(for feature: SourceFeature) async -> SourceProviderReadiness {
        if feature == .downloads {
            return SourceProviderReadiness(source: kind, feature: feature, status: .policyBlocked("YouTube audiovisual downloads are not allowed without approval."), account: connectionState.account)
        }
        return SourceProviderReadiness(source: kind, feature: feature, status: .ready, account: connectionState.account)
    }

    override func resolvePlayback(for track: MusicTrack) async -> SourcePlaybackResolution {
        let plan = playbackPlan(for: track)
        switch plan {
        case .embedded:
            return SourcePlaybackResolution(plan: plan, status: .ready, requiresVisiblePlayer: true, isShareableURL: true)
        case .unavailable(let reason):
            return SourcePlaybackResolution(plan: plan, status: .notConfigured(reason), requiresVisiblePlayer: false, isShareableURL: false)
        default:
            return SourcePlaybackResolution(plan: plan, status: .policyBlocked("YouTube playback uses the visible official player only."), requiresVisiblePlayer: true, isShareableURL: false)
        }
    }
}