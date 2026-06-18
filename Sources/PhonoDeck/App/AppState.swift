import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var selectedSection: LibrarySection? = .listenNow
    @Published var activeSource: MediaSourceKind = .plex

    let playback = PlaybackCoordinator()
    let sources: [MediaSourceDescriptor] = MediaSourceKind.allCases.map(\.descriptor)
}

enum LibrarySection: String, CaseIterable, Identifiable, Hashable {
    case listenNow
    case library
    case albums
    case artists
    case playlists
    case search
    case downloads
    case devices
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .listenNow: "Listen Now"
        case .library: "Library"
        case .albums: "Albums"
        case .artists: "Artists"
        case .playlists: "Playlists"
        case .search: "Search"
        case .downloads: "Downloads"
        case .devices: "Devices"
        case .settings: "Settings"
        }
    }

    var symbolName: String {
        switch self {
        case .listenNow: "play.circle"
        case .library: "music.note.list"
        case .albums: "square.stack"
        case .artists: "music.mic"
        case .playlists: "text.badge.plus"
        case .search: "magnifyingglass"
        case .downloads: "arrow.down.circle"
        case .devices: "airplayaudio"
        case .settings: "gearshape"
        }
    }
}
