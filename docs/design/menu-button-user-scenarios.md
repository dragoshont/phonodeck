# PhonoDeck Menu And Button Scenarios

This document audits the current macOS app controls from a user-scenario point of view. It should be updated whenever a new button, menu, toolbar item, or keyboard command is added.

## Navigation

### I open Listen Now

Expected:
- The main panel shows song-first YouTube recommendations, local PhonoDeck history, account activity, and subscriptions when available.
- The user can scan horizontal shelves/carousels for recently played music without losing the main song list.
- The visible song count reflects the current list.
- The visible YouTube player and bottom Now Playing bar remain available.

Adversarial analysis:
- If account activity is empty, Listen Now must not look broken or blank.
- If search is loading, the app must show progress/status without erasing current playback.

Fix status:
- Local PhonoDeck history and song-first search fallback are shown.
- Recently Played has a horizontal shelf fed by local playback history.
- Current playback is preserved while metadata/search refreshes.

### I open Search

Expected:
- The search field and mode picker are visible.
- The search field has a clear X.
- Songs mode returns official audio, Topic uploads, and lyric-style results first.
- Videos/Balanced are opt-in for clips and music videos.

Adversarial analysis:
- Search must not silently return clips when the user asked for songs.
- Empty Songs results should explain that clips are excluded and that Videos/Balanced can broaden results.

Fix status:
- YouTube result classification is centralized in the data model.
- Songs mode filters out clip/music-video results by default.
- Search has an explicit clear button.

### I scan a song row

Expected:
- The row shows artwork, title, channel, a clean monochrome YouTube source mark, a kind badge, and a play affordance.

Adversarial analysis:
- YouTube source attribution should be visible without making every row visually noisy.
- Song kind and source should not be conflated.

Fix status:
- Rows now show a monochrome YouTube mark separately from the Song/Lyrics/Clip badge.

### I open YouTube Music Playlists

Expected:
- The playlist picker shows the YouTube Music playlist surface, backed by official YouTube account playlist APIs.
- New Playlist creates a private YouTube Music playlist after the user grants the correct Google scope.
- Share Playlist shares the selected playlist URL.
- Load More paginates playlist items.

Adversarial analysis:
- Existing read-only tokens cannot create playlists; the app must ask the user to reconnect instead of failing mysteriously.
- Creating a playlist can return fewer fields than listing playlists; decoding must tolerate that.

Fix status:
- Playlist create/add/share paths are implemented.
- Created playlists decode without `contentDetails`.
- Scope errors prompt Google reconnect.

### I open Settings

Expected:
- The app shows a real settings panel, not an empty song list.
- Google account status is visible.
- Log Out of Google is explicit and easy to find.
- Playback mode and source capability status are visible.

Adversarial analysis:
- Sidebar selection must update the actual detail view, not only highlight the row.
- Logout must not be hidden behind vague wording like Disconnect.

Fix status:
- Sidebar tags now match the optional selection binding.
- Settings has a Google Account row with Log Out of Google.
- The top account menu also says Log Out of Google.

## Now Playing Panel

### I select or double-click a song row

Expected:
- Single-click selects a song and updates Info/Lyrics/Add/Share context.
- Double-click loads and starts the visible YouTube player.
- Current song is persisted for restoration on relaunch.

Adversarial analysis:
- In Songs mode, restoring a previous clip should not make the app look like it prefers clips.
- Failed embeds should not leave playback stuck.

Fix status:
- Clip restoration is blocked while Songs mode is active.
- Failed embeds skip to the next queued item.

### I use Info

Expected:
- Info shows title, source, duration, year, quality availability, record-label availability, lyrics path, local listening time, queue, video ID, and official API metadata when loaded.

Adversarial analysis:
- Info must not invent album/artist metadata YouTube did not provide.
- Quality must not pretend YouTube exposes audio sample rate, bitrate, codec, or Premium quality through public APIs.
- Record label must not be inferred from channel names or descriptions.

Fix status:
- Info displays music-facing facts from official details where available and labels missing API data explicitly.

### I use Lyrics

Expected:
- If the current result is a lyric video, it plays/focuses that result.
- Otherwise, PhonoDeck searches YouTube for lyric-video results.

Adversarial analysis:
- The app must not scrape lyrics websites or claim unavailable lyrics exist.

Fix status:
- Lyrics searches official YouTube results only.

### I use Share

Expected:
- Share opens the macOS share sheet for the current YouTube watch URL.

Adversarial analysis:
- Share should be disabled or unavailable when no item is selected.

Fix status:
- Toolbar Share is disabled until there is a current YouTube song.
- Now Playing Share uses the selected song URL.

### I use Add

Expected:
- Add opens a playlist menu.
- New YouTube Music Playlist creates a private playlist and adds the selected song.
- Existing playlist entries add the selected song to that playlist.

Adversarial analysis:
- Add must not pretend success if Google scope is too narrow.
- Add must not create public playlists without explicit user control.

Fix status:
- Default create path uses private playlists.
- Scope errors are surfaced as reconnect prompts.

### I use Open

Expected:
- Open launches the selected YouTube watch URL in the system browser.

Adversarial analysis:
- Open should not replace the embedded player or make the app lose state.

Fix status:
- Open uses `NSWorkspace` and leaves app state intact.

## Account Menu

### I open Account from Now Playing

Expected:
- The menu shows account status and scope/detail.
- If connected, it has Log Out of Google.
- If signed out, it has Connect.

Adversarial analysis:
- A user should not have to guess that Disconnect means logout.
- If playlist writes require broader scope, reconnecting must be discoverable.

Fix status:
- Menu label now includes Account text.
- Destructive item is named Log Out of Google.
- Settings also exposes the same logout action.

## Toolbar

### I click the sidebar button

Expected:
- The sidebar toggles without changing playback.

Adversarial analysis:
- Hiding the sidebar must not make users lose the active YouTube view.

Fix status:
- Toolbar sidebar action only toggles the split view.

### I click Search

Expected:
- The app switches to the Search section and keeps YouTube as the active source.

Adversarial analysis:
- Search must not open a placeholder or external browser.

Fix status:
- Toolbar Search sets the app section to Search.

## Bottom Now Playing Bar

### I use previous, play/pause, or next

Expected:
- In YouTube mode, controls route through the visible YouTube player and local queue.
- In future native modes, controls route through native playback.

Adversarial analysis:
- The macOS Playback menu and keyboard shortcuts must not control mock tracks while YouTube is active.
- Disabled states must reflect unsupported actions.

Fix status:
- Bottom bar routes to YouTube playback bridge.

## Devices

### I open Devices

Expected:
- A real AirPlay/HomePod route picker is visible for system media routes.
- The panel explains which device features are currently actionable and which APIs are not exposed.
- The user can open Sound Settings or the Home app from the panel.

Adversarial analysis:
- The app must not claim it can silently enumerate HomePods, inspect Home app default music service, or force YouTube iframe audio to a HomePod.
- The app must not claim access to YouTube Premium tier, Family/Student/Individual status, or per-device history such as iPhone/Tesla unless a real API provides it.

Fix status:
- Devices uses `AVRoutePickerView` for system routes.
- Device rows document YouTube playback routing, native music routing, Home app limits, cross-device history limits, and YouTube subscription-tier limits.
- macOS Playback menu routes to YouTube playback bridge when YouTube is active.

## Source Capability Controls

### I see Plex, Spotify, Local, and YouTube source icons

Expected:
- They explain source capability status.
- They do not switch away from YouTube until those integrations are implemented.

Adversarial analysis:
- Planned source icons must not act like working playback sources.

Fix status:
- Source icons are capability indicators, not destructive source switches.