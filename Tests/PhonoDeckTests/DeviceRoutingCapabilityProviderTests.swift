import XCTest
@testable import PhonoDeck

final class DeviceRoutingCapabilityProviderTests: XCTestCase {
    func testStaticProviderDocumentsYouTubeAndHomeLimitations() {
        let capabilities = StaticDeviceRoutingCapabilityProvider().capabilities()
        let titles = capabilities.map(\.title)

        XCTAssertTrue(titles.contains("YouTube Playback Route"))
        XCTAssertTrue(titles.contains("Home App / HomePod Music Service"))
        XCTAssertTrue(titles.contains("Cross-device History"))
        XCTAssertTrue(titles.contains("YouTube Subscription Tier"))
        XCTAssertTrue(capabilities.first { $0.id == "youtube-player-route" }?.detail.contains("cannot force YouTube audio") == true)
        XCTAssertTrue(capabilities.first { $0.id == "home-service" }?.detail.contains("does not expose") == true)
    }
}