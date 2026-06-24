import XCTest
@testable import PhonoDeck

final class MediaSourceDescriptorTests: XCTestCase {
    func testPrimarySourcesRemainExplicit() {
        XCTAssertEqual(MediaSourceKind.youtube.descriptor.displayName, "YouTube")
        XCTAssertEqual(MediaSourceKind.plex.descriptor.displayName, "Plex")
        XCTAssertEqual(MediaSourceKind.youtubeMusic.descriptor.displayName, "YouTube Music")
        XCTAssertEqual(MediaSourceKind.spotify.descriptor.displayName, "Spotify")
        XCTAssertEqual(MediaSourceKind.ownFiles.descriptor.displayName, "Own Files")
        XCTAssertEqual(MediaSourceKind.ownFiles.rawValue, "localFiles")
    }

    func testYouTubeMusicSourceDocumentsPolicyBoundary() async {
        let source = YouTubeMusicSource()

        do {
            _ = try await source.librarySnapshot()
            XCTFail("YouTube Music library snapshots should not pretend an official native API exists.")
        } catch MediaSourceError.unsupportedByPolicy(let message) {
            XCTAssertTrue(message.contains("official YouTube Music library API"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
