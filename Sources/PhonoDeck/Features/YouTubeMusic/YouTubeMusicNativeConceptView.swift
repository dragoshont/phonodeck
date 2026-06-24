import AppKit
import AVKit
import OSLog
import SwiftUI

struct YouTubeMusicNativeConceptView: View {
    @EnvironmentObject private var appState: AppState
    @State private var searchText = ""
    @State private var didRunInitialSearch = false
    @State private var lastProviderLabQuery = ""
    @State private var inspectorMode: YouTubeInspectorMode?
    @State private var selectedAlbumID: MusicProviderEntityID?
    @State private var selectedArtistID: MusicProviderEntityID?
    @State private var lyricsStatus = ""
    @State private var albumFilterText = ""
    @State private var albumSortRaw = "artist"
    @State private var artistFilterText = ""
    @State private var artistSortRaw = "name"
    @State private var playlistFilterText = ""
    @State private var playlistSortRaw = "dateAdded"
    @AppStorage("youtubePlaybackPreference") private var playbackPreferenceRaw = YouTubePlaybackPreference.songFirst.rawValue
    @AppStorage("youtubeMusicEngine") private var musicEngineRaw = YouTubeMusicEngine.automatic.rawValue
    @AppStorage("youtubeLastVideoID") private var lastVideoID = ""
    @AppStorage("youtubeLastVideoTitle") private var lastVideoTitle = ""
    @AppStorage("youtubeLastVideoChannel") private var lastVideoChannel = ""
    @AppStorage("youtubeLastVideoThumbnailURL") private var lastVideoThumbnailURL = ""
    @AppStorage("youtubeRecentSearches") private var recentSearchesRaw = ""
    @AppStorage("youtubeLocalPlayedSeconds") private var localPlayedSeconds = 0.0
    @AppStorage("hasSeenPhonoDeckWelcome") private var hasSeenPhonoDeckWelcome = false
    @State private var artworkCacheBytes: Int64 = 0
    @State private var storageSnapshot = MusicStorageSnapshot.empty
    @State private var storageStatusMessage = ""
    @State private var storageClearReceipt: StorageCacheClearReceipt?
    @State private var pendingCacheClear: StorageCacheClearTarget?
    @State private var isWelcomePresented = false
    @State private var welcomeStatusMessage = ""
    @State private var cachedLibrarySongs: [YouTubeVideoSearchResult] = []
    @State private var cachedMusicTracks: [MusicTrack] = []
    @State private var cachedMusicAlbums: [MusicAlbum] = []
    @State private var cachedDisplayedMusicAlbums: [MusicAlbum] = []
    @State private var cachedMusicArtists: [MusicArtist] = []
    @State private var cachedDisplayedMusicArtists: [MusicArtist] = []
    @State private var cachedDisplayedPlaylistVideos: [YouTubeVideoSearchResult] = []
    @State private var cachedAlbumVideosByID: [MusicProviderEntityID: [YouTubeVideoSearchResult]] = [:]
    @State private var cachedArtistVideosByID: [MusicProviderEntityID: [YouTubeVideoSearchResult]] = [:]
    @State private var pendingLocalPlayedSeconds = 0.0
    @State private var lastLocalListeningPersistDate = Date.distantPast
    @State private var isVideoVisible = false
    @StateObject private var accountViewModel = YouTubeAccountViewModel()
    @StateObject private var playerController = YouTubeMusicWebPlayerController()
    @StateObject private var searchViewModel = YouTubeSearchViewModel()
    private let deviceCapabilityProvider = StaticDeviceRoutingCapabilityProvider()

    var body: some View {
        rootContent
            .padding(DesignTokens.comfortableSpacing)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .navigationTitle("Music")
            .task {
                await loadInitialPageState()
            }
            .onChange(of: currentSection) { _, newSection in
                Task { await handleSectionChange(newSection) }
            }
            .onChange(of: playbackPreferenceRaw) { _, _ in
                Task { await refreshMusicSurfacesIfNeeded(force: true) }
                if currentSection == .providerLab {
                    lastProviderLabQuery = ""
                    Task { await runProviderComparisonIfNeeded() }
                }
            }
            .onChange(of: musicEngineRaw) { _, _ in
                Task {
                    await refreshMusicSurfacesIfNeeded(force: true)
                    if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        await searchViewModel.search(searchText, preference: playbackPreference, engine: musicEngine)
                        rebuildPageCaches()
                    }
                    await runProviderComparisonIfNeeded()
                }
            }
            .onChange(of: searchViewModel.selectedVideo) { _, selectedVideo in
                guard let selectedVideo else { return }
                AppLog.playback.info("UI selected video changed; id=\(selectedVideo.id, privacy: .public), title=\(selectedVideo.title, privacy: .private), videoVisible=\(self.isVideoVisible.description, privacy: .public)")
                appState.youtubeNowPlaying = selectedVideo
                persistLastPlayback(selectedVideo)
                rebuildPageCaches()
                if isVideoVisible, playerController.currentVideoID != selectedVideo.id {
                    AppLog.player.info("UI loading selected video into visible player; id=\(selectedVideo.id, privacy: .public)")
                    playerController.load(video: selectedVideo)
                }
            }
            .onChange(of: playerController.playerState) { _, playerState in
                handlePlayerStateChange(playerState)
            }
            .onChange(of: searchViewModel.canPlayPrevious) { _, _ in updatePlaybackBridge() }
            .onChange(of: searchViewModel.canPlayNext) { _, _ in updatePlaybackBridge() }
            .onChange(of: playerController.volume) { _, _ in updatePlaybackBridge() }
            .onChange(of: playerController.isMuted) { _, _ in updatePlaybackBridge() }
            .onChange(of: playerController.currentTime) { previousTime, currentTime in
                trackLocalListening(previousTime: previousTime, currentTime: currentTime)
            }
            .alert(item: $pendingCacheClear) { target in
                Alert(
                    title: Text(target.title),
                    message: Text(target.message),
                    primaryButton: .destructive(Text(target.confirmTitle)) {
                        clearStorageCaches(target)
                    },
                    secondaryButton: .cancel()
                )
            }
            .sheet(isPresented: $isWelcomePresented, onDismiss: markWelcomeSeen) {
                PhonoDeckWelcomeSheet(
                    continueAction: markWelcomeSeen
                )
            }
    }

    private var rootContent: AnyView {
        AnyView(
        VStack(alignment: .leading, spacing: DesignTokens.comfortableSpacing) {
            header

            HStack(alignment: .top, spacing: DesignTokens.comfortableSpacing) {
                songsPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if shouldShowNowPlayingPanel {
                    nowPlayingPanel
                        .frame(width: 420)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        )
    }

    private var header: some View {
        HStack(spacing: DesignTokens.standardSpacing) {
            VStack(alignment: .leading, spacing: 6) {
                Label("Music", systemImage: "music.note")
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(searchViewModel.selectedVideo?.title ?? "All music in one place, YouTube Music first")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search songs", text: $searchText)
                    .textFieldStyle(.plain)
                    .frame(width: 260)
                    .onSubmit {
                        searchFromUI(searchText)
                    }
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help("Clear search")
                }
                Button {
                    searchFromUI(searchText)
                } label: {
                    Image(systemName: "arrow.forward")
                }
                .buttonStyle(.borderless)
                .disabled(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var songsPanel: some View {
        VStack(alignment: .leading, spacing: DesignTokens.standardSpacing) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    breadcrumbTrail
                    Text(sectionTitle)
                        .font(.title.weight(.semibold))
                    Text(sectionSubtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    if !sectionCountText.isEmpty {
                        Text(sectionCountText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if showsInlineResultModePicker {
                    Picker("Result Mode", selection: $playbackPreferenceRaw) {
                        ForEach(YouTubePlaybackPreference.allCases) { preference in
                            Text(preference.title).tag(preference.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 240)
                    .onChange(of: playbackPreferenceRaw) { _, _ in
                        handleInlineResultModeChange()
                    }
                    .help("Switch between song-first and video-first results")
                }
                if searchViewModel.isSearching || searchViewModel.isLoadingLibrary || searchViewModel.isRefreshingMusicDiscovery {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if currentSection == .playlists {
                playlistPicker
                playlistContentToolbar
            }

            if currentSection == .search || (currentSection == .listenNow && searchViewModel.activityVideos.isEmpty) {
                quickSearches
            }

            if currentSection == .listenNow {
                listenNowContext
            }

            if !searchViewModel.status.isEmpty {
                Text(searchViewModel.status)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            }

            phase5SurfaceStatus

            if currentSection == .queue, let selectedVideo = searchViewModel.selectedVideo, let blocked = playbackBlockedState(for: selectedVideo) {
                compactStatusCallout(
                    source: selectedVideo.mediaSourceKind,
                    status: .policyBlocked(blocked.reason),
                    title: "Queue item blocked",
                    detail: blocked.reason
                )
            }

            if currentSection == .settings {
                // Settings is a self-scrolling grouped Form; don't nest it in the
                // roadmap ScrollView (that would double-scroll and break layout).
                settingsPanel
            } else if showsRoadmapPanel {
                ScrollView {
                    roadmapPanel
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(.bottom, DesignTokens.comfortableSpacing)
                }
            } else if sectionVideos.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(sectionVideos, id: \.stableListID) { result in
                            SongResultRow(
                                result: result,
                                isSelected: result.id == searchViewModel.selectedVideo?.id,
                                action: {
                                    searchViewModel.select(result, queue: sectionVideos)
                                },
                                playAction: {
                                    play(result, queue: sectionVideos)
                                },
                                infoAction: {
                                    searchViewModel.select(result, queue: sectionVideos)
                                    inspectorMode = .info
                                },
                                lyricsAction: {
                                    searchViewModel.select(result, queue: sectionVideos)
                                    inspectorMode = .lyrics
                                },
                                queueAction: {
                                    searchViewModel.addToQueue(result)
                                },
                                alternateSourcesAction: {
                                    findOtherSources(for: result)
                                },
                                removeAction: playlistRemoveAction(for: result)
                            )

                            if result.stableListID != sectionVideos.last?.stableListID {
                                Divider()
                                    .padding(.leading, 76)
                            }
                        }

                        if currentSection == .search, searchViewModel.canLoadMoreSearchResults {
                            Button {
                                Task {
                                    await searchViewModel.loadMoreSearchResults()
                                    rebuildPageCaches()
                                }
                            } label: {
                                Label("Load More", systemImage: "arrow.down.circle")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }

                        if currentSection == .playlists, searchViewModel.canLoadMorePlaylistVideos {
                            Button {
                                Task {
                                    await searchViewModel.loadMorePlaylistVideos()
                                    rebuildPageCaches()
                                }
                            } label: {
                                Label("Load More", systemImage: "arrow.down.circle")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(emptyStateTitle, systemImage: "music.note.list")
                .font(.headline)
            Text(emptyStateDetail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                appState.open(.search)
                searchFromUI(searchText)
            } label: {
                Label("Search Songs", systemImage: "magnifyingglass")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private var phase5SurfaceStatus: some View {
        switch currentSection {
        case .search:
            if searchViewModel.status.localizedCaseInsensitiveContains("cached") {
                compactStatusCallout(
                    source: .youtubeMusic,
                    status: .partial,
                    title: "Using Cached Official Results",
                    detail: "The official YouTube API is temporarily unavailable, so PhonoDeck is showing cached official results."
                )
            } else if searchViewModel.status.localizedCaseInsensitiveContains("quota") || searchViewModel.status.localizedCaseInsensitiveContains("rate") {
                compactStatusCallout(
                    source: .youtubeMusic,
                    status: .rateLimited(retryAfter: nil),
                    title: "Search is rate limited",
                    detail: "Showing cached results where available. Try another query or retry later."
                )
            }
        case .library:
            if !isLibraryEmpty {
                compactStatusCallout(
                    source: .plex,
                    status: .notConfigured("Plex and Spotify are not ready yet, so the Library is not claiming a complete cross-source catalog."),
                    title: "Showing available sources",
                    detail: "YouTube Music and PhonoDeck history are ready. Connect Plex, Spotify, or Own Files to expand the unified library."
                )
            }
        case .playlists:
            if searchViewModel.isLoadingLibrary {
                compactStatusCallout(
                    source: .youtubeMusic,
                    status: .partial,
                    title: "Loading playlists",
                    detail: "Playlist rows stay source-marked while PhonoDeck loads the official YouTube account playlist API."
                )
            }
        default:
            EmptyView()
        }
    }

    private func compactStatusCallout(source: MediaSourceKind, status: SourceProviderStatus, title: String, detail: String) -> some View {
        let base = SourceReadinessPresentation.make(source: source, status: status)
        let presentation = SourceReadinessPresentation(title: title, detail: detail, badge: base.badge, symbolName: base.symbolName, severity: base.severity)
        return ReadinessCallout(source: source, presentation: presentation)
            .padding(10)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var playlistPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !accountViewModel.state.hasPlaylistWriteScope {
                HStack(spacing: 10) {
                    Label("Connect Google with playlist access to create and edit playlists.", systemImage: "person.crop.circle.badge.plus")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        Task { await accountViewModel.connect() }
                    } label: {
                        Label("Connect", systemImage: "person.crop.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(10)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button {
                        Task { await searchViewModel.createDefaultPlaylist() }
                    } label: {
                        Label(searchViewModel.isCreatingPlaylist ? "Creating Playlist" : "New YouTube Music Playlist", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(searchViewModel.isCreatingPlaylist || !accountViewModel.state.hasPlaylistWriteScope)
                    .help(accountViewModel.state.hasPlaylistWriteScope ? "Create a private YouTube Music playlist" : "Connect Google with playlist access first")

                    if let selectedPlaylist = searchViewModel.selectedPlaylist {
                        ShareLink(item: selectedPlaylist.shareURL) {
                            Label("Share Playlist", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    } else {
                        Button {} label: {
                            Label("Share Playlist", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(true)
                        .help("Select a playlist to share")
                    }

                    ForEach(searchViewModel.playlists) { playlist in
                        Button {
                            Task {
                                await searchViewModel.selectPlaylist(playlist)
                                rebuildPageCaches()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: playlistSourceKind(for: playlist).descriptor.symbolName)
                                    .foregroundStyle(playlistSourceKind(for: playlist).tint)
                                Text("\(playlist.snippet.title) (\(playlist.contentDetails?.itemCount ?? 0))")
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(playlist == searchViewModel.selectedPlaylist ? .accentColor : nil)
                        .help("\(playlist.snippet.title): \(playlistSourceLabel(for: playlist))")
                    }
                }
            }
        }
    }

    private var playlistContentToolbar: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let selectedPlaylist = searchViewModel.selectedPlaylist {
                HStack(spacing: 10) {
                    SourcePill(source: selectedPlaylistSourceKind, title: selectedPlaylistSourceLabel(for: selectedPlaylist))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedPlaylist.snippet.title)
                            .font(.callout.weight(.semibold))
                            .lineLimit(1)
                        Text("Official YouTube account playlist API • \(searchViewModel.playlistVideos.count) loaded songs")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    if let selectedVideo = searchViewModel.selectedVideo {
                        Button {
                            findOtherSources(for: selectedVideo)
                        } label: {
                            Label("Find Sources", systemImage: "magnifyingglass.circle")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Inspect official YouTube API readiness and disabled provider policy for the selected song")
                    }
                }
            }

            HStack(spacing: 10) {
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search songs in playlist", text: $playlistFilterText)
                        .textFieldStyle(.plain)
                    if !playlistFilterText.isEmpty {
                        Button {
                            playlistFilterText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                Picker("Playlist Sort", selection: $playlistSortRaw) {
                    Text("Date Added").tag("dateAdded")
                    Text("Title").tag("title")
                    Text("Artist").tag("artist")
                    Text("Source").tag("source")
                }
                .pickerStyle(.segmented)
                .frame(width: 340)
            }
        }
    }

    private var listenNowContext: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !searchViewModel.musicDiscoveryVideos.isEmpty {
                Text("Bounded recommendations from cached official YouTube results. Use Search for deeper pagination.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                SongCarouselShelf(
                    title: "YouTube Music",
                    items: Array(searchViewModel.musicDiscoveryVideos.prefix(8)),
                    selectAction: { searchViewModel.select($0) },
                    playAction: { play($0, queue: searchViewModel.musicDiscoveryVideos) }
                )
            }
            if !searchViewModel.playbackHistory.isEmpty {
                ContextShelf(title: "PhonoDeck History", items: searchViewModel.playbackHistory.prefix(4).map { "\($0.title) - \($0.channelTitle)" })
                SongCarouselShelf(
                    title: "Recently Played",
                    items: Array(searchViewModel.playbackHistory.prefix(8)),
                    selectAction: { searchViewModel.select($0) },
                    playAction: { play($0, queue: searchViewModel.playbackHistory) }
                )
            }
            if !searchViewModel.subscriptions.isEmpty {
                ContextShelf(title: "Subscriptions", items: searchViewModel.subscriptions.prefix(4).map { $0.snippet.title })
            }
        }
    }

    @ViewBuilder
    private var roadmapPanel: some View {
        switch currentSection {
        case .library:
            libraryPanel
        case .albums:
            albumsPanel
        case .artists:
            artistsPanel
        case .devices:
            deviceRoadmapPanel
        case .downloads:
            downloadRoadmapPanel
        case .queue:
            queuePanel
        case .providerLab:
            providerLabPanel
        case .settings:
            settingsPanel
        default:
            integrationRoadmapPanel
        }
    }

    @ViewBuilder
    private var libraryPanel: some View {
        if isLibraryEmpty {
            libraryEmptyState
        } else {
            libraryContentPanel
        }
    }

    private var isLibraryEmpty: Bool {
        librarySongs.isEmpty
            && searchViewModel.playlists.isEmpty
            && searchViewModel.activityVideos.isEmpty
            && searchViewModel.subscriptions.isEmpty
    }

    private var libraryContentPanel: some View {
        VStack(alignment: .leading, spacing: DesignTokens.comfortableSpacing) {
            if !librarySongs.isEmpty {
                SongCarouselShelf(
                    title: "Recently Played",
                    items: Array(librarySongs.prefix(12)),
                    selectAction: { searchViewModel.select($0) },
                    playAction: { play($0, queue: librarySongs) }
                )
            }

            if !searchViewModel.musicDiscoveryVideos.isEmpty {
                SongCarouselShelf(
                    title: "Made for You",
                    items: Array(searchViewModel.musicDiscoveryVideos.prefix(12)),
                    selectAction: { searchViewModel.select($0) },
                    playAction: { play($0, queue: searchViewModel.musicDiscoveryVideos) }
                )
            }

            if !searchViewModel.playlists.isEmpty {
                libraryPlaylistShelf
            }

            if !searchViewModel.activityVideos.isEmpty {
                SongCarouselShelf(
                    title: "From Your Activity",
                    items: Array(searchViewModel.activityVideos.prefix(12)),
                    selectAction: { searchViewModel.select($0) },
                    playAction: { play($0, queue: searchViewModel.activityVideos) }
                )
            }

            if !searchViewModel.subscriptions.isEmpty {
                librarySubscriptionShelf
            }
        }
    }

    private var librarySubscriptionShelf: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Subscriptions")
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(searchViewModel.subscriptions.prefix(12)) { subscription in
                        SubscriptionAvatarCard(
                            title: subscription.snippet.title,
                            artworkURL: subscription.snippet.thumbnails?.medium?.url ?? subscription.snippet.thumbnails?.default?.url
                        ) {
                            searchText = subscription.snippet.title
                            appState.open(.search)
                            searchFromUI(subscription.snippet.title)
                        }
                    }
                }
                .padding(.bottom, 4)
            }
        }
    }

    private var libraryPlaylistShelf: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Your Playlists")
                    .font(.headline)
                Spacer()
                Button {
                    appState.open(.playlists)
                } label: {
                    Label("Show All", systemImage: "chevron.right")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(searchViewModel.playlists.prefix(10)) { playlist in
                        PlaylistArtworkCard(
                            title: playlist.snippet.title,
                            songCount: playlist.contentDetails?.itemCount ?? 0,
                            artworkURL: playlist.snippet.thumbnails?.medium?.url ?? playlist.snippet.thumbnails?.default?.url
                        ) {
                            appState.open(.playlists)
                            Task {
                                await searchViewModel.selectPlaylist(playlist)
                                rebuildPageCaches()
                            }
                        }
                    }
                }
                .padding(.bottom, 4)
            }
        }
    }

    private var libraryEmptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "music.note")
                .font(.system(size: 58, weight: .regular))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text("Bring All Music Into One Place")
                .font(.title.weight(.semibold))
                .multilineTextAlignment(.center)

            Text("Connect your music services to build a single library across YouTube Music, Spotify, and Plex.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .frame(maxWidth: 430)

            HStack(spacing: 8) {
                Button(action: connectYouTubeFromWelcome) {
                    Label(youtubeConnectButtonTitle, systemImage: MediaSourceKind.youtubeMusic.descriptor.symbolName)
                }
                .buttonStyle(.borderedProminent)
                .disabled(accountViewModel.state == .connecting || accountViewModel.state.canDisconnect)

                Button {
                    showPlannedConnection(for: .spotify)
                } label: {
                    Label("Add Spotify", systemImage: MediaSourceKind.spotify.descriptor.symbolName)
                }
                .buttonStyle(.bordered)

                Button {
                    showPlannedConnection(for: .plex)
                } label: {
                    Label("Add Plex", systemImage: MediaSourceKind.plex.descriptor.symbolName)
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.small)

            if !welcomeStatusMessage.isEmpty {
                Text(welcomeStatusMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 460)
            }

            Button {
                isWelcomePresented = true
            } label: {
                Label("Welcome", systemImage: "sparkles")
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, minHeight: 460, alignment: .center)
    }

    private var albumsPanel: some View {
        VStack(alignment: .leading, spacing: DesignTokens.comfortableSpacing) {
            catalogReadinessCallout(
                source: .youtubeMusic,
                title: musicAlbums.isEmpty ? "Albums need a catalog source" : "Limited album grouping",
                detail: musicAlbums.isEmpty
                    ? "YouTube Music search can play songs, but it does not expose canonical albums to third-party apps. Connect Plex, Spotify, or Own Files metadata before Albums behaves like a full catalog."
                    : "These albums are derived from YouTube Music results and may miss year, label, credits, track order, and canonical album identity.",
                status: musicAlbums.isEmpty ? .notConnected : .policyBlocked("YouTube does not expose canonical album metadata to third-party apps.")
            )

            MusicCollectionToolbar(
                filterPlaceholder: "Filter albums",
                filterText: $albumFilterText,
                sortSelection: $albumSortRaw,
                sortOptions: [("artist", "Artist"), ("title", "Title"), ("recent", "Recent")],
                refreshAction: { Task { await searchViewModel.refreshMusicDiscovery(engine: musicEngine, force: true) } }
            )

            if musicAlbums.isEmpty {
                LimitedCatalogEmptyState(
                    symbol: "square.stack",
                    title: "Albums need a catalog source",
                    detail: "Search and play songs now. Canonical albums require Plex, Spotify, Own Files, or another provider that exposes album metadata.",
                    action: { appState.open(.settings) }
                )
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: DesignTokens.standardSpacing)], spacing: DesignTokens.standardSpacing) {
                    ForEach(displayedMusicAlbums) { album in
                        AlbumCard(
                            album: album,
                            isSelected: selectedAlbumID == album.id,
                            action: { selectedAlbumID = album.id },
                            playAction: {
                                let tracks = albumVideos(for: album)
                                if let firstTrack = tracks.first {
                                    play(firstTrack, queue: tracks)
                                }
                            }
                        )
                    }
                }

                if let album = selectedAlbum ?? displayedMusicAlbums.first {
                    MusicCollectionDetailPanel(
                        title: album.title,
                        subtitle: "\(album.artistName) - \(album.trackCount ?? 0) songs - \(album.source.descriptor.displayName)",
                        facts: [
                            "Year: \(album.releaseYear ?? "Not exposed by this source")",
                            "Label: \(album.recordLabel ?? "Not exposed by this source")",
                            "Duration: \(album.displayDuration)"
                        ],
                        symbol: "square.stack",
                        source: album.source,
                        items: albumVideos(for: album),
                        selectedVideo: searchViewModel.selectedVideo,
                        selectAction: { searchViewModel.select($0) },
                        playAction: { item in play(item, queue: albumVideos(for: album)) },
                        infoAction: { item in searchViewModel.select(item); inspectorMode = .info },
                        lyricsAction: { item in searchViewModel.select(item); inspectorMode = .lyrics },
                        queueAction: { searchViewModel.addToQueue($0) },
                        addMenu: { item in AnyView(addToPlaylistMenu(item)) }
                    )
                }
            }
        }
    }

    private var artistsPanel: some View {
        VStack(alignment: .leading, spacing: DesignTokens.comfortableSpacing) {
            catalogReadinessCallout(
                source: .youtubeMusic,
                title: musicArtists.isEmpty ? "Artists need a catalog source" : "Limited artist grouping",
                detail: musicArtists.isEmpty
                    ? "YouTube channels are not the same thing as music artists. Connect a catalog source before Artists behaves like a canonical artist library."
                    : "These artists are derived from YouTube channels/results. Subscriber counts, bios, credits, and canonical identities are not inferred.",
                status: musicArtists.isEmpty ? .notConnected : .policyBlocked("YouTube channels are not canonical music artists.")
            )

            MusicCollectionToolbar(
                filterPlaceholder: "Filter artists",
                filterText: $artistFilterText,
                sortSelection: $artistSortRaw,
                sortOptions: [("name", "Name"), ("songs", "Songs"), ("recent", "Recent")],
                refreshAction: { Task { await searchViewModel.refreshMusicDiscovery(engine: musicEngine, force: true) } }
            )

            if musicArtists.isEmpty {
                LimitedCatalogEmptyState(
                    symbol: "music.mic",
                    title: "Artists need a catalog source",
                    detail: "YouTube search results stay available, but PhonoDeck will not present channels as canonical artist pages.",
                    action: { appState.open(.settings) }
                )
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: DesignTokens.standardSpacing)], spacing: DesignTokens.standardSpacing) {
                    ForEach(displayedMusicArtists) { artist in
                        ArtistCard(
                            artist: artist,
                            isSelected: selectedArtistID == artist.id,
                            action: { selectedArtistID = artist.id },
                            playAction: {
                                let tracks = artistVideos(for: artist)
                                if let firstTrack = tracks.first {
                                    play(firstTrack, queue: tracks)
                                }
                            }
                        )
                    }
                }

                if let artist = selectedArtist ?? displayedMusicArtists.first {
                    MusicCollectionDetailPanel(
                        title: artist.name,
                        subtitle: "\(artist.trackCount ?? 0) songs - \(artist.albumCount ?? 0) albums - \(artist.source.descriptor.displayName)",
                        facts: [
                            "Following: Not exposed by this source",
                            "Radio/Playlists: Not exposed by this source",
                            "Bio/Trivia: No connected metadata provider yet"
                        ],
                        symbol: "music.mic",
                        source: artist.source,
                        items: artistVideos(for: artist),
                        selectedVideo: searchViewModel.selectedVideo,
                        selectAction: { searchViewModel.select($0) },
                        playAction: { item in play(item, queue: artistVideos(for: artist)) },
                        infoAction: { item in searchViewModel.select(item); inspectorMode = .info },
                        lyricsAction: { item in searchViewModel.select(item); inspectorMode = .lyrics },
                        queueAction: { searchViewModel.addToQueue($0) },
                        addMenu: { item in AnyView(addToPlaylistMenu(item)) }
                    )
                    if let seed = artistVideos(for: artist).first {
                        relatedMusicPanel(for: seed, title: "Related to \(artist.name)")
                    }
                }
            }
        }
    }

    private func catalogReadinessCallout(source: MediaSourceKind, title: String, detail: String, status: SourceProviderStatus) -> some View {
        let base = SourceReadinessPresentation.make(source: source, status: status)
        let presentation = SourceReadinessPresentation(
            title: title,
            detail: detail,
            badge: base.badge,
            symbolName: base.symbolName,
            severity: base.severity
        )
        return ReadinessCallout(source: source, presentation: presentation)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var settingsPanel: some View {
        Form {
            Section {
                MusicServicesSection(
                    registry: appState.sourceRegistry,
                    youTubeState: Self.youTubeConnectionState(accountViewModel.state),
                    connectYouTube: { Task { await accountViewModel.connect() } },
                    disconnectYouTube: { accountViewModel.disconnect() }
                )
            } header: {
                Text("Music Services")
            } footer: {
                Text("Connect a service to start listening. PhonoDeck blends them into one library — every item stays marked by its source.")
            }

            Section {
                Picker("YouTube Music Engine", selection: $musicEngineRaw) {
                    ForEach(YouTubeMusicEngine.allCases) { engine in
                        Text(engine.title).tag(engine.rawValue)
                    }
                }
                Picker("Result Mode", selection: $playbackPreferenceRaw) {
                    ForEach(YouTubePlaybackPreference.allCases) { preference in
                        Text(preference.title).tag(preference.rawValue)
                    }
                }
            } header: {
                Text("Playback")
            } footer: {
                Text("\(musicEngine.detail) Songs favors official audio, Topic uploads, and lyric videos; Videos allows clips and music videos.")
            }

            Section {
                CacheSettingsPanel(
                    artworkBytes: artworkCacheBytes,
                    metadataBytes: searchViewModel.metadataCacheUsageBytes,
                    clearArtworkAction: { pendingCacheClear = .artwork },
                    clearMetadataAction: { pendingCacheClear = .metadata }
                )
            } header: {
                Text("Storage")
            }

            if Self.youTubeConnectionState(accountViewModel.state).isConnected {
                Section {
                    ScopeDisclosurePanel(state: accountViewModel.state)
                } header: {
                    Text("YouTube Access")
                }
            }
        }
        .formStyle(.grouped)
    }

    /// Folds the existing Google/YouTube account state into the neutral
    /// `SourceConnectionState` so YouTube + YouTube Music render through the same
    /// `ServiceAccountRow` as every other source.
    private static func youTubeConnectionState(_ state: YouTubeAccountState) -> SourceConnectionState {
        switch state {
        case .signedOut:
            return .notConnected
        case .connecting:
            return .connecting
        case let .connected(channelTitle, _):
            return .connected(SourceAccountSummary(displayName: channelTitle, tier: .none, detail: "\(channelTitle) · YouTube & YouTube Music"))
        case .stored:
            return .connected(SourceAccountSummary(displayName: "YouTube account", tier: .none, detail: "Signed in · YouTube & YouTube Music"))
        case let .failed(message):
            return .failed(reason: message)
        }
    }

    private var providerLabPanel: some View {
        VStack(alignment: .leading, spacing: DesignTokens.standardSpacing) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Compare Engines")
                        .font(.headline)
                    Text("Production diagnostics for official YouTube API readiness and the disabled undocumented metadata path.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button {
                    Task { await runProviderComparison(force: true) }
                } label: {
                    Label(searchViewModel.isComparingProviders ? "Comparing" : "Compare", systemImage: "arrow.left.arrow.right")
                }
                .buttonStyle(.borderedProminent)
                .disabled(providerLabQuery.isEmpty || searchViewModel.isComparingProviders)
            }
            .padding(14)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            if searchViewModel.isComparingProviders {
                ProgressView()
                    .controlSize(.small)
            }

            if let run = searchViewModel.providerComparisonRun {
                ProviderComparisonRunPanel(run: run)
            }

            if searchViewModel.providerComparisons.isEmpty {
                LibraryEmptyShelf(searchAction: { appState.open(.search) })
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: DesignTokens.standardSpacing)], spacing: DesignTokens.standardSpacing) {
                    ForEach(searchViewModel.providerComparisons) { comparison in
                        ProviderComparisonCard(
                            comparison: comparison,
                            selectAction: { item in searchViewModel.select(item) },
                            playAction: { item in play(item, queue: comparison.items) },
                            diagnostic: searchViewModel.providerComparisonRun?.providerResults.first { $0.id == comparison.id }
                        )
                    }
                }
            }
        }
    }

    private var queuePanel: some View {
        VStack(alignment: .leading, spacing: DesignTokens.standardSpacing) {
            HStack(alignment: .center, spacing: 10) {
                LibraryMetricTile(title: "Queued", value: "\(searchViewModel.queue.count)", symbol: "list.bullet", color: .blue)
                if let queuePositionText = searchViewModel.queuePositionText {
                    LibraryMetricTile(title: "Position", value: queuePositionText, symbol: "play.circle", color: .green)
                }
                Spacer(minLength: 0)
                Button(role: .destructive) {
                    searchViewModel.clearQueue()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(searchViewModel.queue.isEmpty)
            }

            if searchViewModel.queue.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "music.note.list")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .background(Color.accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("There is no music in the queue")
                            .font(.headline)
                        Text("Play a song, open a playlist, or add rows to queue from Search, Albums, Artists, or Playlists.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        appState.open(.search)
                    } label: {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(14)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(searchViewModel.queue.enumerated()), id: \.element.id) { index, item in
                        QueueItemRow(
                            index: index + 1,
                            item: item,
                            isSelected: item.id == searchViewModel.selectedVideo?.id,
                            playAction: { play(item, queue: searchViewModel.queue) },
                            selectAction: { searchViewModel.select(item, queue: searchViewModel.queue) },
                            removeAction: { searchViewModel.removeFromQueue(item) }
                        )
                        if item.id != searchViewModel.queue.last?.id {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    private var integrationRoadmapPanel: some View {
        VStack(alignment: .leading, spacing: DesignTokens.standardSpacing) {
            SourceIntegrationRow(
                source: .youtube,
                status: "Active",
                detail: "Clips, music videos, and general YouTube results stay available as a separate video source."
            )
            SourceIntegrationRow(
                source: .youtubeMusic,
                status: "Active",
                detail: "Search, Listen Now, Library, playlists, queue, sharing, and visible official playback are music-first for P0."
            )
            SourceIntegrationRow(
                source: .plex,
                status: "Planned",
                detail: "Native server browsing, personal library playback, downloads for owned media, and artwork sync."
            )
            SourceIntegrationRow(
                source: .spotify,
                status: "Planned",
                detail: "Spotify Connect control and metadata/library surfaces where Spotify policy allows it."
            )
            SourceIntegrationRow(
                source: .ownFiles,
                status: "Planned",
                detail: "User-owned file imports, local playback, and iTunes XML compatibility."
            )
        }
    }

    private var deviceRoadmapPanel: some View {
        VStack(alignment: .leading, spacing: DesignTokens.standardSpacing) {
            HStack(alignment: .center, spacing: 12) {
                AirPlayRoutePickerButton()
                    .frame(width: 42, height: 34)
                VStack(alignment: .leading, spacing: 3) {
                    Text("AirPlay / HomePod Picker")
                        .font(.headline)
                    Text("Shows system media receivers such as HomePod, Apple TV, and AirPlay speakers when macOS exposes them.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    openSoundSettings()
                } label: {
                    Label("Sound", systemImage: "speaker.wave.2")
                }
                Button {
                    openHomeApp()
                } label: {
                    Label("Home", systemImage: "house")
                }
            }
            .buttonStyle(.bordered)
            .padding(14)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            ForEach(deviceCapabilityProvider.capabilities()) { capability in
                DeviceFactRow(
                    symbol: capability.symbol,
                    title: capability.title,
                    status: capability.status,
                    supportState: capability.supportState,
                    detail: capability.detail,
                    color: capability.color.color,
                    evidenceSource: capability.evidenceSource,
                    checkedAt: capability.checkedAt
                )
            }
        }
    }

    private var downloadRoadmapPanel: some View {
        VStack(alignment: .leading, spacing: DesignTokens.standardSpacing) {
            StorageBoundaryPanel(
                snapshot: storageSnapshot,
                refreshAction: refreshCacheStats,
                settingsAction: { appState.open(.settings) }
            )

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: DesignTokens.standardSpacing)], spacing: DesignTokens.standardSpacing) {
                LibraryMetricTile(title: "Total Cache", value: formattedBytes(storageSnapshot.totalBytes), symbol: "internaldrive", color: .blue)
                LibraryMetricTile(title: "Metadata", value: formattedBytes(storageSnapshot.metadataBytes), symbol: "list.bullet.rectangle", color: .green)
                LibraryMetricTile(title: "Artwork", value: formattedBytes(storageSnapshot.artworkBytes), symbol: "photo", color: .orange)
                LibraryMetricTile(title: "Media Downloads", value: formattedBytes(storageSnapshot.mediaDownloadBytes), symbol: "play.slash", color: .red)
            }

            HStack(spacing: 8) {
                EvidenceChip(title: "Measured", value: storageSnapshot.measuredAt.formatted(date: .abbreviated, time: .shortened))
                EvidenceChip(title: "Source", value: storageSnapshot.evidenceSource)
                EvidenceChip(title: "Status", value: storageSnapshot.measurementStatus.rawValue)
                EvidenceChip(title: "Owned media blocked", value: "\(storageSnapshot.blockedMediaAssetCount)")
            }

            if let measurementIssue = storageSnapshot.measurementIssue {
                compactStatusCallout(source: .youtubeMusic, status: .providerUnavailable(measurementIssue), title: "Storage measurement partial", detail: measurementIssue)
            }

            StorageCacheActionsPanel(
                snapshot: storageSnapshot,
                statusMessage: storageStatusMessage,
                clearArtworkAction: { pendingCacheClear = .artwork },
                clearMetadataAction: { pendingCacheClear = .metadata },
                clearAllAction: { pendingCacheClear = .all }
            )

            if let storageClearReceipt {
                StorageCacheClearReceiptPanel(receipt: storageClearReceipt)
            }

            StorageAssetsPanel(
                snapshot: storageSnapshot,
                searchAction: { appState.open(.search) }
            )

            VStack(alignment: .leading, spacing: 10) {
                Text("Source Policies")
                    .font(.headline)
                ForEach(MusicStoragePolicyCatalog.policies) { policy in
                    StorageSourcePolicyRow(policy: policy)
                }
            }

            StorageSafetyPanel()
        }
    }

    private var quickSearches: some View {
        HStack(spacing: 8) {
            ForEach(quickSearchSuggestions, id: \.self) { suggestion in
                Button {
                    searchText = suggestion
                    appState.open(.search)
                    searchFromUI(suggestion)
                } label: {
                    Text(suggestion)
                        .lineLimit(1)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private var nowPlayingPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.standardSpacing) {
            HStack {
                Text("Now Playing")
                    .font(.headline)
                Spacer()
                sourceBadge
                accountMenu
            }

            videoSurface

            if let selectedVideo = searchViewModel.selectedVideo, let blocked = playbackBlockedState(for: selectedVideo) {
                compactStatusCallout(
                    source: selectedVideo.mediaSourceKind,
                    status: .policyBlocked(blocked.reason),
                    title: "Playback route unavailable",
                    detail: blocked.reason
                )
            }

            playerTransportControls

            if let selectedVideo = searchViewModel.selectedVideo {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedVideo.title)
                        .font(.headline)
                        .lineLimit(3)
                    Text(selectedVideo.channelTitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                if let queuePositionText = searchViewModel.queuePositionText {
                    Text("Queue \(queuePositionText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                alwaysVisibleMediaInfo(for: selectedVideo)

                HStack(spacing: 8) {
                    Button {
                        inspectorMode = inspectorMode == .info ? nil : .info
                    } label: {
                        Label("Info", systemImage: "info.circle")
                    }
                    Button {
                        openLyrics(for: selectedVideo)
                    } label: {
                        Label("Lyrics", systemImage: "text.quote")
                    }
                    ShareLink(item: selectedVideo.watchURL) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    addToPlaylistMenu(selectedVideo)
                    Button {
                        NSWorkspace.shared.open(selectedVideo.watchURL)
                    } label: {
                        Label("Open", systemImage: "arrow.up.right.square")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                inspectorPanel(selectedVideo)
                relatedMusicPanel(for: selectedVideo, title: "Related Music")
                upNextPanel
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "music.note.list")
                        .frame(width: 28, height: 28)
                        .background(Color.accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .foregroundStyle(Color.accentColor)
                    Text("Select a song to show info, lyrics, sharing, playlist, and open actions.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(10)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 540, alignment: .topLeading)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private var videoSurface: some View {
        if isVideoVisible {
            ZStack(alignment: .topTrailing) {
                YouTubeMusicWebPlayerView(controller: playerController)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .frame(minHeight: 270)
                    .background(Color(nsColor: .controlBackgroundColor))

                Button {
                    hideVideoSurface()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.borderless)
                .padding(10)
                .help("Hide video and stop YouTube playback")
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            HStack(spacing: 12) {
                Image(systemName: "play.rectangle")
                    .font(.system(size: 34, weight: .regular))
                    .foregroundStyle(.secondary)
                    .frame(width: 52, height: 52)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Video hidden")
                        .font(.headline)
                    Text("Press Play to show the official YouTube player. Hiding the video stops playback.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button {
                    togglePanelPlayback()
                } label: {
                    Label("Play", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(searchViewModel.selectedVideo == nil)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private func alwaysVisibleMediaInfo(for video: YouTubeVideoSearchResult) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Media Info")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                SourcePill(source: video.mediaSourceKind, title: video.mediaSourceKind.shortDisplayName)
                Text(video.songBadge)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(video.songBadgeColor.opacity(0.14), in: Capsule())
                    .foregroundStyle(video.songBadgeColor)
                if let durationText = video.durationText ?? searchViewModel.selectedVideoDetails?.formattedDuration {
                    Label(durationText, systemImage: "clock")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                if let popularityText = video.popularityText ?? searchViewModel.selectedVideoDetails?.popularitySummary {
                    Label(popularityText, systemImage: "chart.bar.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var upNextPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Up Next")
                    .font(.headline)
                Spacer()
                Button(role: .destructive) {
                    searchViewModel.clearQueue()
                } label: {
                    Text("Clear")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .disabled(searchViewModel.queue.isEmpty)
            }

            if upNextItems.isEmpty {
                Text(searchViewModel.queue.isEmpty ? "There is no music in the queue." : "No more songs after this one.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 72)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(upNextItems.prefix(8).enumerated()), id: \.element.id) { index, item in
                        QueueItemRow(
                            index: index + 1,
                            item: item,
                            isSelected: false,
                            playAction: { play(item, queue: searchViewModel.queue) },
                            selectAction: { searchViewModel.select(item, queue: searchViewModel.queue) },
                            removeAction: { searchViewModel.removeFromQueue(item) }
                        )
                        if item.id != upNextItems.prefix(8).last?.id {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var upNextItems: [YouTubeVideoSearchResult] {
        guard let selectedVideo = searchViewModel.selectedVideo,
              let index = searchViewModel.queue.firstIndex(where: { $0.id == selectedVideo.id }) else {
            return searchViewModel.queue
        }
        return Array(searchViewModel.queue.dropFirst(index + 1))
    }

    private var playerTransportControls: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                Button {
                    playPreviousFromQueue()
                } label: {
                    Image(systemName: "backward.fill")
                        .frame(width: 22)
                }
                .disabled(!searchViewModel.canPlayPrevious)
                .help(searchViewModel.canPlayPrevious ? "Previous song" : "No previous song in queue")

                Button {
                    togglePanelPlayback()
                } label: {
                    Image(systemName: playerPlayPauseSymbol)
                        .frame(width: 30)
                }
                .disabled(!canControlPanelPlayer)
                .help(canControlPanelPlayer ? "Play or pause" : "Select a playable song first")

                Button {
                    playNextFromQueue()
                } label: {
                    Image(systemName: "forward.fill")
                        .frame(width: 22)
                }
                .disabled(!searchViewModel.canPlayNext)
                .help(searchViewModel.canPlayNext ? "Next song" : "No next song in queue")

                Divider()
                    .frame(height: 18)

                Text(playerController.playerState.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(timeText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)
            }
            .buttonStyle(.borderless)

            ProgressView(value: playerProgress)
                .frame(height: 4)
                .help(timeText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var playerPlayPauseSymbol: String {
        playerController.playerState == .playing ? "pause.fill" : "play.fill"
    }

    private var canControlPanelPlayer: Bool {
        guard searchViewModel.selectedVideo != nil else { return false }
        if let selectedVideo = searchViewModel.selectedVideo, playbackBlockedState(for: selectedVideo) != nil { return false }
        return !isVideoVisible || playerController.playerState.acceptsCommands
    }

    private func playbackBlockedState(for video: YouTubeVideoSearchResult) -> PlaybackBlockedState? {
        guard let adapter = appState.sourceRegistry.adapter(for: video.mediaSourceKind) else {
            return .sourceUnavailable(source: video.mediaSourceKind, reason: "\(video.mediaSourceKind.descriptor.displayName) is not available.")
        }
        let track = MusicTrack(
            id: .init(source: video.mediaSourceKind, rawValue: video.id),
            title: video.title,
            artistName: video.musicIdentity.artistName,
            albumTitle: video.musicIdentity.albumTitle,
            durationSeconds: nil,
            releaseYear: nil,
            recordLabel: nil,
            artworkURL: video.thumbnailURL,
            source: video.mediaSourceKind,
            sourceURL: video.watchURL
        )
        let plan = adapter.playbackPlan(for: track)
        return appState.playbackRouter.blockedState(for: plan, source: video.mediaSourceKind, trackID: track.id)
    }

    private func togglePanelPlayback() {
        if !isVideoVisible, let selectedVideo = searchViewModel.selectedVideo {
            AppLog.playback.info("Panel play requested while video hidden; revealing player; id=\(selectedVideo.id, privacy: .public)")
            isVideoVisible = true
            let queue = searchViewModel.queue.isEmpty ? [selectedVideo] : searchViewModel.queue
            play(selectedVideo, queue: queue)
            return
        }
        AppLog.playback.info("Panel play/pause toggled; videoVisible=\(self.isVideoVisible.description, privacy: .public), playerState=\(self.playerController.playerState.title, privacy: .public), selected=\(self.searchViewModel.selectedVideo?.id ?? "none", privacy: .public)")
        playerController.togglePlayPause()
    }

    private func hideVideoSurface() {
        AppLog.player.info("Video surface hidden by user; currentVideo=\(self.playerController.currentVideoID ?? "none", privacy: .public), state=\(self.playerController.playerState.title, privacy: .public)")
        playerController.stopAndReset()
        isVideoVisible = false
        updatePlaybackBridge()
    }

    private var playerProgress: Double {
        guard playerController.duration > 0 else { return 0 }
        return min(max(playerController.currentTime / playerController.duration, 0), 1)
    }

    private func addToPlaylistMenu(_ video: YouTubeVideoSearchResult) -> some View {
        Menu {
            if !accountViewModel.state.hasPlaylistWriteScope {
                Button {
                    Task { await accountViewModel.connect() }
                } label: {
                    Label("Reconnect Google for Playlist Access", systemImage: "person.crop.circle.badge.plus")
                }
                Divider()
            }
            Button {
                Task { await searchViewModel.createDefaultPlaylist(adding: video) }
            } label: {
                Label(searchViewModel.isCreatingPlaylist ? "Creating Playlist" : "New YouTube Music Playlist", systemImage: "plus")
            }
            .disabled(searchViewModel.isCreatingPlaylist || !accountViewModel.state.hasPlaylistWriteScope)
            Divider()
            if searchViewModel.playlists.isEmpty {
                Text("No playlists yet. Create one here.")
            } else {
                ForEach(searchViewModel.playlists) { playlist in
                    Button(searchViewModel.isAdding(video, to: playlist) ? "Adding to \(playlist.snippet.title)" : playlist.snippet.title) {
                        Task { await searchViewModel.add(video, to: playlist) }
                    }
                    .disabled(searchViewModel.isAdding(video, to: playlist))
                }
            }
        } label: {
            Label("Add", systemImage: "text.badge.plus")
        }
        .help("Add this song to a YouTube Music playlist")
    }

    private var accountMenu: some View {
        Menu {
            Text(accountViewModel.state.title)
            Text(accountViewModel.state.detail)
            Divider()
            if accountViewModel.state.canDisconnect {
                Button("Log Out of Google", role: .destructive) {
                    accountViewModel.disconnect()
                }
            } else {
                Button("Connect") {
                    Task { await accountViewModel.connect() }
                }
                .disabled(accountViewModel.state == .connecting)
            }
        } label: {
            Label("Account", systemImage: "person.crop.circle")
        }
        .menuStyle(.borderlessButton)
        .help("Google account")
    }

    private var sourceBadge: some View {
        Label(activeYouTubeSource.descriptor.displayName, systemImage: activeYouTubeSource.descriptor.symbolName)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(activeYouTubeSource.tint.opacity(0.14), in: Capsule())
            .foregroundStyle(activeYouTubeSource.tint)
            .help("Playback uses the visible official YouTube player")
    }

    private func refreshMusicSurfacesIfNeeded(force: Bool = false) async {
        guard currentSection == .search || (currentSection == .library && accountViewModel.state.canDisconnect) else { return }
        await searchViewModel.refreshMusicDiscovery(engine: musicEngine, force: force)
    }

    private func loadInitialPageState() async {
        configurePlaybackBridge()
        rebuildPageCaches()
        refreshCacheStats()
        presentWelcomeIfNeeded()
        await accountViewModel.refreshStoredAccount()
        await loadAccountLibraryIfConnected()
        await refreshMusicSurfacesIfNeeded()
        await runInitialSearchIfNeeded()
        await runProviderComparisonIfNeeded()
        rebuildPageCaches()
    }

    private func handleSectionChange(_ newSection: LibrarySection) async {
        if newSection == .listenNow {
            appState.open(.library)
            return
        }
        if newSection == .library {
            await loadAccountLibraryIfConnected()
        }
        await refreshMusicSurfacesIfNeeded()
        if newSection == .providerLab {
            await runProviderComparisonIfNeeded()
        }
    }

    private func loadAccountLibraryIfConnected() async {
        guard accountViewModel.state.canDisconnect else {
            AppLog.playlist.info("Skipping account library load while Google is signed out")
            return
        }
        await searchViewModel.loadLibraryData()
    }

    private func presentWelcomeIfNeeded() {
        guard !hasSeenPhonoDeckWelcome, !isWelcomePresented else { return }
        if currentSection != .library {
            appState.open(.library)
        }
        isWelcomePresented = true
    }

    private func markWelcomeSeen() {
        hasSeenPhonoDeckWelcome = true
        isWelcomePresented = false
    }

    private func connectYouTubeFromWelcome() {
        welcomeStatusMessage = "Opening Google sign-in..."
        Task {
            await accountViewModel.connect()
            welcomeStatusMessage = accountViewModel.pollStatus
            if accountViewModel.state.canDisconnect {
                await loadAccountLibraryIfConnected()
                rebuildPageCaches()
                markWelcomeSeen()
            }
        }
    }

    private func showPlannedConnection(for source: MediaSourceKind) {
        welcomeStatusMessage = "\(source.descriptor.displayName) connection is planned; this source will stay separate and capability-aware when its adapter lands."
        AppLog.app.info("Planned source connection selected from welcome; source=\(source.rawValue, privacy: .public)")
    }

    private func runInitialSearchIfNeeded() async {
        guard !didRunInitialSearch else { return }
        didRunInitialSearch = true
        guard currentSection == .search else { return }
        if let firstRecentSearch = recentSearchesRaw.split(separator: "\n").map(String.init).first {
            searchText = firstRecentSearch
            await searchViewModel.search(firstRecentSearch, preference: playbackPreference, engine: musicEngine)
        }
    }

    private func runProviderComparisonIfNeeded() async {
        guard currentSection == .providerLab else { return }
        await runProviderComparison(force: false)
    }

    private func runProviderComparison(force: Bool) async {
        let query = providerLabQuery
        guard !query.isEmpty else { return }
        guard force || query != lastProviderLabQuery || searchViewModel.providerComparisons.isEmpty else { return }
        lastProviderLabQuery = query
        await searchViewModel.compareProviders(query: query, preference: playbackPreference)
    }

    private var currentSection: LibrarySection {
        appState.selectedSection ?? .library
    }

    private var shouldShowNowPlayingPanel: Bool {
        searchViewModel.selectedVideo != nil || isVideoVisible || playerController.currentVideoID != nil
    }

    private var youtubeConnectButtonTitle: String {
        switch accountViewModel.state {
        case .signedOut:
            "Add YouTube / YouTube Music"
        case .connecting:
            "Adding YouTube / YouTube Music"
        case .connected, .stored:
            "YouTube / YouTube Music Added"
        case .failed:
            "Retry YouTube / YouTube Music"
        }
    }

    private var sectionTitle: String {
        switch currentSection {
        case .listenNow:
            listenNowVideos.isEmpty ? "Listen Now" : "Recommended Songs"
        case .library:
            "Library"
        case .albums:
            "Albums"
        case .artists:
            "Artists"
        case .playlists:
            searchViewModel.selectedPlaylist?.snippet.title ?? "YouTube Music Playlists"
        case .queue:
            "Queue"
        case .search:
            "Songs"
        case .downloads:
            "Downloads"
        case .devices:
            "Devices"
        case .providerLab:
            "Provider Lab"
        case .settings:
            "Settings"
        }
    }

    private var breadcrumbTrail: some View {
        HStack(spacing: 5) {
            ForEach(Array(breadcrumbItems.enumerated()), id: \.offset) { index, item in
                if index > 0 {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                Text(item)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(index == breadcrumbItems.count - 1 ? .secondary : .primary)
                    .lineLimit(1)
            }
        }
    }

    private var breadcrumbItems: [String] {
        switch currentSection {
        case .listenNow:
            ["Music", "Listen Now"]
        case .library:
            ["Music", "Library"]
        case .albums:
            ["Music", "Albums", selectedAlbum?.title ?? "All Albums"]
        case .artists:
            ["Music", "Artists", selectedArtist?.name ?? "All Artists"]
        case .playlists:
            ["Music", "Playlists", searchViewModel.selectedPlaylist?.snippet.title ?? "All Playlists"]
        case .queue:
            ["Music", "Queue"]
        case .search:
            ["Music", "Search"]
        case .downloads:
            ["Music", "Storage"]
        case .devices:
            ["Music", "Devices"]
        case .providerLab:
            ["Music", "Provider Lab"]
        case .settings:
            ["Music", "Settings"]
        }
    }

    private var sectionSubtitle: String {
        switch currentSection {
        case .listenNow:
            "YouTube Music songs from cached metadata, PhonoDeck history, and account activity when connected."
        case .library:
            "YouTube Music songs, playlists, cached metadata, and connected source status in one place."
        case .albums, .artists:
            "Browse albums and artists derived from the current PhonoDeck music library with source attribution."
        case .playlists:
            "Your YouTube Music playlist surface, backed by the official YouTube account playlist API."
        case .queue:
            "The local PhonoDeck queue used by Next, Previous, failed-embed skipping, and Watch remote control later."
        case .search:
            "Find YouTube Music songs first; switch to Video for clips and music videos."
        case .downloads:
            "Downloads are reserved for sources that explicitly allow offline storage."
        case .devices:
            "Device routing will be source-aware; the visible YouTube player controls its own output."
        case .providerLab:
            "Temporary engine diagnostics for official YouTube API readiness and disabled metadata policy."
        case .settings:
            "Source configuration and playback policy live here without changing the active YouTube source."
        }
    }

    private var sectionVideos: [YouTubeVideoSearchResult] {
        switch currentSection {
        case .listenNow:
            listenNowVideos
        case .playlists:
            displayedPlaylistVideos
        case .search:
            searchViewModel.results
        default:
            searchViewModel.results
        }
    }

    private var libraryCacheKey: String {
        [
            albumFilterText,
            albumSortRaw,
            artistFilterText,
            artistSortRaw,
            searchViewModel.selectedVideoDetails?.id ?? "",
            videoCacheKey(searchViewModel.playbackHistory),
            videoCacheKey(searchViewModel.musicDiscoveryVideos),
            videoCacheKey(searchViewModel.playlistVideos),
            videoCacheKey(searchViewModel.results)
        ].joined(separator: "|")
    }

    private var playlistDisplayCacheKey: String {
        [
            searchViewModel.selectedPlaylist?.id ?? "",
            playlistFilterText,
            playlistSortRaw,
            videoCacheKey(searchViewModel.playlistVideos)
        ].joined(separator: "|")
    }

    private func videoCacheKey(_ videos: [YouTubeVideoSearchResult]) -> String {
        videos.map { "\($0.stableListID):\($0.playlistAddedAt ?? "")" }.joined(separator: ",")
    }

    private var sectionCountText: String {
        let count = sectionVideos.count
        guard count > 0, !showsRoadmapPanel else { return "" }
        return "\(count) \(count == 1 ? "song" : "songs")"
    }

    private var librarySongs: [YouTubeVideoSearchResult] {
        cachedLibrarySongs
    }

    private var displayedPlaylistVideos: [YouTubeVideoSearchResult] {
        cachedDisplayedPlaylistVideos
    }

    private func playlistAddedDate(_ video: YouTubeVideoSearchResult) -> Date {
        guard let playlistAddedAt = video.playlistAddedAt else { return .distantPast }
        return ISO8601DateFormatter().date(from: playlistAddedAt) ?? .distantPast
    }

    private var musicTracks: [MusicTrack] {
        cachedMusicTracks
    }

    private var musicAlbums: [MusicAlbum] {
        cachedMusicAlbums
    }

    private var displayedMusicAlbums: [MusicAlbum] {
        cachedDisplayedMusicAlbums
    }

    private var musicArtists: [MusicArtist] {
        cachedMusicArtists
    }

    private var displayedMusicArtists: [MusicArtist] {
        cachedDisplayedMusicArtists
    }

    private var selectedAlbum: MusicAlbum? {
        guard let selectedAlbumID else { return nil }
        return musicAlbums.first { $0.id == selectedAlbumID }
    }

    private var selectedArtist: MusicArtist? {
        guard let selectedArtistID else { return nil }
        return musicArtists.first { $0.id == selectedArtistID }
    }

    private func albumVideos(for album: MusicAlbum) -> [YouTubeVideoSearchResult] {
        cachedAlbumVideosByID[album.id] ?? []
    }

    private func artistVideos(for artist: MusicArtist) -> [YouTubeVideoSearchResult] {
        cachedArtistVideosByID[artist.id] ?? []
    }

    private func albumRecentIndex(_ album: MusicAlbum) -> Int {
        librarySongs.firstIndex { result in
            result.mediaSourceKind == album.source &&
            result.musicIdentity.artistName == album.artistName &&
            result.musicAlbumBucketTitle == album.title
        } ?? Int.max
    }

    private func artistRecentIndex(_ artist: MusicArtist) -> Int {
        librarySongs.firstIndex { result in
            result.mediaSourceKind == artist.source && result.musicIdentity.artistName == artist.name
        } ?? Int.max
    }

    private func albumDurationSeconds(for videos: [YouTubeVideoSearchResult]) -> TimeInterval? {
        let durations = videos.compactMap { video -> TimeInterval? in
            guard searchViewModel.selectedVideoDetails?.id == video.id,
                  let duration = searchViewModel.selectedVideoDetails?.contentDetails?.duration,
                  let seconds = YouTubeVideoDetails.durationSeconds(from: duration) else { return nil }
            return TimeInterval(seconds)
        }
        guard !durations.isEmpty else { return nil }
        return durations.reduce(0, +)
    }

    private func rebuildPageCaches() {
        rebuildLibraryCaches()
        rebuildPlaylistDisplayCache()
    }

    private func rebuildLibraryCaches() {
        let currentSelection = searchViewModel.selectedVideo.map { [$0] } ?? []
        let nowPlayingSelection = appState.youtubeNowPlaying.map { [$0] } ?? []
        let mergedVideos = currentSelection + nowPlayingSelection + searchViewModel.playbackHistory + searchViewModel.musicDiscoveryVideos + searchViewModel.playlistVideos + searchViewModel.results
        let deduplicatedVideos = mergedVideos.deduplicatedByVideoID()
        let songLikeVideos = deduplicatedVideos.filter(\.isSongLike)
        let libraryItems = songLikeVideos.isEmpty ? deduplicatedVideos : songLikeVideos
        cachedLibrarySongs = libraryItems

        cachedMusicTracks = libraryItems.map { result in
            let identity = result.musicIdentity
            return MusicTrack(
                id: .init(source: result.mediaSourceKind, rawValue: result.id),
                title: result.title,
                artistName: identity.artistName,
                albumTitle: identity.albumTitle,
                durationSeconds: nil,
                releaseYear: nil,
                recordLabel: nil,
                artworkURL: result.thumbnailURL,
                source: result.mediaSourceKind,
                sourceURL: result.watchURL
            )
        }

        let albumGroups = Dictionary(grouping: libraryItems) { result in
            "\(result.mediaSourceKind.rawValue)|\(result.musicIdentity.artistName)|\(result.musicAlbumBucketTitle)"
        }
        var albumVideosByID: [MusicProviderEntityID: [YouTubeVideoSearchResult]] = [:]
        let albums = albumGroups.values.compactMap { videos -> MusicAlbum? in
            guard let firstVideo = videos.first else { return nil }
            let identity = firstVideo.musicIdentity
            let title = firstVideo.musicAlbumBucketTitle
            let album = MusicAlbum(
                id: .init(source: firstVideo.mediaSourceKind, rawValue: "\(identity.artistName)|\(title)"),
                title: title,
                artistName: identity.artistName,
                releaseYear: nil,
                recordLabel: nil,
                artworkURL: firstVideo.thumbnailURL,
                source: firstVideo.mediaSourceKind,
                trackCount: videos.deduplicatedByVideoID().count,
                durationSeconds: albumDurationSeconds(for: videos),
                sourceURL: firstVideo.watchURL
            )
            albumVideosByID[album.id] = videos.deduplicatedByVideoID()
            return album
        }
        .sorted { left, right in
            if left.artistName.localizedCaseInsensitiveCompare(right.artistName) == .orderedSame {
                return left.title.localizedCaseInsensitiveCompare(right.title) == .orderedAscending
            }
            return left.artistName.localizedCaseInsensitiveCompare(right.artistName) == .orderedAscending
        }
        cachedAlbumVideosByID = albumVideosByID
        cachedMusicAlbums = albums
        cachedDisplayedMusicAlbums = displayedAlbums(from: albums)

        let artistGroups = Dictionary(grouping: libraryItems) { result in
            "\(result.mediaSourceKind.rawValue)|\(result.musicIdentity.artistName)"
        }
        var artistVideosByID: [MusicProviderEntityID: [YouTubeVideoSearchResult]] = [:]
        let artists = artistGroups.values.compactMap { videos -> MusicArtist? in
            guard let firstVideo = videos.first else { return nil }
            let identity = firstVideo.musicIdentity
            let albumTitles = Set(videos.map(\.musicAlbumBucketTitle))
            let artist = MusicArtist(
                id: .init(source: firstVideo.mediaSourceKind, rawValue: identity.artistName),
                name: identity.artistName,
                artworkURL: firstVideo.thumbnailURL,
                source: firstVideo.mediaSourceKind,
                albumCount: albumTitles.count,
                trackCount: videos.deduplicatedByVideoID().count,
                localPlayTimeSeconds: 0,
                sourceURL: firstVideo.watchURL
            )
            artistVideosByID[artist.id] = videos.deduplicatedByVideoID()
            return artist
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        cachedArtistVideosByID = artistVideosByID
        cachedMusicArtists = artists
        cachedDisplayedMusicArtists = displayedArtists(from: artists)
    }

    private func displayedAlbums(from albums: [MusicAlbum]) -> [MusicAlbum] {
        let query = albumFilterText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filteredAlbums = albums.filter { album in
            guard !query.isEmpty else { return true }
            return album.title.localizedCaseInsensitiveContains(query) || album.artistName.localizedCaseInsensitiveContains(query)
        }

        switch albumSortRaw {
        case "title":
            return filteredAlbums.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case "recent":
            return filteredAlbums.sorted { albumRecentIndex($0) < albumRecentIndex($1) }
        default:
            return filteredAlbums
        }
    }

    private func displayedArtists(from artists: [MusicArtist]) -> [MusicArtist] {
        let query = artistFilterText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filteredArtists = artists.filter { artist in
            guard !query.isEmpty else { return true }
            return artist.name.localizedCaseInsensitiveContains(query)
        }

        switch artistSortRaw {
        case "songs":
            return filteredArtists.sorted { ($0.trackCount ?? 0) > ($1.trackCount ?? 0) }
        case "recent":
            return filteredArtists.sorted { artistRecentIndex($0) < artistRecentIndex($1) }
        default:
            return filteredArtists
        }
    }

    private func rebuildPlaylistDisplayCache() {
        let query = playlistFilterText.trimmingCharacters(in: .whitespacesAndNewlines)
        let playlistTitle = searchViewModel.selectedPlaylist?.snippet.title ?? ""
        let filteredVideos = searchViewModel.playlistVideos.filter { video in
            guard !query.isEmpty else { return true }
            return video.title.localizedCaseInsensitiveContains(query) || video.channelTitle.localizedCaseInsensitiveContains(query) || playlistTitle.localizedCaseInsensitiveContains(query)
        }

        cachedDisplayedPlaylistVideos = switch playlistSortRaw {
        case "title":
            filteredVideos.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case "artist":
            filteredVideos.sorted { $0.channelTitle.localizedCaseInsensitiveCompare($1.channelTitle) == .orderedAscending }
        case "source":
            filteredVideos.sorted { left, right in
                let leftSource = left.mediaSourceKind.descriptor.displayName
                let rightSource = right.mediaSourceKind.descriptor.displayName
                if leftSource == rightSource {
                    return left.title.localizedCaseInsensitiveCompare(right.title) == .orderedAscending
                }
                return leftSource.localizedCaseInsensitiveCompare(rightSource) == .orderedAscending
            }
        default:
            filteredVideos.sorted { playlistAddedDate($0) > playlistAddedDate($1) }
        }
    }

    private var listenNowVideos: [YouTubeVideoSearchResult] {
        let mergedVideos = (searchViewModel.playbackHistory + searchViewModel.musicDiscoveryVideos + searchViewModel.results + searchViewModel.activityVideos).deduplicatedByVideoID()
        let songs = mergedVideos.filter(\.isSongLike)
        return songs.isEmpty ? mergedVideos : songs
    }

    private var showsRoadmapPanel: Bool {
        switch currentSection {
        case .library, .albums, .artists, .queue, .downloads, .devices, .providerLab, .settings:
            true
        default:
            false
        }
    }

    private var emptyStateTitle: String {
        switch currentSection {
        case .listenNow:
            searchViewModel.isSearching || searchViewModel.isRefreshingMusicDiscovery ? "Loading Songs" : "No YouTube Music Songs Yet"
        case .playlists:
            "No YouTube Music Playlist Songs Loaded"
        default:
            "No Songs Loaded"
        }
    }

    private var emptyStateDetail: String {
        switch currentSection {
        case .listenNow:
            searchViewModel.isSearching || searchViewModel.isRefreshingMusicDiscovery ? "PhonoDeck is loading song-first YouTube Music results." : "Search for a song to start playback, or open Search for more focused results."
        case .playlists:
            "Choose a YouTube Music playlist above, or search for songs while playlist loading catches up."
        default:
            "Search YouTube Music for songs, or switch to Video for clips."
        }
    }

    private var playbackPreference: YouTubePlaybackPreference {
        YouTubePlaybackPreference(rawValue: playbackPreferenceRaw) ?? .songFirst
    }

    private var musicEngine: YouTubeMusicEngine {
        YouTubeMusicEngine(rawValue: musicEngineRaw) ?? .automatic
    }

    private var activeYouTubeSource: MediaSourceKind {
        playbackPreference == .videoFirst ? .youtube : .youtubeMusic
    }

    private var selectedPlaylistSourceKind: MediaSourceKind {
        let videos = searchViewModel.playlistVideos
        guard !videos.isEmpty else { return .youtubeMusic }
        let musicCount = videos.filter(\.isSongLike).count
        return musicCount >= max(1, videos.count / 2) ? .youtubeMusic : .youtube
    }

    private func selectedPlaylistSourceLabel(for playlist: YouTubePlaylist) -> String {
        let videos = searchViewModel.selectedPlaylist?.id == playlist.id ? searchViewModel.playlistVideos : []
        guard !videos.isEmpty else { return "YouTube Music" }
        let musicCount = videos.filter(\.isSongLike).count
        if musicCount == videos.count { return "YouTube Music" }
        if musicCount == 0 { return "YouTube" }
        return "Mixed YouTube"
    }

    private func playlistSourceKind(for playlist: YouTubePlaylist) -> MediaSourceKind {
        searchViewModel.selectedPlaylist?.id == playlist.id ? selectedPlaylistSourceKind : .youtube
    }

    private func playlistSourceLabel(for playlist: YouTubePlaylist) -> String {
        searchViewModel.selectedPlaylist?.id == playlist.id ? selectedPlaylistSourceLabel(for: playlist) : "YouTube Playlist"
    }

    private var showsInlineResultModePicker: Bool {
        currentSection == .search || currentSection == .providerLab
    }

    private func sourceStatus(for source: MediaSourceKind) -> String {
        switch source {
        case .youtube, .youtubeMusic:
            "Active"
        case .plex, .spotify, .ownFiles:
            "Planned"
        }
    }

    private var providerLabQuery: String {
        let recentSearch = recentSearchesRaw.split(separator: "\n").map(String.init).first
        let candidates: [String] = [searchText, searchViewModel.selectedVideo?.title, lastVideoTitle, recentSearch]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        return candidates.first(where: { !$0.isEmpty }) ?? ""
    }

    private func play(_ result: YouTubeVideoSearchResult, queue: [YouTubeVideoSearchResult]) {
        AppLog.playback.info("UI play requested; id=\(result.id, privacy: .public), title=\(result.title, privacy: .private), queue=\(queue.count, privacy: .public)")
        isVideoVisible = true
        searchViewModel.play(result, queue: queue)
        appState.youtubeNowPlaying = result
        playerController.load(video: result, autoplay: true)
        rebuildPageCaches()
    }

    private func findOtherSources(for video: YouTubeVideoSearchResult) {
        searchViewModel.select(video, queue: sectionVideos)
        let query = "\(video.title) \(video.channelTitle)"
            .replacingOccurrences(of: "(Official Audio)", with: "")
            .replacingOccurrences(of: "[Official Audio]", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        searchText = query
        appState.open(.providerLab)
        lastProviderLabQuery = ""
        Task { await runProviderComparison(force: true) }
    }

    private func playlistRemoveAction(for video: YouTubeVideoSearchResult) -> (() -> Void)? {
        guard currentSection == .playlists, let selectedPlaylist = searchViewModel.selectedPlaylist else { return nil }
        guard video.playlistItemID != nil else { return nil }
        return {
            Task { await searchViewModel.remove(video, from: selectedPlaylist) }
        }
    }

    @ViewBuilder
    private func relatedMusicPanel(for video: YouTubeVideoSearchResult, title: String) -> some View {
        let relatedItems = relatedMusic(for: video)
        if !relatedItems.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                SongCarouselShelf(
                    title: "",
                    items: Array(relatedItems.prefix(8)),
                    selectAction: { searchViewModel.select($0, queue: relatedItems) },
                    playAction: { play($0, queue: relatedItems) }
                )
            }
            .padding(12)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private func relatedMusic(for video: YouTubeVideoSearchResult) -> [YouTubeVideoSearchResult] {
        let identity = video.musicIdentity
        let candidates = (cachedLibrarySongs + searchViewModel.musicDiscoveryVideos + searchViewModel.results + searchViewModel.playlistVideos)
            .deduplicatedByVideoID()
            .filter { $0.id != video.id }
        let sameArtist = candidates.filter { $0.musicIdentity.artistName == identity.artistName }
        if !sameArtist.isEmpty { return sameArtist }
        let sameSource = candidates.filter { $0.mediaSourceKind == video.mediaSourceKind && $0.isSongLike == video.isSongLike }
        return sameSource.isEmpty ? candidates.filter(\.isSongLike) : sameSource
    }

    @ViewBuilder
    private func inspectorPanel(_ video: YouTubeVideoSearchResult) -> some View {
        switch inspectorMode {
        case .info:
            musicInfoPanel(video)
        case .lyrics:
            VStack(alignment: .leading, spacing: 6) {
                Text("Lyrics")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if video.songBadge == "Lyrics" {
                    Text("This result appears to be a lyric video. Use the visible YouTube player for synced lyrics.")
                } else {
                    Text("PhonoDeck searches official YouTube results for lyric videos. It does not scrape lyrics.")
                    if !lyricsStatus.isEmpty {
                        Text(lyricsStatus)
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        openLyrics(for: video)
                    } label: {
                        Label("Find Lyric Video", systemImage: "magnifyingglass")
                    }
                }
            }
            .font(.caption)
            .padding(10)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        case .none:
            EmptyView()
        }
    }

    private func musicInfoPanel(_ video: YouTubeVideoSearchResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Music Info")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(video.title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(3)
                }
                Spacer()
                Text(video.mediaSourceKind.descriptor.displayName)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(video.mediaSourceKind.tint.opacity(0.15), in: Capsule())
                    .foregroundStyle(video.mediaSourceKind.tint)
            }

            if let details = searchViewModel.selectedVideoDetails {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    MusicFactTile(title: "Duration", value: details.formattedDuration ?? timeText, symbol: "clock")
                    MusicFactTile(title: "Year", value: details.releaseYear ?? "Not exposed", symbol: "calendar")
                    MusicFactTile(title: "Quality", value: details.qualitySummary, symbol: "waveform")
                    MusicFactTile(title: "Bitrate", value: details.audioBitrateSummary, symbol: "speedometer")
                    MusicFactTile(title: "Label", value: details.labelSummary, symbol: "record.circle")
                }
                Text("YouTube video details come from the documented YouTube Data API. Audio codec and exact bitrate are controlled by the visible YouTube player and are not exposed to PhonoDeck.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 5) {
                    MusicInfoLine(title: "Artist / Channel", value: video.channelTitle)
                    MusicInfoLine(title: "Kind", value: video.songBadge)
                    MusicInfoLine(title: "Lyrics", value: lyricsAvailabilityText(for: video, details: details))
                    MusicInfoLine(title: "Trivia", value: "No official trivia provider connected yet; future candidates are MusicBrainz/Wikipedia-style metadata, not YouTube claims.")
                    MusicInfoLine(title: "Local listening", value: "\(formattedLocalListeningTime) in PhonoDeck on this Mac; cross-device hours are not exposed by YouTube.")
                    if let viewCount = details.statistics?.viewCount {
                        MusicInfoLine(title: "YouTube views", value: formattedCount(viewCount))
                    }
                    if let likeCount = details.statistics?.likeCount {
                        MusicInfoLine(title: "YouTube likes", value: formattedCount(likeCount))
                    }
                }
            } else {
                Text("Connect Google to load official duration, publication year, captions, and playback metadata for this item.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let queuePositionText = searchViewModel.queuePositionText {
                Text("Queue \(queuePositionText)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text("Video ID: \(video.id)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            HStack {
                ShareLink(item: video.watchURL) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                Button {
                    NSWorkspace.shared.open(video.watchURL)
                } label: {
                    Label("Open", systemImage: "arrow.up.right.square")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func lyricsAvailabilityText(for video: YouTubeVideoSearchResult, details: YouTubeVideoDetails) -> String {
        if video.resultKind == .lyrics {
            return "This playable item is a lyric video."
        }
        if details.contentDetails?.caption == "true" {
            return "Captions are available; synced YouTube Music lyrics are not exposed by the public API."
        }
        return "Synced YouTube Music lyrics are not exposed by the public API; PhonoDeck can search lyric videos."
    }

    private var formattedLocalListeningTime: String {
        let totalSeconds = max(Int(localPlayedSeconds + pendingLocalPlayedSeconds), 0)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m played"
        }
        return "\(minutes)m played"
    }

    private func formattedCount(_ value: String) -> String {
        guard let number = Int(value) else { return value }
        return number.formatted(.number)
    }

    private func configurePlaybackBridge() {
        appState.youtubePlayback.setHandlers(
            playPause: { togglePanelPlayback() },
            previous: { playPreviousFromQueue() },
            next: { playNextFromQueue() },
            mute: { playerController.toggleMute() },
            volume: { playerController.setVolume($0) }
        )
        updatePlaybackBridge()
    }

    private func updatePlaybackBridge() {
        let effectivePlayerState: YouTubeEmbeddedPlayerState = if !isVideoVisible, searchViewModel.selectedVideo != nil {
            .ready
        } else {
            playerController.playerState
        }
        appState.youtubePlayback.update(
            canPlayPrevious: searchViewModel.canPlayPrevious,
            canPlayNext: searchViewModel.canPlayNext,
            playerState: effectivePlayerState,
            volume: playerController.volume,
            isMuted: playerController.isMuted,
            currentTime: playerController.currentTime,
            duration: playerController.duration
        )
    }

    private func handlePlayerStateChange(_ playerState: YouTubeEmbeddedPlayerState) {
        AppLog.player.info("UI observed player state change; state=\(playerState.title, privacy: .public), selected=\(self.searchViewModel.selectedVideo?.id ?? "none", privacy: .public), currentVideo=\(self.playerController.currentVideoID ?? "none", privacy: .public)")
        updatePlaybackBridge()
        if playerState != .playing {
            flushLocalListeningProgress()
        }
        switch playerState {
        case .failed(let message):
            handleEmbeddedPlaybackFailure(message)
        case .ended where searchViewModel.canPlayNext:
            playNextFromQueue()
        default:
            break
        }
    }

    private var timeText: String {
        guard playerController.duration > 0 else { return "--:--" }
        return "\(formatTime(playerController.currentTime)) / \(formatTime(playerController.duration))"
    }

    private func formatTime(_ seconds: Double) -> String {
        let totalSeconds = max(Int(seconds), 0)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func formattedBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func trackLocalListening(previousTime: Double, currentTime: Double) {
        guard playerController.playerState == .playing, searchViewModel.selectedVideo != nil else {
            return
        }

        let delta = currentTime - previousTime
        if delta > 0, delta < 3 {
            pendingLocalPlayedSeconds += delta
            if Date().timeIntervalSince(lastLocalListeningPersistDate) >= 5 {
                flushLocalListeningProgress()
            }
        }
    }

    private func flushLocalListeningProgress() {
        guard pendingLocalPlayedSeconds > 0 else { return }
        localPlayedSeconds += pendingLocalPlayedSeconds
        pendingLocalPlayedSeconds = 0
        lastLocalListeningPersistDate = Date()
    }

    private func refreshCacheStats() {
        let artworkMeasurement = ArtworkCache.shared.diskUsageMeasurement()
        artworkCacheBytes = artworkMeasurement.bytes
        storageSnapshot = MusicStorageSnapshot.make(
            artworkBytes: artworkCacheBytes,
            metadataBytes: searchViewModel.metadataCacheUsageBytes,
            evidenceSource: "ArtworkCache + UserDefaults metadata cache",
            measurementStatus: artworkMeasurement.status,
            measurementIssue: artworkMeasurement.issue
        )
    }

    private func clearStorageCaches(_ target: StorageCacheClearTarget) {
        AppLog.cache.info("UI clear cache requested; target=\(target.rawValue, privacy: .public)")
        let previousBytes = target.previousBytes(from: storageSnapshot)
        switch target {
        case .artwork:
            ArtworkCache.shared.clear()
        case .metadata:
            searchViewModel.clearMetadataCaches()
        case .all:
            ArtworkCache.shared.clear()
            searchViewModel.clearMetadataCaches()
        }
        storageStatusMessage = target.clearedMessage
        storageClearReceipt = StorageCacheClearReceipt(target: target.receiptTarget, completedAt: Date(), previousBytes: previousBytes, retainedData: target.retainedData)
        refreshCacheStats()
    }

    private func openSoundSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension") else { return }
        NSWorkspace.shared.open(url)
    }

    private func openHomeApp() {
        if let homeURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Home") {
            NSWorkspace.shared.openApplication(at: homeURL, configuration: .init())
        }
    }

    private func openLyrics(for video: YouTubeVideoSearchResult) {
        inspectorMode = .lyrics
        lyricsStatus = ""
        guard video.songBadge != "Lyrics" else {
            play(video, queue: sectionVideos)
            return
        }

        let lyricQuery = "\(video.title.replacingOccurrences(of: "(Official Audio)", with: "")) \(video.channelTitle) lyrics"
        searchText = lyricQuery
        appState.open(.search)
        rememberSearch(lyricQuery)
        lyricsStatus = "Searching lyric videos..."
        Task {
            await searchViewModel.search(lyricQuery, preference: .balanced, engine: musicEngine)
            if let lyricVideo = searchViewModel.results.first(where: { $0.songBadge == "Lyrics" }) {
                lyricsStatus = "Found a lyric video."
                play(lyricVideo, queue: searchViewModel.results)
            } else {
                lyricsStatus = "No lyric video found for this song. Synced YouTube Music lyrics are not exposed by the public API."
            }
        }
    }

    private func playPreviousFromQueue() {
        guard let previousVideo = searchViewModel.playPrevious() else { return }
        AppLog.playback.info("UI previous from queue; id=\(previousVideo.id, privacy: .public), title=\(previousVideo.title, privacy: .private)")
        isVideoVisible = true
        appState.youtubeNowPlaying = previousVideo
        persistLastPlayback(previousVideo)
        playerController.load(video: previousVideo, autoplay: true)
    }

    private func playNextFromQueue() {
        guard let nextVideo = searchViewModel.playNext() else { return }
        AppLog.playback.info("UI next from queue; id=\(nextVideo.id, privacy: .public), title=\(nextVideo.title, privacy: .private)")
        isVideoVisible = true
        appState.youtubeNowPlaying = nextVideo
        persistLastPlayback(nextVideo)
        playerController.load(video: nextVideo, autoplay: true)
    }

    private func handleEmbeddedPlaybackFailure(_ message: String) {
        AppLog.player.error("UI handling embedded playback failure; message=\(message, privacy: .public), selected=\(self.searchViewModel.selectedVideo?.id ?? "none", privacy: .public)")
        guard let replacement = searchViewModel.skipFailedSelectedVideo(reason: message) else {
            updatePlaybackBridge()
            AppLog.player.error("No replacement available after embedded playback failure")
            return
        }
        AppLog.player.warning("Loading replacement after embedded playback failure; replacement=\(replacement.id, privacy: .public)")
        appState.youtubeNowPlaying = replacement
        persistLastPlayback(replacement)
        isVideoVisible = true
        playerController.load(video: replacement, autoplay: true)
    }

    private func restoreLastPlaybackIfNeeded() {
        guard !lastVideoID.isEmpty, !lastVideoTitle.isEmpty else { return }
        let restoredVideo = YouTubeVideoSearchResult(
            id: lastVideoID,
            title: lastVideoTitle,
            channelTitle: lastVideoChannel.isEmpty ? "YouTube" : lastVideoChannel,
            thumbnailURL: URL(string: lastVideoThumbnailURL),
            sourceLabel: "Recent"
        )
        guard playbackPreference != .songFirst || restoredVideo.isSongLike else { return }
        searchViewModel.restoreLastSelection(restoredVideo)
        appState.youtubeNowPlaying = restoredVideo
    }

    private func persistLastPlayback(_ video: YouTubeVideoSearchResult) {
        lastVideoID = video.id
        lastVideoTitle = video.title
        lastVideoChannel = video.channelTitle
        lastVideoThumbnailURL = video.thumbnailURL?.absoluteString ?? ""
    }

    private var quickSearchSuggestions: [String] {
        let recentSearches = recentSearchesRaw
            .split(separator: "\n")
            .map(String.init)
        let contextualSearches = [lastVideoChannel, searchText]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return (recentSearches + contextualSearches).deduplicatedStrings().prefix(4).map { $0 }
    }

    private func searchFromUI(_ query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }
        rememberSearch(trimmedQuery)
        Task {
            await searchViewModel.search(trimmedQuery, preference: playbackPreference, engine: musicEngine)
            rebuildPageCaches()
        }
    }

    private func handleInlineResultModeChange() {
        switch currentSection {
        case .search:
            searchFromUI(searchText)
        case .providerLab:
            lastProviderLabQuery = ""
            Task { await runProviderComparisonIfNeeded() }
        default:
            break
        }
    }

    private func rememberSearch(_ query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }
        let searches = ([trimmedQuery] + recentSearchesRaw.split(separator: "\n").map(String.init))
            .deduplicatedStrings()
            .prefix(6)
        recentSearchesRaw = searches.joined(separator: "\n")
    }
}

private enum YouTubeInspectorMode {
    case info
    case lyrics
}

private struct AlbumCard: View {
    let album: MusicAlbum
    let isSelected: Bool
    let action: () -> Void
    let playAction: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                CachedArtworkImage(url: album.artworkURL) {
                    Rectangle()
                        .fill(album.source.tint.opacity(0.18))
                        .overlay {
                            Image(systemName: "square.stack")
                                .font(.title2)
                                .foregroundStyle(album.source.tint)
                        }
                }
                .scaledToFill()
                .frame(height: 104)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                Text(album.title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(2)
                Text(album.artistName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Image(systemName: album.source.descriptor.symbolName)
                    Text("\(album.source.descriptor.displayName) · \(album.trackCount ?? 0) songs")
                }
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture(count: 2).onEnded(playAction))
        .contextMenu {
            Button("Play Album", action: playAction)
            if let sourceURL = album.sourceURL {
                ShareLink(item: sourceURL) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
        }
        .accessibilityLabel("Album \(album.title), \(album.artistName), source \(album.source.descriptor.displayName), \(album.trackCount ?? 0) songs")
        .accessibilityHint("Double-click to play this album")
    }
}

private struct ArtistCard: View {
    let artist: MusicArtist
    let isSelected: Bool
    let action: () -> Void
    let playAction: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                CachedArtworkImage(url: artist.artworkURL) {
                    Rectangle()
                        .fill(artist.source.tint.opacity(0.18))
                        .overlay {
                            Image(systemName: "music.mic")
                                .font(.title2)
                                .foregroundStyle(artist.source.tint)
                        }
                }
                .scaledToFill()
                .frame(height: 104)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                Text(artist.name)
                    .font(.callout.weight(.semibold))
                    .lineLimit(2)
                HStack(spacing: 5) {
                    Image(systemName: artist.source.descriptor.symbolName)
                    Text("\(artist.source.descriptor.displayName) · \(artist.trackCount ?? 0) songs")
                }
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                Text("\(artist.albumCount ?? 0) albums")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture(count: 2).onEnded(playAction))
        .contextMenu {
            Button("Play Artist Songs", action: playAction)
            if let sourceURL = artist.sourceURL {
                ShareLink(item: sourceURL) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
        }
        .accessibilityLabel("Artist \(artist.name), source \(artist.source.descriptor.displayName), \(artist.trackCount ?? 0) songs")
        .accessibilityHint("Double-click to play songs by this artist")
    }
}

private struct MusicCollectionDetailPanel: View {
    @State private var selectedTab: MusicCollectionDetailTab = .songs

    let title: String
    let subtitle: String
    let facts: [String]
    let symbol: String
    let source: MediaSourceKind
    let items: [YouTubeVideoSearchResult]
    let selectedVideo: YouTubeVideoSearchResult?
    let selectAction: (YouTubeVideoSearchResult) -> Void
    let playAction: (YouTubeVideoSearchResult) -> Void
    let infoAction: (YouTubeVideoSearchResult) -> Void
    let lyricsAction: (YouTubeVideoSearchResult) -> Void
    let queueAction: (YouTubeVideoSearchResult) -> Void
    let addMenu: (YouTubeVideoSearchResult) -> AnyView

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.title3)
                    .frame(width: 34, height: 34)
                    .background(source.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .foregroundStyle(source.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .lineLimit(2)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if !facts.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Media Info")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        ForEach(facts, id: \.self) { fact in
                            Text(fact)
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(source.tint.opacity(0.12), in: Capsule())
                                .foregroundStyle(source.tint)
                                .lineLimit(1)
                        }
                    }
                }
            }

            Picker("Collection Detail", selection: $selectedTab) {
                ForEach(MusicCollectionDetailTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 360)

            switch selectedTab {
            case .songs:
                VStack(spacing: 0) {
                    ForEach(items) { item in
                        VStack(spacing: 0) {
                            SongResultRow(
                                result: item,
                                isSelected: item == selectedVideo,
                                action: { selectAction(item) },
                                playAction: { playAction(item) },
                                infoAction: { infoAction(item) },
                                lyricsAction: { lyricsAction(item) },
                                queueAction: { queueAction(item) },
                                alternateSourcesAction: { infoAction(item) },
                                removeAction: nil
                            )
                            HStack {
                                Spacer()
                                addMenu(item)
                                    .buttonStyle(.bordered)
                                    .controlSize(.mini)
                            }
                            .padding(.trailing, 10)
                            .padding(.bottom, 6)
                        }
                        if item != items.last {
                            Divider().padding(.leading, 76)
                        }
                    }
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            case .reviews:
                CollectionInfoPlaceholder(
                    symbol: "star.bubble",
                    title: "Ratings & Reviews",
                    detail: "YouTube Data API does not expose editorial album reviews or canonical music ratings. Future MusicKit, Plex, Navidrome, or local metadata sources can fill this tab honestly."
                )
            case .related:
                let relatedItems = Array(items.dropFirst().prefix(8))
                if relatedItems.isEmpty {
                    CollectionInfoPlaceholder(symbol: "sparkles", title: "Related", detail: "No related cached tracks yet for this collection.")
                } else {
                    SongCarouselShelf(title: "Related", items: relatedItems, selectAction: selectAction, playAction: playAction)
                }
            }
        }
        .padding(14)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private enum MusicCollectionDetailTab: String, CaseIterable, Identifiable {
    case songs
    case reviews
    case related

    var id: String { rawValue }

    var title: String {
        switch self {
        case .songs: "Songs"
        case .reviews: "Ratings & Reviews"
        case .related: "Related"
        }
    }
}

private struct CollectionInfoPlaceholder: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .frame(width: 28, height: 28)
                .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.callout.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct LimitedCatalogEmptyState: View {
    let symbol: String
    let title: String
    let detail: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .frame(width: 38, height: 38)
                .background(Color.accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Button(action: action) {
                Label("Settings", systemImage: "gearshape")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(detail)")
    }
}

private struct QueueItemRow: View {
    let index: Int
    let item: YouTubeVideoSearchResult
    let isSelected: Bool
    let playAction: () -> Void
    let selectAction: () -> Void
    let removeAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("\(index)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .trailing)

            Button(action: selectAction) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                    Text(item.channelTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            SourcePill(source: item.mediaSourceKind, title: item.mediaSourceKind.shortDisplayName)

            Button(action: playAction) {
                Image(systemName: isSelected ? "speaker.wave.2.fill" : "play.fill")
            }
            .buttonStyle(.borderless)
            .help(isSelected ? "Currently selected" : "Play from here")

            Button(role: .destructive, action: removeAction) {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
            .help("Remove from queue")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(isSelected ? Color.accentColor.opacity(0.16) : Color.clear)
    }
}

private struct MusicCollectionToolbar: View {
    let filterPlaceholder: String
    @Binding var filterText: String
    @Binding var sortSelection: String
    let sortOptions: [(String, String)]
    let refreshAction: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(filterPlaceholder, text: $filterText)
                    .textFieldStyle(.plain)
                if !filterText.isEmpty {
                    Button {
                        filterText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Picker("Sort", selection: $sortSelection) {
                ForEach(sortOptions, id: \.0) { option in
                    Text(option.1).tag(option.0)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 240)

            Button(action: refreshAction) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
}

private struct MusicIdentity: Hashable {
    let artistName: String
    let albumTitle: String?
}

private struct AirPlayRoutePickerButton: NSViewRepresentable {
    func makeNSView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView(frame: .zero)
        picker.isRoutePickerButtonBordered = true
        return picker
    }

    func updateNSView(_ nsView: AVRoutePickerView, context: Context) {
    }
}

private struct MusicFactTile: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol)
                .frame(width: 22)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

private enum StorageCacheClearTarget: String, Identifiable {
    case artwork
    case metadata
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .artwork: "Clear Artwork Cache?"
        case .metadata: "Clear Metadata Cache?"
        case .all: "Clear Local Caches?"
        }
    }

    var message: String {
        switch self {
        case .artwork:
            "This removes cached artwork images only. YouTube audio and video files are not stored by PhonoDeck."
        case .metadata:
            "This removes cached search, playlist, discovery, and provider metadata only. It does not affect YouTube playlists or media files."
        case .all:
            "This removes PhonoDeck metadata and artwork caches. It does not delete owned files or YouTube account data."
        }
    }

    var confirmTitle: String {
        switch self {
        case .artwork: "Clear Artwork"
        case .metadata: "Clear Metadata"
        case .all: "Clear Caches"
        }
    }

    var clearedMessage: String {
        switch self {
        case .artwork: "Artwork cache cleared."
        case .metadata: "Metadata cache cleared."
        case .all: "Metadata and artwork caches cleared."
        }
    }

    var receiptTarget: String {
        switch self {
        case .artwork: "Artwork cache"
        case .metadata: "Metadata cache"
        case .all: "Metadata and artwork caches"
        }
    }

    var retainedData: String {
        switch self {
        case .artwork:
            "Retained metadata, account tokens, playlists, provider libraries, and media files."
        case .metadata:
            "Retained artwork, account tokens, playlists, provider libraries, and media files."
        case .all:
            "Retained account tokens, playlists, provider libraries, user-owned files, and media files."
        }
    }

    func previousBytes(from snapshot: MusicStorageSnapshot) -> Int64 {
        switch self {
        case .artwork: snapshot.artworkBytes
        case .metadata: snapshot.metadataBytes
        case .all: snapshot.artworkBytes + snapshot.metadataBytes
        }
    }
}

private struct StorageBoundaryPanel: View {
    let snapshot: MusicStorageSnapshot
    let refreshAction: () -> Void
    let settingsAction: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.shield")
                .font(.title3)
                .frame(width: 34, height: 34)
                .background(Color.green.opacity(0.15), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 5) {
                Text("Policy-Safe Storage")
                    .font(.headline)
                Text("This page manages PhonoDeck metadata and artwork caches plus future owned-media storage seams. It does not download YouTube or Spotify media, and Premium does not change that boundary.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    EvidenceChip(title: "Measured", value: snapshot.measuredAt.formatted(date: .abbreviated, time: .shortened))
                    EvidenceChip(title: "Source", value: snapshot.evidenceSource)
                }
            }

            Spacer(minLength: 12)

            HStack(spacing: 8) {
                Button(action: refreshAction) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh storage usage")
                Button(action: settingsAction) {
                    Image(systemName: "gearshape")
                }
                .help("Open cache settings")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct StorageCacheClearReceiptPanel: View {
    let receipt: StorageCacheClearReceipt

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.title3)
                .frame(width: 34, height: 34)
                .background(Color.green.opacity(0.15), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 5) {
                Text("\(receipt.target) cleared")
                    .font(.headline)
                Text("Completed \(receipt.completedAt.formatted(date: .abbreviated, time: .shortened)); previous size \(ByteCountFormatter.string(fromByteCount: receipt.previousBytes, countStyle: .file)).")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(receipt.retainedData)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct StorageCacheActionsPanel: View {
    let snapshot: MusicStorageSnapshot
    let statusMessage: String
    let clearArtworkAction: () -> Void
    let clearMetadataAction: () -> Void
    let clearAllAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Cache Controls")
                .font(.headline)
            Text("Actions are scoped to PhonoDeck metadata and artwork. They do not delete YouTube playlists, account data, or user-owned music files.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button(action: clearArtworkAction) {
                    Label("Clear Artwork", systemImage: "trash")
                }
                .disabled(snapshot.artworkBytes == 0)
                .help(snapshot.artworkBytes == 0 ? "No artwork cache to clear" : "Clear cached artwork only")

                Button(action: clearMetadataAction) {
                    Label("Clear Metadata", systemImage: "trash")
                }
                .disabled(snapshot.metadataBytes == 0)
                .help(snapshot.metadataBytes == 0 ? "No metadata cache to clear" : "Clear cached metadata only")

                Button(action: clearAllAction) {
                    Label("Clear All Caches", systemImage: "trash")
                }
                .disabled(snapshot.totalBytes == 0)
                .help(snapshot.totalBytes == 0 ? "No local caches to clear" : "Clear metadata and artwork caches")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct StorageAssetsPanel: View {
    let snapshot: MusicStorageSnapshot
    let searchAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Stored Items")
                .font(.headline)

            if snapshot.assets.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.title3)
                        .frame(width: 34, height: 34)
                        .background(Color.accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .foregroundStyle(Color.accentColor)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("No local cache yet")
                            .font(.callout.weight(.semibold))
                        Text("Search or browse music to populate metadata and artwork caches. YouTube media files will not appear here.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 12)

                    Button(action: searchAction) {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(snapshot.assets) { asset in
                        StorageAssetRow(asset: asset)
                    }
                }
            }

            if snapshot.blockedMediaAssetCount > 0 || snapshot.hasYouTubeMediaDownloads {
                Text("Blocked unsupported media storage entries before display.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct StorageAssetRow: View {
    let asset: MusicStorageAsset

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: asset.kind.symbolName)
                .font(.callout.weight(.semibold))
                .frame(width: 28, height: 28)
                .background(asset.status.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .foregroundStyle(asset.status.color)

            VStack(alignment: .leading, spacing: 3) {
                Text(asset.title)
                    .font(.callout.weight(.medium))
                    .lineLimit(2)
                Text("\(asset.source.descriptor.displayName) • \(asset.kind.title) • \(asset.status.title)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Text(ByteCountFormatter.string(fromByteCount: asset.byteCount, countStyle: .file))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(asset.title), \(asset.source.descriptor.displayName), \(asset.kind.title), \(asset.status.title)")
    }
}

private struct StorageSourcePolicyRow: View {
    let policy: MusicStorageSourcePolicy

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: policy.source.descriptor.symbolName)
                .font(.title3)
                .frame(width: 34, height: 34)
                .background(policy.status.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .foregroundStyle(policy.status.color)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(policy.source.descriptor.displayName)
                        .font(.headline)
                    Text(policy.status.rawValue)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(policy.status.color.opacity(0.14), in: Capsule())
                        .foregroundStyle(policy.status.color)
                }

                Text(policy.detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(policy.cacheDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(policy.filePermissionDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    ForEach(Array(policy.allowedKinds).sorted(by: { $0.title < $1.title }), id: \.self) { kind in
                        Text(kind.title)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.green.opacity(0.14), in: Capsule())
                            .foregroundStyle(Color.green)
                    }
                }
            }

            Spacer(minLength: 12)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct StorageSafetyPanel: View {
    private let rows: [(String, String, String, Color)] = [
        ("play.slash", "No hidden media paths", "No ytdl, stream extraction, copied cookies, or background YouTube media caches are exposed.", .red),
        ("folder.badge.gearshape", "Sandboxed files only", "Future Own Files imports must use user-selected file or folder access and surface permission errors.", .blue),
        ("exclamationmark.triangle", "No silent no-ops", "Unavailable actions are disabled and explain why through labels, status rows, or help text.", .orange)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Release Guardrails")
                .font(.headline)
            ForEach(rows, id: \.1) { row in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: row.0)
                        .frame(width: 26, height: 26)
                        .background(row.3.opacity(0.14), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .foregroundStyle(row.3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.1)
                            .font(.callout.weight(.semibold))
                        Text(row.2)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private extension MusicStoragePolicyStatus {
    var color: Color {
        switch self {
        case .local: .blue
        case .metadataOnly: .green
        case .planned: .orange
        case .unavailable: .red
        }
    }
}

private extension MusicStorageAssetKind {
    var title: String {
        switch self {
        case .metadata: "Metadata"
        case .artwork: "Artwork"
        case .ownedMedia: "Owned Media"
        }
    }

    var symbolName: String {
        switch self {
        case .metadata: "list.bullet.rectangle"
        case .artwork: "photo"
        case .ownedMedia: "music.note"
        }
    }
}

private extension MusicStorageAssetStatus {
    var title: String {
        switch self {
        case .cached: "Cached"
        case .local: "Local"
        case .downloading: "Downloading"
        case .unavailable: "Unavailable"
        case .failed: "Failed"
        }
    }

    var color: Color {
        switch self {
        case .cached: .green
        case .local: .blue
        case .downloading: .orange
        case .unavailable, .failed: .red
        }
    }
}

private struct MusicInfoLine: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 86, alignment: .leading)
            Text(value)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

private struct DeviceFactRow: View {
    let symbol: String
    let title: String
    let status: String
    let supportState: DeviceRouteSupportState
    let detail: String
    let color: Color
    let evidenceSource: String
    let checkedAt: Date

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .frame(width: 34, height: 34)
                .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.headline)
                    Text(status)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(color.opacity(0.14), in: Capsule())
                        .foregroundStyle(color)
                }
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    EvidenceChip(title: "State", value: supportState.rawValue)
                    EvidenceChip(title: "Source", value: evidenceSource)
                    EvidenceChip(title: "Checked", value: checkedAt.formatted(date: .abbreviated, time: .shortened))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private extension ColorName {
    var color: Color {
        switch self {
        case .blue: .blue
        case .green: .green
        case .orange: .orange
        case .red: .red
        case .secondary: .secondary
        }
    }
}

private struct SongResultRow: View {
    let result: YouTubeVideoSearchResult
    let isSelected: Bool
    let action: () -> Void
    let playAction: () -> Void
    let infoAction: () -> Void
    let lyricsAction: () -> Void
    let queueAction: () -> Void
    let alternateSourcesAction: () -> Void
    let removeAction: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Button(action: action) {
                HStack(spacing: 12) {
                CachedArtworkImage(url: result.thumbnailURL) {
                        Rectangle()
                            .fill(.quaternary)
                            .overlay {
                                Image(systemName: "music.note")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                            }
                }
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(result.title)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                    Text(result.channelTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if result.durationText != nil || result.popularityText != nil {
                        HStack(spacing: 8) {
                            if let durationText = result.durationText {
                                Label(durationText, systemImage: "clock")
                            }
                            if let popularityText = result.popularityText {
                                Label(popularityText, systemImage: "chart.bar.fill")
                            }
                        }
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    }
                }

                Spacer(minLength: 12)

                    SourcePill(source: result.mediaSourceKind, title: result.mediaSourceKind.shortDisplayName)

                    Text(result.songBadge)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(result.songBadgeColor.opacity(0.16), in: Capsule())
                        .foregroundStyle(result.songBadgeColor)
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)
            .simultaneousGesture(TapGesture(count: 2).onEnded(playAction))

            HStack(spacing: 6) {
                Button(action: playAction) {
                    Image(systemName: "play.fill")
                }
                .help("Play")

                Button(action: queueAction) {
                    Image(systemName: "text.badge.plus")
                }
                .help("Add to queue")

                Menu {
                    Button("Show Info", action: infoAction)
                    Button("Find Lyrics", action: lyricsAction)
                    Button("Find Other Sources", action: alternateSourcesAction)
                    ShareLink(item: result.watchURL) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    Button("Open on YouTube") {
                        NSWorkspace.shared.open(result.watchURL)
                    }
                    if let removeAction {
                        Divider()
                        Button("Remove from Playlist", role: .destructive, action: removeAction)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .help("More song actions")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(isSelected ? Color.accentColor.opacity(0.16) : Color.clear)
        .contextMenu {
            Button("Play", action: playAction)
            Button("Add to Queue", action: queueAction)
            Button("Show Info", action: infoAction)
            Button("Find Lyrics", action: lyricsAction)
            Button("Find Other Sources", action: alternateSourcesAction)
            ShareLink(item: result.watchURL) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            Button("Open on YouTube") { NSWorkspace.shared.open(result.watchURL) }
            if let removeAction {
                Divider()
                Button("Remove from Playlist", role: .destructive, action: removeAction)
            }
        }
        .accessibilityLabel("\(result.title), \(result.channelTitle), \(result.songBadge)")
        .accessibilityHint("Double-click to play in the visible YouTube player")
    }
}

private struct SourcePill: View {
    let source: MediaSourceKind
    let title: String

    var body: some View {
        Label(title, systemImage: source.descriptor.symbolName)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(source.tint.opacity(0.14), in: Capsule())
            .foregroundStyle(source.tint)
            .help(source.descriptor.displayName)
    }
}

private struct StatusRow: View {
    let symbol: String
    let title: String
    let status: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .frame(width: 26, height: 26)
                .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.medium))
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
        }
    }
}

private struct SourceIntegrationRow: View {
    let source: MediaSourceKind
    let status: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: source.descriptor.symbolName)
                .font(.title3)
                .frame(width: 34, height: 34)
                .background(source.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .foregroundStyle(source.tint)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(source.descriptor.displayName)
                        .font(.headline)
                    Text(status)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(status == "Active" ? Color.green.opacity(0.16) : Color.secondary.opacity(0.12), in: Capsule())
                        .foregroundStyle(status == "Active" ? Color.green : Color.secondary)
                }
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    ForEach(source.descriptor.capabilities.prefix(5)) { capability in
                        Text("\(capability.name): \(capability.status.rawValue)")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(capability.status.color.opacity(0.14), in: Capsule())
                            .foregroundStyle(capability.status.color)
                    }
                }
            }

            Spacer(minLength: 12)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct AccountSettingsRow: View {
    let state: YouTubeAccountState
    let connectAction: () -> Void
    let logoutAction: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "person.crop.circle")
                .font(.title3)
                .frame(width: 34, height: 34)
                .background(state.statusColor.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .foregroundStyle(state.statusColor.color)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("Google Account")
                        .font(.headline)
                    Text(state.title)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(state.statusColor.color.opacity(0.14), in: Capsule())
                        .foregroundStyle(state.statusColor.color)
                }
                Text(state.detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if state.canDisconnect {
                        Button(role: .destructive, action: logoutAction) {
                            Label("Log Out of Google", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } else {
                        Button(action: connectAction) {
                            Label("Connect Google", systemImage: "person.crop.circle.badge.plus")
                        }
                        .disabled(state == .connecting)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Spacer(minLength: 12)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ScopeDisclosurePanel: View {
    let state: YouTubeAccountState
    private let playlistWriteScope = "https://www.googleapis.com/auth/youtube"

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Google Access")
                .font(.headline)

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: state.hasPlaylistWriteScope ? "checkmark.seal" : "exclamationmark.triangle")
                    .font(.title3)
                    .frame(width: 34, height: 34)
                    .background((state.hasPlaylistWriteScope ? Color.green : Color.orange).opacity(0.15), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .foregroundStyle(state.hasPlaylistWriteScope ? Color.green : Color.orange)

                VStack(alignment: .leading, spacing: 5) {
                    Text(state.hasPlaylistWriteScope ? "Playlist write scope granted" : "Playlist write scope needed")
                        .font(.callout.weight(.semibold))
                    Text("Required for creating playlists and adding songs: \(playlistWriteScope)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if state.grantedScopes.isEmpty {
                        Text("No Google scopes are currently stored.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(state.grantedScopes, id: \.self) { scope in
                            Text(scope)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct CacheSettingsPanel: View {
    let artworkBytes: Int64
    let metadataBytes: Int
    let clearArtworkAction: () -> Void
    let clearMetadataAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Local Cache")
                .font(.headline)
            Text("PhonoDeck caches metadata and artwork for snappy navigation. It does not cache or download YouTube media.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                CacheMetric(title: "Artwork", value: formattedBytes(artworkBytes), symbol: "photo")
                CacheMetric(title: "Metadata", value: formattedBytes(Int64(metadataBytes)), symbol: "list.bullet.rectangle")
            }

            HStack(spacing: 8) {
                Button(action: clearArtworkAction) {
                    Label("Clear Artwork", systemImage: "trash")
                }
                Button(action: clearMetadataAction) {
                    Label("Clear Metadata", systemImage: "trash")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func formattedBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

private struct CacheMetric: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .frame(width: 24, height: 24)
                .background(Color.accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.callout.weight(.semibold))
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct EvidenceChip: View {
    let title: String
    let value: String

    var body: some View {
        Text("\(title): \(value)")
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.secondary.opacity(0.12), in: Capsule())
            .foregroundStyle(.secondary)
            .help("\(title): \(value)")
    }
}

private struct ContextShelf: View {
    let title: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.caption)
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.quaternary, in: Capsule())
                }
            }
        }
    }
}

private struct LibraryMetricTile: View {
    let title: String
    let value: String
    let symbol: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.title3)
                .frame(width: 34, height: 34)
                .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3.weight(.semibold))
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct LibraryEmptyShelf: View {
    let searchAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "music.note.list")
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(Color.accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text("No source songs yet")
                    .font(.headline)
                Text("Search or play songs from YouTube Music now. Plex, Spotify, and local libraries will appear here as those sources are connected.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: searchAction) {
                Label("Search", systemImage: "magnifyingglass")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ProviderComparisonCard: View {
    let comparison: YouTubeProviderComparisonResult
    let selectAction: (YouTubeVideoSearchResult) -> Void
    let playAction: (YouTubeVideoSearchResult) -> Void
    let diagnostic: ProviderComparisonProviderResult?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(comparison.title)
                        .font(.headline)
                    Text(comparison.status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(comparison.id.title)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.14), in: Capsule())
                    .foregroundStyle(Color.accentColor)
            }

            if let diagnostic {
                HStack(spacing: 8) {
                    EvidenceChip(title: "Items", value: "\(diagnostic.itemCount)")
                    EvidenceChip(title: "Cache", value: diagnostic.cacheState)
                    EvidenceChip(title: "Requests", value: "\(diagnostic.requestDelta)")
                }
                HStack(spacing: 8) {
                    EvidenceChip(title: "Risk", value: diagnostic.riskLabel)
                    if let errorMessage = diagnostic.errorMessage {
                        EvidenceChip(title: "Error", value: errorMessage)
                    }
                }
            }

            if comparison.items.isEmpty {
                Text("No results")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(comparison.items.prefix(5)) { item in
                        Button {
                            selectAction(item)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: item.isSongLike ? "music.note" : "play.rectangle")
                                    .frame(width: 20)
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(.caption.weight(.semibold))
                                        .lineLimit(1)
                                    Text(item.channelTitle)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Text(item.sourceLabel ?? item.songBadge)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(TapGesture(count: 2).onEnded { playAction(item) })
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ProviderComparisonRunPanel: View {
    let run: ProviderComparisonRun

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Diagnostic Run")
                        .font(.headline)
                    Text(run.id)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                Spacer()
                Text("Completed")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.14), in: Capsule())
                    .foregroundStyle(Color.green)
            }
            HStack(spacing: 8) {
                EvidenceChip(title: "Query", value: run.query)
                EvidenceChip(title: "Mode", value: run.preference.title)
                EvidenceChip(title: "Started", value: run.startedAt.formatted(date: .omitted, time: .shortened))
                EvidenceChip(title: "Completed", value: run.completedAt.formatted(date: .omitted, time: .shortened))
                EvidenceChip(title: "Duration", value: "\(run.durationMilliseconds) ms")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Provider comparison run \(run.id), query \(run.query), completed in \(run.durationMilliseconds) milliseconds")
    }
}

private struct SongCarouselShelf: View {
    let title: String
    let items: [YouTubeVideoSearchResult]
    let selectAction: (YouTubeVideoSearchResult) -> Void
    let playAction: (YouTubeVideoSearchResult) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(items) { item in
                        Button {
                            selectAction(item)
                        } label: {
                            VStack(alignment: .leading, spacing: 7) {
                                CachedArtworkImage(url: item.thumbnailURL) {
                                        Rectangle()
                                            .fill(.quaternary)
                                            .overlay {
                                                Image(systemName: "music.note")
                                                    .foregroundStyle(.secondary)
                                            }
                                }
                                .scaledToFill()
                                .frame(width: 132, height: 74)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                                Text(item.title)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(2)
                                HStack(spacing: 5) {
                                    Image(systemName: "play.rectangle")
                                    Text(item.songBadge)
                                }
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                            }
                            .frame(width: 132, alignment: .leading)
                            .padding(8)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(TapGesture(count: 2).onEnded { playAction(item) })
                    }
                }
            }
        }
    }
}

private struct PlaylistArtworkCard: View {
    let title: String
    let songCount: Int
    let artworkURL: URL?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                CachedArtworkImage(url: artworkURL) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.quaternary)
                        .overlay {
                            Image(systemName: "music.note.list")
                                .font(.title)
                                .foregroundStyle(.secondary)
                        }
                }
                .scaledToFill()
                .frame(width: 156, height: 156)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(.separator.opacity(0.4), lineWidth: 1)
                }

                Text(title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                Text("\(songCount) songs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 156, alignment: .leading)
        }
        .buttonStyle(.plain)
        .help(title)
    }
}

private struct SubscriptionAvatarCard: View {
    let title: String
    let artworkURL: URL?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                CachedArtworkImage(url: artworkURL) {
                    Circle()
                        .fill(.quaternary)
                        .overlay {
                            Image(systemName: "person.fill")
                                .foregroundStyle(.secondary)
                        }
                }
                .scaledToFill()
                .frame(width: 84, height: 84)
                .clipShape(Circle())
                .overlay {
                    Circle().strokeBorder(.separator.opacity(0.4), lineWidth: 1)
                }

                Text(title)
                    .font(.caption.weight(.medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 92)
            }
        }
        .buttonStyle(.plain)
        .help(title)
    }
}

private extension MusicSourceCapabilityStatus {
    var color: Color {
        switch self {
        case .active: .green
        case .planned: .secondary
        case .limited: .orange
        case .unavailable: .red
        }
    }
}

private struct RoadmapRow: View {
    let symbol: String
    let title: String
    let status: String
    let detail: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .frame(width: 34, height: 34)
                .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.headline)
                    Text(status)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(color.opacity(0.14), in: Capsule())
                        .foregroundStyle(color)
                }
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private extension YouTubeVideoSearchResult {
    var mediaSourceKind: MediaSourceKind {
        sourceLabel == "Music" || isSongLike ? .youtubeMusic : .youtube
    }

    var musicIdentity: MusicIdentity {
        let components = channelTitle
            .components(separatedBy: " - ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if sourceLabel == "Music", components.count >= 2 {
            let artist = components.first ?? fallbackArtistName
            let album = components.dropFirst().joined(separator: " - ")
            if !album.localizedCaseInsensitiveContains("topic") {
                return MusicIdentity(artistName: artist, albumTitle: album)
            }
        }

        return MusicIdentity(artistName: fallbackArtistName, albumTitle: nil)
    }

    var musicAlbumBucketTitle: String {
        musicIdentity.albumTitle ?? "Singles & Videos"
    }

    private var fallbackArtistName: String {
        let withoutTopic = channelTitle.replacingOccurrences(of: " - Topic", with: "")
        let trimmed = withoutTopic.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Unknown Artist" : trimmed
    }

    var songBadgeColor: Color {
        switch resultKind {
        case .song: .green
        case .lyrics: .blue
        case .clip, .live, .cover: .orange
        case .video: .secondary
        }
    }
}

private extension MediaSourceKind {
    var shortDisplayName: String {
        switch self {
        case .youtubeMusic: "YT Music"
        case .youtube: "YouTube"
        case .plex: "Plex"
        case .spotify: "Spotify"
        case .ownFiles: "Files"
        }
    }
}

private extension YouTubeAccountState {
    var canDisconnect: Bool {
        switch self {
        case .connected, .stored:
            true
        default:
            false
        }
    }

    var grantedScopes: [String] {
        let scopeText: String
        switch self {
        case .connected(_, let scope), .stored(let scope):
            scopeText = scope
        case .signedOut, .connecting, .failed:
            return []
        }
        return scopeText
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }
            .sorted()
    }

    var hasPlaylistWriteScope: Bool {
        grantedScopes.contains("https://www.googleapis.com/auth/youtube")
    }
}

private extension Array where Element == String {
    func deduplicatedStrings() -> [String] {
        var seen = Set<String>()
        return filter { value in
            seen.insert(value.lowercased()).inserted
        }
    }
}