import SwiftUI

@main
struct PhonoDeckApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
        .commands {
            PlaybackCommands(appState: appState)
        }
    }
}

struct PlaybackCommands: Commands {
    let appState: AppState

    var body: some Commands {
        CommandMenu("Playback") {
            Button("Play/Pause") {
                appState.playback.togglePlayPause()
            }
            .keyboardShortcut(.space, modifiers: [])

            Button("Next Track") {
                appState.playback.nextTrack()
            }
            .keyboardShortcut(.rightArrow, modifiers: [.command])

            Button("Previous Track") {
                appState.playback.previousTrack()
            }
            .keyboardShortcut(.leftArrow, modifiers: [.command])
        }
    }
}
