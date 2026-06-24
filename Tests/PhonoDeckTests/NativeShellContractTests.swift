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

    func testSidebarUsesCompactTokenWidthAndNoTitlebarSourceBadge() throws {
        let rootViewSource = try String(contentsOf: repoRoot().appendingPathComponent("Sources/PhonoDeck/Features/Shell/RootView.swift"), encoding: .utf8)
        XCTAssertTrue(rootViewSource.contains(".frame(width: DesignTokens.sidebarMinWidth)"))
        XCTAssertFalse(rootViewSource.contains("youtubeSourceBadge"))
        XCTAssertFalse(rootViewSource.contains("Label(\"YouTube Music\""))
        XCTAssertTrue(rootViewSource.contains("Select a song to share"))
    }

    func testDesignMapKeepsProviderLabOutOfSidebar() throws {
        let data = try Data(contentsOf: repoRoot().appendingPathComponent("docs/design/phonodeck-ui-map.json"))
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let designTokens = try XCTUnwrap(object["designTokens"] as? [String: Any])
        XCTAssertEqual(designTokens["sidebarRenderedWidth"] as? Int, 220)
        let navigation = try XCTUnwrap(object["navigation"] as? [String: Any])
        let sidebar = try XCTUnwrap(navigation["sidebar"] as? [String: Any])
        XCTAssertEqual(sidebar["renderedWidth"] as? Int, 220)
        let sections = try XCTUnwrap(navigation["sections"] as? [[String: Any]])
        let providerLab = try XCTUnwrap(sections.first { $0["case"] as? String == "providerLab" })
        XCTAssertEqual(providerLab["inSidebar"] as? Bool, false)
    }

    func testSignedOutCopyDoesNotPresentYouTubeAsLoadedLibrary() throws {
        let surfaceSource = try String(contentsOf: repoRoot().appendingPathComponent("Sources/PhonoDeck/Features/YouTubeMusic/YouTubeMusicNativeConceptView.swift"), encoding: .utf8)
        XCTAssertTrue(surfaceSource.contains("Connect a music source to start building your library."))
        XCTAssertTrue(surfaceSource.contains("Connect Google to Load Playlists"))
        XCTAssertTrue(surfaceSource.contains("Connect Google to search official music and video results."))
        XCTAssertTrue(surfaceSource.contains("Connect your music services to build a single library across supported sources."))
        XCTAssertFalse(surfaceSource.contains("YouTube Music songs, playlists, cached metadata, and connected source status in one place."))
        XCTAssertFalse(surfaceSource.contains("Your YouTube Music playlist surface"))
    }

    func testLibraryPlaylistCardLoadsBeforeNavigatingToPlaylistScreen() throws {
        let surfaceSource = try String(contentsOf: repoRoot().appendingPathComponent("Sources/PhonoDeck/Features/YouTubeMusic/YouTubeMusicNativeConceptView.swift"), encoding: .utf8)
        XCTAssertTrue(surfaceSource.contains("openLibraryPlaylist(playlist)"))
        XCTAssertTrue(surfaceSource.contains("await searchViewModel.selectPlaylist(playlist)"))
        XCTAssertTrue(surfaceSource.contains("appState.open(.playlists)"))
        XCTAssertFalse(surfaceSource.contains("appState.open(.playlists)\n                            Task"))
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
