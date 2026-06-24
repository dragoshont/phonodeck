import XCTest
@testable import PhonoDeck

@MainActor
final class NativeShellContractTests: XCTestCase {
    func testProviderLabIsNotInDefaultShippingSidebar() throws {
        let sidebarSource = try String(contentsOf: repoRoot().appendingPathComponent("Sources/PhonoDeck/Features/Shell/SidebarView.swift"), encoding: .utf8)
        XCTAssertFalse(sidebarSource.contains("sections: [.devices, .providerLab, .settings]"))
        XCTAssertTrue(sidebarSource.contains("sections: [.devices, .settings]"))
        XCTAssertTrue(sidebarSource.contains("Text(\"PhonoDeck\")"))
    }

    func testDesignMapKeepsProviderLabOutOfSidebar() throws {
        let data = try Data(contentsOf: repoRoot().appendingPathComponent("docs/design/phonodeck-ui-map.json"))
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let navigation = try XCTUnwrap(object["navigation"] as? [String: Any])
        let sections = try XCTUnwrap(navigation["sections"] as? [[String: Any]])
        let providerLab = try XCTUnwrap(sections.first { $0["case"] as? String == "providerLab" })
        XCTAssertEqual(providerLab["inSidebar"] as? Bool, false)
    }

    func testNowPlayingInspectorTabsMatchDesignContract() {
        XCTAssertEqual(NowPlayingInspectorTab.allCases.map(\.title), ["Now Playing", "Up Next", "Lyrics", "About"])
        XCTAssertEqual(NowPlayingInspectorTab.upNext.symbolName, "list.bullet")
    }

    func testBottomQueueActionTargetsUpNextInspector() throws {
        let rootViewSource = try String(contentsOf: repoRoot().appendingPathComponent("Sources/PhonoDeck/Features/Shell/RootView.swift"), encoding: .utf8)
        let nowPlayingBarSource = try String(contentsOf: repoRoot().appendingPathComponent("Sources/PhonoDeck/Features/Shell/NowPlayingBar.swift"), encoding: .utf8)
        let appCommandsSource = try String(contentsOf: repoRoot().appendingPathComponent("Sources/PhonoDeck/App/PhonoDeckApp.swift"), encoding: .utf8)
        XCTAssertTrue(rootViewSource.contains("openQueue: { appState.openNowPlaying(tab: .upNext) }"))
        XCTAssertTrue(nowPlayingBarSource.contains("Show Up Next"))
        XCTAssertTrue(appCommandsSource.contains("Button(\"Show Up Next\")"))
        XCTAssertFalse(appCommandsSource.contains("Button(\"Show Queue\")"))
    }

    func testVisibleYouTubeEmbedsRemainPlayableInNowPlayingPanel() throws {
        let surfaceSource = try String(contentsOf: repoRoot().appendingPathComponent("Sources/PhonoDeck/Features/YouTubeMusic/YouTubeMusicNativeConceptView.swift"), encoding: .utf8)
        XCTAssertTrue(surfaceSource.contains("visibleWebPlaybackNote(for: selectedVideo)"))
        XCTAssertTrue(surfaceSource.contains("Seeking remains planned"))
        XCTAssertFalse(surfaceSource.contains("Play/Pause and seeking control the visible YouTube player"))
        XCTAssertFalse(surfaceSource.contains("title: \"Playback route unavailable\""))
        XCTAssertFalse(surfaceSource.contains("playbackBlockedState(for: selectedVideo) != nil { return false }"))
    }

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
