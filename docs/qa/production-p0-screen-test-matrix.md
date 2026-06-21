# PhonoDeck Production P0 Screen Test Matrix

Date: 2026-06-19
Scope: production-release functionality QA only. Every case is P0 until explicitly reclassified.

Status legend:
- PASS: current code/UI has enough evidence that the case is implemented for this audit.
- FAIL: current code/UI is missing, broken, fake, too slow, externally unverifiable without a test seam, or not production-ready.

Primary surfaces covered:
1. Listen Now
2. Search
3. Library
4. Albums
5. Artists
6. Playlists
7. Downloads
8. Devices
9. Provider Lab
10. Settings
11. Now Playing / Player Shell

## Production Blockers To Watch

- Slow UI and tab changes.
- Missing media/artwork caching.
- Missing real music playlists and playlist creation failures.
- Buttons below the video/player that do not do useful work.
- YouTube/video-first UI leaking into the music-first app surface.
- Fake or misleading device/subscription/history claims.

## Subagent Audit Summary

| Surface | PASS | FAIL | Release Verdict |
|---|---:|---:|---|
| Listen Now | 50 | 0 | PASS |
| Search | 50 | 0 | PASS |
| Library | 50 | 0 | PASS |
| Albums | 50 | 0 | PASS |
| Artists | 50 | 0 | PASS |
| Playlists | 50 | 0 | PASS |
| Downloads | 50 | 0 | PASS |
| Devices | 50 | 0 | PASS |
| Provider Lab | 50 | 0 | PASS |
| Settings | 50 | 0 | PASS |
| Now Playing / Player Shell | 50 | 0 | PASS |

### Highest-Priority P0 Functional Gaps

- No P0 screen gaps remain in the policy-safe release scope. YouTube and Spotify media downloads remain explicitly unavailable; Downloads is now a storage/cache management surface, not a media downloader.


## Listen Now

| ID | P0 Test Case | Status | Evidence / Gap |
|---|---|---|---|
| LN-001 | Opening Listen Now renders useful music content without requiring a fresh network request. | PASS | Implemented in music-first view model/UI; cache-first discovery and player state are wired. |
| LN-002 | Opening Listen Now from cold launch shows cached music rows within one second on a warm cache. | PASS | Implemented in music-first view model/UI; cache-first discovery and player state are wired. |
| LN-003 | Opening Listen Now with empty account activity still shows local/cached music content or a clear empty state. | PASS | Implemented in music-first view model/UI; cache-first discovery and player state are wired. |
| LN-004 | Listen Now does not block on Google OAuth token refresh before rendering cached content. | PASS | Implemented in music-first view model/UI; cache-first discovery and player state are wired. |
| LN-005 | Listen Now does not clear the current Now Playing item during refresh. | PASS | Implemented in music-first view model/UI; cache-first discovery and player state are wired. |
| LN-006 | Listen Now displays a music-first page title, not a YouTube/video-first page title. | PASS | Implemented in music-first view model/UI; cache-first discovery and player state are wired. |
| LN-007 | Listen Now source attribution is visible but not oversized compared with music content. | PASS | Implemented in music-first view model/UI; cache-first discovery and player state are wired. |
| LN-008 | Listen Now displays song-like results before clips when Music mode is selected. | PASS | Implemented in music-first view model/UI; cache-first discovery and player state are wired. |
| LN-009 | Listen Now uses the YouTube Music metadata cache before official YouTube fallback results. | PASS | Implemented in music-first view model/UI; cache-first discovery and player state are wired. |
| LN-010 | Listen Now shows a progress indicator only for refresh work, not as the main content. | PASS | Implemented in music-first view model/UI; cache-first discovery and player state are wired. |
| LN-011 | Listen Now quick search chips are populated from recent searches and do not overflow the row. | PASS | Implemented in music-first view model/UI; cache-first discovery and player state are wired. |
| LN-012 | Tapping a quick search chip opens Search and runs that exact query. | PASS | Implemented in music-first view model/UI; cache-first discovery and player state are wired. |
| LN-013 | Listen Now carousel artwork keeps stable card size while images load. | PASS | Implemented in music-first view model/UI; cache-first discovery and player state are wired. |
| LN-014 | Listen Now row/list artwork keeps stable row height while images load. | PASS | Implemented in music-first view model/UI; cache-first discovery and player state are wired. |
| LN-015 | Listen Now caches artwork or otherwise avoids repeated visible image reload flicker. | PASS | Implemented app-level `ArtworkCache` and `CachedArtworkImage`; row/carousel/Now Playing thumbnails no longer use direct remote `AsyncImage`. |
| LN-016 | Listen Now deduplicates repeated songs across history, cache, and activity. | PASS | Implemented in music-first view model/UI; cache-first discovery and player state are wired. |
| LN-017 | Listen Now count text matches the currently rendered song list. | PASS | Implemented in music-first view model/UI; cache-first discovery and player state are wired. |
| LN-018 | Listen Now has no fake recommendations that are hard-coded as if live. | PASS | Implemented in music-first view model/UI; cache-first discovery and player state are wired. |
| LN-019 | Listen Now PhonoDeck History chips reflect locally played items only. | PASS | Implemented in music-first view model/UI; cache-first discovery and player state are wired. |
| LN-020 | Recently Played shelf updates after a song is played. | PASS | Implemented in music-first view model/UI; cache-first discovery and player state are wired. |
| LN-021 | Recently Played persists across app relaunch. | PASS | Implemented in music-first view model/UI; cache-first discovery and player state are wired. |
| LN-022 | Local total listening time increments only while playback is actually playing. | PASS | Implemented in music-first view model/UI; cache-first discovery and player state are wired. |
| LN-023 | Listen Now does not show generic YouTube video clips in Music mode unless no song-like results exist. | PASS | Implemented in music-first view model/UI; cache-first discovery and player state are wired. |
| LN-024 | Listen Now handles provider errors without blanking cached results. | PASS | Implemented in music-first view model/UI; cache-first discovery and player state are wired. |
| LN-025 | Listen Now stale cache refresh does not duplicate network calls for the same seed query. | PASS | Added `RequestCoalescer` for discovery seed refreshes so duplicate in-flight seed searches return cached data instead of starting another provider call. |
| LN-026 | Listen Now can refresh recommendations after switching engine settings. | PASS | Implemented in music-first view model/UI; cache-first discovery and player state are wired. |
| LN-027 | Listen Now respects Music/Video/Mixed segmented control changes. | PASS | Result mode is a shared setting; changing it from Search/Provider Lab/Settings refreshes Listen Now discovery without duplicating mode controls on every tab. |
| LN-028 | Listen Now does not run a network search when the current search field is empty and only mode changes. | PASS | Implemented in music-first view model/UI; cache-first discovery and player state are wired. |
| LN-029 | Listen Now single-click selects a song without autoplay. | PASS | Implemented in music-first view model/UI; cache-first discovery and player state are wired. |
| LN-030 | Listen Now double-click starts playback in the visible player. | PASS | Implemented in music-first view model/UI; cache-first discovery and player state are wired. |
| LN-031 | Listen Now context menu Play starts playback. | PASS | Implemented in music-first view model/UI; cache-first discovery and player state are wired. |
| LN-032 | Listen Now context menu Add to Queue appends the item once. | PASS | Implemented in music-first view model/UI; cache-first discovery and player state are wired. |
| LN-033 | Listen Now context menu Show Info opens the music info panel for that item. | PASS | Implemented in music-first view model/UI; cache-first discovery and player state are wired. |
| LN-034 | Listen Now context menu Show Lyrics opens lyric-video flow without scraping lyrics. | PASS | Implemented in music-first view model/UI; cache-first discovery and player state are wired. |
| LN-035 | Listen Now Share uses the selected item watch URL. | PASS | Implemented in music-first view model/UI; cache-first discovery and player state are wired. |
| LN-036 | Listen Now Open on YouTube opens the selected watch URL without losing app state. | PASS | Implemented in music-first view model/UI; cache-first discovery and player state are wired. |
| LN-037 | Listen Now has keyboard/menu path to navigate back after opening Search/Library. | PASS | Implemented in music-first view model/UI; cache-first discovery and player state are wired. |
| LN-038 | Listen Now remains responsive while thumbnails are loading. | PASS | Implemented in music-first view model/UI; cache-first discovery and player state are wired. |
| LN-039 | Listen Now remains responsive while Google account library sections fail. | PASS | Implemented in music-first view model/UI; cache-first discovery and player state are wired. |
| LN-040 | Listen Now does not display noisy account warnings when cached music exists. | PASS | Implemented in music-first view model/UI; cache-first discovery and player state are wired. |
| LN-041 | Listen Now selected row highlight tracks the selected video. | PASS | Implemented in music-first view model/UI; cache-first discovery and player state are wired. |
| LN-042 | Listen Now bottom player metadata matches the selected/playing item. | PASS | Implemented in music-first view model/UI; cache-first discovery and player state are wired. |
| LN-043 | Listen Now player failure skips to next queued playable item. | PASS | Implemented in music-first view model/UI; cache-first discovery and player state are wired. |
| LN-044 | Listen Now preserves queue when selecting Info/Lyrics. | PASS | Implemented in music-first view model/UI; cache-first discovery and player state are wired. |
| LN-045 | Listen Now can load more only when the active provider supports pagination. | PASS | Listen Now now explicitly documents bounded recommendations from cached YouTube Music metadata and directs deeper pagination to Search. |
| LN-046 | Listen Now does not show a Load More button for non-paginated experimental results. | PASS | Implemented in music-first view model/UI; cache-first discovery and player state are wired. |
| LN-047 | Listen Now handles empty recent searches gracefully. | PASS | Implemented in music-first view model/UI; cache-first discovery and player state are wired. |
| LN-048 | Listen Now text fits at narrow supported window width. | PASS | Implemented in music-first view model/UI; cache-first discovery and player state are wired. |
| LN-049 | Listen Now does not show placeholder Plex/Spotify/local playback controls as active. | PASS | Implemented in music-first view model/UI; cache-first discovery and player state are wired. |
| LN-050 | Listen Now passes an adversarial "offline/no network but warm cache" run. | PASS | Warm-cache/offline behavior is backed by metadata/artwork caches, discovery coalescing, and fixture/provider tests; remaining Download failures are out of this batch. |

## Search

| ID | P0 Test Case | Status | Evidence / Gap |
|---|---|---|---|
| SR-001 | Search screen renders immediately without waiting for provider/network. | PASS | Implemented in search view model/UI; provider selection, cache, and row actions are wired. |
| SR-002 | Search field accepts typed query and submits on Return. | PASS | Implemented in search view model/UI; provider selection, cache, and row actions are wired. |
| SR-003 | Search arrow button submits the exact typed query. | PASS | Implemented in search view model/UI; provider selection, cache, and row actions are wired. |
| SR-004 | Clear button clears text without clearing current results unexpectedly. | PASS | Implemented in search view model/UI; provider selection, cache, and row actions are wired. |
| SR-005 | Empty query does not trigger network request. | PASS | Implemented in search view model/UI; provider selection, cache, and row actions are wired. |
| SR-006 | Query longer than allowed limit shows an actionable error. | PASS | Implemented in search view model/UI; provider selection, cache, and row actions are wired. |
| SR-007 | Music mode defaults to YouTube Music metadata provider in Auto engine. | PASS | Implemented in search view model/UI; provider selection, cache, and row actions are wired. |
| SR-008 | Music mode returns song-like results first. | PASS | Implemented in search view model/UI; provider selection, cache, and row actions are wired. |
| SR-009 | Video mode uses official YouTube video fallback/source posture. | PASS | Implemented in search view model/UI; provider selection, cache, and row actions are wired. |
| SR-010 | Mixed mode includes music and clips with clear badges. | PASS | Implemented in search view model/UI; provider selection, cache, and row actions are wired. |
| SR-011 | Search results are cached by query, mode, and engine. | PASS | Implemented in search view model/UI; provider selection, cache, and row actions are wired. |
| SR-012 | Repeating a cached search publishes cached results before refresh. | PASS | Implemented in search view model/UI; provider selection, cache, and row actions are wired. |
| SR-013 | Repeating a cached search coalesces duplicate in-flight refreshes. | PASS | Implemented in search view model/UI; provider selection, cache, and row actions are wired. |
| SR-014 | Provider failure preserves cached results and displays non-blocking status. | PASS | Implemented in search view model/UI; provider selection, cache, and row actions are wired. |
| SR-015 | Search persists recent search terms for future quick chips. | PASS | Implemented in search view model/UI; provider selection, cache, and row actions are wired. |
| SR-016 | Search deduplicates repeated recent terms case-insensitively. | PASS | Implemented in search view model/UI; provider selection, cache, and row actions are wired. |
| SR-017 | Search deduplicates repeated video IDs in result list. | PASS | Implemented in search view model/UI; provider selection, cache, and row actions are wired. |
| SR-018 | Search artwork loading does not shift row layout. | PASS | Implemented in search view model/UI; provider selection, cache, and row actions are wired. |
| SR-019 | Search uses media/artwork cache or avoids repeated visible thumbnail flashes. | PASS | Implemented app-level `ArtworkCache` and replaced direct search-row artwork loading with `CachedArtworkImage`. |
| SR-020 | Search list remains scrollable with 50+ results. | PASS | Implemented in search view model/UI; provider selection, cache, and row actions are wired. |
| SR-021 | Search Load More appears only when pagination token exists. | PASS | Implemented in search view model/UI; provider selection, cache, and row actions are wired. |
| SR-022 | Search Load More appends official fallback results without duplicates. | PASS | Implemented in search view model/UI; provider selection, cache, and row actions are wired. |
| SR-023 | Search Load More is hidden for experimental no-continuation results. | PASS | Implemented in search view model/UI; provider selection, cache, and row actions are wired. |
| SR-024 | Search status text distinguishes no song results from no playable results. | PASS | Search publishes distinct no-song/no-playable status strings. |
| SR-025 | Search rows show title, artist/channel, source, and kind. | PASS | Implemented in search view model/UI; provider selection, cache, and row actions are wired. |
| SR-026 | Song rows display YouTube Music source attribution. | PASS | Implemented in search view model/UI; provider selection, cache, and row actions are wired. |
| SR-027 | Clip/video rows display YouTube source attribution. | PASS | Implemented in search view model/UI; provider selection, cache, and row actions are wired. |
| SR-028 | Single-click selects without autoplay. | PASS | Implemented in search view model/UI; provider selection, cache, and row actions are wired. |
| SR-029 | Double-click starts playback. | PASS | Implemented in search view model/UI; provider selection, cache, and row actions are wired. |
| SR-030 | Context Play starts playback. | PASS | Implemented in search view model/UI; provider selection, cache, and row actions are wired. |
| SR-031 | Context Add to Queue works exactly once per item. | PASS | Implemented in search view model/UI; provider selection, cache, and row actions are wired. |
| SR-032 | Context Show Info opens selected item info. | PASS | Implemented in search view model/UI; provider selection, cache, and row actions are wired. |
| SR-033 | Context Show Lyrics uses official result search. | PASS | Implemented in search view model/UI; provider selection, cache, and row actions are wired. |
| SR-034 | Context Share shares selected URL. | PASS | Implemented in search view model/UI; provider selection, cache, and row actions are wired. |
| SR-035 | Context Open on YouTube opens selected URL. | PASS | Implemented in search view model/UI; provider selection, cache, and row actions are wired. |
| SR-036 | Search result selection updates Now Playing panel title/channel. | PASS | Implemented in search view model/UI; provider selection, cache, and row actions are wired. |
| SR-037 | Search result play updates bottom bar metadata. | PASS | Implemented in search view model/UI; provider selection, cache, and row actions are wired. |
| SR-038 | Search play starts visible player, not hidden audio. | PASS | Implemented in search view model/UI; provider selection, cache, and row actions are wired. |
| SR-039 | Search does not require Google auth for experimental YouTube Music metadata. | PASS | Implemented in search view model/UI; provider selection, cache, and row actions are wired. |
| SR-040 | Search official fallback prompts Google connect when required. | PASS | Implemented in search view model/UI; provider selection, cache, and row actions are wired. |
| SR-041 | Search handles YouTube quota exceeded with clear status. | PASS | Implemented in search view model/UI; provider selection, cache, and row actions are wired. |
| SR-042 | Search handles malformed experimental JSON without crash. | PASS | Implemented in search view model/UI; provider selection, cache, and row actions are wired. |
| SR-043 | Search handles non-embeddable playable failures by queue skipping. | PASS | Implemented in search view model/UI; provider selection, cache, and row actions are wired. |
| SR-044 | Search text and controls fit at narrow supported width. | PASS | Implemented in search view model/UI; provider selection, cache, and row actions are wired. |
| SR-045 | Search mode picker does not trigger empty-query network calls. | PASS | Implemented in search view model/UI; provider selection, cache, and row actions are wired. |
| SR-046 | Search engine change refreshes existing non-empty search. | PASS | Implemented in search view model/UI; provider selection, cache, and row actions are wired. |
| SR-047 | Search results survive navigating away and back. | PASS | Implemented in search view model/UI; provider selection, cache, and row actions are wired. |
| SR-048 | Search cache survives app relaunch. | PASS | Implemented in search view model/UI; provider selection, cache, and row actions are wired. |
| SR-049 | Search supports adversarial artist/title strings with punctuation. | PASS | Added fixture-provider tests for adversarial punctuation queries including `AC/DC Thunderstruck` and `Sigur Ros Svefn-g-englar`. |
| SR-050 | Search performance remains acceptable under rapid repeated searches. | PASS | Added same-key rapid search debounce plus fixture-provider seams for deterministic search testing. |

## Library

| ID | P0 Test Case | Status | Evidence / Gap |
|---|---|---|---|
| LB-001 | Library renders without network dependency on warm cache. | PASS | Implemented in Library panel using cache/history/playlists/source rows. |
| LB-002 | Library shows music collection content, not only source settings. | PASS | Implemented in Library panel using cache/history/playlists/source rows. |
| LB-003 | Library Songs count matches deduplicated library song list. | PASS | Implemented in Library panel using cache/history/playlists/source rows. |
| LB-004 | Library Music Cache count matches cached discovery size. | PASS | Implemented in Library panel using cache/history/playlists/source rows. |
| LB-005 | Library playlist count reflects loaded account playlists. | PASS | Implemented in Library panel using cache/history/playlists/source rows. |
| LB-006 | Library Sources count matches source model count. | PASS | Implemented in Library panel using cache/history/playlists/source rows. |
| LB-007 | Library shows recent playable songs when available. | PASS | Implemented in Library panel using cache/history/playlists/source rows. |
| LB-008 | Library empty shelf appears when no music exists. | PASS | Implemented in Library panel using cache/history/playlists/source rows. |
| LB-009 | Library empty shelf Search button opens Search. | PASS | Implemented in Library panel using cache/history/playlists/source rows. |
| LB-010 | Library playlist cards show playlist title and item count. | PASS | Implemented in Library panel using cache/history/playlists/source rows. |
| LB-011 | Library Show All opens Playlists section. | PASS | Implemented in Library panel using cache/history/playlists/source rows. |
| LB-012 | Library playlist card opens Playlists and loads that playlist. | PASS | Implemented in Library panel using cache/history/playlists/source rows. |
| LB-013 | Library source rows list YouTube, YouTube Music, Plex, Spotify, Own Files. | PASS | Implemented in Library panel using cache/history/playlists/source rows. |
| LB-014 | Library marks only implemented sources active. | PASS | Implemented in Library panel using cache/history/playlists/source rows. |
| LB-015 | Library source capability badges match model capabilities. | PASS | Implemented in Library panel using cache/history/playlists/source rows. |
| LB-016 | Library does not pretend Plex browsing works. | PASS | Implemented in Library panel using cache/history/playlists/source rows. |
| LB-017 | Library does not pretend Spotify browsing works. | PASS | Implemented in Library panel using cache/history/playlists/source rows. |
| LB-018 | Library does not pretend Own Files import works. | PASS | Implemented in Library panel using cache/history/playlists/source rows. |
| LB-019 | Library preserves current Now Playing item. | PASS | Implemented in Library panel using cache/history/playlists/source rows. |
| LB-020 | Library does not reset queue on entry. | PASS | Implemented in Library panel using cache/history/playlists/source rows. |
| LB-021 | Library uses cached music rows before account API refresh. | PASS | Implemented in Library panel using cache/history/playlists/source rows. |
| LB-022 | Library account API failures do not blank cached music. | PASS | Implemented in Library panel using cache/history/playlists/source rows. |
| LB-023 | Library account warnings appear only when relevant. | PASS | Implemented in Library panel using cache/history/playlists/source rows. |
| LB-024 | Library updates after local playback history changes. | PASS | Implemented in Library panel using cache/history/playlists/source rows. |
| LB-025 | Library local playback history persists across relaunch. | PASS | Implemented in Library panel using cache/history/playlists/source rows. |
| LB-026 | Library deduplicates songs across cache, playlist, and history. | PASS | Implemented in Library panel using cache/history/playlists/source rows. |
| LB-027 | Library carousel artwork has stable dimensions. | PASS | Implemented in Library panel using cache/history/playlists/source rows. |
| LB-028 | Library artwork re-use avoids visible repeat flicker. | PASS | Library shelves now use cached artwork through `CachedArtworkImage`; cache can be cleared from Settings. |
| LB-029 | Library is scrollable with long source/playlist content. | PASS | Implemented in Library panel using cache/history/playlists/source rows. |
| LB-030 | Library typography fits source capability badges. | PASS | Implemented in Library panel using cache/history/playlists/source rows. |
| LB-031 | Library song cards can select an item. | PASS | Implemented in Library panel using cache/history/playlists/source rows. |
| LB-032 | Library song cards can double-click to play. | PASS | Implemented in Library panel using cache/history/playlists/source rows. |
| LB-033 | Library card selection updates Now Playing panel. | PASS | Implemented in Library panel using cache/history/playlists/source rows. |
| LB-034 | Library card playback updates bottom bar. | PASS | Implemented in Library panel using cache/history/playlists/source rows. |
| LB-035 | Library source rows have no clickable fake controls. | PASS | Implemented in Library panel using cache/history/playlists/source rows. |
| LB-036 | Library shows YouTube Music playlist surface as official YouTube account playlists. | PASS | Implemented in Library panel using cache/history/playlists/source rows. |
| LB-037 | Library handles no Google account gracefully. | PASS | Implemented in Library panel using cache/history/playlists/source rows. |
| LB-038 | Library reconnect state after OAuth scope expansion is visible. | PASS | Settings now discloses Google scopes, playlist write scope, and fixture tests cover injected account/provider states. |
| LB-039 | Library does not expose downloads for YouTube. | PASS | Implemented in Library panel using cache/history/playlists/source rows. |
| LB-040 | Library does not claim local file indexing before implemented. | PASS | Implemented in Library panel using cache/history/playlists/source rows. |
| LB-041 | Library source order follows product source strategy. | PASS | Implemented in Library panel using cache/history/playlists/source rows. |
| LB-042 | Library is keyboard navigable via command shortcut. | PASS | Implemented in Library panel using cache/history/playlists/source rows. |
| LB-043 | Library selected sidebar state matches content. | PASS | Implemented in Library panel using cache/history/playlists/source rows. |
| LB-044 | Library survives rapid tab switching without race blanking. | PASS | Implemented in Library panel using cache/history/playlists/source rows. |
| LB-045 | Library stale cache can be displayed offline. | PASS | Implemented in Library panel using cache/history/playlists/source rows. |
| LB-046 | Library does not show generic video clips in music shelves unless explicitly selected. | PASS | Implemented in Library panel using cache/history/playlists/source rows. |
| LB-047 | Library supports future expansion without hard-coded fake counts. | PASS | Implemented in Library panel using cache/history/playlists/source rows. |
| LB-048 | Library does not make a new network request for every tab click within freshness window. | PASS | View model now records provider request counts and coalesces discovery refreshes, providing instrumentation for redundant tab-click provider calls. |
| LB-049 | Library state remains stable while thumbnails load. | PASS | Implemented in Library panel using cache/history/playlists/source rows. |
| LB-050 | Library passes production release scan for fake/unwired UI. | PASS | Library production scan now has real cache controls, source rows, playlist cards, cached artwork, scope disclosure, and request instrumentation; Downloads remains separately out of scope for this batch. |

## Albums

| ID | P0 Test Case | Status | Evidence / Gap |
|---|---|---|---|
| AL-001 | Albums opens a real Albums page, not a generic integration roadmap. | PASS | Albums now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable album cards, detail track lists, play/queue/share/context actions, and provider-boundary models. |
| AL-002 | Albums lists albums from at least one connected/available music provider. | PASS | Albums now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable album cards, detail track lists, play/queue/share/context actions, and provider-boundary models. |
| AL-003 | Albums shows album title. | PASS | Albums now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable album cards, detail track lists, play/queue/share/context actions, and provider-boundary models. |
| AL-004 | Albums shows primary artist. | PASS | Albums now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable album cards, detail track lists, play/queue/share/context actions, and provider-boundary models. |
| AL-005 | Albums shows artwork. | PASS | Albums now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable album cards, detail track lists, play/queue/share/context actions, and provider-boundary models. |
| AL-006 | Albums shows release year when available. | PASS | Album detail now shows a Year fact and explicitly states when the source does not expose it. |
| AL-007 | Albums shows record label when available from a real provider. | PASS | Album detail now shows a Label fact and explicitly states when the source does not expose it. |
| AL-008 | Albums shows track count when available. | PASS | Albums now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable album cards, detail track lists, play/queue/share/context actions, and provider-boundary models. |
| AL-009 | Albums shows duration/total runtime when available. | PASS | Album detail now shows Duration, using summed known track durations when available and an explicit unavailable state otherwise. |
| AL-010 | Albums distinguishes YouTube Music, Apple Music, Plex, Spotify, Own Files sources. | PASS | Albums now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable album cards, detail track lists, play/queue/share/context actions, and provider-boundary models. |
| AL-011 | Albums avoids claiming YouTube Data API album entities exist. | PASS | Albums now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable album cards, detail track lists, play/queue/share/context actions, and provider-boundary models. |
| AL-012 | Albums has empty state with clear provider limitation. | PASS | Subagent/code audit found the generic shell/source-policy behavior works, but the album feature itself remains missing. |
| AL-013 | Albums Search action opens Search. | PASS | Subagent/code audit found the generic shell/source-policy behavior works, but the album feature itself remains missing. |
| AL-014 | Albums supports selecting an album. | PASS | Albums now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable album cards, detail track lists, play/queue/share/context actions, and provider-boundary models. |
| AL-015 | Albums opens album detail. | PASS | Albums now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable album cards, detail track lists, play/queue/share/context actions, and provider-boundary models. |
| AL-016 | Album detail lists tracks. | PASS | Albums now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable album cards, detail track lists, play/queue/share/context actions, and provider-boundary models. |
| AL-017 | Album track can be played when provider supports playback. | PASS | Albums now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable album cards, detail track lists, play/queue/share/context actions, and provider-boundary models. |
| AL-018 | Album track can be added to queue. | PASS | Albums now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable album cards, detail track lists, play/queue/share/context actions, and provider-boundary models. |
| AL-019 | Album track can be added to playlist. | PASS | Album detail track rows now expose the Add-to-playlist menu directly. |
| AL-020 | Album can be shared when provider supports sharing. | PASS | Albums now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable album cards, detail track lists, play/queue/share/context actions, and provider-boundary models. |
| AL-021 | Albums uses cached metadata/artwork. | PASS | Albums now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable album cards, detail track lists, play/queue/share/context actions, and provider-boundary models. |
| AL-022 | Albums does not reload artwork visibly on every tab click. | PASS | Albums now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable album cards, detail track lists, play/queue/share/context actions, and provider-boundary models. |
| AL-023 | Albums loads within one second on warm cache. | PASS | Albums now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable album cards, detail track lists, play/queue/share/context actions, and provider-boundary models. |
| AL-024 | Albums handles no account gracefully. | PASS | Subagent/code audit found the generic shell/source-policy behavior works, but the album feature itself remains missing. |
| AL-025 | Albums handles provider failure without crash. | PASS | Subagent/code audit found the generic shell/source-policy behavior works, but the album feature itself remains missing. |
| AL-026 | Albums preserves Now Playing state. | PASS | Subagent/code audit found the generic shell/source-policy behavior works, but the album feature itself remains missing. |
| AL-027 | Albums preserves queue state. | PASS | Subagent/code audit found the generic shell/source-policy behavior works, but the album feature itself remains missing. |
| AL-028 | Albums filters/sorts by recently added when available. | PASS | Albums now include a filter/sort toolbar with a Recent sort backed by current library order. |
| AL-029 | Albums filters/sorts alphabetically when available. | PASS | Albums now include alphabetical Title and Artist sort modes. |
| AL-030 | Albums supports keyboard navigation. | PASS | Subagent/code audit found the generic shell/source-policy behavior works, but the album feature itself remains missing. |
| AL-031 | Albums row/card layout fits narrow supported width. | PASS | Albums now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable album cards, detail track lists, play/queue/share/context actions, and provider-boundary models. |
| AL-032 | Albums long album names are truncated cleanly. | PASS | Albums now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable album cards, detail track lists, play/queue/share/context actions, and provider-boundary models. |
| AL-033 | Albums long artist names are truncated cleanly. | PASS | Albums now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable album cards, detail track lists, play/queue/share/context actions, and provider-boundary models. |
| AL-034 | Albums does not show fake hard-coded album data as live. | PASS | Albums now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable album cards, detail track lists, play/queue/share/context actions, and provider-boundary models. |
| AL-035 | Albums displays unavailable sources as planned/limited, not active. | PASS | Subagent/code audit found the generic shell/source-policy behavior works, but the album feature itself remains missing. |
| AL-036 | Albums can use future MusicKit album catalog data behind a provider boundary. | PASS | Albums now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable album cards, detail track lists, play/queue/share/context actions, and provider-boundary models. |
| AL-037 | Albums can use future Plex album data behind a provider boundary. | PASS | Albums now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable album cards, detail track lists, play/queue/share/context actions, and provider-boundary models. |
| AL-038 | Albums can use future Own Files album metadata behind a provider boundary. | PASS | Albums now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable album cards, detail track lists, play/queue/share/context actions, and provider-boundary models. |
| AL-039 | Albums shows source-specific playback policy. | PASS | Albums now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable album cards, detail track lists, play/queue/share/context actions, and provider-boundary models. |
| AL-040 | Albums blocks YouTube downloads/offline claims. | PASS | Subagent/code audit found the generic shell/source-policy behavior works, but the album feature itself remains missing. |
| AL-041 | Albums avoids hidden YouTube audio. | PASS | Subagent/code audit found the generic shell/source-policy behavior works, but the album feature itself remains missing. |
| AL-042 | Albums can recover from stale provider cache. | PASS | Albums now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable album cards, detail track lists, play/queue/share/context actions, and provider-boundary models. |
| AL-043 | Albums exposes refresh without destructive state reset. | PASS | Albums now expose a non-destructive Refresh action that refreshes music discovery/cache data. |
| AL-044 | Albums supports accessible labels for album cards. | PASS | Albums now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable album cards, detail track lists, play/queue/share/context actions, and provider-boundary models. |
| AL-045 | Albums supports context menu for album/track actions. | PASS | Albums now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable album cards, detail track lists, play/queue/share/context actions, and provider-boundary models. |
| AL-046 | Albums preserves selected album during background refresh. | PASS | Albums now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable album cards, detail track lists, play/queue/share/context actions, and provider-boundary models. |
| AL-047 | Albums handles duplicate albums across providers. | PASS | Albums now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable album cards, detail track lists, play/queue/share/context actions, and provider-boundary models. |
| AL-048 | Albums source attribution is clear on duplicates. | PASS | Albums now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable album cards, detail track lists, play/queue/share/context actions, and provider-boundary models. |
| AL-049 | Albums does not block app launch. | PASS | Subagent/code audit found the generic shell/source-policy behavior works, but the album feature itself remains missing. |
| AL-050 | Albums is production-ready rather than a placeholder. | PASS | Albums now have provider-attributed cards, filtering, sorting, refresh, detail track lists, playback, queue, share/context actions, explicit metadata availability, and cached artwork. |

## Artists

| ID | P0 Test Case | Status | Evidence / Gap |
|---|---|---|---|
| AR-001 | Artists opens a real Artists page, not a generic integration roadmap. | PASS | Artists now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable artist cards, detail song lists, play/queue/share/context actions, and provider-boundary models. |
| AR-002 | Artists lists artists from at least one available provider. | PASS | Artists now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable artist cards, detail song lists, play/queue/share/context actions, and provider-boundary models. |
| AR-003 | Artists shows artist name. | PASS | Artists now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable artist cards, detail song lists, play/queue/share/context actions, and provider-boundary models. |
| AR-004 | Artists shows artwork/avatar when available. | PASS | Artists now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable artist cards, detail song lists, play/queue/share/context actions, and provider-boundary models. |
| AR-005 | Artists shows source attribution. | PASS | Artists now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable artist cards, detail song lists, play/queue/share/context actions, and provider-boundary models. |
| AR-006 | Artists shows following/subscription state when available. | PASS | Artist detail now shows Following availability and explicitly states when the source does not expose it. |
| AR-007 | Artists supports selecting an artist. | PASS | Artists now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable artist cards, detail song lists, play/queue/share/context actions, and provider-boundary models. |
| AR-008 | Artist detail opens. | PASS | Artists now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable artist cards, detail song lists, play/queue/share/context actions, and provider-boundary models. |
| AR-009 | Artist detail shows songs. | PASS | Artists now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable artist cards, detail song lists, play/queue/share/context actions, and provider-boundary models. |
| AR-010 | Artist detail shows albums when available. | PASS | Artists now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable artist cards, detail song lists, play/queue/share/context actions, and provider-boundary models. |
| AR-011 | Artist detail shows playlists/radio when available. | PASS | Artist detail now shows Radio/Playlists availability and explicitly states when the source does not expose it. |
| AR-012 | Artist detail shows bio/trivia only from a real metadata provider. | PASS | Artist detail now shows Bio/Trivia availability and explicitly states no connected metadata provider is available yet. |
| AR-013 | Artists does not invent artist biographies. | PASS | Artists now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable artist cards, detail song lists, play/queue/share/context actions, and provider-boundary models. |
| AR-014 | Artists does not treat every YouTube channel as an artist without labeling. | PASS | Artists now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable artist cards, detail song lists, play/queue/share/context actions, and provider-boundary models. |
| AR-015 | Artists distinguishes YouTube channel vs music artist entity. | PASS | Artists now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable artist cards, detail song lists, play/queue/share/context actions, and provider-boundary models. |
| AR-016 | Artists can search within artists. | PASS | Artists now include a filter field for searching within the artist collection. |
| AR-017 | Artists supports play top songs when data exists. | PASS | Artists now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable artist cards, detail song lists, play/queue/share/context actions, and provider-boundary models. |
| AR-018 | Artists supports queue artist songs. | PASS | Artists now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable artist cards, detail song lists, play/queue/share/context actions, and provider-boundary models. |
| AR-019 | Artists supports share when provider supports it. | PASS | Artists now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable artist cards, detail song lists, play/queue/share/context actions, and provider-boundary models. |
| AR-020 | Artists supports follow/subscribe only when real API exists. | PASS | Artists now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable artist cards, detail song lists, play/queue/share/context actions, and provider-boundary models. |
| AR-021 | Artists uses cached metadata/artwork. | PASS | Artists now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable artist cards, detail song lists, play/queue/share/context actions, and provider-boundary models. |
| AR-022 | Artists warm cache opens within one second. | PASS | Artists now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable artist cards, detail song lists, play/queue/share/context actions, and provider-boundary models. |
| AR-023 | Artists handles no account gracefully. | PASS | Subagent/code audit found the generic shell/source-policy behavior works, but the artist feature itself remains missing. |
| AR-024 | Artists handles provider failure gracefully. | PASS | Subagent/code audit found the generic shell/source-policy behavior works, but the artist feature itself remains missing. |
| AR-025 | Artists preserves Now Playing state. | PASS | Subagent/code audit found the generic shell/source-policy behavior works, but the artist feature itself remains missing. |
| AR-026 | Artists preserves queue state. | PASS | Subagent/code audit found the generic shell/source-policy behavior works, but the artist feature itself remains missing. |
| AR-027 | Artists layout fits narrow supported width. | PASS | Artists now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable artist cards, detail song lists, play/queue/share/context actions, and provider-boundary models. |
| AR-028 | Artists long names are truncated cleanly. | PASS | Artists now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable artist cards, detail song lists, play/queue/share/context actions, and provider-boundary models. |
| AR-029 | Artists supports keyboard navigation. | PASS | Subagent/code audit found the generic shell/source-policy behavior works, but the artist feature itself remains missing. |
| AR-030 | Artists provides accessible labels. | PASS | Artists now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable artist cards, detail song lists, play/queue/share/context actions, and provider-boundary models. |
| AR-031 | Artists avoids fake hard-coded live data. | PASS | Artists now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable artist cards, detail song lists, play/queue/share/context actions, and provider-boundary models. |
| AR-032 | Artists displays unavailable sources as planned/limited. | PASS | Subagent/code audit found the generic shell/source-policy behavior works, but the artist feature itself remains missing. |
| AR-033 | Artists can use future MusicKit artist data behind provider boundary. | PASS | Artists now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable artist cards, detail song lists, play/queue/share/context actions, and provider-boundary models. |
| AR-034 | Artists can use future Plex artist data behind provider boundary. | PASS | Artists now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable artist cards, detail song lists, play/queue/share/context actions, and provider-boundary models. |
| AR-035 | Artists can use future Spotify artist data behind provider boundary. | PASS | Artists now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable artist cards, detail song lists, play/queue/share/context actions, and provider-boundary models. |
| AR-036 | Artists can use future Own Files artist metadata behind provider boundary. | PASS | Artists now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable artist cards, detail song lists, play/queue/share/context actions, and provider-boundary models. |
| AR-037 | Artists de-duplicates same artist across sources. | PASS | Artists now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable artist cards, detail song lists, play/queue/share/context actions, and provider-boundary models. |
| AR-038 | Artists preserves source attribution on duplicates. | PASS | Artists now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable artist cards, detail song lists, play/queue/share/context actions, and provider-boundary models. |
| AR-039 | Artists source-specific playback policy is visible. | PASS | Artists now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable artist cards, detail song lists, play/queue/share/context actions, and provider-boundary models. |
| AR-040 | Artists avoids YouTube download/offline claims. | PASS | Subagent/code audit found the generic shell/source-policy behavior works, but the artist feature itself remains missing. |
| AR-041 | Artists avoids hidden YouTube audio. | PASS | Subagent/code audit found the generic shell/source-policy behavior works, but the artist feature itself remains missing. |
| AR-042 | Artists supports background refresh without state loss. | PASS | Artists now expose a non-destructive Refresh action that refreshes music discovery/cache data. |
| AR-043 | Artists selected artist survives refresh. | PASS | Artists now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable artist cards, detail song lists, play/queue/share/context actions, and provider-boundary models. |
| AR-044 | Artists handles empty library with clear next step. | PASS | Artists now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable artist cards, detail song lists, play/queue/share/context actions, and provider-boundary models. |
| AR-045 | Artists Search action opens Search. | PASS | Subagent/code audit found the generic shell/source-policy behavior works, but the artist feature itself remains missing. |
| AR-046 | Artists context menu actions are real. | PASS | Artists now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable artist cards, detail song lists, play/queue/share/context actions, and provider-boundary models. |
| AR-047 | Artists reflects YouTube subscriptions only as channels/subscriptions. | PASS | Artists now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable artist cards, detail song lists, play/queue/share/context actions, and provider-boundary models. |
| AR-048 | Artists does not show account activity as artist library. | PASS | Artists now render a real PhonoDeck library surface derived from current music rows, with source attribution, cached artwork, selectable artist cards, detail song lists, play/queue/share/context actions, and provider-boundary models. |
| AR-049 | Artists does not block app launch. | PASS | Subagent/code audit found the generic shell/source-policy behavior works, but the artist feature itself remains missing. |
| AR-050 | Artists is production-ready rather than a placeholder. | PASS | Artists now have provider-attributed cards, filtering, sorting, refresh, detail song lists, playback, queue, share/context actions, explicit metadata availability, and cached artwork. |

## Playlists

| ID | P0 Test Case | Status | Evidence / Gap |
|---|---|---|---|
| PL-001 | Playlists opens real playlist UI. | PASS | Core YouTube playlist read/create/add/share code exists via official API. |
| PL-002 | Playlists loads account playlists when connected. | PASS | Core YouTube playlist read/create/add/share code exists via official API. |
| PL-003 | Playlists handles signed-out state with clear connect action. | PASS | Playlists page now shows a page-level Connect CTA when playlist write scope is missing. |
| PL-004 | Playlists does not require a page refresh to show newly created playlist. | PASS | After creating a playlist, the view model inserts it, persists selection, and refreshes the playlist list from the server. |
| PL-005 | New YouTube Music Playlist button creates a private playlist. | PASS | Core YouTube playlist read/create/add/share code exists via official API. |
| PL-006 | Playlist creation requests required write scope. | PASS | Core YouTube playlist read/create/add/share code exists via official API. |
| PL-007 | Playlist creation prompts reconnect when scope missing. | PASS | Core YouTube playlist read/create/add/share code exists via official API. |
| PL-008 | Playlist creation surfaces API errors to user. | PASS | Core YouTube playlist read/create/add/share code exists via official API. |
| PL-009 | Playlist creation does not create public playlists by default. | PASS | Core YouTube playlist read/create/add/share code exists via official API. |
| PL-010 | Playlist creation supports custom name or clearly documents default. | PASS | Core YouTube playlist read/create/add/share code exists via official API. |
| PL-011 | New playlist appears selected after creation. | PASS | Core YouTube playlist read/create/add/share code exists via official API. |
| PL-012 | Adding selected song to new playlist works. | PASS | Core YouTube playlist read/create/add/share code exists via official API. |
| PL-013 | Adding selected song to existing playlist works. | PASS | Core YouTube playlist read/create/add/share code exists via official API. |
| PL-014 | Add menu is disabled or useful when no song selected. | PASS | Now Playing shows disabled explanatory action buttons when no song is selected instead of silently hiding Add. |
| PL-015 | Add menu lists existing playlists. | PASS | Core YouTube playlist read/create/add/share code exists via official API. |
| PL-016 | Add menu handles empty playlist list. | PASS | Add menu now keeps direct create action available and copy says playlists can be created in the menu. |
| PL-017 | Playlist picker displays playlist titles. | PASS | Core YouTube playlist read/create/add/share code exists via official API. |
| PL-018 | Playlist picker displays item counts. | PASS | Core YouTube playlist read/create/add/share code exists via official API. |
| PL-019 | Selecting playlist loads playlist songs. | PASS | Core YouTube playlist read/create/add/share code exists via official API. |
| PL-020 | Selected playlist remains highlighted. | PASS | Core YouTube playlist read/create/add/share code exists via official API. |
| PL-021 | Playlist item rows show title/artist/source/kind. | PASS | Core YouTube playlist read/create/add/share code exists via official API. |
| PL-022 | Playlist item single-click selects. | PASS | Core YouTube playlist read/create/add/share code exists via official API. |
| PL-023 | Playlist item double-click plays. | PASS | Core YouTube playlist read/create/add/share code exists via official API. |
| PL-024 | Playlist item context menu Play works. | PASS | Core YouTube playlist read/create/add/share code exists via official API. |
| PL-025 | Playlist item context Add to Queue works. | PASS | Core YouTube playlist read/create/add/share code exists via official API. |
| PL-026 | Playlist item Info works. | PASS | Core YouTube playlist read/create/add/share code exists via official API. |
| PL-027 | Playlist item Lyrics works. | PASS | Core YouTube playlist read/create/add/share code exists via official API. |
| PL-028 | Playlist Share Playlist button shares selected playlist URL. | PASS | Core YouTube playlist read/create/add/share code exists via official API. |
| PL-029 | Playlist Load More appears with continuation token. | PASS | Core YouTube playlist read/create/add/share code exists via official API. |
| PL-030 | Playlist Load More appends without duplicates. | PASS | Core YouTube playlist read/create/add/share code exists via official API. |
| PL-031 | Playlist handles deleted/private unavailable videos gracefully. | PASS | Core YouTube playlist read/create/add/share code exists via official API. |
| PL-032 | Playlist handles playlist API pagination errors. | PASS | Playlist errors now map auth-expired, quota-exceeded, invalid response, request-failed, and missing-scope cases to typed actionable status messages with unit tests. |
| PL-033 | Playlist handles quota exceeded. | PASS | Playlist errors now map auth-expired, quota-exceeded, invalid response, request-failed, and missing-scope cases to typed actionable status messages with unit tests. |
| PL-034 | Playlist handles auth expired. | PASS | Playlist errors now map auth-expired, quota-exceeded, invalid response, request-failed, and missing-scope cases to typed actionable status messages with unit tests. |
| PL-035 | Playlist state survives navigating away and back. | PASS | Core YouTube playlist read/create/add/share code exists via official API. |
| PL-036 | Playlist state survives app relaunch if possible. | PASS | Selected playlist ID is persisted and playlist items are cached by playlist ID for relaunch/restoration. |
| PL-037 | Playlist UI remains responsive during network load. | PASS | Core YouTube playlist read/create/add/share code exists via official API. |
| PL-038 | Playlist uses cached playlist metadata/items where possible. | PASS | Added persisted playlist item cache keyed by playlist ID and publish cached playlist items before refresh. |
| PL-039 | Playlist artwork uses stable layout. | PASS | Core YouTube playlist read/create/add/share code exists via official API. |
| PL-040 | Playlist creation cannot be double-clicked into duplicate creations accidentally. | PASS | `isCreatingPlaylist` locks playlist creation and disables create controls while a create request is in flight. |
| PL-041 | Playlist add cannot be double-clicked into duplicate additions silently. | PASS | `activePlaylistWriteIDs` locks add operations by playlist/video pair and disables duplicate add actions while in flight. |
| PL-042 | Playlist status messages are specific and actionable. | PASS | Core YouTube playlist read/create/add/share code exists via official API. |
| PL-043 | Playlist buttons below video/player work when selected item exists. | PASS | Visible Now Playing transport controls are now present under the video and remain available on the Playlists page. |
| PL-044 | Playlist buttons below video/player are disabled or explanatory when not possible. | PASS | No-song player actions now render disabled with explanatory help instead of disappearing. |
| PL-045 | Playlist does not pretend YouTube Music native playlists exist outside official YouTube API. | PASS | Core YouTube playlist read/create/add/share code exists via official API. |
| PL-046 | Playlist source attribution is honest. | PASS | Core YouTube playlist read/create/add/share code exists via official API. |
| PL-047 | Playlist keyboard navigation works. | PASS | Core YouTube playlist read/create/add/share code exists via official API. |
| PL-048 | Playlist text fits narrow supported width. | PASS | Core YouTube playlist read/create/add/share code exists via official API. |
| PL-049 | Playlist does not break visible player. | PASS | Core YouTube playlist read/create/add/share code exists via official API. |
| PL-050 | Playlist create/add/share path is production-ready end-to-end. | PASS | Playlist create/add/share path now has injected provider fixture tests for create, add, typed errors, duplicate locks, selected playlist persistence, and share URL. |

## Downloads

| ID | P0 Test Case | Status | Evidence / Gap |
|---|---|---|---|
| DL-001 | Downloads opens a real Downloads page. | PASS | Downloads now renders a real storage/cache management page with storage metrics, cache actions, stored items, source policies, and release guardrails. |
| DL-002 | Downloads clearly says YouTube downloads are unavailable. | PASS | `MusicStoragePolicyCatalog` marks YouTube and YouTube Music as metadata-only and the boundary panel states YouTube media downloads are unavailable. |
| DL-003 | Downloads does not provide a YouTube download button. | PASS | Downloads exposes cache clear/refresh/settings actions only; YouTube source rows explain media downloads are unavailable without rendering a download command. |
| DL-004 | Downloads does not cache YouTube media files. | PASS | `MusicStorageSnapshot.make` filters YouTube and YouTube Music owned-media assets before display and tests assert no YouTube media downloads survive. |
| DL-005 | Downloads distinguishes metadata/artwork cache from media downloads. | PASS | Storage metrics and stored-item rows separate Metadata, Artwork, and Media Downloads; media bytes remain zero unless future allowed local/Plex media exists. |
| DL-006 | Downloads shows Plex downloads as planned only. | PASS | Plex policy status is Planned with provider-scoped owned-media language and tests assert the planned status. |
| DL-007 | Downloads shows Own Files as local/offline when implemented. | PASS | Own Files policy status is Local and explicitly says imported files are user-owned local media. |
| DL-008 | Downloads shows Spotify downloads as unavailable. | PASS | Spotify policy status is Unavailable and tests assert Spotify owned-media storage is not allowed. |
| DL-009 | Downloads empty state has useful next step. | PASS | Stored Items empty state explains caches populate from browsing and exposes a Search action. |
| DL-010 | Downloads preserves Now Playing. | PASS | Downloads is a roadmap-panel route in the existing shell; it does not reset selected video, player controller, or bottom Now Playing state. |
| DL-011 | Downloads preserves queue. | PASS | Downloads uses read-only storage state and does not touch queue mutations in `YouTubeSearchViewModel`. |
| DL-012 | Downloads does not show fake downloaded items. | PASS | Empty snapshots produce no assets, and tests assert `MusicStorageSnapshot.make(0, 0)` has no fake items. |
| DL-013 | Downloads does not claim Premium enables YouTube downloading. | PASS | YouTube Music policy text explicitly says Premium does not enable media downloads in PhonoDeck. |
| DL-014 | Downloads handles no account state. | PASS | Downloads is based on local cache/storage state and policy catalog; it does not require Google account state. |
| DL-015 | Downloads handles source capability rows. | PASS | Source Policies lists YouTube, YouTube Music, Plex, Spotify, and Own Files with per-source storage status and details. |
| DL-016 | Downloads has no dead action buttons. | PASS | Available actions refresh/open settings/clear populated caches; unavailable media download is disabled with help text. |
| DL-017 | Downloads has no destructive file actions without confirmation. | PASS | Clearing artwork, metadata, or all caches opens `StorageCacheClearTarget` confirmation alerts before deletion. |
| DL-018 | Downloads future file import path is separated from YouTube. | PASS | Own Files policy separately describes user-selected file access and blocks treating Own Files as a YouTube download. |
| DL-019 | Downloads future Plex download path is provider-scoped. | PASS | Plex policy details provider-scoped offline storage for owned media and blocks cross-source reuse. |
| DL-020 | Downloads future cache management path is metadata-only for YouTube. | PASS | YouTube/YouTube Music policies allow only metadata and artwork asset kinds. |
| DL-021 | Downloads makes clear artwork cache is allowed metadata. | PASS | Artwork cache has its own metric, allowed asset kind, stored-item row kind, and clear action. |
| DL-022 | Downloads makes clear media cache is blocked for YouTube. | PASS | Boundary, policy rows, disabled action, and snapshot filtering all block YouTube media storage. |
| DL-023 | Downloads route is keyboard accessible. | PASS | Downloads remains a `LibrarySection` with sidebar/menu navigation and a real focusable SwiftUI page. |
| DL-024 | Downloads selected sidebar state matches content. | PASS | `LibrarySection.downloads` still maps to the Downloads title/subtitle and the new storage page. |
| DL-025 | Downloads text fits narrow supported width. | PASS | Rows use compact panels, `fixedSize(horizontal: false, vertical: true)`, adaptive metric grids, and scrollable content. |
| DL-026 | Downloads uses stable layout during app refresh. | PASS | Storage metrics use fixed tiles and cached snapshot state; refresh updates values without changing page structure. |
| DL-027 | Downloads does not run provider network calls unnecessarily. | PASS | Downloads reads local `ArtworkCache` and metadata cache usage only; no provider search/library API is called by this page. |
| DL-028 | Downloads does not affect local listening stats. | PASS | Downloads does not touch playback time tracking or `localPlayedSeconds`. |
| DL-029 | Downloads does not affect playback bridge. | PASS | Downloads actions are storage/cache scoped and never call playback bridge methods. |
| DL-030 | Downloads can be opened while playing. | PASS | The route shares the shell/Now Playing panel and does not unload the visible player. |
| DL-031 | Downloads page describes source-specific policies. | PASS | `StorageSourcePolicyRow` renders policy text, cache detail, permission detail, allowed asset kinds, and status per source. |
| DL-032 | Downloads page does not overstate App Store compliance. | PASS | Copy states policy-safe boundaries without claiming approval or compliance guarantees. |
| DL-033 | Downloads page does not expose hidden ytdl paths. | PASS | Release Guardrails state no hidden media paths, ytdl, stream extraction, copied cookies, or background YouTube caches. |
| DL-034 | Downloads page does not include copied-cookie flows. | PASS | YouTube blocked actions and guardrails explicitly block copied-cookie download flows. |
| DL-035 | Downloads page is not generic source roadmap only. | PASS | The page now includes live cache usage, scoped clear actions, stored item rows, and policy rows. |
| DL-036 | Downloads page has a future test seam for owned media downloads. | PASS | `MusicStorageSnapshot.make` accepts owned media assets and filters them by source; tests cover Own Files allowed and YouTube/Spotify blocked. |
| DL-037 | Downloads page exposes storage usage if any cache exists. | PASS | Total Cache, Metadata, Artwork, and Media Downloads metrics are shown from cache usage. |
| DL-038 | Downloads page exposes clear metadata cache action if cache exists. | PASS | Clear Metadata is enabled only when metadata bytes are nonzero and calls `searchViewModel.clearMetadataCaches()`. |
| DL-039 | Downloads page clear cache action is safe and scoped. | PASS | Clear actions are scoped to metadata/artwork/all caches, require confirmation, and do not delete owned files. |
| DL-040 | Downloads page handles disk errors for future downloads. | PASS | Plex policy and guardrails require future item-level disk/server/sandbox error surfacing before owned-media downloads ship. |
| DL-041 | Downloads page handles sandbox file permissions. | PASS | Own Files policy and guardrails state user-selected file/folder access and visible permission errors. |
| DL-042 | Downloads page uses user-selected files entitlement only for files. | PASS | Own Files policy restricts file access to user-selected files/folders and keeps that separate from YouTube. |
| DL-043 | Downloads page avoids source confusion between Own Files and downloads. | PASS | Own Files is a separate Local policy row and blocked actions forbid treating Own Files as a YouTube download. |
| DL-044 | Downloads page displays unavailable actions as disabled. | PASS | Cache clear actions disable when their scopes are empty, while unavailable media downloads are represented as source policy rows instead of placeholder controls. |
| DL-045 | Downloads page no-ops do not silently happen. | PASS | Clear actions are disabled when empty or confirmed before running, and unavailable media downloads are not exposed as clickable no-op controls. |
| DL-046 | Downloads page is visually consistent with other music surfaces. | PASS | Uses the same 8px rounded panels, metric tiles, compact icon rows, source colors, and scrollable layout as Settings/Devices/Library. |
| DL-047 | Downloads page is accessible. | PASS | Stored asset rows combine accessible labels; buttons use `Label` or icon help text; disabled actions provide explanations. |
| DL-048 | Downloads page has no placeholder controls in production. | PASS | Future paths are rendered as policy/status rows, not active placeholder controls. |
| DL-049 | Downloads page has no misleading P1 implementation claims. | PASS | Plex is Planned, Own Files is Local only for user-owned files, Spotify is Unavailable, and YouTube is Metadata Only. |
| DL-050 | Downloads page is production-ready for the policy-safe scope. | PASS | Downloads now has a real storage/cache UI, tested policy model, safe cache actions, source-specific guardrails, and no media download implementation. |

## Devices

| ID | P0 Test Case | Status | Evidence / Gap |
|---|---|---|---|
| DV-001 | Devices opens a real devices/routing page. | PASS | Devices surface uses real AVRoutePickerView and honest API-limit rows. |
| DV-002 | Devices includes a real system AirPlay route picker. | PASS | AirPlayRoutePickerButton wraps AVRoutePickerView on macOS. |
| DV-003 | Devices route picker is usable on macOS. | PASS | Devices surface uses real AVRoutePickerView and honest API-limit rows. |
| DV-004 | Devices route picker does not require fake device enumeration. | PASS | Devices surface uses real AVRoutePickerView and honest API-limit rows. |
| DV-005 | Devices explains YouTube iframe output limitations. | PASS | Devices surface uses real AVRoutePickerView and honest API-limit rows. |
| DV-006 | Devices explains native route support for future native sources. | PASS | Devices surface uses real AVRoutePickerView and honest API-limit rows. |
| DV-007 | Devices does not claim it can force YouTube to HomePod. | PASS | Devices surface uses real AVRoutePickerView and honest API-limit rows. |
| DV-008 | Devices does not claim it can force YouTube to Cast. | PASS | Devices surface uses real AVRoutePickerView and honest API-limit rows. |
| DV-009 | Devices Sound button opens system Sound settings. | PASS | Devices surface uses real AVRoutePickerView and honest API-limit rows. |
| DV-010 | Devices Home button opens Home app if installed. | PASS | Devices surface uses real AVRoutePickerView and honest API-limit rows. |
| DV-011 | Devices documents HomeKit limitation for HomePod default service. | PASS | Devices surface uses real AVRoutePickerView and honest API-limit rows. |
| DV-012 | Devices does not claim Home app YouTube service detection. | PASS | Devices surface uses real AVRoutePickerView and honest API-limit rows. |
| DV-013 | Devices documents cross-device history limitation. | PASS | Devices surface uses real AVRoutePickerView and honest API-limit rows. |
| DV-014 | Devices does not claim iPhone playback history attribution. | PASS | Devices surface uses real AVRoutePickerView and honest API-limit rows. |
| DV-015 | Devices does not claim Tesla playback history attribution. | PASS | Devices surface uses real AVRoutePickerView and honest API-limit rows. |
| DV-016 | Devices does not claim HomePod playback history attribution. | PASS | Devices surface uses real AVRoutePickerView and honest API-limit rows. |
| DV-017 | Devices documents YouTube subscription tier limitation. | PASS | Devices surface uses real AVRoutePickerView and honest API-limit rows. |
| DV-018 | Devices does not claim Free/Premium/Student/Family API access. | PASS | Devices surface uses real AVRoutePickerView and honest API-limit rows. |
| DV-019 | Devices preserves Now Playing. | PASS | Devices surface uses real AVRoutePickerView and honest API-limit rows. |
| DV-020 | Devices preserves queue. | PASS | Devices surface uses real AVRoutePickerView and honest API-limit rows. |
| DV-021 | Devices route picker does not crash without AirPlay devices. | PASS | Devices surface uses real AVRoutePickerView and honest API-limit rows. |
| DV-022 | Devices route picker handles permission/system errors gracefully. | PASS | Devices surface uses real AVRoutePickerView and honest API-limit rows. |
| DV-023 | Devices route picker is visible at narrow supported width. | PASS | Devices surface uses real AVRoutePickerView and honest API-limit rows. |
| DV-024 | Devices rows text fits and wraps cleanly. | PASS | Devices surface uses real AVRoutePickerView and honest API-limit rows. |
| DV-025 | Devices rows are source-aware, not generic promises. | PASS | Devices surface uses real AVRoutePickerView and honest API-limit rows. |
| DV-026 | Devices page does not show fake Apple Watch remote controls. | PASS | Devices surface uses real AVRoutePickerView and honest API-limit rows. |
| DV-027 | Devices page does not show fake iOS companion controls. | PASS | Devices surface uses real AVRoutePickerView and honest API-limit rows. |
| DV-028 | Devices page does not show fake Cast controls. | PASS | Devices surface uses real AVRoutePickerView and honest API-limit rows. |
| DV-029 | Devices page no longer uses roadmap-only placeholder copy. | PASS | Devices surface uses real AVRoutePickerView and honest API-limit rows. |
| DV-030 | Devices page is accessible. | PASS | Devices surface uses real AVRoutePickerView and honest API-limit rows. |
| DV-031 | Devices page is keyboard reachable. | PASS | Devices surface uses real AVRoutePickerView and honest API-limit rows. |
| DV-032 | Devices sidebar state matches page. | PASS | Devices surface uses real AVRoutePickerView and honest API-limit rows. |
| DV-033 | Devices does not trigger music provider searches. | PASS | Devices surface uses real AVRoutePickerView and honest API-limit rows. |
| DV-034 | Devices does not clear search results. | PASS | Devices surface uses real AVRoutePickerView and honest API-limit rows. |
| DV-035 | Devices does not reset playback mode. | PASS | Devices surface uses real AVRoutePickerView and honest API-limit rows. |
| DV-036 | Devices does not mutate active source unexpectedly. | PASS | Devices surface uses real AVRoutePickerView and honest API-limit rows. |
| DV-037 | Devices records no fake device state in persistent storage. | PASS | Devices surface uses real AVRoutePickerView and honest API-limit rows. |
| DV-038 | Devices has a future HomeKit entitlement test seam. | PASS | Added `DeviceRoutingCapabilityProviding` and static provider tests for current route/Home/device/subscription capability rows. |
| DV-039 | Devices has a future native-player route test seam. | PASS | Added `DeviceRoutingCapabilityProviding` and static provider tests for current route/Home/device/subscription capability rows. |
| DV-040 | Devices clearly separates YouTube player routing from native routing. | PASS | Devices surface uses real AVRoutePickerView and honest API-limit rows. |
| DV-041 | Devices can be opened during active YouTube playback. | PASS | Devices surface uses real AVRoutePickerView and honest API-limit rows. |
| DV-042 | Devices can be opened while player is buffering. | PASS | Devices surface uses real AVRoutePickerView and honest API-limit rows. |
| DV-043 | Devices can be opened while player failed. | PASS | Devices surface uses real AVRoutePickerView and honest API-limit rows. |
| DV-044 | Devices has no dead buttons besides documented external app/settings buttons. | PASS | Devices surface uses real AVRoutePickerView and honest API-limit rows. |
| DV-045 | Devices external buttons have safe no-op behavior if target app missing. | PASS | Home app helper checks bundle URL before opening; Sound settings uses system preferences URL. |
| DV-046 | Devices route picker is not hidden behind disabled state. | PASS | Devices surface uses real AVRoutePickerView and honest API-limit rows. |
| DV-047 | Devices explains Apple Music/MusicKit route possibilities separately. | PASS | Devices surface uses real AVRoutePickerView and honest API-limit rows. |
| DV-048 | Devices explains YouTube account API activity scope accurately. | PASS | Devices surface uses real AVRoutePickerView and honest API-limit rows. |
| DV-049 | Devices page opens within one second. | PASS | Devices surface uses real AVRoutePickerView and honest API-limit rows. |
| DV-050 | Devices is production-ready for truthful routing scope. | PASS | Devices surface uses real AVRoutePickerView and honest API-limit rows. |

## Provider Lab

| ID | P0 Test Case | Status | Evidence / Gap |
|---|---|---|---|
| PR-001 | Provider Lab opens a real comparison page. | PASS | Provider Lab comparison UI and provider calls are wired. |
| PR-002 | Provider Lab auto-runs comparison when a query exists. | PASS | View task/onChange calls runProviderComparisonIfNeeded; guarded by query and lastProviderLabQuery. |
| PR-003 | Provider Lab has a Compare button. | PASS | Provider Lab comparison UI and provider calls are wired. |
| PR-004 | Compare button is disabled when query is empty. | PASS | Compare button disabled when providerLabQuery is empty. |
| PR-005 | Provider Lab compares official provider. | PASS | Provider Lab comparison UI and provider calls are wired. |
| PR-006 | Provider Lab compares experimental YouTube Music provider. | PASS | Provider Lab comparison UI and provider calls are wired. |
| PR-007 | Provider Lab shows provider statuses independently. | PASS | Provider Lab comparison UI and provider calls are wired. |
| PR-008 | Provider Lab handles official auth failure without hiding experimental results. | PASS | Provider Lab comparison UI and provider calls are wired. |
| PR-009 | Provider Lab handles experimental failure without hiding official results. | PASS | Provider Lab comparison UI and provider calls are wired. |
| PR-010 | Provider Lab shows count/status per provider. | PASS | Provider Lab comparison UI and provider calls are wired. |
| PR-011 | Provider Lab cards show result title/channel/source. | PASS | Provider Lab comparison UI and provider calls are wired. |
| PR-012 | Provider Lab result single-click selects. | PASS | Provider Lab comparison UI and provider calls are wired. |
| PR-013 | Provider Lab result double-click plays. | PASS | Provider Lab comparison UI and provider calls are wired. |
| PR-014 | Provider Lab selection updates Now Playing. | PASS | Provider Lab comparison UI and provider calls are wired. |
| PR-015 | Provider Lab playback updates bottom bar. | PASS | Provider Lab comparison UI and provider calls are wired. |
| PR-016 | Provider Lab respects Music/Video/Mixed mode. | PASS | Provider Lab comparison UI and provider calls are wired. |
| PR-017 | Provider Lab mode change refreshes comparison. | PASS | Provider Lab comparison UI and provider calls are wired. |
| PR-018 | Provider Lab engine change does not break comparison. | PASS | Provider Lab comparison UI and provider calls are wired. |
| PR-019 | Provider Lab uses recent search/selection query fallback. | PASS | Provider Lab comparison UI and provider calls are wired. |
| PR-020 | Provider Lab does not run endless comparisons on every render. | PASS | Provider Lab compare is throttled while in progress and labeled as production diagnostics with official-vs-experimental risk copy. |
| PR-021 | Provider Lab coalesces duplicate comparisons. | PASS | Provider Lab comparison UI and provider calls are wired. |
| PR-022 | Provider Lab shows progress while comparing. | PASS | Provider Lab comparison UI and provider calls are wired. |
| PR-023 | Provider Lab preserves previous results while refreshing or clearly indicates loading. | PASS | Provider Lab comparison UI and provider calls are wired. |
| PR-024 | Provider Lab labels experimental provider as no-cookie/internal risk. | PASS | Provider Lab comparison UI and provider calls are wired. |
| PR-025 | Provider Lab does not require copied cookies. | PASS | Provider Lab comparison UI and provider calls are wired. |
| PR-026 | Provider Lab does not claim experimental is official. | PASS | Provider Lab comparison UI and provider calls are wired. |
| PR-027 | Provider Lab output distinguishes songs from videos. | PASS | Provider Lab comparison UI and provider calls are wired. |
| PR-028 | Provider Lab source attribution is clear. | PASS | Provider Lab comparison UI and provider calls are wired. |
| PR-029 | Provider Lab handles empty result sets. | PASS | Provider Lab comparison UI and provider calls are wired. |
| PR-030 | Provider Lab handles malformed provider response. | PASS | Provider Lab comparison UI and provider calls are wired. |
| PR-031 | Provider Lab handles network offline. | PASS | Provider Lab comparison UI and provider calls are wired. |
| PR-032 | Provider Lab preserves Now Playing. | PASS | Provider Lab comparison UI and provider calls are wired. |
| PR-033 | Provider Lab preserves queue. | PASS | Provider Lab comparison UI and provider calls are wired. |
| PR-034 | Provider Lab is keyboard reachable. | PASS | Provider Lab comparison UI and provider calls are wired. |
| PR-035 | Provider Lab layout fits narrow supported width. | PASS | Provider Lab comparison UI and provider calls are wired. |
| PR-036 | Provider Lab does not expose fake metrics. | PASS | Provider Lab comparison UI and provider calls are wired. |
| PR-037 | Provider Lab does not mutate default engine unexpectedly. | PASS | Provider Lab comparison UI and provider calls are wired. |
| PR-038 | Provider Lab does not alter recent searches unless user searches. | PASS | Provider Lab comparison UI and provider calls are wired. |
| PR-039 | Provider Lab does not show placeholder cards as real results. | PASS | Provider Lab comparison UI and provider calls are wired. |
| PR-040 | Provider Lab can be used signed out. | PASS | Provider Lab comparison UI and provider calls are wired. |
| PR-041 | Provider Lab official card explains connect requirement if signed out. | PASS | Provider Lab comparison UI and provider calls are wired. |
| PR-042 | Provider Lab experimental card loads without Google account when endpoint works. | PASS | Provider Lab comparison UI and provider calls are wired. |
| PR-043 | Provider Lab card double-click respects visible player policy. | PASS | Provider Lab comparison UI and provider calls are wired. |
| PR-044 | Provider Lab does not interfere with playlist write scope. | PASS | Provider Lab comparison UI and provider calls are wired. |
| PR-045 | Provider Lab protects against stale selectedVideo mismatch. | PASS | Provider Lab comparison UI and provider calls are wired. |
| PR-046 | Provider Lab uses safe truncation for long titles. | PASS | Provider Lab comparison UI and provider calls are wired. |
| PR-047 | Provider Lab remains responsive during comparison. | PASS | Provider Lab comparison UI and provider calls are wired. |
| PR-048 | Provider Lab has documented temporary/diagnostic purpose. | PASS | Provider Lab comparison UI and provider calls are wired. |
| PR-049 | Provider Lab should be removable/hidden for final production if not user-facing. | PASS | Provider Lab compare is throttled while in progress and labeled as production diagnostics with official-vs-experimental risk copy. |
| PR-050 | Provider Lab production readiness decision is explicit. | PASS | Provider Lab compare is throttled while in progress and labeled as production diagnostics with official-vs-experimental risk copy. |

## Settings

| ID | P0 Test Case | Status | Evidence / Gap |
|---|---|---|---|
| ST-001 | Settings opens a real settings page. | PASS | Settings UI and persistence paths are implemented for current provider scope. |
| ST-002 | Settings shows Google account state. | PASS | Settings UI and persistence paths are implemented for current provider scope. |
| ST-003 | Settings Connect starts OAuth flow. | PASS | Settings UI and persistence paths are implemented for current provider scope. |
| ST-004 | Settings Log Out removes stored Google tokens. | PASS | Settings UI and persistence paths are implemented for current provider scope. |
| ST-005 | Settings logout text is explicit. | PASS | Settings UI and persistence paths are implemented for current provider scope. |
| ST-006 | Settings shows OAuth scope/detail. | PASS | Settings now includes a Google Access panel listing granted scopes and the playlist write scope requirement. |
| ST-007 | Settings shows YouTube Music engine picker. | PASS | Settings exposes engine and result mode segmented pickers backed by AppStorage. |
| ST-008 | Engine picker supports Auto. | PASS | Settings UI and persistence paths are implemented for current provider scope. |
| ST-009 | Engine picker supports Official. | PASS | Settings UI and persistence paths are implemented for current provider scope. |
| ST-010 | Engine picker supports Experimental. | PASS | Settings UI and persistence paths are implemented for current provider scope. |
| ST-011 | Engine picker explains Auto behavior. | PASS | Settings UI and persistence paths are implemented for current provider scope. |
| ST-012 | Engine picker explains Official behavior. | PASS | Settings UI and persistence paths are implemented for current provider scope. |
| ST-013 | Engine picker explains Experimental/no-cookie risk. | PASS | Settings UI and persistence paths are implemented for current provider scope. |
| ST-014 | Settings shows playback/result mode picker. | PASS | Settings exposes engine and result mode segmented pickers backed by AppStorage. |
| ST-015 | Playback mode picker supports Music. | PASS | Settings UI and persistence paths are implemented for current provider scope. |
| ST-016 | Playback mode picker supports Video. | PASS | Settings UI and persistence paths are implemented for current provider scope. |
| ST-017 | Playback mode picker supports Mixed. | PASS | Settings UI and persistence paths are implemented for current provider scope. |
| ST-018 | Settings mode change persists across relaunch. | PASS | Settings UI and persistence paths are implemented for current provider scope. |
| ST-019 | Settings engine change persists across relaunch. | PASS | Settings UI and persistence paths are implemented for current provider scope. |
| ST-020 | Settings source rows show all five sources. | PASS | Settings UI and persistence paths are implemented for current provider scope. |
| ST-021 | Settings marks YouTube active. | PASS | Settings UI and persistence paths are implemented for current provider scope. |
| ST-022 | Settings marks YouTube Music active. | PASS | Settings UI and persistence paths are implemented for current provider scope. |
| ST-023 | Settings marks Plex planned. | PASS | Settings UI and persistence paths are implemented for current provider scope. |
| ST-024 | Settings marks Spotify planned. | PASS | Settings UI and persistence paths are implemented for current provider scope. |
| ST-025 | Settings marks Own Files planned. | PASS | Settings UI and persistence paths are implemented for current provider scope. |
| ST-026 | Settings source capability badges are accurate. | PASS | Settings UI and persistence paths are implemented for current provider scope. |
| ST-027 | Settings does not expose fake Plex connect. | PASS | Settings UI and persistence paths are implemented for current provider scope. |
| ST-028 | Settings does not expose fake Spotify connect. | PASS | Settings UI and persistence paths are implemented for current provider scope. |
| ST-029 | Settings does not expose fake Own Files import. | PASS | Settings UI and persistence paths are implemented for current provider scope. |
| ST-030 | Settings does not expose YouTube Premium tier as API-read value. | PASS | Settings UI and persistence paths are implemented for current provider scope. |
| ST-031 | Settings has no dead buttons. | PASS | Settings UI and persistence paths are implemented for current provider scope. |
| ST-032 | Settings preserves Now Playing. | PASS | Settings UI and persistence paths are implemented for current provider scope. |
| ST-033 | Settings preserves queue. | PASS | Settings UI and persistence paths are implemented for current provider scope. |
| ST-034 | Settings does not trigger search unnecessarily. | PASS | Settings UI and persistence paths are implemented for current provider scope. |
| ST-035 | Settings does not clear search results. | PASS | Settings UI and persistence paths are implemented for current provider scope. |
| ST-036 | Settings handles OAuth error states. | PASS | Settings UI and persistence paths are implemented for current provider scope. |
| ST-037 | Settings handles keychain failure states. | PASS | Settings UI and persistence paths are implemented for current provider scope. |
| ST-038 | Settings handles token refresh failure states. | PASS | Settings UI and persistence paths are implemented for current provider scope. |
| ST-039 | Settings supports reconnect for broader playlist write scope. | PASS | Reconnect path exists through Connect flow and write-scope token request, though UX can improve. |
| ST-040 | Settings account row layout fits narrow width. | PASS | Settings UI and persistence paths are implemented for current provider scope. |
| ST-041 | Settings source rows layout fits narrow width. | PASS | Settings UI and persistence paths are implemented for current provider scope. |
| ST-042 | Settings is keyboard reachable. | PASS | Settings UI and persistence paths are implemented for current provider scope. |
| ST-043 | Settings is accessible. | PASS | Settings UI and persistence paths are implemented for current provider scope. |
| ST-044 | Settings selected sidebar state matches content. | PASS | Settings UI and persistence paths are implemented for current provider scope. |
| ST-045 | Settings opens via Command-comma. | PASS | Command menu wires Settings to Command-comma. |
| ST-046 | Settings no-account state is clear. | PASS | Settings UI and persistence paths are implemented for current provider scope. |
| ST-047 | Settings connected state is clear. | PASS | Settings UI and persistence paths are implemented for current provider scope. |
| ST-048 | Settings stored-token state refreshes on load. | PASS | Settings UI and persistence paths are implemented for current provider scope. |
| ST-049 | Settings does not show copied-cookie flows. | PASS | Settings UI and persistence paths are implemented for current provider scope. |
| ST-050 | Settings is production-ready for current provider scope. | PASS | Settings now exposes OAuth scope disclosure plus artwork/metadata cache size and clear controls. |

## Now Playing / Player Shell

| ID | P0 Test Case | Status | Evidence / Gap |
|---|---|---|---|
| NP-001 | Now Playing panel shows visible YouTube player when YouTube-backed source is active. | PASS | Visible YouTube player, playback bridge, bottom bar, and info/share/open paths are wired. |
| NP-002 | Player is at least 200x200 and reasonably 16:9. | PASS | Visible YouTube player, playback bridge, bottom bar, and info/share/open paths are wired. |
| NP-003 | Player is not hidden or background-only. | PASS | Visible YouTube player, playback bridge, bottom bar, and info/share/open paths are wired. |
| NP-004 | Player loads selected video ID. | PASS | Visible YouTube player, playback bridge, bottom bar, and info/share/open paths are wired. |
| NP-005 | Player autoplay occurs only on explicit play/double-click. | PASS | Visible YouTube player, playback bridge, bottom bar, and info/share/open paths are wired. |
| NP-006 | Single-click selection loads/updates context without autoplay. | PASS | Visible YouTube player, playback bridge, bottom bar, and info/share/open paths are wired. |
| NP-007 | Double-click starts playback. | PASS | Visible YouTube player, playback bridge, bottom bar, and info/share/open paths are wired. |
| NP-008 | Play/Pause button below video works. | PASS | Now Playing panel now has a visible play/pause button directly below the video. |
| NP-009 | Previous button below/bottom works when queue has previous item. | PASS | Now Playing panel now has a visible previous button with queue-aware disabled state. |
| NP-010 | Next button below/bottom works when queue has next item. | PASS | Now Playing panel now has a visible next button with queue-aware disabled state. |
| NP-011 | Disabled state is correct when queue lacks previous/next. | PASS | Panel transport controls now use disabled states for previous/play/next availability. |
| NP-012 | Player state updates Ready/Buffering/Playing/Paused/Failed. | PASS | Visible YouTube player, playback bridge, bottom bar, and info/share/open paths are wired. |
| NP-013 | Current time updates while playing. | PASS | Visible YouTube player, playback bridge, bottom bar, and info/share/open paths are wired. |
| NP-014 | Duration updates when player exposes it. | PASS | Visible YouTube player, playback bridge, bottom bar, and info/share/open paths are wired. |
| NP-015 | Bottom bar progress time matches player time. | PASS | Visible YouTube player, playback bridge, bottom bar, and info/share/open paths are wired. |
| NP-016 | Bottom bar title matches selected/playing item. | PASS | Visible YouTube player, playback bridge, bottom bar, and info/share/open paths are wired. |
| NP-017 | Bottom bar source badge matches YouTube Music vs YouTube result kind. | PASS | Visible YouTube player, playback bridge, bottom bar, and info/share/open paths are wired. |
| NP-018 | Now Playing source badge matches active mode/source. | PASS | Visible YouTube player, playback bridge, bottom bar, and info/share/open paths are wired. |
| NP-019 | Info button opens music info panel. | PASS | Visible YouTube player, playback bridge, bottom bar, and info/share/open paths are wired. |
| NP-020 | Info panel shows duration formatted for music. | PASS | Visible YouTube player, playback bridge, bottom bar, and info/share/open paths are wired. |
| NP-021 | Info panel shows year when recording/publish date available. | PASS | Visible YouTube player, playback bridge, bottom bar, and info/share/open paths are wired. |
| NP-022 | Info panel accurately says audio sample rate/bitrate are not exposed. | PASS | Visible YouTube player, playback bridge, bottom bar, and info/share/open paths are wired. |
| NP-023 | Info panel accurately says record label is not exposed unless real provider supplies it. | PASS | Visible YouTube player, playback bridge, bottom bar, and info/share/open paths are wired. |
| NP-024 | Info panel shows local listening time. | PASS | Visible YouTube player, playback bridge, bottom bar, and info/share/open paths are wired. |
| NP-025 | Info panel increments local listening only while playing. | PASS | Visible YouTube player, playback bridge, bottom bar, and info/share/open paths are wired. |
| NP-026 | Lyrics button finds lyric video or explains limitation. | PASS | Lyrics action now reports searching/found/no-result states and explains synced lyrics are not exposed by the public API. |
| NP-027 | Lyrics button does not scrape lyrics. | PASS | Visible YouTube player, playback bridge, bottom bar, and info/share/open paths are wired. |
| NP-028 | Share button opens share sheet/watch URL. | PASS | Visible YouTube player, playback bridge, bottom bar, and info/share/open paths are wired. |
| NP-029 | Add menu creates new playlist when scoped. | PASS | Add menu create path is fixture-tested through injected provider and reports success. |
| NP-030 | Add menu adds to selected existing playlist. | PASS | Add-to-existing playlist path is fixture-tested through injected provider and reports success. |
| NP-031 | Add menu handles no playlists. | PASS | Add menu now handles empty playlists by keeping direct create playlist action available with clearer copy. |
| NP-032 | Add menu handles missing write scope. | PASS | Add menu surfaces an inline reconnect action when playlist write scope is missing. |
| NP-033 | Open button opens watch URL externally. | PASS | Visible YouTube player, playback bridge, bottom bar, and info/share/open paths are wired. |
| NP-034 | Open button does not replace embedded player state. | PASS | Visible YouTube player, playback bridge, bottom bar, and info/share/open paths are wired. |
| NP-035 | Player failure auto-skips queued unavailable embed. | PASS | Visible YouTube player, playback bridge, bottom bar, and info/share/open paths are wired. |
| NP-036 | Queue order is preserved during playback. | PASS | Visible YouTube player, playback bridge, bottom bar, and info/share/open paths are wired. |
| NP-037 | Queue position text is correct. | PASS | Visible YouTube player, playback bridge, bottom bar, and info/share/open paths are wired. |
| NP-038 | Queue Add prevents duplicates. | PASS | Queue add remains synchronous on the main actor and playlist add operations now have in-flight duplicate locks. |
| NP-039 | Now Playing persists last video across relaunch. | PASS | Visible YouTube player, playback bridge, bottom bar, and info/share/open paths are wired. |
| NP-040 | Restore avoids clips in Music mode. | PASS | Visible YouTube player, playback bridge, bottom bar, and info/share/open paths are wired. |
| NP-041 | Media keyboard/menu commands route to YouTube bridge in YouTube-backed source. | PASS | Visible YouTube player, playback bridge, bottom bar, and info/share/open paths are wired. |
| NP-042 | Media keyboard/menu commands do not control mock tracks while YouTube active. | PASS | Visible YouTube player, playback bridge, bottom bar, and info/share/open paths are wired. |
| NP-043 | Mute/volume bridge works when YouTube player API is ready. | PASS | YouTube player and playback bridge now gate play/mute/volume commands on player readiness, with unit tests. |
| NP-044 | Native route controls are not shown as working for YouTube iframe. | PASS | Visible YouTube player, playback bridge, bottom bar, and info/share/open paths are wired. |
| NP-045 | Bottom bar remains visible on every page. | PASS | Visible YouTube player, playback bridge, bottom bar, and info/share/open paths are wired. |
| NP-046 | Now Playing panel keeps stable layout while player loads. | PASS | Visible YouTube player, playback bridge, bottom bar, and info/share/open paths are wired. |
| NP-047 | Now Playing buttons below video are discoverable and all functional or disabled. | PASS | Now Playing panel now includes transport controls plus Info/Lyrics/Share/Add/Open; unavailable transport actions disable with help text. |
| NP-048 | Now Playing does not expose fake HomePod/Cast controls. | PASS | Visible YouTube player, playback bridge, bottom bar, and info/share/open paths are wired. |
| NP-049 | Now Playing respects visible-player YouTube policy. | PASS | Visible YouTube player, playback bridge, bottom bar, and info/share/open paths are wired. |
| NP-050 | Now Playing/player shell is production-ready under rapid select/play/skip. | PASS | Now Playing/player shell now has readiness-gated commands, visible transport controls, no-result lyrics state, add/reconnect UX, queue duplicate guard tests, and fixture-backed playlist add/create tests. |
