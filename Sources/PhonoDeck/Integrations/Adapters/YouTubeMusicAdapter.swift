import Foundation

/// YouTube Music adapter — the song-first surface over the official YouTube APIs
/// and the visible embedded player. Catalog wiring reuses the existing YouTube
/// clients in a later phase; Phase 0 establishes identity, capability, and the
/// (policy-compliant) playback plan.
final class YouTubeMusicAdapter: YouTubePlaybackAdapter {
    init() { super.init(kind: .youtubeMusic) }

    override func playbackPlan(for track: MusicTrack) -> PlaybackPlan {
        guard let url = YouTubeEmbed.embedURL(forVideoID: track.id.rawValue) else {
            return .unavailable(reason: "Missing YouTube video id for \(track.title).")
        }
        return .embedded(WebEmbed(provider: .youtube, url: url, contentID: track.id.rawValue))
    }
}
