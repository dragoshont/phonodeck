import AppKit
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $appState.selectedSection)
                .navigationSplitViewColumnWidth(min: DesignTokens.sidebarMinWidth, ideal: 250)
        } detail: {
            detailView
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            NowPlayingBar(playback: appState.playback)
        }
        .frame(minWidth: DesignTokens.sidebarMinWidth + DesignTokens.contentMinWidth, minHeight: 640)
        .toolbar {
            ToolbarItemGroup {
                Button(action: toggleSidebar) {
                    Image(systemName: "sidebar.leading")
                }
                .help("Show or hide sidebar")
                Picker("Source", selection: $appState.activeSource) {
                    ForEach(appState.sources) { source in
                        Label(source.displayName, systemImage: source.symbolName)
                            .tag(source.id)
                    }
                }
                .pickerStyle(.menu)
            }
            ToolbarItemGroup {
                Button(action: {}) {
                    Image(systemName: "square.and.arrow.up")
                }
                .help("Share")
                Button(action: {}) {
                    Image(systemName: "magnifyingglass")
                }
                .help("Search")
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        if appState.activeSource == .youtubeMusic {
            YouTubeMusicNativeConceptView()
        } else {
            LibraryHomeView(
                section: appState.selectedSection ?? .listenNow,
                sources: appState.sources,
                activeSource: appState.activeSource
            )
        }
    }

    private func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
    }
}
