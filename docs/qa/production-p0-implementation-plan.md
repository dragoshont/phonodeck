# PhonoDeck Production P0 Implementation Plan

Date: 2026-06-19
Source audit: [production-p0-screen-test-matrix.md](production-p0-screen-test-matrix.md)

## Goal

Turn the current prototype into a production-testable P0 music app by closing every `FAIL` in the QA matrix before any production release candidate.

This is an implementation plan, not a new feature wish list. Each phase has exit criteria tied to failed QA IDs.

Adversarial review: [production-p0-plan-adversarial-review.md](production-p0-plan-adversarial-review.md)

## Release Strategy

There will be no interim release and no subset release. Production release means every user-facing screen in the current product promise is implemented, tested, and passing.

The QA matrix still shows two different implementation sizes:

1. Stabilization failures in already-useful surfaces: Listen Now, Search, Library, Playlists, Settings, Devices, Provider Lab, Now Playing.
2. Missing-product failures in large incomplete surfaces: Albums, Artists, Downloads.

Both categories are P0. The first category should be hardened first because it unblocks daily app usage and shared foundations. The second category still must be implemented before release.

| Surface | Current Verdict | Required P0 Outcome Before Release |
|---|---|---|
| Albums | 11 pass / 39 fail | Real provider-backed album surface with list/detail/actions/cache/tests. |
| Artists | 10 pass / 40 fail | Real provider-backed artist surface with list/detail/actions/cache/tests. |
| Downloads | 10 pass / 40 fail | Real storage/download/cache-management surface for supported sources only. No YouTube media downloads. |
| Provider Lab | 47 pass / 3 fail | Production-ready diagnostics surface with tests, throttling, and clear provider-risk language. |

Internal development toggles are allowed while building, but they are not a release strategy. A production release candidate must expose and pass every P0 surface.

## Phase 0: Test Harness And Scope Lock

Purpose: prevent new work from adding more ambiguous UI, split the current monolithic state model before it grows further, and make every P0 surface testable before feature expansion.

### Tasks

- Add architecture seams before more surface work:
  - Extract `YouTubeMusicSearchService` for query execution, provider selection, pagination, and search cache access.
  - Extract `YouTubeMusicDiscoveryService` for seed queries, discovery refresh, request coalescing, and discovery cache access.
  - Extract `YouTubePlaylistService` for playlist read/create/add/pagination/error mapping.
  - Keep `YouTubeSearchViewModel` as a thin `@MainActor` state adapter instead of the owner of all provider logic.
- Add provider/client protocols:
  - `YouTubeSearchClient`.
  - `YouTubePlaylistClient`.
  - `MusicLibraryProviding` for tracks/albums/artists.
  - `MusicStorageProviding` for storage/download/cache surfaces.
  - `DeviceRoutingCapabilityProvider` for Devices.
- Add request/concurrency foundation:
  - Request coalescer actor keyed by provider/query/mode/source.
  - Cancellation tokens for stale searches and discovery refreshes.
  - Timeout wrapper for experimental provider calls.
- Add a development configuration model for risky work-in-progress sections.
  - Suggested type: `FeatureAvailability` or `ReleaseFeatureFlags`.
  - Flags: `showAlbums`, `showArtists`, `showDownloads`, `showProviderLab`, `showPlex`, `showSpotify`, `showOwnFiles`.
  - Development toggles may support branch work isolation, but release candidate defaults must expose all committed P0 user-facing surfaces.
- Update `SidebarView` to derive visible sections from flags.
- Add unit tests for development and release sidebar configurations.
- Add UI smoke tests or testable view-model hooks for each visible section.
- Add a QA status script that reads the matrix and fails CI if any P0 test remains `FAIL`.
- Add deterministic fixture mode:
  - Fixture YouTube Music search.
  - Fixture official YouTube playlist read/create/add.
  - Fixture account states: signed out, stored, connected, missing write scope, expired token.
  - Fixture player bridge states: ready, buffering, playing, paused, failed.
- Add CI entry points:
  - Build.
  - Unit tests.
  - Fixture UI tests.
  - `qa-status` matrix check.

### QA IDs Closed

- AL-001..AL-050 by implementing real Albums.
- AR-001..AR-050 by implementing real Artists.
- DL-001..DL-050 by implementing real Downloads/Storage for supported sources.
- PR-049, PR-050 by making Provider Lab a production-ready diagnostic surface.

### Exit Criteria

- Release sidebar exposes all P0 user-facing surfaces and every exposed surface is real.
- QA matrix has zero `FAIL` rows for P0.
- Build/test passes with release configuration.
- View models have provider/service seams and are no longer the only place to test provider behavior.
- Fixture mode can run without live Google credentials.

## Phase 0A: Provider Strategy Lock

Purpose: assign real providers to every full-app surface before Albums, Artists, Downloads, Plex, Spotify, and Own Files implementation begins.

### Required Provider Commitments

| Surface / Source | Required Provider Strategy Before Release |
|---|---|
| YouTube Music | Official YouTube Data API + visible player for compliant playback; undocumented/internal metadata paths are not production sources. |
| YouTube | Official video/clips source using documented APIs and visible player. |
| Albums | Must be backed by Plex, Own Files/iTunes XML, MusicKit, Spotify metadata, or another real album-capable provider. Not inferred from YouTube videos alone. |
| Artists | Must be backed by Plex, Own Files/iTunes XML, MusicKit, Spotify metadata, or another real artist-capable provider. Not inferred from YouTube channels alone. |
| Downloads/Storage | Must manage real metadata/artwork cache and at least one supported local/offline source such as Own Files or Plex owned media. YouTube media downloads remain unavailable. |
| Plex | If it remains a source in the release, implement auth, server selection, music library browsing, metadata/artwork, and native playback or clearly source-specific unavailable states. |
| Spotify | If it remains a source in the release, implement OAuth, metadata/library surfaces, playlists where scopes allow, and Spotify Connect-style remote control. No fake native streaming. |
| Own Files | Implement file/folder or iTunes XML import, metadata extraction, albums/artists, security-scoped file access, and native playback. |
| Provider Lab | Ship as a production diagnostics surface with tests and throttling, not temporary scaffolding. |

### Exit Criteria

- Every P0 surface has an assigned real provider path.
- No plan step depends on YouTube Data API pretending to expose canonical albums/artists.
- Experimental YouTube Music metadata is isolated behind provider-risk labels and tests.

## Phase 1: Artwork And Metadata Cache

Purpose: fix the perceived slow UI and repeated image reloads.

### Tasks

- Introduce an app-level image/artwork cache.
  - Suggested component: `ArtworkCache` actor/service.
  - Key by canonical thumbnail URL string.
  - Memory cache via `NSCache<NSURL, NSImage>`.
  - Disk cache under app caches directory for thumbnails/artwork.
  - Store decoded images or raw bytes with size/TTL budget.
- Replace direct `AsyncImage` usage in song rows, carousels, now playing artwork, provider cards, playlist cards, future album/artist cards.
  - Suggested view: `CachedArtworkImage(url:placeholderSymbol:source:)`.
- Add cache controls in Settings.
  - Show metadata/artwork cache size.
  - Add `Clear Artwork Cache` and `Clear Metadata Cache` controls.
  - Make clear this is metadata/artwork only, not YouTube media download.
- Add cache instrumentation.
  - Track cache hit/miss count in debug logs or a simple in-app diagnostics value.
  - Track provider request count per section.
- Add tests.
  - Unit-test cache keying, memory hit, disk fallback, clear behavior.
  - UI smoke: reopening Listen Now/Search/Library should not flash placeholders on warm cache.

### QA IDs Closed

- LN-015, LN-050
- SR-019
- LB-028, LB-050
- ST-050
- DL-005, DL-020, DL-021, DL-022, DL-037, DL-038, DL-039 if Downloads becomes cache-management page

### Exit Criteria

- Warm-cache navigation does not visibly reload thumbnails.
- Settings exposes cache size and clear controls.
- No YouTube audiovisual media is cached.

## Phase 2: Search And Discovery Responsiveness

Purpose: fix rapid search/tab-click lag and unverifiable request behavior.

### Tasks

- Add request coalescing for discovery seed searches.
  - Current direct search has `activeSearchKey`; discovery refresh also needs an in-flight key set.
  - Prevent `top songs`, `new music`, etc. from being refetched repeatedly across tab clicks.
- Add search debouncing/cancellation.
  - Keep explicit Enter/button submit immediate.
  - When mode/engine changes, cancel stale refresh tasks before publishing results.
  - Ensure older provider responses cannot overwrite newer query results.
- Add provider request instrumentation.
  - Count calls by query/mode/engine/source.
  - Expose in debug logs or Provider Lab diagnostics.
- Add adversarial query tests.
  - Unicode, punctuation, apostrophes, parentheses, slash, emoji-safe handling.
  - Example queries: `AC/DC Thunderstruck`, `Beyonce - Halo`, `Sigur Ros Svefn-g-englar`, `Rosalia DESPECHA`, `Oasis (What's The Story)`.
- Add offline/warm-cache test seams.
  - Inject mock URLSession/provider failures.
  - Verify stale rows remain visible.
- Decide Listen Now pagination.
  - If YouTube Music no-cookie endpoint has no stable continuation parser, do not render Load More for discovery and mark bounded recommendations as intentional.
  - If implementing pagination, add continuation support to `YouTubeMusicInnerTubeClient` and UI.

### QA IDs Closed

- LN-025, LN-045, LN-050
- SR-049, SR-050
- LB-048

### Exit Criteria

- Rapid mode/engine/tab changes do not produce stale content or visible stalls.
- Provider request counts prove no repeated same-query network calls inside freshness window.
- Search has unit tests for adversarial queries.

## Phase 3: Now Playing Panel Controls

Purpose: make every visible player control honest and keep transport controls discoverable without exposing unsupported YouTube skip chrome.

### Tasks

- Keep the visible YouTube player in the Now Playing panel and expose only the controls PhonoDeck can honestly route.
  - Play/pause, progress, and embed volume are supported.
  - Previous/Next are queue-aware for YouTube; they appear/enable only when PhonoDeck has adjacent explicit queue items. A real ended event advances to the next queued song, while pause/failure never auto-advance.
  - Native/Plex/local routes keep Previous/Next through `PlaybackCoordinator`.
- Add loading/ready/error states around the buttons.
  - Ready, buffering, playing, paused, failed.
  - Failed state should show `Try another song` and a Retry/Skip action if possible.
- Add JS bridge readiness guard.
  - Queue play/pause/volume commands until `ready`, or disable controls until ready.
  - Add unit-testable state transitions in `YouTubePlaybackBridge`.
- Improve Lyrics button behavior.
  - If lyric result exists, play/select it.
  - If no lyric result exists, show `No lyric video found` instead of silently doing nothing.
  - Keep no-scraping policy.
- Improve Add button states.
  - If no selected video, show disabled Add with tooltip, not absent context.
  - If no playlists, provide direct `Create Playlist` action in the menu.
  - If missing write scope, show clear reconnect CTA.
- Add UI tests for video-panel buttons.

### QA IDs Closed

- NP-008, NP-009, NP-010, NP-011
- NP-026
- NP-029, NP-030, NP-031, NP-032
- NP-038, NP-043, NP-047, NP-050
- PL-014, PL-016, PL-043, PL-044

### Exit Criteria

- All buttons under/around the video either work, disable with explanation, or are removed.
- Transport controls are visible without relying on keyboard media keys.
- Add/Lyrics flows produce clear success/failure feedback.

## Phase 4: Playlist Production Hardening

Purpose: make playlist create/add/share actually production reliable.

### Tasks

- Add playlist operation state to `YouTubeSearchViewModel`.
  - `isCreatingPlaylist`
  - `isAddingToPlaylist`
  - `playlistOperationError`
  - `playlistOperationStatus`
- Add in-flight locks/debounce.
  - Disable New Playlist while create is running.
  - Disable Add while add is running for the selected video/playlist pair.
- Persist selected playlist context.
  - `youtubeSelectedPlaylistID` in AppStorage/UserDefaults.
  - Restore selected playlist after playlist list loads.
  - Persist playlist item cache by playlist ID with freshness interval.
- Refresh after writes.
  - After create: insert optimistically, then refresh `playlists` from API.
  - After add: refresh selected playlist item page and playlist counts.
- Improve signed-out and scope UX.
  - Page-level Connect/Reconnect CTA for Playlists.
  - Show required scope: `https://www.googleapis.com/auth/youtube`.
  - In Settings, list granted scope and missing required scopes.
- Add mockable YouTube playlist client protocol.
  - Allows unit tests without live Google credentials.
  - Test create body, add body, pagination, quota, expired token, missing scope.
- Add end-to-end manual script/checklist for live Google test account.

### QA IDs Closed

- PL-003, PL-004, PL-032, PL-033, PL-034, PL-036, PL-038, PL-040, PL-041, PL-050
- NP-029, NP-030, NP-031, NP-032
- LB-038
- ST-006, ST-050

### Exit Criteria

- User can create a private playlist once, see it immediately, add a song once, and see confirmation.
- Rapid clicks cannot create duplicate playlists/adds.
- Playlist state survives relaunch.
- Playlist flows are unit-tested through a mock client.

## Phase 5: Settings Scope, Cache, And Privacy Controls

Purpose: make account/cache behavior explicit in production.

### Tasks

- Add OAuth scope disclosure.
  - Show current granted scopes from token store/account state.
  - Show required scopes by feature: read search/account, playlist write.
  - Add Reconnect button when playlist write scope is missing.
- Add cache controls from Phase 1.
  - Metadata cache size.
  - Artwork cache size.
  - Clear buttons.
- Add local data controls.
  - Clear recent searches.
  - Clear playback history.
  - Reset local listening time.
- Add privacy copy.
  - Keychain tokens.
  - UserDefaults local metadata/history.
  - No YouTube media downloads.
- Add tests for Settings state.

### QA IDs Closed

- ST-006, ST-050
- LB-038
- DL cache-policy-related IDs if Downloads is converted to cache management

### Exit Criteria

- A user can understand what Google scopes are granted and why.
- User can clear local app data/cache without deleting credentials unless they choose logout.

## Phase 6: Albums And Artists Implementation

Purpose: close the largest failure cluster without faking a library. Albums and Artists are P0 and must be real before release.

### Tasks

- Add provider-neutral models:
  - `MusicAlbum`
  - `MusicArtist`
  - `MusicTrack`
  - `MusicProviderEntityID`
  - `MusicEntitySource`
- Add provider protocol extensions:
  - `albumLibrarySnapshot()`
  - `artistLibrarySnapshot()`
  - `albumDetails(id:)`
  - `artistDetails(id:)`
- Implement at least one real album/artist source before release:
  - Own Files/iTunes XML tags if local import is implemented.
  - Plex music library if Plex auth/library browsing is implemented.
  - MusicKit if Apple Music integration is added.
- Do not pretend YouTube Data API exposes canonical albums/artists.
- Use YouTube Music internal metadata only behind the existing experimental provider boundary, with clear risk label.
- Build Albums screen:
  - Album grid/list.
  - Search/filter/sort.
  - Album detail with tracks.
  - Play album / queue / share where supported.
  - Missing year/label shown honestly.
- Build Artists screen:
  - Artist list.
  - Artist detail with songs/albums.
  - Local play totals.
  - Source-specific follow/subscribe only where real.
- Add cache:
  - Album/artist metadata cache.
  - Artwork cache via Phase 1.
- Remove all preview/demo `Track.previewTracks` from production surfaces.
- Add list/detail/search/sort/play/share tests and screenshots.

Closes:

- AL-001..AL-050.
- AR-001..AR-050.

Exit criteria:

- Albums/Artists show real provider-backed entities, not derived video/channel guesses.
- Album and Artist QA sections have zero `FAIL` rows before release.

## Phase 7: Downloads And Storage Implementation

Purpose: ship a real policy-safe Downloads/Storage surface for supported sources. Downloads remains P0, but YouTube media downloads remain explicitly out of scope.

### Tasks

- Decide final product label: `Downloads`, `Storage`, or `Cache & Offline`; keep sidebar text consistent with implemented behavior.
- Add `DownloadManager` / `StorageManager` domain:
  - Source.
  - Asset type: media vs artwork vs metadata.
  - Status/progress/error.
  - Storage usage.
- Add metadata/artwork cache management from Phase 1.
- Add explicit YouTube policy block:
  - YouTube media downloads unavailable.
  - YouTube artwork/metadata cache is metadata cache, not media download.
- Implement at least one supported local/offline source before release:
  - Own Files import with security-scoped bookmarks and metadata extraction; or
  - Plex owned-media download path with server permission/Plex Pass checks.
- Add storage usage, clear cache, and delete supported local media/download actions.
- No fake downloaded items.
- No copied-cookie, ytdl, hidden audio, or YouTube media cache paths.

Closes:

- DL-001..DL-050 as a real supported-source storage/download/cache-management surface.

### Exit Criteria

- Downloads/Storage has zero `FAIL` rows before release.
- YouTube media download remains unavailable and clearly explained.
- At least one supported source has real offline/local storage behavior if the screen is labeled Downloads.

## Phase 8: Provider Lab Production Hardening

Purpose: ship Provider Lab as a production-ready diagnostics surface instead of temporary internal tooling.

Tasks:

- Add debounce/throttle for comparisons.
- Add explicit diagnostics labeling.
- Add user-facing explanation of official vs experimental risk.
- Add cache/in-flight coalescing for repeated comparisons.
- Add signed-out, official-failure, experimental-failure, and network-failure states.
- Add tests for auto-run, comparison retry, signed-out behavior, provider failure isolation, and production layout.

### QA IDs Closed

- PR-020, PR-049, PR-050

### Exit Criteria

- Provider Lab is intentionally documented, tested, throttled, and production-ready.

## Phase 9: Devices Test Seams

Purpose: close the two remaining Devices failures without pretending HomeKit support.

Tasks:

- Add `DeviceRoutingCapabilityProvider` protocol.
  - Current implementation wraps system AirPlay picker availability and static policy facts.
  - Future HomeKit implementation can plug in without changing UI.
- Add unit tests for current capability rows.
- If HomeKit is added later:
  - Add entitlement and `NSHomeKitUsageDescription`.
  - Add permission request flow.
  - Do not claim HomePod default music service is exposed unless Apple provides it.

### QA IDs Closed

- DV-038, DV-039

### Exit Criteria

- Devices has mockable/testable capability state.
- HomeKit/native route integration has a planned seam, not hardcoded UI copy.

## Phase 10: Production Test Automation

Purpose: turn the QA matrix from a document into a release gate. Phase 0 creates the first fixture/CI seams; this phase completes coverage after every surface is implemented.

### Tasks

- Complete deterministic fixture mode:
  - Mock YouTube Music search responses.
  - Mock official YouTube playlists, playlist items, auth errors, quota errors, and missing scopes.
  - Mock player state messages from the embedded player bridge.
  - Mock account states: signed out, stored token, connected, missing write scope, expired token.
- Add UI test coverage for every P0 page:
  - Listen Now.
  - Search.
  - Library.
  - Playlists.
  - Devices.
  - Settings.
  - Now Playing.
- Add performance tests:
  - Warm-cache Listen Now open.
  - Cached search result render.
  - Rapid section switching.
  - Rapid play/select/skip/add flows.
- Add screenshot verification for production-visible surfaces.
- Add a `qa-status` script:
  - Parses [production-p0-screen-test-matrix.md](production-p0-screen-test-matrix.md).
  - Fails if any P0 case remains `FAIL`.
  - Fails release if any P0 surface has remaining failures.

### Exit Criteria

- The release candidate cannot pass CI with a visible production P0 failure.
- Every shipped page has unit/UI coverage and a reviewed screenshot.

## Suggested Work Order

| Order | Phase | Why First |
|---:|---|---|
| 1 | Phase 0: architecture, fixtures, scope lock | Prevents ambiguous UI, splits provider logic, and makes every P0 surface testable. |
| 2 | Phase 0A: provider strategy lock | Avoids fake Albums/Artists/Downloads by assigning real sources before UI expansion. |
| 3 | Phase 2: search/discovery responsiveness | Removes lag/race conditions and adds adversarial tests before more surfaces depend on provider calls. |
| 4 | Phase 1: artwork/cache | Directly addresses slow UI and repeated media reload. |
| 5 | Phase 3: Now Playing controls | Directly addresses user-visible dead buttons under the video. |
| 6 | Phase 4: playlist hardening | P0 user complaint: new playlist does not reliably work. |
| 7 | Phase 5: settings scope/cache/privacy | Makes account/cache state production-transparent. |
| 8 | Phase 6: Albums and Artists implementation | Required for the full music-library promise. |
| 9 | Phase 7: Downloads and Storage implementation | Required for the full storage/offline/cache promise. |
| 10 | Phase 9: Devices test seams | Closes remaining Devices verification gaps. |
| 11 | Phase 8: Provider Lab hardening | Keeps diagnostics shippable rather than temporary. |
| 12 | Phase 10: production test automation completion | Completes coverage and screenshot/performance release gates. |

## First Implementation Batch

Batch objective: start closing shared foundations while keeping the release blocked until all phases are complete. This is not an interim release checkpoint.

Scope:

- Add `CachedArtworkImage` and app-level artwork cache.
- Split `YouTubeSearchViewModel` into provider services/coordinators and add mockable provider protocols.
- Add fixture mode and the initial `qa-status` CI script.
- Add request coalescing/cancellation and provider timing instrumentation.
- Add visible Now Playing panel transport controls.
- Add playlist operation lock/debounce and selected playlist persistence.
- Add Settings OAuth scope disclosure and cache controls.
- Start Albums/Artists domain models and provider protocols.
- Start Downloads/Storage domain model and policy-safe cache/storage surface.
- Add fixture-mode tests for Listen Now, Search, Library, Playlists, Albums, Artists, Downloads, Devices, Provider Lab, Settings, and Now Playing.

Expected QA impact:

- Closes shared UI/performance failures while beginning the larger music-library surfaces.
- Keeps release blocked until Albums, Artists, Downloads, Provider Lab, and all existing core pages pass the matrix.

## Release Gates

Before a production release candidate:

- `xcodebuild build` passes.
- `xcodebuild test` passes.
- Full P0 QA matrix has zero `FAIL` rows.
- Screenshots captured for every P0 surface.
- Manual live Google account test covers:
  - Connect.
  - Search.
  - Play.
  - Create private playlist.
  - Add selected song.
  - Share playlist.
  - Logout.
- Warm-cache navigation test covers:
  - Listen Now.
  - Search.
  - Library.
  - Playlists.
- Offline/warm-cache test covers cached Listen Now/Search/Library behavior.

## Non-goals For This Plan

- YouTube/YouTube Music media downloads.
- Hidden/background YouTube audio extraction.
- Claiming YouTube Premium tier, Family/Student/Individual status from public APIs.
- Claiming HomePod default music service configuration from HomeKit.
- Scraped lyrics.

## Scope Lock

The release scope is locked to the full app promise: music-first Search, Listen Now, Library, real Playlists, Albums, Artists, Downloads/Storage for supported sources, Devices, Provider Lab, Settings, and Now Playing. No production release candidate exists until every P0 surface has zero `FAIL` rows in the QA matrix.
