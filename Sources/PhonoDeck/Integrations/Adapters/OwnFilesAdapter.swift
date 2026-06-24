import Foundation

/// Own Files adapter — user-owned local media and imports. No account/tier; every
/// capability is available and playback is native local-file via AVFoundation.
final class OwnFilesAdapter: BaseSourceAdapter {
    init() { super.init(kind: .ownFiles) }

    /// Local media has no account concept.
    override var tier: SourceAccountTier { .none }

    override func readiness(for feature: SourceFeature) async -> SourceProviderReadiness {
        SourceProviderReadiness(source: kind, feature: feature, status: .ready, account: nil)
    }

    override func resolvePlayback(for track: MusicTrack) async -> SourcePlaybackResolution {
        guard let url = track.sourceURL else {
            return SourcePlaybackResolution(plan: .unavailable(reason: "Missing local file URL for \(track.title)."), status: .notConfigured("Missing local file URL for \(track.title)."), requiresVisiblePlayer: false, isShareableURL: false)
        }
        guard url.isFileURL else {
            return SourcePlaybackResolution(plan: .unavailable(reason: "Own Files playback requires a local file URL."), status: .policyBlocked("Own Files playback requires a local file URL."), requiresVisiblePlayer: false, isShareableURL: false)
        }
        let supportedExtensions = ["aac", "aif", "aiff", "alac", "caf", "flac", "m4a", "mp3", "wav"]
        guard supportedExtensions.contains(url.pathExtension.lowercased()) else {
            return SourcePlaybackResolution(plan: .unavailable(reason: "Unsupported local audio format."), status: .policyBlocked("Unsupported local audio format."), requiresVisiblePlayer: false, isShareableURL: false)
        }
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            return SourcePlaybackResolution(plan: .unavailable(reason: "Local file is missing or unreadable."), status: .notConfigured("Local file is missing or unreadable."), requiresVisiblePlayer: false, isShareableURL: false)
        }
        return SourcePlaybackResolution(plan: .localFile(url: url), status: .ready, requiresVisiblePlayer: false, isShareableURL: false)
    }

    override func playbackPlan(for track: MusicTrack) -> PlaybackPlan {
        guard let url = track.sourceURL else {
            return .unavailable(reason: "Missing local file URL for \(track.title).")
        }
        return .localFile(url: url)
    }
}
