import XCTest
@testable import PhonoDeckCore

@MainActor
final class PlaybackCoreTests: XCTestCase {
    func testNativeRoutesCanOwnSystemNowPlaying() throws {
        let router = PlaybackRouter()
        let streamURL = try XCTUnwrap(URL(string: "https://plex.example/library/parts/track.flac"))
        let decision = router.decision(for: .nativeStream(url: streamURL), source: .plex, trackID: trackID(.plex))

        XCTAssertEqual(decision.engine, .nativeAV)
        XCTAssertFalse(decision.requiresVisiblePlayer)
        XCTAssertTrue(decision.canOwnSystemNowPlaying)
        XCTAssertNil(decision.blockedState)
    }

    func testVisibleEmbedRoutesCannotOwnSystemNowPlaying() throws {
        let router = PlaybackRouter()
        let embedURL = try XCTUnwrap(YouTubeEmbed.embedURL(forVideoID: "video-id"))
        let decision = router.decision(
            for: .embedded(WebEmbed(provider: .youtube, url: embedURL, contentID: "video-id")),
            source: .youtubeMusic,
            trackID: trackID(.youtubeMusic)
        )

        XCTAssertEqual(decision.engine, .webEmbed)
        XCTAssertTrue(decision.requiresVisiblePlayer)
        XCTAssertFalse(decision.canOwnSystemNowPlaying)
        XCTAssertEqual(decision.blockedState?.reason, "YouTube plays through the visible official embed only.")
    }

    func testCapabilityResolverKeepsProviderPolicyHonestAcrossTiers() {
        XCTAssertEqual(SourceCapabilityResolver.status(for: .downloads, source: .youtubeMusic, tier: .premium), .unavailable)
        XCTAssertEqual(SourceCapabilityResolver.status(for: .playback, source: .spotify, tier: .free), .limited)
        XCTAssertEqual(SourceCapabilityResolver.status(for: .downloads, source: .plex, tier: .free), .unavailable)
        XCTAssertEqual(SourceCapabilityResolver.status(for: .downloads, source: .plex, tier: .premium), .active)
        XCTAssertEqual(SourceCapabilityResolver.status(for: .playback, source: .ownFiles, tier: .none), .active)
    }

    func testImmediatePlaybackEngineAcceptsOnlyNativePlans() async throws {
        let engine = ImmediatePlaybackEngine()
        let streamItem = PlaybackQueueItem(track: track(.plex), routeDecision: nativeDecision())

        try await engine.load(streamItem)
        XCTAssertEqual(engine.loadedItem?.id, streamItem.id)
        XCTAssertEqual(engine.duration, streamItem.track.durationSeconds)

        let embedItem = PlaybackQueueItem(track: track(.youtubeMusic), routeDecision: visibleDecision())
        do {
            try await engine.load(embedItem)
            XCTFail("Embedded plans must not load in the native engine")
        } catch let failure as PlaybackFailure {
            XCTAssertTrue(failure.reason.contains("cannot load on nativeAV") || failure.reason.contains("Only native stream"))
        }
    }

    func testQueueSnapshotPreservesRouteDecisions() throws {
        let nativeItem = PlaybackQueueItem(track: track(.plex), routeDecision: nativeDecision())
        let visibleItem = PlaybackQueueItem(track: track(.youtubeMusic), routeDecision: visibleDecision())
        let snapshot = PlaybackQueueSnapshot(items: [nativeItem, visibleItem], currentIndex: 1, repeatMode: .all, shuffleEnabled: true)

        XCTAssertEqual(snapshot.currentItem?.id, visibleItem.id)
        XCTAssertEqual(snapshot.currentItem?.routeDecision.engine, .webEmbed)
        XCTAssertEqual(snapshot.repeatMode, .all)
        XCTAssertTrue(snapshot.shuffleEnabled)
    }

    private func nativeDecision() -> PlaybackRouteDecision {
        PlaybackRouter().decision(
            for: .nativeStream(url: URL(string: "https://plex.example/library/parts/track.flac")!),
            source: .plex,
            trackID: trackID(.plex)
        )
    }

    private func visibleDecision() -> PlaybackRouteDecision {
        PlaybackRouter().decision(
            for: .embedded(WebEmbed(provider: .youtube, url: YouTubeEmbed.embedURL(forVideoID: "video-id")!, contentID: "video-id")),
            source: .youtubeMusic,
            trackID: trackID(.youtubeMusic)
        )
    }

    private func track(_ source: MediaSourceKind) -> MusicTrack {
        MusicTrack(
            id: trackID(source),
            title: "Track",
            artistName: "Artist",
            albumTitle: "Album",
            durationSeconds: 180,
            releaseYear: nil,
            recordLabel: nil,
            artworkURL: nil,
            source: source,
            sourceURL: nil
        )
    }

    private func trackID(_ source: MediaSourceKind) -> MusicProviderEntityID {
        MusicProviderEntityID(source: source, rawValue: "track")
    }
}