import AppKit
import OSLog
import SwiftUI

@main
struct PhonoDeckApp: App {
    @NSApplicationDelegateAdaptor(PhonoDeckAppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
        .commands {
            NavigationCommands(appState: appState)
            PhonoDeckViewCommands(appState: appState)
            PlaybackCommands(appState: appState)
        }
    }
}

@MainActor
final class PhonoDeckAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppLog.app.info("Application did finish launching")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            Self.openWindowIfNeeded()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        AppLog.app.info("Application reopen requested; has visible windows=\(flag.description, privacy: .public)")
        if !flag {
            Self.openWindowIfNeeded()
        }
        return true
    }

    private static func openWindowIfNeeded() {
        PhonoDeckWindowManager.shared.openWindowIfNeeded()
    }
}

@MainActor
final class PhonoDeckWindowManager {
    static let shared = PhonoDeckWindowManager()

    private var fallbackWindow: NSWindow?

    func openWindowIfNeeded() {
        let hasVisibleContentWindow = NSApp.windows.contains { window in
            window.isVisible && !window.isMiniaturized && window.canBecomeMain
        }
        guard !hasVisibleContentWindow else {
            AppLog.app.info("Window restore check found visible content window; no fallback needed")
            return
        }

        AppLog.app.info("No visible content window found; opening fallback window")

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1400, height: 900),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Music"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: RootView().environmentObject(AppState.shared))
        fallbackWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

struct NavigationCommands: Commands {
    let appState: AppState

    var body: some Commands {
        CommandMenu("Navigate") {
            Button("Library") {
                appState.open(.library)
            }
            .keyboardShortcut("1", modifiers: [.command])

            Button("Playlists") {
                appState.open(.playlists)
            }
            .keyboardShortcut("2", modifiers: [.command])

            Button("Albums") {
                appState.open(.albums)
            }
            .keyboardShortcut("3", modifiers: [.command])

            Button("Artists") {
                appState.open(.artists)
            }
            .keyboardShortcut("4", modifiers: [.command])

            Button("Queue") {
                appState.open(.queue)
            }
            .keyboardShortcut("5", modifiers: [.command])

            Button("Search") {
                appState.open(.search)
            }
            .keyboardShortcut("f", modifiers: [.command])

            Button("Settings") {
                appState.open(.settings)
            }
            .keyboardShortcut(",", modifiers: [.command])
        }
    }
}

struct PlaybackCommands: Commands {
    let appState: AppState

    private var shouldUseNativeSession: Bool {
        appState.playback.ownsSystemNowPlaying || appState.playback.routeDecision?.engine == .nativeAV
    }

    private var canPlayPause: Bool {
        if shouldUseNativeSession || !appState.activeSource.isYouTubePlayerBacked {
            return appState.playback.queueSnapshot.currentItem != nil
        }
        return appState.youtubeNowPlaying != nil && appState.youtubePlayback.playerState.acceptsCommands
    }

    var body: some Commands {
        CommandMenu("Playback") {
            Button("Play/Pause") {
                if shouldUseNativeSession || !appState.activeSource.isYouTubePlayerBacked {
                    appState.playback.togglePlayPause()
                } else {
                    appState.youtubePlayback.playPause()
                }
            }
            .keyboardShortcut(.space, modifiers: [])
            .disabled(!canPlayPause)

            Button("Next Track") {
                appState.playback.nextTrack()
            }
            .keyboardShortcut(.rightArrow, modifiers: [.command])
            .disabled(appState.activeSource.isYouTubePlayerBacked || appState.playback.queueSnapshot.currentIndex == nil)

            Button("Previous Track") {
                appState.playback.previousTrack()
            }
            .keyboardShortcut(.leftArrow, modifiers: [.command])
            .disabled(appState.activeSource.isYouTubePlayerBacked || appState.playback.queueSnapshot.currentIndex == nil)
        }
    }
}

struct PhonoDeckViewCommands: Commands {
    let appState: AppState

    var body: some Commands {
        CommandMenu("View") {
            Button(appState.isSidebarVisible ? "Hide Sidebar" : "Show Sidebar") {
                appState.toggleSidebar()
            }
            .keyboardShortcut("s", modifiers: [.command, .option])

            Divider()

            Button("Show Up Next") {
                appState.openNowPlaying(tab: .upNext)
            }
            .keyboardShortcut("u", modifiers: [.command, .option])

            Button("Show Settings") {
                appState.open(.settings)
            }
            .keyboardShortcut(",", modifiers: [.command])
        }
    }
}
