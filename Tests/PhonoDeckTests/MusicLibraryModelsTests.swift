import XCTest
@testable import PhonoDeck

final class MusicLibraryModelsTests: XCTestCase {
    func testProviderEntityIDIsStableAcrossSources() {
        let youtubeID = MusicProviderEntityID(source: .youtubeMusic, rawValue: "abc")
        let plexID = MusicProviderEntityID(source: .plex, rawValue: "abc")

        XCTAssertEqual(youtubeID.stableID, "youtubeMusic:abc")
        XCTAssertEqual(plexID.stableID, "plex:abc")
        XCTAssertNotEqual(youtubeID.stableID, plexID.stableID)
    }

    func testMusicTrackFormatsDuration() {
        let track = MusicTrack(
            id: .init(source: .youtubeMusic, rawValue: "song"),
            title: "Song",
            artistName: "Artist",
            albumTitle: "Album",
            durationSeconds: 201,
            releaseYear: "1995",
            recordLabel: nil,
            artworkURL: nil,
            source: .youtubeMusic,
            sourceURL: nil
        )

        XCTAssertEqual(track.displayDuration, "3:21")
    }

    func testStorageAssetsSeparateArtworkMetadataAndOwnedMedia() {
        let assets: [MusicStorageAsset] = [
            .init(id: "metadata", source: .youtubeMusic, title: "Search cache", kind: .metadata, status: .cached, byteCount: 10, localURL: nil, sourceURL: nil),
            .init(id: "artwork", source: .youtubeMusic, title: "Artwork cache", kind: .artwork, status: .cached, byteCount: 20, localURL: nil, sourceURL: nil),
            .init(id: "file", source: .ownFiles, title: "Owned song", kind: .ownedMedia, status: .local, byteCount: 30, localURL: nil, sourceURL: nil)
        ]

        XCTAssertEqual(assets.map(\.kind), [.metadata, .artwork, .ownedMedia])
    }

    func testStoragePoliciesKeepYouTubeAndSpotifyMediaUnavailable() {
        let youtubeMusic = MusicStoragePolicyCatalog.policy(for: .youtubeMusic)
        let youtube = MusicStoragePolicyCatalog.policy(for: .youtube)
        let spotify = MusicStoragePolicyCatalog.policy(for: .spotify)

        XCTAssertEqual(youtubeMusic.status, .metadataOnly)
        XCTAssertEqual(youtube.status, .metadataOnly)
        XCTAssertEqual(spotify.status, .unavailable)
        XCTAssertFalse(youtubeMusic.allowedKinds.contains(.ownedMedia))
        XCTAssertFalse(youtube.allowedKinds.contains(.ownedMedia))
        XCTAssertFalse(spotify.allowedKinds.contains(.ownedMedia))
        XCTAssertTrue(youtubeMusic.detail.contains("Premium"))
        XCTAssertTrue(youtube.blockedActions.contains("Copied-cookie download flows"))
    }

    func testStoragePoliciesSeparateOwnedFilesAndPlexFuturePath() {
        let plex = MusicStoragePolicyCatalog.policy(for: .plex)
        let ownFiles = MusicStoragePolicyCatalog.policy(for: .ownFiles)

        XCTAssertEqual(plex.status, .planned)
        XCTAssertEqual(ownFiles.status, .local)
        XCTAssertTrue(plex.allowedKinds.contains(.ownedMedia))
        XCTAssertTrue(ownFiles.allowedKinds.contains(.ownedMedia))
        XCTAssertTrue(ownFiles.filePermissionDetail.contains("user-selected"))
    }

    func testStorageSnapshotOnlySurfacesSafeAssets() {
        let blockedYouTubeAsset = MusicStorageAsset(
            id: "blocked-youtube",
            source: .youtubeMusic,
            title: "Downloaded song",
            kind: .ownedMedia,
            status: .cached,
            byteCount: 100,
            localURL: nil,
            sourceURL: nil
        )
        let blockedSpotifyAsset = MusicStorageAsset(
            id: "blocked-spotify",
            source: .spotify,
            title: "Spotify offline file",
            kind: .ownedMedia,
            status: .cached,
            byteCount: 200,
            localURL: nil,
            sourceURL: nil
        )
        let ownedAsset = MusicStorageAsset(
            id: "owned-file",
            source: .ownFiles,
            title: "Owned file",
            kind: .ownedMedia,
            status: .local,
            byteCount: 300,
            localURL: nil,
            sourceURL: nil
        )

        let measuredAt = Date(timeIntervalSince1970: 1234)
        let snapshot = MusicStorageSnapshot.make(
            artworkBytes: 20,
            metadataBytes: 10,
            ownedMediaAssets: [blockedYouTubeAsset, blockedSpotifyAsset, ownedAsset],
            measuredAt: measuredAt,
            evidenceSource: "unit-test cache"
        )

        XCTAssertEqual(snapshot.metadataBytes, 10)
        XCTAssertEqual(snapshot.artworkBytes, 20)
        XCTAssertEqual(snapshot.blockedMediaAssetCount, 2)
        XCTAssertFalse(snapshot.hasYouTubeMediaDownloads)
        XCTAssertEqual(snapshot.assets.map(\.id), ["youtubeMusic.metadataCache", "youtubeMusic.artworkCache", "owned-file"])
        XCTAssertEqual(snapshot.totalBytes, 330)
        XCTAssertEqual(snapshot.mediaDownloadBytes, 0)
        XCTAssertEqual(snapshot.measuredAt, measuredAt)
        XCTAssertEqual(snapshot.evidenceSource, "unit-test cache")
    }

    func testCacheClearReceiptRecordsScopeAndRetainedData() {
        let receipt = StorageCacheClearReceipt(
            target: "Metadata cache",
            completedAt: Date(timeIntervalSince1970: 42),
            previousBytes: 1024,
            retainedData: "Retained account tokens and provider libraries."
        )

        XCTAssertEqual(receipt.target, "Metadata cache")
        XCTAssertEqual(receipt.previousBytes, 1024)
        XCTAssertTrue(receipt.retainedData.contains("Retained"))
    }

    func testStorageSnapshotCanRepresentPartialMeasurement() {
        let snapshot = MusicStorageSnapshot.make(
            artworkBytes: 10,
            metadataBytes: 20,
            measuredAt: Date(timeIntervalSince1970: 1),
            evidenceSource: "partial-test",
            measurementStatus: .partial,
            measurementIssue: "Skipped one unreadable file."
        )

        XCTAssertEqual(snapshot.measurementStatus, .partial)
        XCTAssertEqual(snapshot.measurementIssue, "Skipped one unreadable file.")
        XCTAssertEqual(snapshot.totalBytes, 30)
    }

    func testDeviceCapabilitiesCarryEvidence() {
        let capabilities = StaticDeviceRoutingCapabilityProvider().capabilities()
        XCTAssertTrue(capabilities.contains { $0.supportState == .limited && $0.evidenceSource.contains("IFrame") })
        XCTAssertTrue(capabilities.contains { $0.supportState == .available && $0.evidenceSource.contains("AVRoutePickerView") })
        XCTAssertTrue(capabilities.allSatisfy { !$0.evidenceSource.isEmpty })
    }

    func testEmptyStorageSnapshotHasNoFakeItems() {
        let snapshot = MusicStorageSnapshot.make(artworkBytes: 0, metadataBytes: 0)

        XCTAssertTrue(snapshot.assets.isEmpty)
        XCTAssertEqual(snapshot.totalBytes, 0)
        XCTAssertFalse(snapshot.hasYouTubeMediaDownloads)
    }
}