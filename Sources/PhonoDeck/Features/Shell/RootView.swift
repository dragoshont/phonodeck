import AppKit
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack(alignment: .bottom) {
            HStack(spacing: 0) {
                if appState.isSidebarVisible {
                    SidebarView(selection: $appState.selectedSection)
                        .frame(width: DesignTokens.sidebarMinWidth)
                    Divider()
                }

                detailView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if shouldShowNowPlayingBar {
                NowPlayingBar(
                    activeSource: appState.activeSource,
                    playback: appState.playback,
                    youtubeNowPlaying: appState.youtubeNowPlaying,
                    youtubePlayback: appState.youtubePlayback,
                    openQueue: { appState.openNowPlaying(tab: .upNext) }
                )
                .padding(.horizontal, DesignTokens.comfortableSpacing)
                .padding(.bottom, 14)
            }
        }
        .frame(minWidth: DesignTokens.sidebarMinWidth + DesignTokens.contentMinWidth, minHeight: 640)
        .toolbar {
            ToolbarItemGroup {
                Button(action: toggleSidebar) {
                    Image(systemName: "sidebar.leading")
                }
                .help("Show or hide sidebar")

                Button(action: toggleNowPlayingDrawer) {
                    Image(systemName: "sidebar.trailing")
                }
                .help("Show or hide Now Playing")
            }
            ToolbarItemGroup {
                if let youtubeNowPlaying = appState.youtubeNowPlaying {
                    ShareLink(item: youtubeNowPlaying.watchURL) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .help("Share current YouTube song")
                } else {
                    Button(action: {}) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(true)
                    .help("Select a song to share")
                }
                Button(action: openLibrary) {
                    Image(systemName: "music.note.list")
                }
                .help("Open Library")
                Button(action: openSearch) {
                    Image(systemName: "magnifyingglass")
                }
                .help("Open Search")
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        if appState.activeSource.isYouTubePlayerBacked {
            YouTubeMusicNativeConceptView()
        } else {
            LibraryHomeView(
                section: appState.selectedSection ?? .library,
                sources: appState.sources,
                activeSource: appState.activeSource
            )
        }
    }

    private var shouldShowNowPlayingBar: Bool {
        if appState.activeSource.isYouTubePlayerBacked {
            return appState.youtubeNowPlaying != nil
        }
        return appState.playback.currentTrack != .placeholder || appState.playback.state == .playing
    }

    private func toggleSidebar() {
        appState.toggleSidebar()
    }

    private func toggleNowPlayingDrawer() {
        appState.toggleNowPlayingDrawer()
    }

    private func openSearch() {
        appState.open(.search)
    }

    private func openLibrary() {
        appState.open(.library)
    }

}
