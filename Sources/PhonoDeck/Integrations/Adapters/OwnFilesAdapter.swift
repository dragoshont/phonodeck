import Foundation

/// Own Files adapter — user-owned local media and imports. No account/tier; every
/// capability is available and playback is native local-file via AVFoundation.
final class OwnFilesAdapter: BaseSourceAdapter {
    init() { super.init(kind: .ownFiles) }

    /// Local media has no account concept.
    override var tier: SourceAccountTier { .none }

    override func playbackPlan(for track: MusicTrack) -> PlaybackPlan {
        guard let url = track.sourceURL else {
            return .unavailable(reason: "Missing local file URL for \(track.title).")
        }
        return .localFile(url: url)
    }
}
