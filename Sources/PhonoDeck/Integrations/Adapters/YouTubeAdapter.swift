import Foundation

/// YouTube adapter — the video-first surface (clips, music videos) over the
/// visible official embedded player.
final class YouTubeAdapter: YouTubePlaybackAdapter {
    init() { super.init(kind: .youtube) }

    override func playbackPlan(for track: MusicTrack) -> PlaybackPlan {
        guard let url = YouTubeEmbed.embedURL(forVideoID: track.id.rawValue) else {
            return .unavailable(reason: "Missing YouTube video id for \(track.title).")
        }
        return .embedded(WebEmbed(provider: .youtube, url: url, contentID: track.id.rawValue))
    }
}
