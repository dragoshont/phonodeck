import AppKit
import CryptoKit
import OSLog
import SwiftUI

@MainActor
final class ArtworkCache {
    static let shared = ArtworkCache()

    private let memoryCache = NSCache<NSURL, NSImage>()
    private let fileManager: FileManager
    private let cacheDirectory: URL

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let baseDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        cacheDirectory = baseDirectory.appendingPathComponent("PhonoDeck/Artwork", isDirectory: true)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        memoryCache.countLimit = 400
        AppLog.cache.info("Artwork cache initialized at \(self.cacheDirectory.path, privacy: .public)")
    }

    func cachedImage(for url: URL?) -> NSImage? {
        guard let url else { return nil }
        let key = url as NSURL
        if let image = memoryCache.object(forKey: key) {
            AppLog.cache.debug("Artwork memory cache hit for \(RedactedURL.string(url), privacy: .public)")
            return image
        }
        let fileURL = fileURL(for: url)
        guard let image = NSImage(contentsOf: fileURL) else {
            AppLog.cache.debug("Artwork cache miss for \(RedactedURL.string(url), privacy: .public)")
            return nil
        }
        AppLog.cache.debug("Artwork disk cache hit for \(RedactedURL.string(url), privacy: .public)")
        memoryCache.setObject(image, forKey: key)
        return image
    }

    func image(for url: URL?) async -> NSImage? {
        guard let url else { return nil }
        if let image = cachedImage(for: url) {
            return image
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode),
                  let image = NSImage(data: data) else {
                                AppLog.cache.warning("Artwork download returned invalid response for \(RedactedURL.string(url), privacy: .public)")
                return nil
            }
            memoryCache.setObject(image, forKey: url as NSURL)
            try? data.write(to: fileURL(for: url), options: .atomic)
            AppLog.cache.info("Artwork downloaded and cached for \(RedactedURL.string(url), privacy: .public); bytes=\(data.count, privacy: .public)")
            return image
        } catch {
            AppLog.cache.error("Artwork download failed for \(RedactedURL.string(url), privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func clear() {
        let previousBytes = diskUsageBytes()
        memoryCache.removeAllObjects()
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        AppLog.cache.info("Artwork cache cleared; previous bytes=\(previousBytes, privacy: .public)")
    }

    func diskUsageBytes() -> Int64 {
        diskUsageMeasurement().bytes
    }

    func diskUsageMeasurement() -> StorageMeasurement {
        guard let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return StorageMeasurement(bytes: 0, status: .failed, issue: "Could not enumerate artwork cache directory.")
        }
        var total: Int64 = 0
        var skipped = 0
        for case let fileURL as URL in enumerator {
            guard let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
                skipped += 1
                continue
            }
            total += Int64(fileSize)
        }
        if skipped > 0 {
            return StorageMeasurement(bytes: total, status: .partial, issue: "Skipped \(skipped) unreadable artwork cache files.")
        }
        return StorageMeasurement(bytes: total, status: .complete, issue: nil)
    }

    private func fileURL(for url: URL) -> URL {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return cacheDirectory.appendingPathComponent(digest).appendingPathExtension("img")
    }
}

struct CachedArtworkImage<Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let placeholder: () -> Placeholder
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            image = ArtworkCache.shared.cachedImage(for: url)
            guard image == nil else { return }
            image = await ArtworkCache.shared.image(for: url)
        }
    }
}