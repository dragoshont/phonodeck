# Production P0 Plan Adversarial Review

Date: 2026-06-19
Reviewed Plan: [production-p0-implementation-plan.md](production-p0-implementation-plan.md)
QA Matrix: [production-p0-screen-test-matrix.md](production-p0-screen-test-matrix.md)

## Review Directive

The product directive is: **no interim release, no subset release, ship all P0 surfaces only when complete**.

Any reviewer recommendation to hide, defer, or scope down Albums, Artists, Downloads/Storage, Provider Lab, Plex, Spotify, Own Files, or other promised surfaces is rejected as a release strategy. Development toggles may exist for branch work, but production release still requires every P0 surface to pass.

## Subagent Review Summary

Four read-only subagents reviewed the plan and current code from different angles:

- UI/UX red team.
- Implementation architecture red team.
- API/policy red team.
- QA/release-gate red team.

## Accepted Findings

### 1. Architecture Must Precede More UI Work

The implementation plan underestimates the risk of continuing to add state to `YouTubeSearchViewModel`. It already owns search, discovery, playlists, provider comparisons, history, queue, metadata caches, and video details.

Accepted change:

- Add an architecture foundation phase before more feature work.
- Split responsibilities into services/coordinators.
- Add provider/client protocols before expanding Albums, Artists, Downloads, or playlist tests.

### 2. Fixture Mode And CI Gates Are Not Optional

The QA matrix is useful, but it is currently document-driven. Release readiness cannot depend on manual inspection.

Accepted change:

- Fixture mode must move earlier.
- Mock providers must exist before playlist, album, artist, download, and UI tests can be reliable.
- Add a `qa-status` script and CI workflow that blocks release while any P0 case is `FAIL`.

### 3. Search/Discovery Coalescing Should Move Earlier

Slow UI and repeated tab/search network calls are a root problem. Delaying coalescing and cancellation until after more UI work creates rework.

Accepted change:

- Move request coalescing/cancellation before large surface implementation.
- Add provider timing and cache hit/miss instrumentation early.

### 4. Playlist Client Must Be Mockable

Playlist create/add cannot be considered production reliable while tied directly to live Google APIs and generic errors.

Accepted change:

- Add a `YouTubePlaylistClient` / `YouTubeDataClientProtocol` test seam.
- Add fixtures for missing scope, auth expired, quota exceeded, pagination error, duplicate item, network unavailable, create success, add success.

### 5. Albums/Artists Need A Real Source Decision

YouTube Data API cannot supply canonical albums/artists. YouTube Music internal metadata is not a stable official album/artist source.

Accepted change:

- Albums and Artists must be powered by real sources: Plex, Own Files/iTunes XML, MusicKit, and/or Spotify metadata.
- YouTube/YouTube Music can contribute playable tracks and source links, but must not pretend to be a canonical album/artist catalog unless the provider exposes that entity.

### 6. Downloads/Storage Needs A Real Supported Source

The Downloads/Storage surface cannot be only policy text. It must manage real local/cache/offline assets for supported sources.

Accepted change:

- Implement metadata/artwork cache management.
- Implement Own Files local storage/import and/or Plex owned-media downloads before the surface passes.
- Keep YouTube media downloads explicitly unavailable.

### 7. Provider Lab Must Be A Production Diagnostic Surface

Because the current directive says ship all, Provider Lab cannot be treated as temporary internal tooling if it remains in the app.

Accepted change:

- Make Provider Lab production-ready: throttle comparisons, label diagnostics clearly, show provider risk, handle failure states, and cover it with tests.

### 8. API/Policy Documentation Needs A Hard Boundary

The plan must not imply undocumented YouTube Music internals are policy-safe production infrastructure.

Accepted change:

- Keep official YouTube Data API + visible YouTube player as the compliant playback path.
- Treat internal/no-cookie YouTube Music metadata experiments as superseded and not production sources.
- Use Plex/Own Files/MusicKit/Spotify for official album/artist/library style metadata where possible.

## Rejected Findings

### Hide Or Defer Incomplete Surfaces

Several subagent recommendations suggested hiding Albums, Artists, Downloads, Plex, Spotify, Own Files, or Provider Lab for a focused release.

Disposition: **Rejected for release strategy.**

Reason:

- The current product directive is no interim/subset release.
- Development toggles are acceptable while work is in progress, but release candidate builds must expose and pass all P0 surfaces.

### YouTube-Music-Only P0

One review proposed a YouTube/YouTube-Music-only P0.

Disposition: **Rejected.**

Reason:

- The current user directive is to ship the full app promise, not a focused YouTube-only release.

## Required Plan Corrections

The implementation plan must be updated to include:

1. A new architecture foundation phase before feature expansion.
2. A provider strategy phase that explicitly assigns real providers for Albums, Artists, Downloads/Storage, Plex, Spotify, and Own Files.
3. Earlier fixture-mode and CI release gates.
4. Earlier request coalescing/cancellation work.
5. Explicit policy boundary for YouTube Music internal metadata.
6. Production-ready Provider Lab requirements, not a ship/remove ambiguity.

## Corrected High-Level Order

1. Architecture foundation and provider strategy.
2. Fixture mode, mock providers, QA script, CI gates.
3. Request coalescing/cancellation and instrumentation.
4. Artwork/metadata cache.
5. Now Playing controls and player state hardening.
6. Playlist client abstraction and production error UX.
7. Own Files/Plex/MusicKit/Spotify source implementations needed for album/artist/download surfaces.
8. Albums and Artists real surfaces.
9. Downloads/Storage real surface.
10. Devices test seams.
11. Provider Lab production hardening.
12. Full matrix/screenshot/performance release pass.
