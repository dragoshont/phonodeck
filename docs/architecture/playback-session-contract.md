# Playback Session Contract

Status: accepted for the P0 playback/queue foundation slice.

This document is the native-service contract for PhonoDeck playback. In this repo the backend lane is inside the macOS app: source adapters, routing, queue state, and system playback integration are Swift model/protocol boundaries rather than HTTP endpoints.

## Scope

This slice defines and implements a source-neutral playback session around `MusicTrack` and `PlaybackPlan`.

In scope:

- A deterministic queue/session model for `MusicTrack` items.
- Route decisions derived from `PlaybackPlan` through `PlaybackRouter`.
- Explicit blocked and failed states for unsupported, unavailable, or failed playback.
- A small playback engine boundary that is testable without real media playback.
- Compatibility with the existing `PlaybackCoordinator` name while callers migrate.
- System Now Playing and media-key ownership rules that are driven by the current route.

Out of scope for this slice:

- Full AVFoundation streaming UI and buffering behavior.
- Persisted queues, downloads, library deduplication, lyrics, and queue visual redesign.
- Native YouTube or Spotify audio streams.
- Watch/iOS remote control.
- Any change to source capability claims.

## Existing Seams

The implementation extends these seams:

- `MusicSourceAdapter.playbackPlan(for:)` resolves a `MusicTrack` to a `PlaybackPlan`.
- `PlaybackRouter` selects the playback engine and system integration policy.
- `PlaybackCoordinator` remains the app-facing facade during migration.
- `NowPlayingController` is the only bridge to `MPNowPlayingInfoCenter` and `MPRemoteCommandCenter`.
- `MusicTrack` is the source-neutral playback item. Legacy `Track` is compatibility-only.

No UI or app command path may branch directly on a provider to decide playback ownership. Provider-specific policy belongs in adapters and route decisions.

## Route Decision

`PlaybackRouter` returns a `PlaybackRouteDecision` for every `PlaybackPlan`.

Fields:

- `plan`: the original `PlaybackPlan`.
- `engine`: `PlaybackEngineKind` (`webEmbed`, `nativeAV`, `connectRemote`, `none`).
- `systemIntegration`: `PlaybackSystemIntegration`.
- `requiresVisiblePlayer`: true for official web embeds.
- `blockedState`: a `PlaybackBlockedState` when the plan cannot be executed by the native session.

`PlaybackSystemIntegration` values:

- `eligibleNative`: the plan may publish system Now Playing after a native engine successfully loads the item.
- `forbidden(reason:)`: the plan must not publish system Now Playing or enable media keys.
- `unavailable(reason:)`: no playable path exists.

Route invariants:

- `.nativeStream` and `.localFile` route to `.nativeAV` and are `eligibleNative`.
- `.embedded` routes to `.webEmbed`, requires a visible official player, and is system-integration forbidden.
- `.connectRemote` routes to `.connectRemote` and is system-integration forbidden.
- `.unavailable(reason)` routes to `.none` and preserves the exact reason.
- Eligibility is not ownership. System Now Playing ownership begins only after the session accepts a native item; blocked, failed, idle, embedded, and remote states clear or avoid system ownership.

## Queue And Session API

The queue/session model is `@MainActor` and exposes these commands through `PlaybackCoordinator`:

- `replaceQueue(with:startAt:)`
- `play(track:)`
- `enqueue(_:)`
- `play()`
- `pause()`
- `togglePlayPause()`
- `seek(to:)`
- `nextTrack()`
- `previousTrack()`
- `clearQueue()`

Queue invariants:

- Queue items keep their original `MusicTrack`, source, and resolved route decision.
- Duplicate tracks may appear more than once in the queue; each queue item has its own stable queue id.
- Empty queue commands are deterministic no-ops and do not crash.
- `replaceQueue(with:startAt:)` rejects invalid indexes by entering a blocked state rather than crashing.
- `enqueue(_:)` does not interrupt the current item.
- `nextTrack()` advances when possible; at the end it stops/ends honestly.
- `previousTrack()` returns to the previous item when possible; otherwise it restarts the current item by seeking to zero.
- `clearQueue()` stops playback, clears current item, disables system commands, and clears system Now Playing.

Session states:

- `idle`
- `loading(PlaybackQueueItem)`
- `playing(PlaybackQueueItem, elapsed: TimeInterval, duration: TimeInterval?)`
- `paused(PlaybackQueueItem, elapsed: TimeInterval, duration: TimeInterval?)`
- `ended(PlaybackQueueItem)`
- `blocked(PlaybackBlockedState)`
- `failed(PlaybackFailure)`

Blocked states:

- `unavailable(reason:)`
- `unsupportedEngine(engine:reason:)`
- `missingMediaURL(source:trackID:)`
- `sourceUnavailable(source:reason:)`
- `notConnected(source:)`

Failures:

- `invalidMediaURL(URL)`
- `engineFailed(reason:)`
- `sourceResolutionFailed(source:reason:)`

## Playback Engine Boundary

`PlaybackEngine` is a small protocol used by the session, not a provider abstraction.

Required behavior:

- `load(_:)` accepts a `PlaybackQueueItem` and either succeeds or throws `PlaybackFailure`.
- `play()`, `pause()`, `stop()`, and `seek(to:)` mutate only engine-local playback state.
- The engine receives an already resolved route decision. It does not call source adapters and does not inspect provider-specific APIs.

This slice may use an immediate/testable native engine that accepts valid native plans without performing real streaming. Real AVFoundation playback is a later implementation behind the same boundary.

## Capability Honesty

Plex and own files:

- May route to `.nativeAV` when their adapters return `.nativeStream` or `.localFile`.
- May publish system Now Playing only after native load succeeds.
- Downloads remain out of scope and still follow the capability matrix.

YouTube and YouTube Music:

- Remain visible official embed playback only.
- Never produce app-owned native audio, hidden playback, background extraction, downloads, or system Now Playing ownership.
- Premium tier does not change native playback capability.

Spotify:

- Remains visible official Spotify player or external remote control.
- Never produces app-owned native audio or system Now Playing ownership in this slice.
- Premium may affect the official player experience, not PhonoDeck native ownership.

Global:

- `PlaybackRouter` is the ownership gate.
- Embed controls may use visible-player bridges, but not `MPRemoteCommandCenter` ownership.
- No source capability status changes in this slice.

## Compatibility And Migration

Migration is additive:

1. Add route decisions and session/queue types.
2. Keep `PlaybackCoordinator` as the public facade.
3. Expose legacy `currentTrack`, `state`, and `progress` as compatibility views over the new session where possible.
4. Stop publishing placeholder metadata on launch.
5. Migrate UI call sites later, after tests are green.

Rollback is code-only: revert the new playback/session files and coordinator internals. No user data, Keychain item, cache, or queue persistence is migrated.

## Test Matrix

Route decision tests:

- Native stream routes to `nativeAV`, is eligible native, and does not require a visible player.
- Local file routes to `nativeAV`, is eligible native, and does not require a visible player.
- YouTube and Spotify embeds route to `webEmbed`, require a visible player, and forbid system integration.
- Connect remote routes to `connectRemote` and forbids system integration.
- Unavailable preserves its reason.

Queue/session tests:

- Replacing a queue starts the requested item.
- Invalid start index enters a blocked state.
- Enqueue preserves the current item.
- Next and previous move through the queue deterministically.
- Empty queue commands are no-ops.
- Clearing queue clears current item and system ownership.

Capability honesty tests:

- YouTube/Spotify embedded tracks never enable system ownership.
- Native Plex/local tracks enable ownership only after native load succeeds.
- Engine failure leaves the queue intact, records a failure, and disables ownership.
- A mixed queue preserves each item source and route decision.

## Phase 2: Service Split And Fixture Foundation Contract

Status: proposed for the next implementation phase.

This phase makes YouTube provider behavior testable and modular before real AVFoundation playback, provider expansion, or P0 surface completion. It does not change playback capabilities.

### Scope

In scope:

- Extract YouTube search/provider selection/pagination/cache behavior from `YouTubeSearchViewModel` into a service layer.
- Extract YouTube discovery seed refresh/coalescing/cache behavior into a service layer.
- Extract YouTube playlist read/pagination/create/add/remove behavior into a service layer.
- Keep `YouTubeSearchViewModel` as the `@MainActor` UI state adapter for published properties, selection, queue presentation, and user-facing status copy.
- Promote reusable deterministic fixtures for unit tests.
- Wire an initial `qa-status` command/target that parses the P0 QA matrix and fails when rows remain `FAIL`.

Out of scope:

- Real AVFoundation streaming implementation.
- Albums, Artists, Downloads/Storage, Provider Lab production hardening, or P0 UI completion.
- Full migration of YouTube rows to neutral `MusicTrack`.
- New provider capabilities, OAuth scopes, source tiers, or playback policies.
- Live provider write tests.

### Existing Seams

The service split must reuse:

- `YouTubeAccountTokenProviding`
- `YouTubeOfficialProviding`
- `YouTubeMusicMetadataProviding`
- `RequestCoalescer`
- Existing cache keys for search, playlist items, discovery, playback history, and selected playlist.
- Existing `YouTubeVideoSearchResult`, `YouTubeVideoPage`, `YouTubePlaylist`, and playlist status copy.

### Service Contracts

The phase may add small service protocols/types. The minimum target boundaries are:

- `YouTubeSearchServicing`: cached search publication, search execution, pagination, provider comparison, search cache clearing, provider request counts.
- `YouTubeDiscoveryServicing`: cached discovery publication, seed refresh, coalescing, discovery cache clearing.
- `YouTubePlaylistServicing`: library load, playlist selection, pagination, create/add/remove, selected playlist persistence, playlist cache clearing.

Typed service results must carry enough information for the view model to preserve current behavior without directly calling provider clients:

- result page/items;
- resolved engine/provider;
- next page token;
- typed provider/cache status;
- request-count deltas;
- cache freshness or fallback state;
- write operation status for create/add/remove.

Required method/result shapes:

```swift
struct YouTubeSearchRequest: Hashable, Sendable {
	let query: String
	let preference: YouTubePlaybackPreference
	let engine: YouTubeMusicEngine
	let maxResults: Int
}

struct YouTubeSearchContinuation: Hashable, Sendable {
	let query: String
	let preference: YouTubePlaybackPreference
	let engine: YouTubeMusicEngine
	let pageToken: String
	let maxResults: Int
}

enum YouTubeProviderStatus: Equatable, Sendable {
	case ready
	case cachedFallback
	case experimentalUnavailableOfficialFallback
	case officialUnavailableExperimentalFallback
	case undocumentedMetadataDisabledOfficialOnly
	case connectRequired
	case missingWriteScope
	case authorizationExpired
	case quotaExceeded
	case unsupportedExperimentalVideoMode
	case invalidProviderResponse
	case failed(String)
}

enum YouTubeCacheState: Equatable, Sendable {
	case none
	case warm(updatedAt: Date)
	case stale(updatedAt: Date)
	case refreshed(updatedAt: Date)
}

struct YouTubeSearchServiceResult: Equatable, Sendable {
	let request: YouTubeSearchRequest
	let page: YouTubeVideoPage
	let resolvedEngine: YouTubeMusicEngine
	let status: YouTubeProviderStatus
	let cacheState: YouTubeCacheState
	let nextPageToken: String?
	let requestCountDeltas: [String: Int]
}

@MainActor
protocol YouTubeSearchServicing: AnyObject {
	func cachedPage(for request: YouTubeSearchRequest) -> YouTubeSearchServiceResult?
	func search(_ request: YouTubeSearchRequest) async -> YouTubeSearchServiceResult
	func loadMore(_ continuation: YouTubeSearchContinuation) async -> YouTubeSearchServiceResult
	func compareProviders(query: String, preference: YouTubePlaybackPreference) async -> [YouTubeProviderComparisonResult]
	func clearSearchCache()
	var providerRequestCounts: [String: Int] { get }
}
```

```swift
struct YouTubeDiscoveryRequest: Hashable, Sendable {
	let engine: YouTubeMusicEngine
	let force: Bool
	let seedQueries: [String]
}

struct YouTubeDiscoverySnapshot: Equatable, Sendable {
	let items: [YouTubeVideoSearchResult]
	let status: YouTubeProviderStatus
	let cacheState: YouTubeCacheState
	let requestCountDeltas: [String: Int]
}

@MainActor
protocol YouTubeDiscoveryServicing: AnyObject {
	func cachedDiscovery(engine: YouTubeMusicEngine, seedQueries: [String], currentItems: [YouTubeVideoSearchResult]) -> YouTubeDiscoverySnapshot
	func refreshDiscovery(_ request: YouTubeDiscoveryRequest, currentItems: [YouTubeVideoSearchResult]) async -> YouTubeDiscoverySnapshot
	func clearDiscoveryCache()
}
```

```swift
struct YouTubeLibrarySnapshot: Equatable, Sendable {
	let activityVideos: [YouTubeVideoSearchResult]
	let playlists: [YouTubePlaylist]
	let subscriptions: [YouTubeSubscription]
	let selectedPlaylist: YouTubePlaylist?
	let playlistVideos: [YouTubeVideoSearchResult]
	let nextPlaylistPageToken: String?
	let warnings: Set<YouTubeLibraryWarning>
	let status: YouTubeProviderStatus
	let requestCountDeltas: [String: Int]
}

enum YouTubeLibraryWarning: String, Equatable, Hashable, Sendable {
	case activity
	case playlists
	case subscriptions
	case selectedPlaylist
}

enum YouTubePlaylistWriteKind: Equatable, Sendable {
	case createDefault(adding: YouTubeVideoSearchResult?)
	case add(video: YouTubeVideoSearchResult, playlist: YouTubePlaylist)
	case remove(video: YouTubeVideoSearchResult, playlist: YouTubePlaylist)
}

struct YouTubePlaylistWriteResult: Equatable, Sendable {
	let kind: YouTubePlaylistWriteKind
	let status: YouTubeProviderStatus
	let statusMessage: String
	let playlists: [YouTubePlaylist]
	let selectedPlaylist: YouTubePlaylist?
	let playlistVideos: [YouTubeVideoSearchResult]
	let nextPlaylistPageToken: String?
	let requestCountDeltas: [String: Int]
}

@MainActor
protocol YouTubePlaylistServicing: AnyObject {
	func loadLibrary() async -> YouTubeLibrarySnapshot
	func selectPlaylist(_ playlist: YouTubePlaylist) async -> YouTubeLibrarySnapshot
	func loadMorePlaylistItems(playlist: YouTubePlaylist, pageToken: String) async -> YouTubeLibrarySnapshot
	func createDefaultPlaylist(adding video: YouTubeVideoSearchResult?) async -> YouTubePlaylistWriteResult
	func add(_ video: YouTubeVideoSearchResult, to playlist: YouTubePlaylist) async -> YouTubePlaylistWriteResult
	func remove(_ video: YouTubeVideoSearchResult, from playlist: YouTubePlaylist) async -> YouTubePlaylistWriteResult
	func isAdding(_ video: YouTubeVideoSearchResult, to playlist: YouTubePlaylist) -> Bool
	func isRemoving(_ video: YouTubeVideoSearchResult) -> Bool
	func clearPlaylistCache()
}
```

Cancellation and stale-response rules:

- Search services must key in-flight work by normalized query, result preference, and engine.
- Duplicate same-key searches inside the existing debounce window must not start another provider call.
- A response for an older request must not overwrite a newer view-model request.
- Discovery refresh must coalesce seed queries by engine/query/mode and preserve warm cached data when one seed fails.
- Undocumented YouTube Music metadata providers are disabled by policy; search/discovery must use documented YouTube Data API results or fail closed with cache/status evidence.

### Fixture Mode Contract

Fixtures are test-only unless a later UI fixture mode explicitly gates them behind launch arguments/environment.

Fixture behavior:

- no Keychain access;
- no live `URLSession` calls;
- no real Google OAuth/browser flow;
- deterministic IDs, ordering, timestamps, request counts, and errors;
- in-memory or isolated `UserDefaults` state;
- capability honesty identical to live mode.

Required fixture states:

- signed out;
- connected read-only;
- connected with YouTube write scope;
- missing write scope;
- expired token;
- quota exceeded;
- network unavailable with warm cache;
- disabled undocumented metadata with official-only behavior;
- playlist create/add/remove success and failure;
- playlist pagination error.

### QA Status Contract

`scripts/qa-status.py` remains the matrix parser:

- exit `0`: matrix parsed and has zero `FAIL` rows;
- exit `1`: matrix parsed and still has `FAIL` rows;
- exit `2`: matrix missing or malformed.

Phase 2 may add a `qa-status` Make target and gate documentation. Passing `qa-status` is not the same as provider proof; fixture/unit/UI tests remain required.

### Acceptance Criteria

Phase 2 is complete when:

- `YouTubeSearchViewModel` delegates search, discovery, and playlist provider work to services.
- Existing UI-facing published state and status messages remain behavior-compatible.
- Provider request counts are produced by service code and still surfaced for diagnostics/tests.
- Reusable fixtures cover required provider/account/error states.
- `python3 scripts/qa-status.py` is available through a repo command or documented gate.
- `make test`, `gates/checks.sh`, and `gates/backend-checks.sh` pass.

### Tests

Add or update tests for:

- official search success;
- disabled undocumented metadata never called;
- explicit disabled-mode official-only status;
- automatic official failure does not use undocumented fallback;
- video-mode official failure surfaces the official failure;
- duplicate search/discovery coalescing;
- warm-cache/offline fallback;
- playlist load/pagination/create/add/remove success;
- missing write scope, expired auth, quota exceeded, missing playlist item ID;
- fixture graph with no live network/keychain dependency;
- `qa-status` exit codes using small fixture matrices.

### Phase Boundaries

Not started after Phase 2:

- real AVFoundation playback;
- Plex/Spotify/Own Files production hardening;
- Albums/Artists/Downloads implementation;
- Provider Lab production hardening;
- deployment/signing/notarization;
- final release-candidate validation.

## Phase 3: Real AVFoundation Native Playback Contract

Status: proposed for the next implementation phase.

This phase replaces the test-only immediate native engine default with a real AVFoundation-backed engine for `.nativeStream` and `.localFile` playback plans. It does not change source capabilities or add provider surfaces.

### Scope

In scope:

- Add `AVFoundationPlaybackEngine` implementing `PlaybackEngine`.
- Accept only `PlaybackPlan.nativeStream(url:)` and `PlaybackPlan.localFile(url:)` for `nativeAV` routes.
- Build and control an `AVPlayerItem`/`AVPlayer` for native tracks.
- Track elapsed time, duration, play/pause/stop/seek, item ended, and load/playback failures.
- Keep `ImmediatePlaybackEngine` for tests.
- Make `PlaybackCoordinator` default to `AVFoundationPlaybackEngine` in app/runtime code while tests may inject fake engines.
- Preserve `PlaybackRouter` as the only engine-selection gate.
- Preserve `NowPlayingController` as the only `MPNowPlayingInfoCenter` / `MPRemoteCommandCenter` bridge.

Out of scope:

- YouTube or Spotify native audio.
- Hidden/background web playback or stream extraction.
- Downloads/offline storage.
- Plex server hardening beyond using already resolved `MusicTrack.sourceURL`.
- Queue visual redesign, persisted queue, AirPlay UI redesign, or P0 surface completion.

### Engine Contract

`AVFoundationPlaybackEngine` must be `@MainActor` and implement:

- `kind == .nativeAV`.
- `load(_:)` validates the route decision is `.nativeAV` and the plan is `.nativeStream` or `.localFile`.
- `load(_:)` creates an `AVPlayerItem` and prepares an `AVPlayer` without knowing which provider produced the URL.
- `play()`, `pause()`, `stop()`, and `seek(to:)` call through to `AVPlayer`.
- `elapsedTime`, `duration`, and `isPlaying` reflect the current player/item as closely as possible.
- end-of-item notification updates engine state without directly changing queue state; coordinator remains responsible for queue advancement.
- any invalid URL or item failure throws/reports `PlaybackFailure`.

The existing `PlaybackEngine` command surface stays intentionally small. AVFoundation's asynchronous events are surfaced through a separate optional observer so tests can still inject simple engines:

```swift
@MainActor
protocol PlaybackEngineEventObserving: AnyObject {
	func playbackEngineDidUpdateTime(elapsed: TimeInterval, duration: TimeInterval?)
	func playbackEngineDidFinishItem(_ item: PlaybackQueueItem)
	func playbackEngineDidFail(_ failure: PlaybackFailure)
}

@MainActor
protocol PlaybackEngineEventEmitting: AnyObject {
	var eventObserver: PlaybackEngineEventObserving? { get set }
}
```

`AVFoundationPlaybackEngine` must conform to `PlaybackEngineEventEmitting`. `PlaybackCoordinator` may subscribe when the injected engine supports events. Existing test engines may ignore events.

Event rules:

- Time updates refresh coordinator `elapsedTime` and current `PlaybackSessionState` only for the currently loaded queue item.
- Item-ended events set the current session to `.ended` and clear native ownership unless a later phase implements automatic advancement.
- Failure events transition to `.failed`, stop native ownership, and clear Now Playing.
- `clearQueue()` and `stop()` must remove AVPlayer observers/time observers and prevent stale events from mutating a later item.
- Unknown duration remains `nil` and must not crash progress calculations.
- `seek(to:)` clamps to zero and may seek past known duration only if AVPlayer accepts it; tests should cover negative seek clamping.

### Ownership Rules

- System Now Playing/media keys are still enabled only by `PlaybackCoordinator` after native load succeeds.
- Engine success does not bypass `PlaybackRouter.ownsSystemNowPlaying`.
- Embedded and connect-remote plans must still block/clear native ownership.
- Switching away from native playback stops the `AVPlayer` and clears Now Playing.

### Test Matrix

Add tests for:

- native stream plan loads into `AVFoundationPlaybackEngine` and records a loaded item;
- local file plan loads into `AVFoundationPlaybackEngine` when URL is a file URL;
- embedded/connect/unavailable plans are rejected by the native engine;
- invalid URL maps to `PlaybackFailure.invalidMediaURL` or `engineFailed`;
- play/pause/stop/seek mutate engine state deterministically;
- engine event observer delivers elapsed/duration updates to the coordinator;
- item-ended event transitions the coordinator to `.ended` and clears system ownership;
- post-load failure event transitions the coordinator to `.failed` and clears system ownership;
- observer cleanup prevents stale events from a previous item changing the current session;
- coordinator default engine is native AV for app runtime while tests can inject `ImmediatePlaybackEngine`;
- existing `PlaybackSessionTests` inject `ImmediatePlaybackEngine`/fake engines where they assert synchronous fake behavior;
- existing playback session tests remain green.

### Phase Boundaries

Not started after Phase 3:

- provider production hardening;
- downloads/storage;
- P0 surface completion;
- signing/notarization/deployment;
- live provider write tests.

## Phase 4: Provider Production Hardening Contract

Status: proposed for the next implementation phase.

This phase hardens provider behavior behind the existing source adapter seams. It prepares Plex, Own Files, Spotify, YouTube, and YouTube Music for production use without building P0 UI surfaces or downloads.

### Scope

In scope:

- Add source readiness/status snapshots for each provider and feature.
- Add typed provider statuses and issues for not connected, missing config, missing scope, auth expired, rate limited, partial, policy blocked, invalid response, and failure.
- Keep `MusicSourceAdapter`, `SourceRegistry`, `SourceCapabilityResolver`, `PlaybackPlan`, and `PlaybackRouter` as the existing seams.
- Keep capability policy separate from readiness: a feature can be policy-supported but currently blocked by account/server/file state.
- Harden Plex, Own Files, Spotify, YouTube, and YouTube Music adapter behavior and tests.
- Preserve YouTube/Spotify visible embed policy and Plex/Own Files native playback policy.

Out of scope:

- Albums, Artists, Downloads/Storage, Provider Lab, or Settings UI implementation.
- Actual media downloads/offline transfer.
- Spotify native audio or offline storage.
- YouTube native audio, hidden/background playback, extraction, or downloads.
- Live provider write tests.
- Release candidate validation, signing, or notarization.

### Shared Provider Contracts

```swift
enum SourceProviderStatus: Equatable, Sendable {
	case ready
	case notConnected
	case notConfigured(String)
	case missingScope(String)
	case authorizationExpired
	case rateLimited(retryAfter: Date?)
	case providerUnavailable(String)
	case partial
	case policyBlocked(String)
	case invalidProviderResponse
	case failed(String)
}

enum SourceCacheState: Equatable, Sendable {
	case none
	case warm(updatedAt: Date)
	case stale(updatedAt: Date)
	case refreshed(updatedAt: Date)
}

struct SourceProviderIssue: Equatable, Sendable {
	let code: String
	let message: String
}

struct SourceProviderReadiness: Equatable, Sendable {
	let source: MediaSourceKind
	let feature: SourceFeature
	let status: SourceProviderStatus
	let checkedAt: Date
	let account: SourceAccountSummary?
	let cacheState: SourceCacheState
	let issues: [SourceProviderIssue]
	let requestCounts: [String: Int]
}

enum MusicPlaybackLocator: Codable, Hashable, Sendable {
	case providerItem(MusicProviderEntityID)
	case plexMediaPart(path: String, serverID: String?)
	case securityScopedBookmark(id: String)
	case webEmbed(contentID: String)
}

struct SourcePlaybackResolution: Equatable, Sendable {
	let plan: PlaybackPlan
	let status: SourceProviderStatus
	let requiresVisiblePlayer: Bool
	let isShareableURL: Bool
}

@MainActor
protocol SourceProviderReadinessProviding: AnyObject {
	func readiness(for feature: SourceFeature) async -> SourceProviderReadiness
}

@MainActor
protocol SourcePlaybackResolving: AnyObject {
	func resolvePlayback(for track: MusicTrack) async -> SourcePlaybackResolution
}
```

`playbackPlan(for:)` remains as a compatibility shim; new provider code should prefer `resolvePlayback(for:)` where readiness/status matters.

### Provider Acceptance

Plex:

- PIN auth, Keychain token storage, restore, disconnect, and Plex Pass tier remain in `Integrations/Plex`.
- Server discovery must prefer secure reachable connections and reject plain HTTP unless a later explicit insecure-local policy is approved.
- Search/library/playlists/tracks map real Plex DTOs to neutral models with partial/error status, not fake empties.
- Playback resolves to `.nativeStream` only for reachable token-bearing media parts.
- Token-bearing media URLs must never be logged, stored as public source links, or shared.

Own Files:

- Local playback resolves to `.localFile` only after a file URL is valid and accessible.
- Missing files, non-file URLs, stale future bookmarks, unsupported formats, and permission denial are explicit blocked states.
- Import UI and persistent bookmark/index store are not part of this phase.

Spotify:

- OAuth PKCE, token refresh, Web API search/library/playlists stay official-only.
- 401/expired auth, 429/rate limit, missing config, pagination errors, and decode failures produce typed statuses.
- Playback remains `.embedded(WebEmbed(provider: .spotify))`; no native AV, system Now Playing ownership, downloads, or media-key ownership.
- Spotify Connect remote control remains a later phase unless separately contracted.

YouTube / YouTube Music:

- Reuse Phase 2 YouTube services.
- Official YouTube Data API and visible embed remain the policy-safe path.
- Undocumented YouTube Music metadata is disabled; risk-labeling is not sufficient for production use.
- Playlist writes require official write scope and typed missing-scope/quota/auth-expired states.
- YouTube Data API must not pretend to expose canonical albums/artists.

### Capability Honesty

`SourceCapabilityResolver` remains the policy matrix. UI and backend callers must pair policy capability with `SourceProviderReadiness`. Examples:

- Plex playback is policy-active but readiness-blocked when no server or media part is configured.
- Own Files playback is policy-active but readiness-blocked by missing/inaccessible local files.
- Spotify playback is limited to visible official embed, never native.
- YouTube downloads remain unavailable across all tiers.

### Test Matrix

Add or update tests for:

- readiness for connected, not connected, missing config, missing scope, expired auth, rate limited/quota, partial, and policy blocked states;
- Plex secure connection preference, no-server/no-music-section/no-media-part errors, token-bearing URL redaction, and native-stream playback resolution;
- Own Files non-file URL rejection, missing file handling, local-file playback resolution, and unsupported format/policy status;
- Spotify auth/rate-limit/decode/pagination errors and visible-embed-only playback resolution;
- YouTube adapter/service readiness, no canonical album/artist fabrication, no downloads/native routes, playlist write scope required;
- mixed-provider queue route decisions remain native for Plex/Own Files and web embed for YouTube/Spotify.

### Phase Boundaries

Still not started after Phase 4:

- Albums/Artists/P0 UI surface completion;
- actual Downloads/Storage/offline transfer;
- Provider Lab UI hardening;
- live provider write tests;
- deployment/signing/notarization;
- release-candidate validation.

## Phase 5: P0 Music Surfaces Contract

Status: proposed for the next implementation phase.

This phase stabilizes the production music loop: Home, Search, Library, Playlists, Albums, Artists, Queue, Settings, and Now Playing. The phase is UI-facing, but it must bind to the provider readiness and playback-resolution seams from Phase 4. It does not add downloads, device routing, deployment, or live provider write testing.

### Scope

In scope:

- Update the design map and Storybook to show Phase 5 readiness states before native SwiftUI changes.
- Keep Home/Search/Library/Playlists/Queue/Settings/Now Playing aligned with the existing Storybook components and `docs/design/phonodeck-ui-map.json` glossary.
- Surface `SourceProviderReadiness` and `SourcePlaybackResolution` honestly in the UI where provider status changes actions.
- Make source provenance visible on every row/card/detail through `SourceBadge`/`SourcePill`-style markers.
- Stabilize existing Home, Search, Library, Playlists, Queue, Settings, and Now Playing surfaces with empty/loading/error/partial states.
- Make Albums and Artists honest: either backed by real catalog metadata from a ready provider or clearly labeled as limited/derived; do not present YouTube video/channel groupings as canonical albums/artists.
- Keep YouTube/Spotify visible official embed playback and Plex/Own Files native playback ownership rules intact.

Out of scope:

- Actual media downloads/offline transfer and storage-provider UI beyond honest disabled/blocked states.
- Devices/AirPlay/Spotify Connect/Plex session routing beyond truthful current readiness messaging.
- Provider Lab hardening.
- New external metadata providers such as MusicBrainz, Wikipedia, Musixmatch, LyricFind, Songkick, or Bandsintown.
- Spotify native audio, Spotify offline storage, YouTube native audio, hidden/background playback, extraction, or YouTube downloads.
- Signing, notarization, packaging, release-candidate validation, and live provider write tests.

### Surface Acceptance

Home:

- Shows only real recent/cached/account-derived shelves.
- Every shelf/card has truthful provenance such as PhonoDeck history, YouTube activity, YouTube playlist, or connected source.
- Empty and signed-out states lead to Settings/Connect, not fake recommendations.

Search:

- Search remains song-first by default with an explicit result-mode picker.
- Loading, no-results, quota/rate-limit, stale-cache, and fallback states are visible.
- Rows expose source, capability-sensitive actions, and disabled reasons.

Library:

- Phase 5 library is unified but explicitly source-marked.
- If only YouTube is ready, the UI says so; it must not imply a complete multi-source catalog.
- Source filtering is available where mixed-source data exists and hidden or disabled honestly where it does not.

Playlists:

- Shows provider-backed playlists only.
- YouTube playlist read/create/add/remove actions require account state and scopes; missing scope/auth/quota states are typed and visible.
- Multi-source playlists, Plex/Spotify writes, and live write validation remain later work.

Queue:

- Queue is the canonical local app queue and is mirrored in Now Playing > Up Next.
- Blocked provider items stay visible with source/status reason; native engine does not attempt to load them.
- Queue actions remain keyboard/context-menu reachable.

Settings:

- One service row per source reports readiness using Phase 4 statuses: ready, not connected, setup needed, missing scope, expired auth, rate limited, partial, policy blocked, failed.
- Primary actions are Connect, Reconnect, Manage, Retry, or disabled with reason.
- Cache controls remain metadata/artwork-only and never imply YouTube media downloads.

Now Playing:

- Trailing `NowPlayingPanel` and bottom `NowPlayingBar` remain the canonical player surfaces.
- YouTube/Spotify embeds stay visible when they are the active route; native/system media ownership is enabled only for ready Plex/Own Files native routes.
- Lyrics/About/Info states show honest unavailable or attributed data; no synthesized credits, lyrics, bitrate, or artist facts.

Albums and Artists:

- Do not ship normal-looking catalog grids from YouTube video/channel inference alone.
- If no real catalog provider is ready, show a limited empty state explaining that Albums/Artists require Plex, Spotify, or Own Files metadata.
- If a derived YouTube grouping is shown, it must be explicitly labeled limited/derived and every detail field that is not provider-backed must say unavailable.
- Rich/cinematic artist pages require real artist imagery/bio/provider facts and are not part of this phase unless Storybook and data contracts prove them.

### Storybook Preview Contract

Before native SwiftUI implementation, Storybook must include or update these states:

- Home ready, signed-out/empty, partial/stale.
- Search empty, loading, results, no results, quota/rate-limited, fallback/stale cache.
- Library unified/source-marked, source-filtered, partial-source, empty.
- Playlists loading, selected, empty, missing scope, row context menu, sort menu.
- Queue empty, populated, blocked item.
- Settings service rows for ready, notConnected, notConfigured, missingScope, authorizationExpired, rateLimited, policyBlocked, failed.
- Now Playing no-selection, YouTube/Spotify visible embed, native ready, blocked/failed, lyrics unavailable, About unavailable.
- Albums limited empty, limited derived, and real-provider populated examples.
- Artists limited empty, limited derived, and real-provider populated examples.

### Test Matrix

Add or update tests for:

- readiness-status-to-user-facing-message mapping;
- source badge/source pill accessibility labels and non-color-only source identity;
- surface state derivation for Home, Search, Library, Playlists, Queue, Settings, Now Playing, Albums, and Artists;
- Albums/Artists cannot silently present YouTube-derived data as canonical;
- playlist missing-scope/auth/quota states;
- Now Playing ownership: native routes enable system controls, embeds do not;
- blocked queue item presentation and native engine non-load;
- `make qa-status` remains green.

### Phase Boundaries

Still not started after Phase 5:

- Downloads/Storage/offline transfer;
- Devices and external route management beyond truthful readiness display;
- Provider Lab production hardening;
- security/privacy/policy release audit;
- deployment/signing/notarization;
- release-candidate validation.

## Phase 6: Storage, Devices, Provider Lab Contract

Status: proposed for the next implementation phase.

This phase turns three operational utility surfaces into truthful, evidence-bearing product surfaces: Storage/Downloads, Devices, and Provider Lab. It does not implement YouTube/Spotify media downloads, deployment, signing, or release-candidate validation.

### Scope

In scope:

- Rename/position Downloads as a policy-safe Storage Center where the current product only supports metadata/artwork cache management and source policy visibility.
- Add evidence fields to storage, device, and provider diagnostics models: source, checked/measured/created timestamps, status, reason, and cache/request-count evidence where available.
- Keep YouTube and YouTube Music media downloads unavailable; keep Spotify media downloads unavailable.
- Keep current cache clear actions local to metadata/artwork and show confirmation/receipt-style status after completion.
- Keep Devices as route capability/readiness, not a fake device inventory. Use the system AirPlay route picker and explicit source/timestamp/policy rows.
- Harden Provider Lab into a diagnostic-run surface with comparison run identity, timestamps, provider statuses, elapsed time, request count deltas, cache states, and failure isolation.
- Update UI map + Storybook preview before native SwiftUI changes.
- Add tests for source-policy invariants, evidence/timestamp fields, provider diagnostic runs, and no fake media/device claims.

Out of scope:

- Actual Plex or Own Files media download/import operations.
- YouTube/Spotify media downloads, hidden audio, copied cookies, stream extraction, or background playback.
- Enumerating real AirPlay/HomePod/Cast targets beyond public system UI.
- Provider Lab live external writes or destructive actions.
- Security/privacy release audit, signing, notarization, packaging, deployment, or RC validation.

### Operational Objects

Storage:

- `MusicStorageAsset`: source, title, kind, status, byte count, local/source URL where safe.
- `MusicStorageSourcePolicy`: source, support status, details, allowed asset kinds, blocked actions.
- `MusicStorageSnapshot`: assets, bytes, blocked count, measuredAt, evidence source.
- `StorageCacheClearReceipt`: target, clearedAt, estimated/previous bytes, retained data statement.

Devices:

- `DeviceRoutingCapability`: id, symbol, title, support state, detail, source, checkedAt.
- `DeviceRouteSupportState`: available, limited, notExposed, planned.

Provider Lab:

- `ProviderComparisonRun`: run id, query, preference, startedAt, completedAt, durationMs, provider results, request count deltas.
- `ProviderComparisonProviderResult`: provider id, status, item count, cache state, error message, risk label.

### Acceptance

Storage Center:

- Empty/cache-ready/partial/error states are distinguishable.
- All metrics show scope and timestamp; no generic dashboard numbers without source.
- Cache clear explains what is deleted and what is retained; after completion, a receipt/status states what happened.
- YouTube/Spotify media downloads appear only as policy-blocked source rows, not as primary enabled actions.
- `MusicStorageSnapshot` never surfaces YouTube/YouTube Music/Spotify owned-media assets.

Devices:

- Shows system AirPlay picker for native routes where public APIs allow it.
- Shows YouTube/Spotify web-player routing limits as explicit capability rows.
- Shows source and checkedAt for capability facts.
- Does not fabricate device inventory, HomePod default service, Cast targets, Premium tier, or cross-device history.

Provider Lab:

- A comparison is a diagnostic run, not just two result cards.
- Each run has id/timestamps/duration/query/preference and preserves provider-independent success/failure.
- Official provider results and the disabled metadata policy row show status, item count, request delta, cache state, and risk label.
- In-flight duplicate comparisons are coalesced or disabled; repeated runs are not silently spammed.
- Signed-out, quota, invalid response, both-failed, warm-cache, and disabled-policy states remain visible and actionable.

### Storybook Preview Contract

Before native SwiftUI implementation, Storybook must include or verify:

- Storage empty cache, populated metadata/artwork, policy-blocked source rows, clear confirmation/receipt, and partial/error measurement.
- Devices active YouTube embed route, active native route, no fake devices, system picker available, source/timestamp rows, and external action unavailable states.
- Provider Lab no query, comparing with prior results retained, official success plus disabled-policy row, official auth/quota with no undocumented fallback, both failed, warm cache/offline, invalid response, and long-title/narrow states.

### Tests

Add or update tests for:

- storage snapshot measuredAt/evidence source and blocked owned-media count;
- cache clear receipt/preflight for artwork/metadata/all targets;
- YouTube/Spotify owned-media assets remain blocked;
- device capability source/checkedAt/support-state correctness;
- provider comparison run id/timestamps/duration, per-provider status, request deltas, timeout/failure isolation, and in-flight duplicate behavior;
- UI surface state derivation for storage/device/provider diagnostics.

### Phase Boundaries

Still not started after Phase 6:

- broader UX/accessibility/performance validation;
- security/privacy/policy release audit;
- deployment/signing/notarization;
- release-candidate validation.

## Phase 7: UX, Accessibility, Performance Contract

Status: proposed for the next implementation phase.

This phase validates and lightly polishes the already-implemented surfaces. It adds screenshot and accessibility/performance evidence, then fixes only issues found inside the current surfaces. It does not add new provider capability, downloads, deployment, or release-candidate security work.

### Scope

In scope:

- Restore or add the configured screenshot harness referenced by `architrave.config.json` (`scripts/screenshot.sh`).
- Capture or define reproducible screenshot targets for Storybook and native app surfaces.
- Validate light/dark, minimum window, standard desktop, and wide layouts for Home, Search, Library, Playlists, Albums, Artists, Queue, Settings, Now Playing, Storage, Devices, and Provider Lab.
- Validate VoiceOver/accessibility labels and Full Keyboard Access for sidebar, toolbar/search, row actions, queue controls, Settings rows, Now Playing, Storage, Devices, and Provider Lab.
- Validate menu/keyboard behavior: Navigate commands, Playback commands, sidebar visibility, and Now Playing/Up Next/Lyrics/About availability.
- Validate reduced-motion/increase-contrast states where automation or system settings make this practical.
- Measure warm-cache behavior for Home/Search/Library/Storage/Provider Lab enough to prove no spinner-only or frozen cached state.
- Make targeted fixes for missing labels/help, disabled reasons, keyboard reachability, screenshot harness, and obvious layout overflow found by the checks.

Out of scope:

- Full native shell rewrite to `NavigationSplitView` unless validation proves the current shell is unusable.
- Full playlist/album `Table` parity if it requires a broad refactor; mark as defer/failing item with evidence if necessary.
- New provider integrations, downloads/imports, device inventory, live writes, security/privacy release audit, deployment, signing, notarization, or RC validation.

### Golden Surface Matrix

Storybook preview set:

- Screens: Home, First Run, Library, Playlist, Albums, Artists, Queue, Search, Settings.
- Now Playing: no selection, visible YouTube iframe, Spotify embed, native source, blocked route, failed route, lyrics unavailable, About unavailable/native.
- Phase 5 readiness states.
- Phase 6 Storage, Devices, Provider Lab operational states.

Native surface set:

- Library/Home, Search, Playlists, Albums, Artists, Queue, Settings, Now Playing, Storage, Devices, Provider Lab.

Viewport/environment set:

- Minimum window: 940 × 640.
- Standard desktop: 1200 × 760.
- Wide desktop: 1400 × 900 or wider.
- Light and Dark appearance.
- Increase Contrast and Reduce Motion checks where available.

### Accessibility Acceptance

- No unlabeled icon-only actionable controls on golden surfaces.
- Disabled controls remain visible and explain why through label/help/status.
- Rows announce title, artist/channel, source, selected/current state, and action hint.
- Source identity is not color-only.
- Full Keyboard Access traversal is deterministic: sidebar → toolbar/search → content rows/tables → row actions/context menus → right panel → bottom bar.
- Standard shortcuts do not break text editing; Space must not steal typing focus from text fields.
- Menu commands exist or are explicitly deferred for sidebar/Now Playing/Up Next/Lyrics/About visibility.

### Performance Acceptance

- Warm-cache Home/Search/Library/Storage surfaces show cached or stale evidence within roughly 500 ms after view appear.
- No spinner-only state remains over 1 s when warm cache exists.
- Section switches and cached scrolling should avoid visible main-thread stalls over roughly 100 ms.
- Provider Lab keeps previous diagnostic results visible while a new comparison runs.

### Test And Evidence Matrix

Add or update:

- screenshot harness script and docs/output path;
- focused tests for any added presentation helpers or keyboard/menu state logic;
- Storybook build and UI map validation;
- native build/test gates;
- recorded manual checklist for VoiceOver/Full Keyboard Access if fully automating is impractical;
- explicit deferred/failing items with phase assignment when broad refactors are out of Phase 7 scope.

### Phase Boundaries

Still not started after Phase 7:

- security/privacy/policy release audit;
- deployment/signing/notarization;
- release-candidate validation.

## Phase 8: Security, Privacy, Policy Contract

Status: completed.

This phase audits and hardens security, privacy, and source-policy behavior before deployment engineering. It focuses on token handling, secret hygiene, local data deletion, logging/redaction, OAuth scope truth, cache retention, and provider policy boundaries.

### Scope

In scope:

- Verify Google, Spotify, and Plex tokens are stored only in Keychain.
- Verify disconnect paths delete provider Keychain credentials and either clear provider-authorized local metadata/artwork by default or expose an explicit user-visible deletion path that satisfies provider revocation/storage rules.
- Remove or redact local secret values from ignored developer files where safe; never print secrets in logs, artifacts, or chat.
- Add tests or guardrails for token redaction, Keychain accessibility attributes, and local data deletion helpers.
- Audit logs for accidental token/secret/personal-data exposure and ensure URLs with tokens are redacted.
- Confirm OAuth scopes are current-feature scoped and UI copy explains missing scopes/reconnect needs.
- Confirm YouTube/Spotify/Plex policy boundaries: no YouTube/Spotify media downloads, no hidden extraction, no private APIs, Plex token URLs non-shareable.
- Update `docs/security-privacy.md` with implemented privacy controls and remaining release-audit tasks.

Out of scope:

- Signing, notarization, installer/package creation, or deployment.
- Final public privacy policy/legal copy publication.
- Live provider write tests or account revocation calls beyond local disconnect behavior.
- Full release-candidate validation/go-no-go.

### Acceptance

- `Config/Secrets.xcconfig` is ignored and local secret hygiene is documented; no secret value is stored in run artifacts or logs.
- Keychain items use appropriate accessibility attributes for app tokens.
- Account disconnect removes stored credentials for Google, Spotify, and Plex.
- Account disconnect behavior for authorized cached metadata/artwork is explicit and testable: either provider-authorized caches are cleared during disconnect, or a visible deletion path is documented and implemented.
- Local cache clearing without credential deletion remains available as a separate action and must not imply provider logout.
- Logs use `.private` for titles/personal data and redact token-bearing URLs.
- Tests cover `RedactedURL`, Keychain query attributes where testable, and local cache/data deletion helpers.
- Security/privacy docs list current controls, user-visible data deletion paths, and items intentionally deferred to Phase 10/release legal review.
- Entitlement rationale is documented: network server is for loopback OAuth; file access is user-selected; deployment signing/notarization remains Phase 9.

### Phase Boundaries

Still not started after Phase 8:

- deployment/signing/notarization;
- release-candidate validation/go-no-go.

## Phase 9: Deployment Engineering Contract

Status: proposed for the next implementation phase.

This phase makes the macOS app reproducibly packageable and signing/notarization-ready without storing Apple credentials or shipping a public release. It focuses on version/package metadata, local unsigned artifacts, credential-free preflight checks, and clean-install smoke instructions. It does not perform final RC validation or public distribution approval.

### Scope

In scope:

- Add deterministic release scripts/Make targets for a local unsigned Release build and packaged artifact.
- Validate app bundle metadata: bundle identifier, marketing version, build number, category, sandbox entitlements, and local-secret placeholders.
- Add signing/notarization preflight that reports required environment variables, certificates, and tools without reading or printing credentials.
- Document signed Developer ID archive/export/notarization/stapling workflow as operator-run steps.
- Document clean-install/reset smoke steps for Phase 10, including what local state can be removed and what provider-side credential rotation remains external.
- Keep Debug/test targets unchanged and keep `CODE_SIGNING_ALLOWED=NO` deterministic gates available.

Out of scope:

- Signing with a real Developer ID, submitting notarization, stapling, or uploading/releasing artifacts.
- Creating/storing Apple IDs, app-specific passwords, API keys, team IDs, certificates, or provisioning secrets in the repo.
- Final live OAuth/provider validation, public privacy/legal publication, release notes, or go/no-go.
- Changing provider policy or playback/source architecture.

### Acceptance

- `make package-local` or equivalent produces a local unsigned Release `.app` and compressed artifact under `build/release/` without credentials.
- A release preflight command validates expected tools, project metadata, entitlements, and secret hygiene, and reports signed/notarized readiness without exposing secrets.
- Version/build numbers come from `project.yml`/Info.plist expansion and are visible in the packaged app.
- Signing/notarization docs list exact operator steps and required environment variables, with redaction/no-secret rules.
- Clean-install smoke checklist exists for Phase 10 and separates app-local state removal from provider-side revocation/rotation.
- `make test`, `gates/backend-checks.sh`, `gates/checks.sh`, release preflight, package-local, secret/policy scans, and run validation pass.

### Phase Boundaries

Still not started after Phase 9:

- final release-candidate validation/go-no-go;
- live provider write/revocation validation;
- public privacy/legal release approval;
- actual signed/notarized public distribution.

## Phase 10: RC Validation Go/No-Go Contract

Status: proposed for the final validation phase.

This phase consolidates release-candidate evidence and makes an explicit go/no-go recommendation. It does not silently release PhonoDeck. It separates deterministic repo evidence from manual/operator evidence that requires credentials, live providers, or external legal/policy approval.

### Scope

In scope:

- Produce `docs/qa/rc-validation-report.md` with deterministic gate results, package metadata, security/privacy status, source-policy status, manual/live validation checklist, and go/no-go recommendation.
- Re-run deterministic gates: `make release-preflight`, `make package-local`, `make test`, `gates/backend-checks.sh`, `gates/checks.sh`, `make qa-status`, UI map JSON validation, policy scan, secret-prefix scan, and run validation.
- Verify the unsigned local package artifact metadata and packaged OAuth secret state.
- List operator-required evidence for Developer ID signing, notarization, provider live smoke, Google secret rotation, final privacy/legal publication, and release notes.
- Mark release status as GO only if all required deterministic and operator/manual evidence is complete; otherwise produce an explicit NO-GO with blockers.

Out of scope:

- Performing real signing, notarization, stapling, upload, or public release.
- Rotating provider credentials for the user.
- Running live provider writes/revocation without separate explicit operator approval and test-account cleanup.
- Publishing legal/privacy documents or release notes.

### Acceptance

- RC report exists and includes completed deterministic evidence with timestamps/artifact references.
- RC report explicitly identifies manual/operator blockers and the resulting GO/NO-GO state.
- Deterministic gates pass or failures are listed as blockers.
- Package metadata and packaged OAuth secret checks are recorded.
- Run artifacts and summary reflect Phase 10 status and judge verdict.