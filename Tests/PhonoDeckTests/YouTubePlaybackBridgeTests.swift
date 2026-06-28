import XCTest
@testable import PhonoDeck

@MainActor
final class YouTubePlaybackBridgeTests: XCTestCase {
    func testCommandsDoNotFireBeforePlayerIsReady() {
        let bridge = YouTubePlaybackBridge()
        var previousCount = 0
        var nextCount = 0
        var playPauseCount = 0
        var muteCount = 0
        var volumeValues: [Double] = []
        var seekValues: [Double] = []
        bridge.setHandlers(
            previous: { previousCount += 1 },
            next: { nextCount += 1 },
            playPause: { playPauseCount += 1 },
            mute: { muteCount += 1 },
            volume: { volumeValues.append($0) },
            seek: { seekValues.append($0) }
        )

        bridge.update(playerState: .idle, volume: 100, isMuted: false, currentTime: 0, duration: 0)
        bridge.previous()
        bridge.next()
        bridge.playPause()
        bridge.toggleMute()
        bridge.setVolume(50)
        bridge.seek(to: 42)

        XCTAssertEqual(previousCount, 0)
        XCTAssertEqual(nextCount, 0)
        XCTAssertEqual(playPauseCount, 0)
        XCTAssertEqual(muteCount, 0)
        XCTAssertTrue(volumeValues.isEmpty)
        XCTAssertTrue(seekValues.isEmpty)
    }

    func testCommandsFireWhenPlayerIsReady() {
        let bridge = YouTubePlaybackBridge()
        var previousCount = 0
        var nextCount = 0
        var playPauseCount = 0
        var muteCount = 0
        var volumeValues: [Double] = []
        var seekValues: [Double] = []
        bridge.setHandlers(
            previous: { previousCount += 1 },
            next: { nextCount += 1 },
            playPause: { playPauseCount += 1 },
            mute: { muteCount += 1 },
            volume: { volumeValues.append($0) },
            seek: { seekValues.append($0) }
        )

        bridge.update(playerState: .ready, volume: 100, isMuted: false, currentTime: 0, duration: 120, canPlayPrevious: true, canPlayNext: true)
        bridge.previous()
        bridge.next()
        bridge.playPause()
        bridge.toggleMute()
        bridge.setVolume(50)
        bridge.seek(to: 75)

        XCTAssertEqual(previousCount, 1)
        XCTAssertEqual(nextCount, 1)
        XCTAssertEqual(playPauseCount, 1)
        XCTAssertEqual(muteCount, 1)
        XCTAssertEqual(volumeValues, [50])
        XCTAssertEqual(seekValues, [75])
    }

    func testSeekClampsToDuration() {
        let bridge = YouTubePlaybackBridge()
        var seekValues: [Double] = []
        bridge.setHandlers(
            previous: {},
            next: {},
            playPause: {},
            mute: {},
            volume: { _ in },
            seek: { seekValues.append($0) }
        )

        bridge.update(playerState: .ready, volume: 100, isMuted: false, currentTime: 0, duration: 120)
        bridge.seek(to: 200)
        bridge.seek(to: -10)

        XCTAssertEqual(seekValues, [120, 0])
    }

    func testPreviousNextDoNotFireWithoutAdjacentQueueItems() {
        let bridge = YouTubePlaybackBridge()
        var previousCount = 0
        var nextCount = 0
        bridge.setHandlers(
            previous: { previousCount += 1 },
            next: { nextCount += 1 },
            playPause: {},
            mute: {},
            volume: { _ in },
            seek: { _ in }
        )

        bridge.update(playerState: .ready, volume: 100, isMuted: false, currentTime: 0, duration: 0, canPlayPrevious: false, canPlayNext: false)
        bridge.previous()
        bridge.next()

        XCTAssertEqual(previousCount, 0)
        XCTAssertEqual(nextCount, 0)
    }

    func testResetClearsPlaybackStateForFreshSignOut() {
        let bridge = YouTubePlaybackBridge()
        bridge.update(playerState: .playing, volume: 42, isMuted: true, currentTime: 12, duration: 120)

        bridge.reset()

        XCTAssertEqual(bridge.playerState, .idle)
        XCTAssertEqual(bridge.volume, 100)
        XCTAssertFalse(bridge.isMuted)
        XCTAssertEqual(bridge.currentTime, 0)
        XCTAssertEqual(bridge.duration, 0)
        XCTAssertFalse(bridge.canPlayPrevious)
        XCTAssertFalse(bridge.canPlayNext)
    }
}