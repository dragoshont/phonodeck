import Foundation
import Security
import XCTest
@testable import PhonoDeck

final class SecurityPrivacyTests: XCTestCase {
    func testKeychainSaveQueryUsesWhenUnlockedThisDeviceOnlyAccessibility() {
        let query = KeychainStore.saveQuery(service: "svc", account: "acct", data: Data([1, 2, 3]))

        XCTAssertEqual(query[kSecAttrAccessible as String] as? String, kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)
        XCTAssertEqual(query[kSecAttrService as String] as? String, "svc")
        XCTAssertEqual(query[kSecAttrAccount as String] as? String, "acct")
        XCTAssertEqual(query[kSecClass as String] as? String, kSecClassGenericPassword as String)
    }

    func testRedactedURLRedactsSensitiveQueryNamesCaseInsensitively() {
        let url = URL(string: "https://example.test/callback?X-Plex-Token=abc&client_secret=def&Auth_Token=ghi&safe=value")!
        let redacted = RedactedURL.string(url)

        XCTAssertTrue(redacted.contains("X-Plex-Token=REDACTED"))
        XCTAssertTrue(redacted.contains("client_secret=REDACTED"))
        XCTAssertTrue(redacted.contains("Auth_Token=REDACTED"))
        XCTAssertTrue(redacted.contains("safe=value"))
        XCTAssertFalse(redacted.contains("abc"))
        XCTAssertFalse(redacted.contains("def"))
        XCTAssertFalse(redacted.contains("ghi"))
    }

    func testLocalPrivacyDataStoreClearsYouTubeAuthorizedDefaults() {
        let suiteName = "Phase8PrivacyTests-\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        defer { suite.removePersistentDomain(forName: suiteName) }

        for key in LocalPrivacyDataStore.youtubeAuthorizedCacheKeys {
            suite.set("value", forKey: key)
        }

        let cleared = LocalPrivacyDataStore.clearYouTubeAuthorizedData(defaults: suite)

        XCTAssertEqual(Set(cleared), Set(LocalPrivacyDataStore.youtubeAuthorizedCacheKeys))
        XCTAssertTrue(LocalPrivacyDataStore.youtubeAuthorizedCacheKeys.allSatisfy { suite.object(forKey: $0) == nil })
    }

    func testProductionSourcesDoNotContainPrivateYouTubeMetadataEndpoints() throws {
        let productionSources = repoRoot()
            .appendingPathComponent("Sources")
            .appendingPathComponent("PhonoDeck")
        let forbiddenFragments = [
            "youtube" + "i",
            "music.youtube.com/" + "youtube" + "i",
            "Inner" + "Tube",
            "no-" + "cookie",
            "metadata first, with official YouTube API " + "fallback",
            "official YouTube API " + "fallback",
            "Using official YouTube " + "fallback",
            "YouTube Music metadata did not return enough " + "song results",
            "cached YouTube Music " + "metadata",
            "official-to-" + "experimental",
            "experimental-to-" + "official",
            "risk-" + "labeled"
        ]
        var violations: [String] = []

        let enumerator = FileManager.default.enumerator(at: productionSources, includingPropertiesForKeys: nil)!
        for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
            let contents = try String(contentsOf: fileURL, encoding: .utf8)
            let relativePath = fileURL.path.replacingOccurrences(of: repoRoot().path + "/", with: "")
            for fragment in forbiddenFragments where contents.contains(fragment) || relativePath.contains(fragment) {
                violations.append("\(relativePath): \(fragment)")
            }
        }

        XCTAssertTrue(violations.isEmpty, "Private YouTube metadata endpoint references are not allowed in production sources: \(violations)")
    }

    func testGoogleOAuthScopesMatchCurrentFeatureSet() {
        XCTAssertEqual(GoogleOAuthConfiguration.currentFeatureScopes, ["https://www.googleapis.com/auth/youtube"])
    }

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}