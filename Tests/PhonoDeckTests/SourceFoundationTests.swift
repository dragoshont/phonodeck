import XCTest
@testable import PhonoDeck

@MainActor
final class SourceFoundationTests: XCTestCase {

    // MARK: Helpers

    private func track(_ source: MediaSourceKind, id: String = "dQw4w9WgXcQ", url: URL? = nil) -> MusicTrack {
        MusicTrack(
            id: MusicProviderEntityID(source: source, rawValue: id),
            title: "Test Track",
            artistName: "Test Artist",
            albumTitle: nil,
            durationSeconds: nil,
            releaseYear: nil,
            recordLabel: nil,
            artworkURL: nil,
            source: source,
            sourceURL: url
        )
    }

    // MARK: Honest free-vs-paid capability matrix

    func testYouTubeCapabilitiesAreTierIndependent() {
        for tier in [SourceAccountTier.free, .premium] {
            XCTAssertEqual(SourceCapabilityResolver.status(for: .search, source: .youtubeMusic, tier: tier), .active)
            XCTAssertEqual(SourceCapabilityResolver.status(for: .playlists, source: .youtubeMusic, tier: tier), .active)
            // Visible embed only; never "active" native playback.
            XCTAssertEqual(SourceCapabilityResolver.status(for: .playback, source: .youtubeMusic, tier: tier), .limited)
            // Never downloadable via the API.
            XCTAssertEqual(SourceCapabilityResolver.status(for: .downloads, source: .youtube, tier: tier), .unavailable)
        }
    }

    func testSpotifyPlaybackIsEmbeddedOnEveryTier() {
        // Metadata/library is available on both tiers.
        XCTAssertEqual(SourceCapabilityResolver.status(for: .search, source: .spotify, tier: .free), .active)
        XCTAssertEqual(SourceCapabilityResolver.status(for: .playlists, source: .spotify, tier: .free), .active)
        // Playback via the official Spotify iFrame embed = limited on BOTH tiers
        // (previews for all; full tracks when signed in to Premium in the player).
        XCTAssertEqual(SourceCapabilityResolver.status(for: .playback, source: .spotify, tier: .free), .limited)
        XCTAssertEqual(SourceCapabilityResolver.status(for: .playback, source: .spotify, tier: .premium), .limited)
    }

    func testPlexDownloadsRequirePlexPass() {
        XCTAssertEqual(SourceCapabilityResolver.status(for: .playback, source: .plex, tier: .free), .active)
        XCTAssertEqual(SourceCapabilityResolver.status(for: .downloads, source: .plex, tier: .free), .unavailable)
        XCTAssertEqual(SourceCapabilityResolver.status(for: .downloads, source: .plex, tier: .premium), .active)
    }

    func testOwnFilesEverythingAvailable() {
        for feature in SourceFeature.allCases {
            XCTAssertEqual(SourceCapabilityResolver.status(for: feature, source: .ownFiles, tier: .none), .active)
        }
    }

    func testCapabilityDetailIsTierHonest() {
        XCTAssertTrue(SourceCapabilityResolver.detail(for: .playback, source: .spotify, tier: .free).contains("Premium"))
        XCTAssertTrue(SourceCapabilityResolver.detail(for: .downloads, source: .plex, tier: .free).contains("Plex Pass"))
    }

    // MARK: Descriptor <-> feature mapping

    func testDescriptorExposesEveryFeature() {
        for kind in MediaSourceKind.allCases {
            for feature in SourceFeature.allCases {
                XCTAssertNotNil(kind.descriptor.capability(feature), "\(kind) missing \(feature)")
            }
        }
        XCTAssertEqual(MediaSourceKind.youtube.descriptor.capability(.search)?.name, "Search")
    }

    // MARK: Adapter capability + tier

    func testAdapterPlaybackIsTierHonestInDetail() {
        let spotify = SpotifyAdapter()
        // Spotify playback is the official embed on every tier.
        XCTAssertEqual(spotify.capabilityStatus(.playback), .limited)
        XCTAssertTrue(spotify.canPlayInApp)
        XCTAssertEqual(spotify.capabilityStatus(.downloads), .unavailable)
        XCTAssertEqual(spotify.capabilityStatus(.search), .active)

        // The tier shows up in the honest DETAIL, not the status.
        spotify.updateConnectionState(.connected(SourceAccountSummary(displayName: "Me", tier: .free)))
        XCTAssertTrue(spotify.capabilityDetail(.playback).lowercased().contains("preview"))
        spotify.updateConnectionState(.connected(SourceAccountSummary(displayName: "Me", tier: .premium)))
        XCTAssertTrue(spotify.capabilityDetail(.playback).lowercased().contains("full"))
    }

    // MARK: Playback plans

    func testYouTubeAdapterProducesVisibleEmbedPlan() {
        let plan = YouTubeMusicAdapter().playbackPlan(for: track(.youtubeMusic, id: "abc123"))
        guard case let .embedded(embed) = plan else { return XCTFail("expected embedded plan") }
        XCTAssertEqual(embed.provider, .youtube)
        XCTAssertTrue(embed.url.absoluteString.contains("/embed/abc123"))
        XCTAssertEqual(embed.contentID, "abc123")
        XCTAssertEqual(plan.policy, .embeddedPlayer)
    }

    func testYouTubeAdapterRejectsEmptyVideoID() {
        let plan = YouTubeAdapter().playbackPlan(for: track(.youtube, id: ""))
        guard case .unavailable = plan else { return XCTFail("expected unavailable plan") }
    }

    func testPlexAdapterProducesNativeStreamPlan() {
        let url = URL(string: "https://plex.example.com:32400/library/parts/1/file.flac")!
        let plan = PlexAdapter().playbackPlan(for: track(.plex, url: url))
        guard case let .nativeStream(streamURL) = plan else { return XCTFail("expected nativeStream") }
        XCTAssertEqual(streamURL, url)
        XCTAssertEqual(plan.policy, .nativeStream)
    }

    func testOwnFilesAdapterProducesLocalFilePlan() {
        let url = URL(fileURLWithPath: "/Users/me/Music/song.m4a")
        let plan = OwnFilesAdapter().playbackPlan(for: track(.ownFiles, url: url))
        guard case .localFile = plan else { return XCTFail("expected localFile") }
        XCTAssertEqual(plan.policy, .localFile)
    }

    func testSpotifyAdapterProducesVisibleEmbedPlan() {
        let plan = SpotifyAdapter().playbackPlan(for: track(.spotify, id: "11dFghVXANMlKmJXsNCbNl"))
        guard case let .embedded(embed) = plan else { return XCTFail("expected embedded plan") }
        XCTAssertEqual(embed.provider, .spotify)
        XCTAssertTrue(embed.url.absoluteString.contains("open.spotify.com/embed/track/11dFghVXANMlKmJXsNCbNl"))
        XCTAssertEqual(embed.contentID, "spotify:track:11dFghVXANMlKmJXsNCbNl")
        XCTAssertEqual(plan.policy, .embeddedPlayer)
    }

    // MARK: Playback router (system Now Playing ownership)

    func testRouterMapsPlansToEngines() {
        let router = PlaybackRouter()
        let embed = PlaybackPlan.embedded(WebEmbed(provider: .youtube, url: URL(string: "https://youtube.com/embed/x")!, contentID: "x"))
        let native = PlaybackPlan.nativeStream(url: URL(string: "https://plex/x")!)
        let local = PlaybackPlan.localFile(url: URL(fileURLWithPath: "/x.m4a"))
        let connect = PlaybackPlan.connectRemote(reason: "r")
        let none = PlaybackPlan.unavailable(reason: "r")

        XCTAssertEqual(router.engineKind(for: embed), .webEmbed)
        XCTAssertEqual(router.engineKind(for: native), .nativeAV)
        XCTAssertEqual(router.engineKind(for: local), .nativeAV)
        XCTAssertEqual(router.engineKind(for: connect), .connectRemote)
        XCTAssertEqual(router.engineKind(for: none), .none)
    }

    func testOnlyNativeEngineOwnsSystemNowPlaying() {
        let router = PlaybackRouter()
        // The crux of the honest media-key behaviour: only native playback owns
        // MPRemoteCommandCenter / MPNowPlayingInfoCenter.
        XCTAssertTrue(router.ownsSystemNowPlaying(for: .nativeStream(url: URL(string: "https://x")!)))
        XCTAssertTrue(router.ownsSystemNowPlaying(for: .localFile(url: URL(fileURLWithPath: "/x"))))
        XCTAssertFalse(router.ownsSystemNowPlaying(for: .embedded(WebEmbed(provider: .youtube, url: URL(string: "https://x")!, contentID: "x"))))
        XCTAssertFalse(router.ownsSystemNowPlaying(for: .connectRemote(reason: "r")))
    }

    // MARK: Registry

    func testRegistryHasAllSourcesAndResolvesByKind() {
        let registry = SourceRegistry.makeDefault()
        XCTAssertEqual(registry.ordered.count, MediaSourceKind.allCases.count)
        XCTAssertEqual(registry.adapter(for: .spotify)?.kind, .spotify)
        XCTAssertEqual(registry.adapter(for: .plex)?.kind, .plex)
    }

    func testRegistryPlayableNowIncludesEmbeddableSources() {
        let registry = SourceRegistry.makeDefault()
        let playable = Set(registry.playableNow.map(\.kind))
        // Every source now has an in-app playback path (YouTube + Spotify visible
        // embeds, Plex + own files native), so all five are playable.
        XCTAssertTrue(playable.contains(.spotify))      // official Spotify embed (previews/full)
        XCTAssertTrue(playable.contains(.youtubeMusic))
        XCTAssertTrue(playable.contains(.plex))
        XCTAssertTrue(playable.contains(.ownFiles))
        XCTAssertEqual(registry.playableNow.count, MediaSourceKind.allCases.count)
    }
}
