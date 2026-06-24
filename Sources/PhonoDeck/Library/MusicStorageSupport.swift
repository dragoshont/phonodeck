import Foundation

struct MusicStorageSourcePolicy: Identifiable, Hashable {
    let source: MediaSourceKind
    let status: MusicStoragePolicyStatus
    let detail: String
    let cacheDetail: String
    let filePermissionDetail: String
    let allowedKinds: Set<MusicStorageAssetKind>
    let blockedActions: [String]

    var id: MediaSourceKind { source }
}

enum MusicStoragePolicyStatus: String, Hashable {
    case local = "Local"
    case metadataOnly = "Metadata Only"
    case planned = "Planned"
    case unavailable = "Unavailable"
}

enum StorageMeasurementStatus: String, Hashable {
    case complete = "Complete"
    case partial = "Partial"
    case failed = "Failed"
}

enum MusicStoragePolicyCatalog {
    static let policies: [MusicStorageSourcePolicy] = [
        .init(
            source: .youtube,
            status: .metadataOnly,
            detail: "YouTube media downloads are unavailable. Playback stays in the visible official YouTube player.",
            cacheDetail: "PhonoDeck may cache YouTube result metadata and artwork for navigation only.",
            filePermissionDetail: "No YouTube file import, hidden stream extraction, or copied-cookie flow is used.",
            allowedKinds: [.metadata, .artwork],
            blockedActions: ["Media file downloads", "Hidden stream extraction", "Copied-cookie download flows"]
        ),
        .init(
            source: .youtubeMusic,
            status: .metadataOnly,
            detail: "YouTube Music media downloads are unavailable even when the signed-in account has Premium.",
            cacheDetail: "Only search/library metadata and artwork are stored locally for snappy browsing.",
            filePermissionDetail: "The YouTube Music path does not write audio or video files to disk.",
            allowedKinds: [.metadata, .artwork],
            blockedActions: ["Premium media downloads", "Background audio extraction", "Unofficial media caches"]
        ),
        .init(
            source: .plex,
            status: .planned,
            detail: "Plex offline storage is a future provider-scoped path for media you own or are allowed to store.",
            cacheDetail: "Future Plex metadata/artwork caches must remain separate from media copies.",
            filePermissionDetail: "Future downloads must surface disk, server permission, and sandbox errors per item.",
            allowedKinds: [.metadata, .artwork, .ownedMedia],
            blockedActions: ["Cross-source reuse", "Silent failed downloads"]
        ),
        .init(
            source: .spotify,
            status: .unavailable,
            detail: "Spotify offline downloads are not exposed for third-party app file storage.",
            cacheDetail: "Future Spotify support can store metadata allowed by Spotify API scopes, not audio files.",
            filePermissionDetail: "No Spotify files are written by PhonoDeck.",
            allowedKinds: [.metadata, .artwork],
            blockedActions: ["Spotify audio downloads", "Local Spotify media caches"]
        ),
        .init(
            source: .ownFiles,
            status: .local,
            detail: "Imported files are already user-owned local media and remain available offline when file import lands.",
            cacheDetail: "Local file indexing may create metadata/artwork records without copying unrelated source media.",
            filePermissionDetail: "File access must use user-selected files or folders from the app sandbox entitlement.",
            allowedKinds: [.metadata, .artwork, .ownedMedia],
            blockedActions: ["Treating Own Files as a YouTube download", "Silent permission failures"]
        )
    ]

    static func policy(for source: MediaSourceKind) -> MusicStorageSourcePolicy {
        policies.first { $0.source == source } ?? policies[0]
    }
}

struct MusicStorageSnapshot: Equatable {
    let assets: [MusicStorageAsset]
    let metadataBytes: Int64
    let artworkBytes: Int64
    let blockedMediaAssetCount: Int
    let measuredAt: Date
    let evidenceSource: String
    let measurementStatus: StorageMeasurementStatus
    let measurementIssue: String?

    static let empty = MusicStorageSnapshot(assets: [], metadataBytes: 0, artworkBytes: 0, blockedMediaAssetCount: 0, measuredAt: Date(), evidenceSource: "PhonoDeck local cache", measurementStatus: .complete, measurementIssue: nil)

    var totalBytes: Int64 {
        assets.reduce(0) { $0 + max($1.byteCount, 0) }
    }

    var mediaDownloadBytes: Int64 {
        assets
            .filter { $0.kind == .ownedMedia && $0.status != .local }
            .reduce(0) { $0 + max($1.byteCount, 0) }
    }

    var hasYouTubeMediaDownloads: Bool {
        assets.contains { asset in
            (asset.source == .youtube || asset.source == .youtubeMusic) && asset.kind == .ownedMedia
        }
    }

    static func make(
        artworkBytes: Int64,
        metadataBytes: Int,
        ownedMediaAssets: [MusicStorageAsset] = [],
        measuredAt: Date = Date(),
        evidenceSource: String = "PhonoDeck local cache",
        measurementStatus: StorageMeasurementStatus = .complete,
        measurementIssue: String? = nil
    ) -> MusicStorageSnapshot {
        let safeArtworkBytes = max(artworkBytes, 0)
        let safeMetadataBytes = max(Int64(metadataBytes), 0)
        var assets: [MusicStorageAsset] = []

        if safeMetadataBytes > 0 {
            assets.append(.init(
                id: "youtubeMusic.metadataCache",
                source: .youtubeMusic,
                title: "YouTube Music metadata cache",
                kind: .metadata,
                status: .cached,
                byteCount: safeMetadataBytes,
                localURL: nil,
                sourceURL: nil
            ))
        }

        if safeArtworkBytes > 0 {
            assets.append(.init(
                id: "youtubeMusic.artworkCache",
                source: .youtubeMusic,
                title: "Artwork cache",
                kind: .artwork,
                status: .cached,
                byteCount: safeArtworkBytes,
                localURL: nil,
                sourceURL: nil
            ))
        }

        let allowedOwnedMediaAssets = ownedMediaAssets.filter(Self.allowsOwnedMediaAsset)
        assets.append(contentsOf: allowedOwnedMediaAssets)

        return MusicStorageSnapshot(
            assets: assets,
            metadataBytes: safeMetadataBytes,
            artworkBytes: safeArtworkBytes,
            blockedMediaAssetCount: ownedMediaAssets.count - allowedOwnedMediaAssets.count,
            measuredAt: measuredAt,
            evidenceSource: evidenceSource,
            measurementStatus: measurementStatus,
            measurementIssue: measurementIssue
        )
    }

    private static func allowsOwnedMediaAsset(_ asset: MusicStorageAsset) -> Bool {
        guard asset.kind == .ownedMedia else { return true }
        switch asset.source {
        case .plex, .ownFiles:
            return true
        case .youtube, .youtubeMusic, .spotify:
            return false
        }
    }
}

struct StorageMeasurement: Equatable {
    let bytes: Int64
    let status: StorageMeasurementStatus
    let issue: String?
}

struct StorageCacheClearReceipt: Equatable {
    let target: String
    let completedAt: Date
    let previousBytes: Int64
    let retainedData: String
}