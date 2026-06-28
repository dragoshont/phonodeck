import Foundation
import OSLog

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    private static let selectedSectionDefaultsKey = "selectedSection"

    @Published var selectedSection: LibrarySection? = AppState.loadSelectedSection() {
        didSet {
            UserDefaults.standard.set(selectedSection?.rawValue, forKey: Self.selectedSectionDefaultsKey)
            AppLog.app.info("Selected section changed to \(self.selectedSection?.rawValue ?? "none", privacy: .public)")
        }
    }
    @Published var activeSource: MediaSourceKind = .youtubeMusic {
        didSet {
            playback.refreshRemoteCommandAvailability()
            AppLog.app.info("Active source changed to \(String(describing: self.activeSource), privacy: .public); native playback owns remote commands=\(self.playback.ownsSystemNowPlaying.description, privacy: .public)")
        }
    }
    @Published var youtubeNowPlaying: YouTubeVideoSearchResult? {
        didSet {
            AppLog.playback.info("App now-playing changed; id=\(self.youtubeNowPlaying?.id ?? "none", privacy: .public), title=\(self.youtubeNowPlaying?.title ?? "none", privacy: .private)")
        }
    }
    @Published var isSidebarVisible = true
    @Published var isTopSearchVisible = false
    @Published var topSearchText = ""
    @Published var submittedTopSearchQuery: String?
    @Published var isNowPlayingDrawerVisible: Bool = UserDefaults.standard.object(forKey: "isNowPlayingDrawerVisible") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(isNowPlayingDrawerVisible, forKey: "isNowPlayingDrawerVisible")
            AppLog.app.info("Now Playing drawer visibility changed; visible=\(self.isNowPlayingDrawerVisible.description, privacy: .public)")
        }
    }
    @Published var selectedNowPlayingInspectorTab: NowPlayingInspectorTab = .now

    let playback = PlaybackCoordinator()
    let youtubePlayback = YouTubePlaybackBridge()
    let sources: [MediaSourceDescriptor] = MediaSourceKind.allCases.map(\.descriptor)

    /// The pluggable source-adapter layer (account + catalog + playback policy),
    /// and the router that maps a playback plan to the right engine. These are the
    /// portable, source-agnostic foundation Spotify/Plex and every screen build on.
    let sourceRegistry = SourceRegistry.makeDefault()
    let playbackRouter = PlaybackRouter()

    init() {
        playback.refreshRemoteCommandAvailability()
        AppLog.app.info("AppState initialized; selected section=\(self.selectedSection?.rawValue ?? "none", privacy: .public); active source=\(String(describing: self.activeSource), privacy: .public)")
    }

    func open(_ section: LibrarySection) {
        AppLog.app.info("Opening section \(section.rawValue, privacy: .public)")
        activeSource = .youtubeMusic
        selectedSection = section
    }

    func toggleSidebar() {
        isSidebarVisible.toggle()
        AppLog.app.info("Sidebar visibility changed; visible=\(self.isSidebarVisible.description, privacy: .public)")
    }

    func toggleTopSearch() {
        isTopSearchVisible.toggle()
        AppLog.app.info("Top search visibility changed; visible=\(self.isTopSearchVisible.description, privacy: .public)")
    }

    func submitTopSearch() {
        let query = topSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        isTopSearchVisible = true
        selectedSection = .search
        submittedTopSearchQuery = query
        AppLog.search.info("Top search submitted; query=\(query, privacy: .private)")
    }

    func toggleNowPlayingDrawer() {
        guard canCollapseNowPlayingDrawer else {
            isNowPlayingDrawerVisible = true
            AppLog.app.info("Now Playing drawer collapse ignored while YouTube playback is active")
            return
        }
        isNowPlayingDrawerVisible.toggle()
    }

    var canCollapseNowPlayingDrawer: Bool {
        !(activeSource.isYouTubePlayerBacked && youtubeNowPlaying != nil)
    }

    func openNowPlaying(tab: NowPlayingInspectorTab) {
        isNowPlayingDrawerVisible = true
        selectedNowPlayingInspectorTab = tab
        AppLog.playback.info("Opening Now Playing inspector tab \(tab.rawValue, privacy: .public)")
    }

    private static func loadSelectedSection() -> LibrarySection {
        guard let rawValue = UserDefaults.standard.string(forKey: selectedSectionDefaultsKey),
              let section = LibrarySection(rawValue: rawValue) else {
            AppLog.app.info("No valid saved section; defaulting to library")
            return .library
        }
        if section.isHiddenPrimaryNavigationSection {
            AppLog.app.info("Saved hidden section replaced with Library")
            return .library
        }
        AppLog.app.info("Loaded saved section \(section.rawValue, privacy: .public)")
        return section
    }
}

enum LibrarySection: String, CaseIterable, Identifiable, Hashable {
    case listenNow
    case library
    case albums
    case artists
    case playlists
    case queue
    case search
    case downloads
    case devices
    case providerLab
    case settings

    var id: String { rawValue }

    var isHiddenPrimaryNavigationSection: Bool {
        switch self {
        case .listenNow, .queue, .downloads, .devices, .providerLab, .settings:
            true
        case .library, .albums, .artists, .playlists, .search:
            false
        }
    }

    var title: String {
        switch self {
        case .listenNow: "Listen Now"
        case .library: "Library"
        case .albums: "Albums"
        case .artists: "Artists"
        case .playlists: "Playlists"
        case .queue: "Queue"
        case .search: "Search"
        case .downloads: "Downloads"
        case .devices: "Devices"
        case .providerLab: "Provider Lab"
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
        case .queue: "list.bullet"
        case .search: "magnifyingglass"
        case .downloads: "arrow.down.circle"
        case .devices: "airplayaudio"
        case .providerLab: "testtube.2"
        case .settings: "gearshape"
        }
    }
}

enum NowPlayingInspectorTab: String, CaseIterable, Identifiable, Hashable {
    case now
    case upNext
    case lyrics
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .now: "Now Playing"
        case .upNext: "Up Next"
        case .lyrics: "Lyrics"
        case .about: "About"
        }
    }

    var symbolName: String {
        switch self {
        case .now: "play.rectangle"
        case .upNext: "list.bullet"
        case .lyrics: "quote.bubble"
        case .about: "info.circle"
        }
    }
}
