import XCTest
@testable import PhonoDeck

@MainActor
final class NativeShellContractTests: XCTestCase {
    func testProviderLabIsNotInDefaultShippingSidebar() throws {
        let sidebarSource = try String(contentsOf: repoRoot().appendingPathComponent("Sources/PhonoDeck/Features/Shell/SidebarView.swift"), encoding: .utf8)
        let rootViewSource = try String(contentsOf: repoRoot().appendingPathComponent("Sources/PhonoDeck/Features/Shell/RootView.swift"), encoding: .utf8)
        XCTAssertFalse(sidebarSource.contains("sections: [.devices, .providerLab, .settings]"))
        XCTAssertFalse(sidebarSource.contains("sections: [.devices, .settings]"))
        XCTAssertFalse(sidebarSource.contains(".downloads"))
        XCTAssertFalse(sidebarSource.contains(".devices"))
        XCTAssertFalse(sidebarSource.contains(".settings"))
        XCTAssertFalse(sidebarSource.contains(".queue"))
        XCTAssertFalse(sidebarSource.contains("sections: [.library, .search]"))
        XCTAssertTrue(sidebarSource.contains("sections: [.library]"))
        XCTAssertFalse(rootViewSource.contains("openSearch()"))
        XCTAssertTrue(rootViewSource.contains("topNavigationBar"))
        XCTAssertTrue(rootViewSource.contains("topSearchBar"))
        XCTAssertTrue(rootViewSource.contains("ToolbarItem(placement: .principal)"))
        XCTAssertTrue(rootViewSource.contains("ToolbarItemGroup(placement: .primaryAction)"))
        XCTAssertFalse(rootViewSource.contains("appState.open(.downloads)"))
        XCTAssertFalse(rootViewSource.contains("appState.open(.devices)"))
        XCTAssertFalse(rootViewSource.contains("appState.open(.settings)"))
        XCTAssertTrue(rootViewSource.contains("appState.toggleTopSearch()"))
        XCTAssertFalse(rootViewSource.contains("SidebarView(selection:"))
        XCTAssertTrue(sidebarSource.contains("Text(\"PhonoDeck\")"))
    }

    func testSidebarUsesCompactTokenWidthAndNoTitlebarSourceBadge() throws {
        let rootViewSource = try String(contentsOf: repoRoot().appendingPathComponent("Sources/PhonoDeck/Features/Shell/RootView.swift"), encoding: .utf8)
        let sidebarSource = try String(contentsOf: repoRoot().appendingPathComponent("Sources/PhonoDeck/Features/Shell/SidebarView.swift"), encoding: .utf8)
        XCTAssertFalse(rootViewSource.contains(".frame(width: DesignTokens.sidebarMinWidth)"))
        XCTAssertTrue(sidebarSource.contains("RoundedRectangle(cornerRadius: 18"))
        XCTAssertTrue(sidebarSource.contains(".strokeBorder(.separator.opacity(0.55)"))
        XCTAssertFalse(rootViewSource.contains("youtubeSourceBadge"))
        XCTAssertFalse(rootViewSource.contains("Label(\"YouTube Music\""))
        XCTAssertTrue(rootViewSource.contains("Select a song to share"))
    }

    func testDesignMapKeepsProviderLabOutOfSidebar() throws {
        let data = try Data(contentsOf: repoRoot().appendingPathComponent("docs/design/phonodeck-ui-map.json"))
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let designTokens = try XCTUnwrap(object["designTokens"] as? [String: Any])
        XCTAssertEqual(designTokens["sidebarRenderedWidth"] as? Int, 0)
        let navigation = try XCTUnwrap(object["navigation"] as? [String: Any])
        let sidebar = try XCTUnwrap(navigation["sidebar"] as? [String: Any])
        XCTAssertEqual(sidebar["renderedWidth"] as? Int, 0)
        let sections = try XCTUnwrap(navigation["sections"] as? [[String: Any]])
        let providerLab = try XCTUnwrap(sections.first { $0["case"] as? String == "providerLab" })
        XCTAssertEqual(providerLab["inSidebar"] as? Bool, false)
        let search = try XCTUnwrap(sections.first { $0["case"] as? String == "search" })
        XCTAssertEqual(search["inSidebar"] as? Bool, false)
        XCTAssertEqual(search["placement"] as? String, "top search field / top navigation menu")
    }

    func testTopSearchStateIsSubmittedThroughAppState() throws {
        let appStateSource = try String(contentsOf: repoRoot().appendingPathComponent("Sources/PhonoDeck/App/AppState.swift"), encoding: .utf8)
        let surfaceSource = try String(contentsOf: repoRoot().appendingPathComponent("Sources/PhonoDeck/Features/YouTubeMusic/YouTubeMusicNativeConceptView.swift"), encoding: .utf8)
        let rootViewSource = try String(contentsOf: repoRoot().appendingPathComponent("Sources/PhonoDeck/Features/Shell/RootView.swift"), encoding: .utf8)
        XCTAssertTrue(appStateSource.contains("isTopSearchVisible"))
        XCTAssertTrue(appStateSource.contains("submittedTopSearchQuery"))
        XCTAssertTrue(appStateSource.contains("func submitTopSearch()"))
        XCTAssertTrue(rootViewSource.contains("Image(systemName: \"magnifyingglass\")"))
        XCTAssertFalse(rootViewSource.contains(".queue, .downloads"))
        XCTAssertFalse(rootViewSource.contains(".downloads, .devices, .settings"))
        XCTAssertTrue(surfaceSource.contains("onChange(of: appState.submittedTopSearchQuery)"))
        XCTAssertTrue(surfaceSource.contains("searchFromUI(query)"))
        XCTAssertFalse(surfaceSource.contains("TextField(\"Search songs, artists, playlists\", text: $searchText)"))
    }

    func testHiddenPrimarySectionsDoNotRestoreOrShowInChrome() throws {
        let appStateSource = try String(contentsOf: repoRoot().appendingPathComponent("Sources/PhonoDeck/App/AppState.swift"), encoding: .utf8)
        let rootViewSource = try String(contentsOf: repoRoot().appendingPathComponent("Sources/PhonoDeck/Features/Shell/RootView.swift"), encoding: .utf8)
        let storybookSource = try String(contentsOf: repoRoot().appendingPathComponent("ui-lab/src/components/PhonoDeck.jsx"), encoding: .utf8)
        XCTAssertTrue(appStateSource.contains("isHiddenPrimaryNavigationSection"))
        XCTAssertTrue(appStateSource.contains(".queue, .downloads, .devices, .providerLab, .settings"))
        XCTAssertTrue(appStateSource.contains("Saved hidden section replaced with Library"))
        XCTAssertFalse(rootViewSource.contains("appState.open(.downloads)"))
        XCTAssertFalse(rootViewSource.contains("appState.open(.devices)"))
        XCTAssertFalse(rootViewSource.contains("appState.open(.settings)"))
        XCTAssertFalse(storybookSource.contains("['downloads', 'Downloads'"))
        XCTAssertFalse(storybookSource.contains("['devices', 'Devices'"))
        XCTAssertFalse(storybookSource.contains("['settings', 'Settings'"))
        XCTAssertFalse(storybookSource.contains("aria-label=\"Settings\""))
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
        XCTAssertTrue(surfaceSource.contains("if accountViewModel.state.canDisconnect {"))
        XCTAssertTrue(surfaceSource.contains("youtubeMusicPlaylistShelf"))
        XCTAssertTrue(surfaceSource.contains("youtubePlaylistShelf"))
    }

    func testHomeSplitsYouTubeMusicAndYouTubePlaylistShelves() throws {
        let surfaceSource = try String(contentsOf: repoRoot().appendingPathComponent("Sources/PhonoDeck/Features/YouTubeMusic/YouTubeMusicNativeConceptView.swift"), encoding: .utf8)
        let storybookSource = try String(contentsOf: repoRoot().appendingPathComponent("ui-lab/src/components/PhonoDeck.jsx"), encoding: .utf8)
        let designMapSource = try String(contentsOf: repoRoot().appendingPathComponent("docs/design/phonodeck-ui-map.json"), encoding: .utf8)
        XCTAssertTrue(surfaceSource.contains("youtubeMusicPlaylistShelf"))
        XCTAssertTrue(surfaceSource.contains("youtubePlaylistShelf"))
        XCTAssertTrue(surfaceSource.contains("title: \"YouTube Music Playlists\""))
        XCTAssertTrue(surfaceSource.contains("title: \"YouTube Playlists\""))
        XCTAssertTrue(surfaceSource.contains("searchViewModel.playlists.filter { playlistSourceKind(for: $0) == .youtubeMusic }"))
        XCTAssertTrue(surfaceSource.contains("searchViewModel.playlists.filter { playlistSourceKind(for: $0) == .youtube }"))
        XCTAssertTrue(surfaceSource.contains("EmptyPlaylistShelf("))
        XCTAssertTrue(surfaceSource.contains("Connect Google to show your"))
        XCTAssertFalse(surfaceSource.contains("Text(\"Your Playlists\")"))
        XCTAssertTrue(storybookSource.contains("function PlaylistShelf"))
        XCTAssertTrue(storybookSource.contains("playlist-empty-card"))
        XCTAssertTrue(storybookSource.contains("YouTube Music Playlists"))
        XCTAssertTrue(storybookSource.contains("YouTube Playlists"))
        XCTAssertFalse(storybookSource.contains("<h3>Your Playlists</h3>"))
        XCTAssertTrue(designMapSource.contains("Do not blend Google playlist surfaces into one generic row on Home"))
    }

    func testVisibleSourcesDoNotExposeHiddenLibrarySources() throws {
        let visibleSources = [
            "Sources/PhonoDeck/Views/MusicServicesSection.swift",
            "Sources/PhonoDeck/Views/ServiceAccountRow.swift",
            "Sources/PhonoDeck/Views/SourcesOverviewView.swift",
            "Sources/PhonoDeck/Features/YouTubeMusic/YouTubeMusicNativeConceptView.swift",
            "ui-lab/src/components/PhonoDeck.jsx",
            "ui-lab/src/phonodeck.css",
            "ui-lab/src/stories/NowPlayingPanel.stories.jsx",
            "ui-lab/src/stories/NowPlayingBar.stories.jsx",
            "ui-lab/src/stories/FullScreenPlayer.stories.jsx",
            "ui-lab/src/stories/Phase5Readiness.stories.jsx",
            "ui-lab/src/stories/Cards.stories.jsx",
            "docs/design/phonodeck-ui-map.json",
            "docs/design/youtube-music-player-experience.md"
        ]

        for relativePath in visibleSources {
            let source = try String(contentsOf: repoRoot().appendingPathComponent(relativePath), encoding: .utf8)
            XCTAssertFalse(source.contains("Own Files"), relativePath)
            XCTAssertFalse(source.localizedCaseInsensitiveContains("local music"), relativePath)
            XCTAssertFalse(source.contains("Local files"), relativePath)
            XCTAssertFalse(source.contains("local files"), relativePath)
            XCTAssertFalse(source.contains("\"Plex\""), relativePath)
            XCTAssertFalse(source.contains("'Plex'"), relativePath)
            XCTAssertFalse(source.contains("Add Plex"), relativePath)
            XCTAssertFalse(source.contains("No Plex"), relativePath)
            XCTAssertFalse(source.contains("Plex "), relativePath)
            XCTAssertFalse(source.contains(" plex"), relativePath)
            XCTAssertFalse(source.contains("src=\"plex\""), relativePath)
            XCTAssertFalse(source.contains("source=\"plex\""), relativePath)
            XCTAssertFalse(source.contains("src: 'plex'"), relativePath)
            XCTAssertFalse(source.localizedCaseInsensitiveContains("native library"), relativePath)
            XCTAssertFalse(source.localizedCaseInsensitiveContains("Apple Music native"), relativePath)
            XCTAssertFalse(source.contains("source === 'own'"), relativePath)
            XCTAssertFalse(source.contains("src: 'own'"), relativePath)
        }
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
        XCTAssertFalse(surfaceSource.contains("currentSection == .playlists || searchViewModel.selectedVideo != nil"))
        XCTAssertTrue(surfaceSource.contains("Choose another playlist below"))
        XCTAssertTrue(surfaceSource.contains("Label(\"Up Next\", systemImage: \"list.bullet\")"))
        XCTAssertTrue(surfaceSource.contains("Text(selectedPlaylist.snippet.title)"))
    }

    func testRightNowPlayingDrawerIsToggleableAndShowsVideoThenQueue() throws {
        let rootViewSource = try String(contentsOf: repoRoot().appendingPathComponent("Sources/PhonoDeck/Features/Shell/RootView.swift"), encoding: .utf8)
        let appStateSource = try String(contentsOf: repoRoot().appendingPathComponent("Sources/PhonoDeck/App/AppState.swift"), encoding: .utf8)
        let surfaceSource = try String(contentsOf: repoRoot().appendingPathComponent("Sources/PhonoDeck/Features/YouTubeMusic/YouTubeMusicNativeConceptView.swift"), encoding: .utf8)

        XCTAssertTrue(rootViewSource.contains("sidebar.trailing"))
        XCTAssertTrue(rootViewSource.contains("Now Playing stays visible while YouTube is playing"))
        XCTAssertTrue(appStateSource.contains("isNowPlayingDrawerVisible"))
        XCTAssertTrue(appStateSource.contains("canCollapseNowPlayingDrawer"))
        XCTAssertTrue(surfaceSource.contains("appState.isNowPlayingDrawerVisible"))
        XCTAssertTrue(surfaceSource.contains("collapsedNowPlayingRail"))
        XCTAssertTrue(surfaceSource.contains("YouTubeMusicWebPlayerView(controller: playerController)"))
        XCTAssertTrue(surfaceSource.contains("shouldKeepYouTubePlayerVisible"))
        XCTAssertFalse(surfaceSource.contains("compactYouTubeMiniPlayer"))
        XCTAssertFalse(surfaceSource.contains(".frame(width: 220, height: 200)"))
        XCTAssertFalse(surfaceSource.contains(".frame(width: 1, height: 1)"))
        XCTAssertTrue(surfaceSource.contains("nowPlayingNowTab"))
        XCTAssertTrue(surfaceSource.contains("upNextPanel"))
    }

    func testBottomBarStaysVisibleWhileYouTubeDrawerIsOpen() throws {
        let rootViewSource = try String(contentsOf: repoRoot().appendingPathComponent("Sources/PhonoDeck/Features/Shell/RootView.swift"), encoding: .utf8)
        let surfaceSource = try String(contentsOf: repoRoot().appendingPathComponent("Sources/PhonoDeck/Features/YouTubeMusic/YouTubeMusicNativeConceptView.swift"), encoding: .utf8)
        XCTAssertTrue(rootViewSource.contains("return appState.youtubeNowPlaying != nil"))
        XCTAssertFalse(rootViewSource.contains("appState.youtubeNowPlaying != nil && !appState.isNowPlayingDrawerVisible"))
        XCTAssertFalse(surfaceSource.contains("playerTransportControls\n\n            if let selectedVideo"))
    }

    func testSongRowSelectionPlaysImmediately() throws {
        let surfaceSource = try String(contentsOf: repoRoot().appendingPathComponent("Sources/PhonoDeck/Features/YouTubeMusic/YouTubeMusicNativeConceptView.swift"), encoding: .utf8)
        XCTAssertTrue(surfaceSource.contains("action: {\n                                    play(result, queue: sectionVideos)"))
        XCTAssertTrue(surfaceSource.contains("appState.openNowPlaying(tab: .now)"))
        XCTAssertTrue(surfaceSource.contains("onChange(of: appState.submittedTopSearchQuery)"))
        XCTAssertTrue(surfaceSource.contains("searchFromUI(query)"))
        XCTAssertTrue(surfaceSource.contains("selectAction: { play($0, queue: librarySongs) }"))
        XCTAssertTrue(surfaceSource.contains("selectAction: { play($0, queue: relatedItems) }"))
        XCTAssertTrue(surfaceSource.contains("Text(result.musicIdentity.artistName)"))
        XCTAssertTrue(surfaceSource.contains("Text(item.musicIdentity.artistName)"))
        XCTAssertFalse(surfaceSource.contains("accessibilityLabel(\"\\(result.title), \\(result.channelTitle), \\(result.songBadge)\")"))
        XCTAssertTrue(surfaceSource.contains("selectAction: { play(item, queue: searchViewModel.queue) }"))
    }

    func testSelectedVideoDoesNotMasqueradeAsNowPlaying() throws {
        let surfaceSource = try String(contentsOf: repoRoot().appendingPathComponent("Sources/PhonoDeck/Features/YouTubeMusic/YouTubeMusicNativeConceptView.swift"), encoding: .utf8)
        XCTAssertFalse(surfaceSource.contains("appState.youtubeNowPlaying = selectedVideo"))
        XCTAssertFalse(surfaceSource.contains("persistLastPlayback(selectedVideo)"))
        XCTAssertFalse(surfaceSource.contains("playerController.load(video: selectedVideo)"))
        XCTAssertTrue(surfaceSource.contains("let nowPlayingSelection = appState.youtubeNowPlaying.map { [$0] } ?? []"))
        XCTAssertFalse(surfaceSource.contains("let currentSelection = searchViewModel.selectedVideo.map { [$0] } ?? []"))
    }

    func testProviderLabLabelsChannelAsEvidence() throws {
        let surfaceSource = try String(contentsOf: repoRoot().appendingPathComponent("Sources/PhonoDeck/Features/YouTubeMusic/YouTubeMusicNativeConceptView.swift"), encoding: .utf8)
        XCTAssertTrue(surfaceSource.contains("Text(\"Channel: \\(item.channelTitle)\")"))
        XCTAssertFalse(surfaceSource.contains("Text(item.channelTitle)"))
    }

    func testLyricsActionsDoNotAutoplay() throws {
        let surfaceSource = try String(contentsOf: repoRoot().appendingPathComponent("Sources/PhonoDeck/Features/YouTubeMusic/YouTubeMusicNativeConceptView.swift"), encoding: .utf8)
        XCTAssertTrue(surfaceSource.contains("lyricsStatus = \"Selected lyric video. Press Play to start it.\""))
        XCTAssertTrue(surfaceSource.contains("lyricsStatus = \"Found a lyric video. Press Play to start it.\""))
        XCTAssertFalse(surfaceSource.contains("play(lyricVideo, queue: searchViewModel.results)"))
    }

    func testYouTubeMusicIdentityDoesNotUseChannelFallbackAsArtist() throws {
        let dataClientSource = try String(contentsOf: repoRoot().appendingPathComponent("Sources/PhonoDeck/Integrations/YouTube/YouTubeDataClient.swift"), encoding: .utf8)
        XCTAssertTrue(dataClientSource.contains("Artist not exposed"))
        XCTAssertTrue(dataClientSource.contains("videoOwnerChannelTitle ?? playlistItem.snippet.channelTitle"))
        XCTAssertTrue(dataClientSource.contains("sourceLabel = \"Music\""))
    }

    func testBottomBarUsesMusicIdentityForYouTubeSubtitle() throws {
        let nowPlayingBarSource = try String(contentsOf: repoRoot().appendingPathComponent("Sources/PhonoDeck/Features/Shell/NowPlayingBar.swift"), encoding: .utf8)
        XCTAssertTrue(nowPlayingBarSource.contains("youtubeNowPlaying.musicIdentity.artistName"))
        XCTAssertFalse(nowPlayingBarSource.contains("return youtubeNowPlaying.channelTitle"))
    }

    func testEndedAutoAdvanceUsesExplicitQueueOnly() throws {
        let surfaceSource = try String(contentsOf: repoRoot().appendingPathComponent("Sources/PhonoDeck/Features/YouTubeMusic/YouTubeMusicNativeConceptView.swift"), encoding: .utf8)
        XCTAssertTrue(surfaceSource.contains("lastObservedPlayerState"))
        XCTAssertTrue(surfaceSource.contains("case .ended where previousPlayerState == .playing"))
        XCTAssertTrue(surfaceSource.contains("handleEmbeddedPlaybackEnded()"))
        XCTAssertTrue(surfaceSource.contains("guard playerController.currentVideoID == appState.youtubeNowPlaying?.id"))
        XCTAssertTrue(surfaceSource.contains("guard searchViewModel.nextQueueItem != nil"))
        XCTAssertTrue(surfaceSource.contains("playNextQueuedVideo()"))
        XCTAssertFalse(surfaceSource.contains("func playNextFromQueue()"))
        XCTAssertFalse(surfaceSource.contains("func playPreviousFromQueue()"))
        let viewModelSource = try String(contentsOf: repoRoot().appendingPathComponent("Sources/PhonoDeck/Features/YouTubeMusic/YouTubeSearchViewModel.swift"), encoding: .utf8)
        XCTAssertFalse(viewModelSource.contains("func playNext()"))
        XCTAssertFalse(viewModelSource.contains("func playPrevious()"))
        XCTAssertFalse(viewModelSource.contains("func skipFailedSelectedVideo"))
    }

    func testYouTubeChromeExposesOnlyQueueAwarePreviousNextNavigation() throws {
        let nowPlayingBarSource = try String(contentsOf: repoRoot().appendingPathComponent("Sources/PhonoDeck/Features/Shell/NowPlayingBar.swift"), encoding: .utf8)
        let surfaceSource = try String(contentsOf: repoRoot().appendingPathComponent("Sources/PhonoDeck/Features/YouTubeMusic/YouTubeMusicNativeConceptView.swift"), encoding: .utf8)
        let bridgeSource = try String(contentsOf: repoRoot().appendingPathComponent("Sources/PhonoDeck/Features/YouTubeMusic/YouTubePlaybackBridge.swift"), encoding: .utf8)

        XCTAssertTrue(nowPlayingBarSource.contains("isYouTubeMode ? youtubePlayback.canPlayPrevious"))
        XCTAssertTrue(nowPlayingBarSource.contains("isYouTubeMode ? youtubePlayback.canPlayNext"))
        XCTAssertTrue(nowPlayingBarSource.contains("isYouTubeMode ? youtubePlayback.previous()"))
        XCTAssertTrue(nowPlayingBarSource.contains("isYouTubeMode ? youtubePlayback.next()"))
        XCTAssertFalse(surfaceSource.contains("previous: { playPreviousFromQueue() }"))
        XCTAssertFalse(surfaceSource.contains("next: { playNextFromQueue() }"))
        XCTAssertFalse(surfaceSource.contains("skipFailedSelectedVideo(reason: message)"))
        XCTAssertTrue(surfaceSource.contains("markSelectedPlaybackFailed(reason: message)"))
        XCTAssertTrue(bridgeSource.contains("canPlayPrevious"))
        XCTAssertTrue(bridgeSource.contains("canPlayNext"))
        XCTAssertTrue(bridgeSource.contains("func previous()"))
        XCTAssertTrue(bridgeSource.contains("func next()"))
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

    func testNowPlayingHeaderDoesNotDuplicateSourceOrAccountControls() throws {
        let surfaceSource = try String(contentsOf: repoRoot().appendingPathComponent("Sources/PhonoDeck/Features/YouTubeMusic/YouTubeMusicNativeConceptView.swift"), encoding: .utf8)
        let headerStart = try XCTUnwrap(surfaceSource.range(of: "private var nowPlayingPanel: some View"))
        let headerEnd = try XCTUnwrap(surfaceSource.range(of: "ScrollView {", range: headerStart.lowerBound..<surfaceSource.endIndex))
        let headerSource = String(surfaceSource[headerStart.lowerBound..<headerEnd.lowerBound])
        XCTAssertFalse(headerSource.contains("sourceBadge"))
        XCTAssertFalse(headerSource.contains("accountMenu"))
        XCTAssertTrue(headerSource.contains("Text(\"Now Playing\")"))
        XCTAssertTrue(headerSource.contains("sidebar.trailing"))
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

    func testMacMenuBarMatchesTopNavigationContract() throws {
        let appCommandsSource = try String(contentsOf: repoRoot().appendingPathComponent("Sources/PhonoDeck/App/PhonoDeckApp.swift"), encoding: .utf8)
        XCTAssertTrue(appCommandsSource.contains("CommandGroup(replacing: .sidebar)"))
        XCTAssertTrue(appCommandsSource.contains("CommandMenu(\"Navigate\")"))
        XCTAssertTrue(appCommandsSource.contains("Button(\"Home\")"))
        XCTAssertTrue(appCommandsSource.contains("appState.isTopSearchVisible = true"))
        XCTAssertTrue(appCommandsSource.contains("CommandGroup(after: .toolbar)"))
        XCTAssertFalse(appCommandsSource.contains("Button(\"Show Settings\")"))
        XCTAssertFalse(appCommandsSource.contains("CommandMenu(\"View\")"))
        XCTAssertFalse(appCommandsSource.contains("Button(\"Library\")"))
        XCTAssertFalse(appCommandsSource.contains("Button(\"Queue\")"))
        XCTAssertFalse(appCommandsSource.contains("appState.open(.search)"))
    }

    func testYouTubePlaybackMenuGatesPreviousNextCommandsByQueueAvailability() throws {
        let appCommandsSource = try String(contentsOf: repoRoot().appendingPathComponent("Sources/PhonoDeck/App/PhonoDeckApp.swift"), encoding: .utf8)
        XCTAssertTrue(appCommandsSource.contains("if shouldUseNativeSession || !appState.activeSource.isYouTubePlayerBacked"))
        XCTAssertTrue(appCommandsSource.contains("appState.youtubePlayback.next()"))
        XCTAssertTrue(appCommandsSource.contains("appState.youtubePlayback.previous()"))
        XCTAssertTrue(appCommandsSource.contains("!appState.youtubePlayback.canPlayNext"))
        XCTAssertTrue(appCommandsSource.contains("!appState.youtubePlayback.canPlayPrevious"))
    }

    func testNativeTrackPlaybackSwitchesActiveSource() throws {
        let surfaceSource = try String(contentsOf: repoRoot().appendingPathComponent("Sources/PhonoDeck/Features/YouTubeMusic/YouTubeMusicNativeConceptView.swift"), encoding: .utf8)
        XCTAssertTrue(surfaceSource.contains("appState.activeSource = result.mediaSourceKind"))
        XCTAssertTrue(surfaceSource.contains("appState.playback.clearQueue()"))
        XCTAssertTrue(surfaceSource.contains("appState.activeSource = track.source"))
    }

    func testQueueCopyDoesNotPromiseYouTubePreviousNextChrome() throws {
        let surfaceSource = try String(contentsOf: repoRoot().appendingPathComponent("Sources/PhonoDeck/Features/YouTubeMusic/YouTubeMusicNativeConceptView.swift"), encoding: .utf8)
        XCTAssertFalse(surfaceSource.contains("queue used by Next, Previous"))
        XCTAssertTrue(surfaceSource.contains("YouTube song changes come from row selection"))
    }

    func testVisibleYouTubeEmbedsRemainPlayableInNowPlayingPanel() throws {
        let surfaceSource = try String(contentsOf: repoRoot().appendingPathComponent("Sources/PhonoDeck/Features/YouTubeMusic/YouTubeMusicNativeConceptView.swift"), encoding: .utf8)
        XCTAssertTrue(surfaceSource.contains("visibleWebPlaybackNote(for: selectedVideo)"))
        XCTAssertTrue(surfaceSource.contains("Visible YouTube player · Play/Pause + progress/seek · no hidden audio"))
        XCTAssertTrue(surfaceSource.contains("hasActiveNowPlayingMedia"))
        XCTAssertTrue(surfaceSource.contains("Choose a song, playlist, album, or artist to start listening."))
        XCTAssertTrue(surfaceSource.contains("Choose something to play"))
        XCTAssertFalse(surfaceSource.contains("Video hidden"))
        XCTAssertTrue(surfaceSource.contains("audio bitrate not exposed"))
        XCTAssertTrue(surfaceSource.contains("nowPlayingSubtitle(for:"))
        XCTAssertTrue(surfaceSource.contains("nowPlayingQualitySummary(for:"))
        XCTAssertFalse(surfaceSource.contains("alwaysVisibleMediaInfo(for:"))
        XCTAssertFalse(surfaceSource.contains("private func alwaysVisibleMediaInfo"))
        XCTAssertTrue(surfaceSource.contains("MusicInfoLine(title: \"Artist\", value: video.musicIdentity.artistName)"))
        XCTAssertTrue(surfaceSource.contains("MusicInfoLine(title: \"YouTube channel\", value: video.channelTitle)"))
        XCTAssertFalse(surfaceSource.contains("MusicInfoLine(title: \"Artist / Channel\", value: video.channelTitle)"))
        XCTAssertFalse(surfaceSource.contains("let label = identity.albumTitle ?? \"Record label not exposed\""))
        XCTAssertFalse(surfaceSource.contains("Play/Pause and seeking control the visible YouTube player"))
        XCTAssertFalse(surfaceSource.contains("title: \"Visible official player\""))
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
