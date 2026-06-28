import AppKit
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                if appState.isTopSearchVisible {
                    topSearchBar
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
        .frame(minWidth: DesignTokens.contentMinWidth + 360, minHeight: 640)
        .toolbar {
            ToolbarItem(placement: .principal) {
                topNavigationBar
            }

            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: toggleNowPlayingDrawer) {
                    Image(systemName: "sidebar.trailing")
                }
                .disabled(!appState.canCollapseNowPlayingDrawer && appState.isNowPlayingDrawerVisible)
                .help(appState.canCollapseNowPlayingDrawer ? "Show or hide Now Playing" : "Now Playing stays visible while YouTube is playing")

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
            }
        }
    }

    private var topNavigationBar: some View {
        HStack(spacing: DesignTokens.standardSpacing) {
            HStack(spacing: 8) {
                Image(systemName: "music.note.house")
                    .foregroundStyle(Color.accentColor)
                Text("PhonoDeck")
                    .font(.headline.weight(.semibold))
            }
            .padding(.trailing, DesignTokens.compactSpacing)

            HStack(spacing: 3) {
                ForEach(topNavigationSections) { section in
                    Button {
                        appState.open(section)
                    } label: {
                        Text(topNavigationTitle(for: section))
                            .font(.callout.weight(.semibold))
                            .padding(.horizontal, 13)
                            .padding(.vertical, 7)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(isTopNavigationSelected(section) ? Color.primary : Color.secondary)
                    .background(isTopNavigationSelected(section) ? Color.secondary.opacity(0.14) : Color.clear, in: Capsule())
                    .help(section.title)
                }

                Button {
                    appState.toggleTopSearch()
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.title3.weight(.medium))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .foregroundStyle(appState.isTopSearchVisible ? Color.primary : Color.secondary)
                .background(appState.isTopSearchVisible ? Color.secondary.opacity(0.14) : Color.clear, in: Circle())
                .help("Search")
            }
            .padding(4)
            .background(.regularMaterial, in: Capsule())
            .overlay {
                Capsule().strokeBorder(.separator.opacity(0.35), lineWidth: 1)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var topSearchBar: some View {
        HStack(spacing: DesignTokens.standardSpacing) {
            Spacer(minLength: 0)
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search songs, artists, playlists", text: $appState.topSearchText)
                    .textFieldStyle(.plain)
                    .frame(minWidth: 320, idealWidth: 520, maxWidth: 680)
                    .onSubmit { appState.submitTopSearch() }
                if !appState.topSearchText.isEmpty {
                    Button {
                        appState.topSearchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help("Clear search")
                }
                Button {
                    appState.submitTopSearch()
                } label: {
                    Image(systemName: "arrow.forward")
                }
                .buttonStyle(.borderless)
                .disabled(appState.topSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(.quaternary, in: Capsule())
            .overlay { Capsule().strokeBorder(.separator.opacity(0.35), lineWidth: 1) }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DesignTokens.comfortableSpacing)
        .padding(.vertical, 9)
        .background(.bar)
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

    private var topNavigationSections: [LibrarySection] {
        [.library, .playlists, .albums, .artists]
    }

    private func isTopNavigationSelected(_ section: LibrarySection) -> Bool {
        let selectedSection = appState.selectedSection ?? .library
        return selectedSection == section || (section == .library && selectedSection == .listenNow)
    }

    private func topNavigationTitle(for section: LibrarySection) -> String {
        switch section {
        case .library: "Home"
        default: section.title
        }
    }

    private func toggleNowPlayingDrawer() {
        appState.toggleNowPlayingDrawer()
    }

    private func openLibrary() {
        appState.open(.library)
    }

}
