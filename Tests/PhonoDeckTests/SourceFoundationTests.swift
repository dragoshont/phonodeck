import XCTest
@testable import PhonoDeck

@MainActor
final class SourceFoundationTests: XCTestCase {

    struct FixturePlexCredentialStore: PlexCredentialStoring {
        var credentials: PlexCredentials?
        var error: Error?

        func load() throws -> PlexCredentials? {
            if let error { throw error }
            return credentials
        }

        func save(_ credentials: PlexCredentials) throws {}
        func disconnect() throws {}
    }

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

    private func temporaryAudioFile(extension fileExtension: String = "m4a") throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)
        FileManager.default.createFile(atPath: url.path, contents: Data([0, 1, 2, 3]))
        return url
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

    func testRouteDecisionDocumentsVisibleEmbedAndNativeEligibility() {
        let router = PlaybackRouter()
        let youtube = PlaybackPlan.embedded(WebEmbed(provider: .youtube, url: URL(string: "https://youtube.com/embed/x")!, contentID: "x"))
        let spotify = PlaybackPlan.embedded(WebEmbed(provider: .spotify, url: URL(string: "https://open.spotify.com/embed/track/x")!, contentID: "spotify:track:x"))
        let native = PlaybackPlan.nativeStream(url: URL(string: "https://plex.example/song.flac")!)

        let youtubeDecision = router.decision(for: youtube)
        XCTAssertEqual(youtubeDecision.engine, .webEmbed)
        XCTAssertTrue(youtubeDecision.requiresVisiblePlayer)
        XCTAssertFalse(youtubeDecision.canOwnSystemNowPlaying)
        XCTAssertEqual(youtubeDecision.blockedState, .unsupportedEngine(engine: .webEmbed, reason: "YouTube plays through the visible official embed only."))

        let spotifyDecision = router.decision(for: spotify)
        XCTAssertEqual(spotifyDecision.engine, .webEmbed)
        XCTAssertTrue(spotifyDecision.requiresVisiblePlayer)
        XCTAssertFalse(spotifyDecision.canOwnSystemNowPlaying)
        XCTAssertEqual(spotifyDecision.blockedState, .unsupportedEngine(engine: .webEmbed, reason: "Spotify plays through the visible official Spotify player; native macOS streaming is not available."))

        let nativeDecision = router.decision(for: native)
        XCTAssertEqual(nativeDecision.engine, .nativeAV)
        XCTAssertFalse(nativeDecision.requiresVisiblePlayer)
        XCTAssertTrue(nativeDecision.canOwnSystemNowPlaying)
        XCTAssertNil(nativeDecision.blockedState)
    }

    func testRouteDecisionPreservesUnavailableReason() {
        let router = PlaybackRouter()
        let reason = "Missing Plex media URL."
        let decision = router.decision(for: .unavailable(reason: reason), source: .plex, trackID: MusicProviderEntityID(source: .plex, rawValue: "t1"))

        XCTAssertEqual(decision.engine, .none)
        XCTAssertFalse(decision.requiresVisiblePlayer)
        XCTAssertFalse(decision.canOwnSystemNowPlaying)
        XCTAssertEqual(decision.blockedState, .missingMediaURL(source: .plex, trackID: MusicProviderEntityID(source: .plex, rawValue: "t1")))
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

    // MARK: Provider readiness and playback resolution

    func testDefaultReadinessSeparatesCapabilityFromConnection() async {
        let spotify = SpotifyAdapter()
        let readiness = await spotify.readiness(for: .search)
        XCTAssertEqual(readiness.source, .spotify)
        XCTAssertEqual(readiness.feature, .search)
        XCTAssertEqual(readiness.status, .notConnected)
    }

    func testYouTubeMusicReadinessKeepsDownloadsPolicyBlocked() async {
        let adapter = YouTubeMusicAdapter()
        let readiness = await adapter.readiness(for: .downloads)
        XCTAssertEqual(readiness.status, .policyBlocked("YouTube audiovisual downloads are not allowed without approval."))
    }

    func testYouTubeVideoReadinessKeepsDownloadsPolicyBlocked() async {
        let adapter = YouTubeAdapter()
        let readiness = await adapter.readiness(for: .downloads)
        XCTAssertEqual(readiness.status, .policyBlocked("YouTube audiovisual downloads are not allowed without approval."))
    }

    func testPlexReadinessReportsNotConnectedWithoutCredentials() async {
        let readiness = await PlexAdapter(accountStore: FixturePlexCredentialStore(credentials: nil)).readiness(for: .playback)
        XCTAssertEqual(readiness.source, .plex)
        XCTAssertEqual(readiness.status, .notConnected)
    }

    func testPlexReadinessReportsMissingServerConfiguration() async {
        let credentials = PlexCredentials(token: "token", serverName: nil, serverBaseURL: nil, hasPlexPass: false)
        let readiness = await PlexAdapter(accountStore: FixturePlexCredentialStore(credentials: credentials)).readiness(for: .playback)
        XCTAssertEqual(readiness.status, .notConfigured("No Plex music server is configured."))
    }

    func testPlexReadinessBlocksDownloadsWithoutPlexPass() async {
        let credentials = PlexCredentials(token: "token", serverName: "Home", serverBaseURL: "https://home.plex.direct:32400", hasPlexPass: false)
        let readiness = await PlexAdapter(accountStore: FixturePlexCredentialStore(credentials: credentials)).readiness(for: .downloads)
        XCTAssertEqual(readiness.status, .policyBlocked("Offline downloads require Plex Pass."))
    }

    func testPlexReadinessIsReadyForConfiguredServer() async {
        let credentials = PlexCredentials(token: "token", serverName: "Home", serverBaseURL: "https://home.plex.direct:32400", hasPlexPass: true)
        let readiness = await PlexAdapter(accountStore: FixturePlexCredentialStore(credentials: credentials)).readiness(for: .playback)
        XCTAssertEqual(readiness.status, .ready)
        XCTAssertEqual(readiness.account?.tier, .premium)
    }

    func testPlexResolvePlaybackRejectsInsecureURL() async {
        let track = track(.plex, url: URL(string: "http://plex.local/library/parts/1/file.flac")!)
        let store = FixturePlexCredentialStore(credentials: PlexCredentials(token: "token", serverName: "Home", serverBaseURL: "https://plex.local", hasPlexPass: true))
        let resolution = await PlexAdapter(accountStore: store).resolvePlayback(for: track)
        XCTAssertEqual(resolution.status, .policyBlocked("Plex playback requires a secure media URL."))
        guard case .unavailable = resolution.plan else { return XCTFail("expected unavailable") }
        XCTAssertFalse(resolution.isShareableURL)
    }

    func testPlexResolvePlaybackRequiresConnectedServerAndMatchingToken() async {
        let url = URL(string: "https://plex.local/library/parts/1/file.flac?X-Plex-Token=wrong")!
        let store = FixturePlexCredentialStore(credentials: PlexCredentials(token: "token", serverName: "Home", serverBaseURL: "https://plex.local", hasPlexPass: true))
        let resolution = await PlexAdapter(accountStore: store).resolvePlayback(for: track(.plex, url: url))
        XCTAssertEqual(resolution.status, .authorizationExpired)
        XCTAssertFalse(resolution.isShareableURL)
    }

    func testPlexResolvePlaybackRequiresMediaPartPath() async {
        let url = URL(string: "https://plex.local/library/metadata/1?X-Plex-Token=token")!
        let store = FixturePlexCredentialStore(credentials: PlexCredentials(token: "token", serverName: "Home", serverBaseURL: "https://plex.local", hasPlexPass: true))
        let resolution = await PlexAdapter(accountStore: store).resolvePlayback(for: track(.plex, url: url))
        XCTAssertEqual(resolution.status, .policyBlocked("Plex playback requires a media part URL."))
    }

    func testPlexResolvePlaybackAcceptsConnectedTokenBearingMediaPart() async {
        let url = URL(string: "https://plex.local/library/parts/1/file.flac?X-Plex-Token=token")!
        let store = FixturePlexCredentialStore(credentials: PlexCredentials(token: "token", serverName: "Home", serverBaseURL: "https://plex.local", hasPlexPass: true))
        let resolution = await PlexAdapter(accountStore: store).resolvePlayback(for: track(.plex, url: url))
        XCTAssertEqual(resolution.status, .ready)
        guard case let .nativeStream(streamURL) = resolution.plan else { return XCTFail("expected native stream") }
        XCTAssertEqual(streamURL, url)
        XCTAssertFalse(resolution.isShareableURL)
    }

    func testOwnFilesResolvePlaybackRejectsNonFileURL() async {
        let track = track(.ownFiles, url: URL(string: "https://example.com/song.m4a")!)
        let resolution = await OwnFilesAdapter().resolvePlayback(for: track)
        XCTAssertEqual(resolution.status, .policyBlocked("Own Files playback requires a local file URL."))
        guard case .unavailable = resolution.plan else { return XCTFail("expected unavailable") }
    }

    func testOwnFilesResolvePlaybackRejectsMissingLocalFile() async {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
        let resolution = await OwnFilesAdapter().resolvePlayback(for: track(.ownFiles, url: missing))
        XCTAssertEqual(resolution.status, .notConfigured("Local file is missing or unreadable."))
        guard case .unavailable = resolution.plan else { return XCTFail("expected unavailable") }
    }

    func testOwnFilesResolvePlaybackRejectsUnsupportedFormat() async throws {
        let unsupported = try temporaryAudioFile(extension: "txt")
        defer { try? FileManager.default.removeItem(at: unsupported) }
        let resolution = await OwnFilesAdapter().resolvePlayback(for: track(.ownFiles, url: unsupported))
        XCTAssertEqual(resolution.status, .policyBlocked("Unsupported local audio format."))
        guard case .unavailable = resolution.plan else { return XCTFail("expected unavailable") }
    }

    func testOwnFilesResolvePlaybackAcceptsReadableSupportedFile() async throws {
        let url = try temporaryAudioFile(extension: "m4a")
        defer { try? FileManager.default.removeItem(at: url) }
        let resolution = await OwnFilesAdapter().resolvePlayback(for: track(.ownFiles, url: url))
        XCTAssertEqual(resolution.status, .ready)
        guard case let .localFile(fileURL) = resolution.plan else { return XCTFail("expected local file") }
        XCTAssertEqual(fileURL, url)
    }

    func testSpotifyResolvePlaybackRemainsVisibleEmbedOnly() async {
        let resolution = await SpotifyAdapter().resolvePlayback(for: track(.spotify, id: "11dFghVXANMlKmJXsNCbNl"))
        XCTAssertEqual(resolution.status, .ready)
        XCTAssertTrue(resolution.requiresVisiblePlayer)
        XCTAssertTrue(resolution.isShareableURL)
        guard case let .embedded(embed) = resolution.plan else { return XCTFail("expected embed") }
        XCTAssertEqual(embed.provider, .spotify)
    }

    func testYouTubeResolvePlaybackRemainsVisibleEmbedOnly() async {
        let resolution = await YouTubeMusicAdapter().resolvePlayback(for: track(.youtubeMusic, id: "abc123"))
        XCTAssertEqual(resolution.status, .ready)
        XCTAssertTrue(resolution.requiresVisiblePlayer)
        guard case let .embedded(embed) = resolution.plan else { return XCTFail("expected embed") }
        XCTAssertEqual(embed.provider, .youtube)
    }

    func testYouTubeVideoResolvePlaybackRemainsVisibleEmbedOnly() async {
        let resolution = await YouTubeAdapter().resolvePlayback(for: track(.youtube, id: "abc123"))
        XCTAssertEqual(resolution.status, .ready)
        XCTAssertTrue(resolution.requiresVisiblePlayer)
        guard case let .embedded(embed) = resolution.plan else { return XCTFail("expected embed") }
        XCTAssertEqual(embed.provider, .youtube)
    }

    func testReadinessPresentationMapsPhaseFiveStatuses() {
        let partial = SourceReadinessPresentation.make(source: .youtubeMusic, status: .partial)
        XCTAssertEqual(partial.badge, "Partial")
        XCTAssertTrue(partial.detail.contains("showing what is ready"))

        let missingScope = SourceReadinessPresentation.make(source: .youtubeMusic, status: .missingScope("https://www.googleapis.com/auth/youtube"))
        XCTAssertEqual(missingScope.badge, "Permission needed")
        XCTAssertTrue(missingScope.detail.contains("Reconnect"))

        let unavailable = SourceReadinessPresentation.make(source: .plex, status: .providerUnavailable("Server unavailable"))
        XCTAssertEqual(unavailable.badge, "Service issue")
        XCTAssertEqual(unavailable.detail, "Server unavailable")
    }

    func testReadinessPresentationDoesNotPromoteConnectedButNotConfiguredProviderToReady() async {
        let credentials = PlexCredentials(token: "token", serverName: nil, serverBaseURL: nil, hasPlexPass: false)
        let readiness = await PlexAdapter(accountStore: FixturePlexCredentialStore(credentials: credentials)).readiness(for: .playback)

        XCTAssertEqual(readiness.status, .notConfigured("No Plex music server is configured."))
        let presentation = SourceReadinessPresentation.make(source: .plex, status: readiness.status)
        XCTAssertEqual(presentation.badge, "Setup needed")
        XCTAssertTrue(presentation.detail.contains("No Plex music server"))
    }

    func testEmbeddedRoutesExposeBlockedReasonForNativeNowPlayingHonesty() {
        let router = PlaybackRouter()
        let plan = PlaybackPlan.embedded(WebEmbed(provider: .youtube, url: URL(string: "https://youtube.com/embed/abc")!, contentID: "abc"))
        let blocked = router.blockedState(for: plan, source: .youtubeMusic, trackID: .init(source: .youtubeMusic, rawValue: "abc"))

        XCTAssertEqual(blocked, .unsupportedEngine(engine: .webEmbed, reason: "YouTube plays through the visible official embed only."))
        XCTAssertEqual(blocked?.reason, "YouTube plays through the visible official embed only.")
    }

    func testPhaseFiveAlbumsArtistsDoNotTreatYouTubeAsCanonicalCatalog() {
        XCTAssertEqual(SourceCapabilityResolver.status(for: .search, source: .youtubeMusic, tier: .premium), .active)
        XCTAssertEqual(SourceCapabilityResolver.status(for: .playback, source: .youtubeMusic, tier: .premium), .limited)

        let albumPresentation = SourceReadinessPresentation.make(
            source: .youtubeMusic,
            status: .policyBlocked("YouTube does not expose canonical album metadata to third-party apps.")
        )
        XCTAssertEqual(albumPresentation.badge, "Unavailable")
        XCTAssertTrue(albumPresentation.detail.contains("canonical album metadata"))
    }
}
