# PhonoDeck Current Handoff

This note captures the useful state from the chat so work can continue without relying on the chat history.

## Project

- Repository: `github.com/dragoshont/phonodeck`
- Product name: PhonoDeck
- Priority: YouTube Music is P0. Plex, Spotify, Local files, downloads, cast targets, iOS, and watchOS are later priorities.

## Product Constraints

- Build a native macOS app using SwiftUI/AppKit patterns.
- Avoid a browser-slab or hidden-webview playback model.
- Do not scrape YouTube, use undocumented YouTube Music endpoints, hide/background an official YouTube player, extract audio/video, or implement YouTube offline downloads without Google approval.
- Native UI may organize account/library/search/playlist metadata, but playback needs to stay inside policy-approved YouTube surfaces unless an approved native route exists.

## OAuth State

- Google Cloud project: create or select a project owned by the maintainer/operator.
- YouTube Data API v3 is enabled.
- Google Auth Platform is configured as External/Testing.
- Test users should be configured in Google Auth Platform when the app is in Testing.
- Each operator/developer should create their own Desktop OAuth client for local development.
- The client secret must stay local only. Do not paste it into chat, docs, commits, or memory.

The local ignored file should contain:

```xcconfig
GOOGLE_OAUTH_CLIENT_ID = <desktop-client-id>.apps.googleusercontent.com
GOOGLE_OAUTH_CLIENT_SECRET = <desktop-client-secret>
```

Path:

```text
Config/Secrets.xcconfig
```

## Current State

- Desktop installed-app OAuth is wired through the POSIX loopback callback server.
- Access tokens are refreshed through `GoogleAccountStore.loadFreshTokens()` before YouTube API calls.
- YouTube search, playlists, playlist items, and account activity use the official YouTube Data API.
- YouTube subscriptions and video details are loaded through official Data API endpoints for discovery and Info metadata.
- YouTube Music playlist create/add/share is wired through official YouTube account playlist APIs and requires the broader `https://www.googleapis.com/auth/youtube` scope.
- Playback uses a visible official YouTube embed in `YouTubeMusicWebPlayerView`.
- Default YouTube `Songs` search filters out clip/music-video results unless the user switches to Videos or Balanced.
- Local PhonoDeck playback history is persisted separately from YouTube account activity and is used in Listen Now.
- The right Now Playing panel no longer duplicates transport or volume controls; the official player owns its own player chrome.
- The bottom bar mirrors the selected YouTube result and exposes only queue/play-pause controls that PhonoDeck can honestly route.
- The app persists the last selected YouTube song locally and restores it on launch.
- If a YouTube embed fails, PhonoDeck skips to the next local queue item instead of leaving the player stuck.
- Plex, Spotify, Local files, Watch/iOS remote, device routing, and downloads are represented as non-clickable roadmap/status rows, not fake source switches.

## Code State To Verify Next

- Confirm real playback after launch with the current restored song and a fresh search result.
- If playlist create/add reports a scope error, disconnect and reconnect Google so the stored token includes the YouTube write scope.
- Confirm failed/unavailable embeds advance to the next queued result.
- Confirm YouTube Music playlist pagination with a larger playlist.
- Keep YouTube downloads unavailable unless an approved Google route exists.
- Implement Plex downloads only for user-owned media and only after Plex browsing/playback are real.
- Keep Spotify scoped to Spotify Connect/control surfaces unless Spotify grants a native playback route.

## Important Files

- `project.yml`
- `Config/BuildSettings.xcconfig`
- `Config/Secrets.xcconfig.example`
- `Config/Secrets.xcconfig` ignored local secret file
- `Sources/PhonoDeck/Integrations/Google/GoogleOAuthClient.swift`
- `Sources/PhonoDeck/Integrations/Google/OAuthLoopbackServer.swift`
- `Sources/PhonoDeck/Integrations/Google/GoogleAccountStore.swift`
- `Sources/PhonoDeck/Integrations/Google/KeychainStore.swift`
- `Sources/PhonoDeck/Integrations/YouTube/YouTubeDataClient.swift`
- `Sources/PhonoDeck/Features/YouTubeMusic/YouTubeAccountViewModel.swift`
- `Sources/PhonoDeck/Features/YouTubeMusic/YouTubeMusicNativeConceptView.swift`
- `docs/setup/google-youtube.md`
- `docs/research/google-oauth-findings.md`
- `docs/research/youtube-policy-findings.md`

## Build And Test

```sh
cd /path/to/phonodeck
xcodegen generate
xcodebuild -quiet -project PhonoDeck.xcodeproj -scheme PhonoDeck -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO SYMROOT="$PWD/build" build
xcodebuild -quiet -project PhonoDeck.xcodeproj -scheme PhonoDeck -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test
```

After the secret is set, launch and test sign-in:

```sh
pkill -x PhonoDeck 2>/dev/null || true
open -n "$PWD/build/Debug/PhonoDeck.app"
```

Then click Connect Google and complete the browser consent flow.