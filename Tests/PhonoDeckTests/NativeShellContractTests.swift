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

    func testContentHeaderDoesNotRepeatWindowTitle() throws {
        let surfaceSource = try String(contentsOf: repoRoot().appendingPathComponent("Sources/PhonoDeck/Features/YouTubeMusic/YouTubeMusicNativeConceptView.swift"), encoding: .utf8)
        XCTAssertTrue(surfaceSource.contains("Label(windowTitle, systemImage: currentSection.symbolName)"))
        XCTAssertFalse(surfaceSource.contains("Text(sectionTitle)"))
        XCTAssertFalse(surfaceSource.contains("breadcrumbTrail\n                    Text(sectionSubtitle)"))
        XCTAssertFalse(surfaceSource.contains("Text(sectionSubtitle)\n                        .font(.callout)"))
    }

    func testLibraryDoesNotMixSignedOutAndConnectedCopy() throws {
        let surfaceSource = try String(contentsOf: repoRoot().appendingPathComponent("Sources/PhonoDeck/Features/YouTubeMusic/YouTubeMusicNativeConceptView.swift"), encoding: .utf8)
        XCTAssertTrue(surfaceSource.contains("shouldShowInlineStatus"))
        XCTAssertTrue(surfaceSource.contains("YouTube Music is signed out"))
        XCTAssertFalse(surfaceSource.contains("Connected account data and PhonoDeck history are ready"))
        XCTAssertTrue(surfaceSource.contains("accountViewModel.state.canDisconnect, !searchViewModel.playlists.isEmpty"))
    }

    func testLibraryPlaylistCardLoadsBeforeNavigatingToPlaylistScreen() throws {
        let surfaceSource = try String(contentsOf: repoRoot().appendingPathComponent("Sources/PhonoDeck/Features/YouTubeMusic/YouTubeMusicNativeConceptView.swift"), encoding: .utf8)
        XCTAssertTrue(surfaceSource.contains("openLibraryPlaylist(playlist)"))
        XCTAssertTrue(surfaceSource.contains("await searchViewModel.selectPlaylist(playlist)"))
        XCTAssertTrue(surfaceSource.contains("appState.open(.playlists)"))
        XCTAssertFalse(surfaceSource.contains("appState.open(.playlists)\n                            Task"))
    }

    func testPlaylistsKeepRightPanelAndFocusedHero() throws {
        let surfaceSource = try String(contentsOf: repoRoot().appendingPathComponent("Sources/PhonoDeck/Features/YouTubeMusic/YouTubeMusicNativeConceptView.swift"), encoding: .utf8)
        XCTAssertTrue(surfaceSource.contains("currentSection == .playlists || searchViewModel.selectedVideo != nil"))
        XCTAssertTrue(surfaceSource.contains("Choose another playlist below"))
        XCTAssertTrue(surfaceSource.contains("Label(\"Up Next\", systemImage: \"list.bullet\")"))
        XCTAssertTrue(surfaceSource.contains("Text(selectedPlaylist.snippet.title)"))
    }

    func testGlobalSearchOpensSearchScreenBeforeRunningQuery() throws {
        let surfaceSource = try String(contentsOf: repoRoot().appendingPathComponent("Sources/PhonoDeck/Features/YouTubeMusic/YouTubeMusicNativeConceptView.swift"), encoding: .utf8)
        XCTAssertTrue(surfaceSource.contains("if currentSection != .search"))
        XCTAssertTrue(surfaceSource.contains("appState.open(.search)"))
        XCTAssertTrue(surfaceSource.contains("await searchViewModel.search(trimmedQuery"))
    }

    func testPlaylistEmptyStateExplainsSelectedPlaylistFailures() throws {
        let surfaceSource = try String(contentsOf: repoRoot().appendingPathComponent("Sources/PhonoDeck/Features/YouTubeMusic/YouTubeMusicNativeConceptView.swift"), encoding: .utf8)
        XCTAssertTrue(surfaceSource.contains("No Playable Playlist Songs"))
        XCTAssertTrue(surfaceSource.contains("Private, deleted, or unavailable rows are skipped."))
        XCTAssertTrue(surfaceSource.contains("searchViewModel.selectedPlaylist != nil, !searchViewModel.status.isEmpty"))
        XCTAssertTrue(surfaceSource.contains("playlistLoadSummary"))
    }

    func testLibraryLoadsConnectedSourceSnapshots() throws {
        let surfaceSource = try String(contentsOf: repoRoot().appendingPathComponent("Sources/PhonoDeck/Features/YouTubeMusic/YouTubeMusicNativeConceptView.swift"), encoding: .utf8)
        XCTAssertTrue(surfaceSource.contains("loadConnectedSourceLibraries()"))
        XCTAssertTrue(surfaceSource.contains("adapter.librarySnapshot()"))
        XCTAssertTrue(surfaceSource.contains("sourceLibraryTracks"))
        XCTAssertTrue(surfaceSource.contains("sourceLibraryPlaylists"))
        XCTAssertTrue(surfaceSource.contains("MusicTrackShelf("))
    }

    func testAlbumsAndArtistsCanRenderNativeSourceTracks() throws {
        let surfaceSource = try String(contentsOf: repoRoot().appendingPathComponent("Sources/PhonoDeck/Features/YouTubeMusic/YouTubeMusicNativeConceptView.swift"), encoding: .utf8)
        XCTAssertTrue(surfaceSource.contains("albumTracks(for:"))
        XCTAssertTrue(surfaceSource.contains("artistTracks(for:"))
        XCTAssertTrue(surfaceSource.contains("MusicTrackCollectionDetailPanel("))
        XCTAssertTrue(surfaceSource.contains("appState.playback.replaceQueue(with: queue"))
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
