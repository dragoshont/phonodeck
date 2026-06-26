import XCTest
@testable import PhonoDeck

@MainActor
final class YouTubePlaybackBridgeTests: XCTestCase {
    func testCommandsDoNotFireBeforePlayerIsReady() {
        let bridge = YouTubePlaybackBridge()
        var playPauseCount = 0
        var muteCount = 0
        var volumeValues: [Double] = []
        bridge.setHandlers(
            playPause: { playPauseCount += 1 },
            mute: { muteCount += 1 },
            volume: { volumeValues.append($0) }
        )

        bridge.update(canPlayPrevious: false, canPlayNext: false, playerState: .idle, volume: 100, isMuted: false, currentTime: 0, duration: 0)
        bridge.playPause()
        bridge.toggleMute()
        bridge.setVolume(50)

        XCTAssertEqual(playPauseCount, 0)
        XCTAssertEqual(muteCount, 0)
        XCTAssertTrue(volumeValues.isEmpty)
    }

    func testCommandsFireWhenPlayerIsReady() {
        let bridge = YouTubePlaybackBridge()
        var playPauseCount = 0
        var muteCount = 0
        var volumeValues: [Double] = []
        bridge.setHandlers(
            playPause: { playPauseCount += 1 },
            mute: { muteCount += 1 },
            volume: { volumeValues.append($0) }
        )

        bridge.update(canPlayPrevious: false, canPlayNext: false, playerState: .ready, volume: 100, isMuted: false, currentTime: 0, duration: 0)
        bridge.playPause()
        bridge.toggleMute()
        bridge.setVolume(50)

        XCTAssertEqual(playPauseCount, 1)
        XCTAssertEqual(muteCount, 1)
        XCTAssertEqual(volumeValues, [50])
    }

    func testResetClearsPlaybackStateForFreshSignOut() {
        let bridge = YouTubePlaybackBridge()
        bridge.update(canPlayPrevious: true, canPlayNext: true, playerState: .playing, volume: 42, isMuted: true, currentTime: 12, duration: 120)

        bridge.reset()

        XCTAssertFalse(bridge.canPlayPrevious)
        XCTAssertFalse(bridge.canPlayNext)
        XCTAssertEqual(bridge.playerState, .idle)
        XCTAssertEqual(bridge.volume, 100)
        XCTAssertFalse(bridge.isMuted)
        XCTAssertEqual(bridge.currentTime, 0)
        XCTAssertEqual(bridge.duration, 0)
    }
}