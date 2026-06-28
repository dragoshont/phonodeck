# YouTube Music Player Experience Design

This is the design contract for PhonoDeck's YouTube-first playback surface. It intentionally treats video as supporting context unless the user chooses video-first mode.

## Design Goal

PhonoDeck should feel like a native music player that happens to use official YouTube embeds for playback. The user should feel they are choosing songs, albums, playlists, recommendations, and queues first; the video player is present because YouTube requires a visible official player, not because the whole app is a video site.

## Product Truths

- YouTube Data API can provide searchable videos, account identity, playlists, playlist items, subscriptions, and activity.
- YouTube Data API does not provide native audio stream URLs.
- Playback must use a visible official YouTube player, currently `youtube.com/embed` in `WKWebView`.
- We must not hide, obscure, or cover the player controls.
- We must not pretend the app owns native audio playback for YouTube content.
- We can make the surrounding app song-first and Apple Music-like.
- Spotify, Watch/iOS remote, downloads, AirPlay, and cast targets must not appear as working source switches until their playback/control paths are actually implemented.

## Apple/Mac Principles Applied

From Apple HIG research:

- Mac apps should use large displays to show more content with fewer modal transitions.
- Toolbars should contain only important actions, grouped by purpose, using familiar symbols.
- Menus and contextual actions should use clear verbs and put important actions first.
- Audio apps should respond to playback controls only when it makes sense and avoid redefining expected media-control behavior.
- Sidebars and split views should reveal top-level areas and let the main pane focus on the selected content.

For PhonoDeck this means:

- Search/results/playlist lists are primary.
- The official player is visible but not dominant unless the user chooses video-first.
- The bottom Now Playing bar should reflect the selected YouTube result.
- Rows, buttons, and menus should use standard symbols and predictable actions.
- Double-click in a song list should start that song.

## Award-Caliber Bar

Apple Design Award research reinforces that a high-quality app is not just attractive; it is intuitive, inclusive, technically sound, and carefully scoped. PhonoDeck should be judged against these qualities:

- Delight and focus: one clear primary job on each screen, with no placeholder controls that erode trust.
- Interaction: common actions should feel discoverable by accident: double-click row to play, Return to play, context menus on rows, keyboard shortcuts, and a Now Playing area that behaves honestly.
- Inclusivity: VoiceOver labels, keyboard navigation, sufficient contrast, no color-only state, and clear empty/error states.
- Innovation: use the Mac's large display, sidebar/split-view model, keyboard, menu bar, and system media affordances where truthful.
- Visual craft: dense but calm music library layout, consistent row heights, standard symbols, minimal cards, no decorative noise.
- Technical achievement: no fake controls; if the YouTube player state cannot be controlled, the UI must say so or disable unsupported commands.

The app is not award-caliber until the blockers in this document are resolved.

## Layout Modes

### Song-First Mode

Default mode.

- Main pane: Songs list, playlist rows, or recommendation rows.
- Right pane: compact Now Playing inspector with visible official YouTube embed.
- Bottom bar: current song metadata, transport controls, progress, route/volume.
- Video size: at least policy-compliant minimum, preferably 16:9 and at least 480x270 when the window allows it.

### Video-First Mode

Optional user preference.

- Main pane: visible official YouTube player.
- Side pane or lower pane: queue/recommendations.
- Use when the user wants clips, live videos, or visual playback.
- Must not obscure official player controls.

### Compact Mode

For smaller windows.

- Main pane: selected list or player, not both squeezed into unusable sizes.
- Player can move below the list if the right pane would drop below policy/recommended size.
- Bottom Now Playing remains visible.

## Core Information Architecture

### Listen Now

Purpose: recommendations and recent/resumable items.

Sources:

- `activities.list` for account activity.
- `subscriptions.list` for followed channels/artists.
- Search suggestions later, if supported via official APIs.

Behavior:

- Show rows/shelves like Recently Played, From Subscriptions, More Like This.
- Never claim these are YouTube Music recommendations unless returned by an official YouTube Music API.
- Label them honestly as YouTube recommendations/account activity when appropriate.

### Search

Purpose: find playable songs.

Search strategy:

- Query Data API `search.list` with `type=video`, `videoCategoryId=10`, `videoEmbeddable=true`, and a query biased toward `official audio`.
- Rank results locally:
  - prefer `Official Audio`, `Artist - Topic`, and provided-to-YouTube style uploads;
  - then lyric videos;
  - then official music videos;
  - demote covers, reactions, tutorials, live clips, karaoke, and instrumentals unless the user asks for them.

Result row content:

- artwork thumbnail;
- song/title;
- channel/artist;
- badge: Song, Lyrics, Clip, Live, Cover, or Video;
- source marker: YouTube;
- optional overflow menu.

### Playlists

Purpose: real account-aware playlist browsing.

Sources:

- `playlists.list?mine=true`
- `playlistItems.list?playlistId=...`

Behavior:

- Playlist list looks like an Apple Music playlist library.
- Selecting playlist shows track-like rows.
- Double-click row loads selected video into official player.
- Queue is local app state built from playlist item video IDs.

### Song Detail / Info

Purpose: information and secondary actions.

Surface:

- Inspector panel or popover from an Info button.

Fields:

- title;
- channel/artist;
- source: YouTube;
- video ID;
- current classification: Song/Lyrics/Clip/Video;
- playlist/source context if selected from playlist;
- link/open on YouTube action;
- copy link action.

### Lyrics

Purpose: a visible Lyrics button should exist, but it cannot fabricate official lyrics.

States:

- If selected result is a lyric video, Lyrics button can focus/select it as the preferred result.
- If captions are available through official APIs later, Lyrics can show captions/transcript only if policy and API use are valid.
- Otherwise Lyrics button opens a clear empty state: `Lyrics are not available from the official YouTube API for this item.`

Do not scrape lyrics websites or YouTube pages.

## Interaction Rules

### Single Click

- Selects a song/result.
- Updates the Info/Lyrics context.
- Does not autoplay unless the user has enabled a clear preference.

### Double Click

- Loads and starts the selected song in the visible official player when possible.
- If autoplay/scripted playback cannot be done safely, double-click loads the player and focuses it so the user can press play.
- This must remain user-initiated.

### Return Key

- In search field: run search.
- In result list: play selected row.

### Space Key

- If a row/list is focused, toggle the embedded player only if the IFrame API safely supports it and the player remains visible.
- Otherwise do not hijack space from text entry or system behavior.

### Context Menu / Overflow

Every song row should eventually expose:

- Play;
- Add to Queue;
- Show Info;
- Show Lyrics;
- Open on YouTube;
- Copy Link.

## Preferences

Add a YouTube Playback preference:

- Song-first: prioritize official audio/topic/lyrics, keep video small.
- Video-first: prioritize official music videos/clips, make player large.
- Balanced: rank official audio and official clips near each other.

Default: Song-first.

Search ranking and layout should both respect this preference.

## API And Quota Resilience

YouTube Data API use must be budgeted and observable.

- Show a clear user-facing error for quota exhaustion and authorization expiry.
- Keep search calls deliberate; do not search on every keystroke.
- Cache recent search responses only within YouTube API data-retention rules.
- Implement pagination with `nextPageToken` before implying search is exhaustive.
- Deduplicate or group likely variants of the same song.
- Keep default scope read-only until write features actually exist.
- Validate embed `origin` and `Referer` behavior with real playback tests.

Default query strategy is a ranking heuristic, not truth. The UI should let users switch preference and should make result type visible with badges.

## Now Playing Bar

The bottom bar should stop being a static preview.

It should show:

- selected result thumbnail;
- title;
- channel/artist;
- source badge: YouTube;
- play/pause and progress for the visible player;
- queue-aware Previous/Next in PhonoDeck chrome for YouTube only when the explicit PhonoDeck queue has adjacent items; real ended events advance to the next queued song, while pause and failures never auto-advance;
- queue position;
- output/volume controls only when supported by the current playback route.

If the IFrame API cannot reliably expose a state, the bar must avoid lying. Use disabled controls or a clear `Controlled in YouTube player` state.

## Source And Roadmap Surfaces

Spotify, Watch/iOS remote, device routing, and downloads can be shown as roadmap/status surfaces, but they must not steal focus from YouTube P0 playback.

- Source rows are informational until their integration exists.
- YouTube downloads remain unavailable without an approved Google route.
- Spotify is treated as Connect/control/metadata unless Spotify grants native playback rights.
- Watch and iOS companion apps depend on the macOS queue/playback model being stable first.

## Unified Music Player Model

PhonoDeck should present one music-player workflow across sources, but the implementation must respect each provider's rights and APIs.

Common surfaces:

- Search
- Listen Now / discovery
- Library
- Playlists
- Queue
- History
- Share
- Now Playing
- Devices / routing

Source-specific truth:

- YouTube: official Data API metadata, account activity, subscriptions, playlist read/write, and a visible official embedded player. Songs mode filters to official audio/topic/lyric-style results. Clips appear only in Videos/Balanced or in user playlists/history where they are honestly labeled.
- Spotify: Web API can provide metadata, search, playlists, library, top/recent items, queue, and Spotify Connect control with scopes. Native streaming is limited to Spotify-approved playback SDK routes and Premium requirements.

YouTube player sizing/collapse rule:

- Do not collapse, hide, background, or crop the YouTube player during playback.
- Keep the embedded player at least 200x200, and prefer 480x270 for a 16:9 player in normal layouts.
- More than half of the player must be visible before autoplay/scripted playback.
- Do not draw custom overlays over YouTube player controls.

## Immediate Implementation Plan

1. Stop lying in the bottom Now Playing bar: mirror the selected YouTube result and disable or relabel unsupported controls.
2. Fix embed identity and sizing: use validated `origin`/`Referer`, keep the visible player at least 480x270 in normal layouts, and test real embeds.
3. Add double-click on song rows to load/play selected result; if autoplay is blocked, load/focus the visible player and make that limitation clear.
4. Add a persistent playback preference: Song-first / Video-first / Balanced.
5. Add Lyrics and Info buttons in the Now Playing panel.
6. Replace the side `Account` dominance with a smaller account badge/menu.
7. Implement real playlists with `playlists.list` and `playlistItems.list`.
8. Implement real Listen Now sections with `activities.list` and `subscriptions.list`, labeled honestly.
9. Add context menus and overflow actions on song rows.
10. Add pagination, quota/error handling, and result deduplication.
11. Make sidebar navigation the single source of truth for Listen Now / Search / Playlists / Settings.
12. Add UI tests or snapshot checks for song-first layout density and compact mode.

## Validated Adversarial Findings

The following issues were identified by adversarial review and verified against the current codebase.

### P0 Blockers

- Bottom `NowPlayingBar` still uses mock `PlaybackCoordinator` tracks and media-key handlers, not the selected YouTube result. This violates the design truth that PhonoDeck must not pretend it owns native YouTube playback.
- Double-click/Return-to-play are not implemented on song rows.
- Playback preference modes do not exist yet.
- Sidebar navigation and the toolbar source picker conflict; sidebar selections do not currently drive YouTube subviews.
- Current playlist and recommendation surfaces are not implemented despite being part of the target design.
- Account controls still occupy more content-panel space than they should; account should become a compact badge/menu.

### P1 Corrections

- Add Info and Lyrics buttons before expanding visual polish.
- Add row context menus: Play, Add to Queue, Show Info, Show Lyrics, Open on YouTube, Copy Link.
- Add quota, authorization-expiry, and API-error states.
- Implement result pagination and deduplication.
- Ensure player size and embed identity match YouTube RMF requirements.
- Verify IFrame API control support before enabling additional PhonoDeck chrome; current YouTube chrome is limited to Play/Pause, progress, and embed volume.

### Accessibility Corrections

- Do not rely on color-only status.
- Add labels/help for icon-only controls.
- Ensure song rows are keyboard reachable and announce title, channel, result kind, and selection state.
- Provide clear empty states for logged-out, no results, quota exceeded, lyrics unavailable, and embed failed.

## Design Anti-Patterns To Avoid

- A giant empty player region before the user has selected music.
- Treating video clips as the default when the user asked for songs.
- Labels like `Playback route` that explain implementation rather than user intent.
- Static mock queue content once real API data exists.
- Hiding the YouTube player or covering it with custom controls.
- Promising native media-key control until it actually works.