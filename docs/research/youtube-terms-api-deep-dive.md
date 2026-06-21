# YouTube Terms And API Deep Dive

Checked on 2026-06-19 against official YouTube, YouTube API Services, Google API Services, and YouTube Paid Service terms/docs.

This is engineering risk analysis, not legal advice.

## Immediate Product Conclusion

PhonoDeck's P0 can be a YouTube-first player, but it should not rely on `music.youtube.com` running as a full website inside `WKWebView`. The current embedded YouTube Music page shows "browser deprecated", which means YouTube Music itself is declining that embedded browser environment.

The safer official playback path is:

1. Use YouTube Data API for search, playlists, subscriptions, activity, and metadata.
2. Use a visible YouTube embedded player / IFrame Player API for selected playable YouTube video IDs or playlist IDs.
3. Keep the YouTube player visible, large enough, unobscured, branded, and user-initiated.

Do not build a hidden audio player, stream extractor, downloader, cache, or user-agent-spoofed YouTube Music browser without written approval.

## Official Docs Reviewed

- YouTube API Services Terms of Service: https://developers.google.com/youtube/terms/api-services-terms-of-service
- YouTube API Services Developer Policies: https://developers.google.com/youtube/terms/developer-policies
- Required Minimum Functionality: https://developers.google.com/youtube/terms/required-minimum-functionality
- YouTube Embedded Players and Player Parameters: https://developers.google.com/youtube/player_parameters
- YouTube IFrame Player API: https://developers.google.com/youtube/iframe_api_reference
- YouTube Data API Overview: https://developers.google.com/youtube/v3/getting-started
- Google API Services User Data Policy: https://developers.google.com/terms/api-services-user-data-policy
- YouTube Terms of Service: https://www.youtube.com/t/terms
- YouTube Paid Service Terms / Premium terms: https://www.youtube.com/t/terms_paidservice

## Hard Boundaries

### No Native YouTube Audio Stream API

None of the official YouTube Data API or Player API docs expose a native audio stream URL for third-party apps. YouTube Premium / YouTube Music Premium does not change that; Premium grants user-facing benefits inside YouTube's own service surfaces, not a documented native audio playback entitlement for PhonoDeck.

### No Download / Offline / Extraction

The Developer Policies prohibit downloading, importing, backing up, caching, or storing copies of YouTube audiovisual content without prior written approval. They also prohibit making content available for offline playback and separating or promoting just the audio or video component.

### No Hidden Player

Policies prohibit creating or promoting playback from a background player not displayed in the page, tab, or screen the user is viewing. Therefore a hidden `WKWebView`, invisible player, or "native controls over hidden YouTube audio" design is out.

### Do Not Modify Or Obscure YouTube Player

The YouTube player must not be modified, built upon, blocked, obscured, or replaced. No overlays in front of player controls. YouTube attribution and branding must remain visible.

### Do Not Scrape Or Use Undocumented APIs

The Developer Policies and Google API Services User Data Policy prohibit undocumented APIs and reverse engineering. Unofficial YouTube Music endpoints are not acceptable for a stable product direction.

### Be Honest About Environment

Google's User Data Policy says not to mislead Google about an application's operating environment, including user-agent/environment claims during authentication. YouTube API policies also prohibit masking or misrepresenting API client identity. User-agent spoofing to make YouTube Music believe `WKWebView` is Chrome may be technically tempting, but it is a high-risk product choice and should not be treated as compliant without explicit approval.

## Official Playback Paths

### Path A: YouTube IFrame / Embedded Player

This is the strongest policy-safe playback path.

Allowed mechanics:

- Load `https://www.youtube.com/embed/VIDEO_ID` in a visible embedded player.
- Load playlists with `https://www.youtube.com/embed?listType=playlist&list=PLAYLIST_ID`.
- Use the IFrame Player API for supported controls and events if `enablejsapi=1` is set.
- Use `origin` / `Referer` identity as required by Required Minimum Functionality.
- Use OS-provided WebView types; `WKWebView` is explicitly listed as acceptable for Apple platforms.

Requirements:

- Minimum player viewport: 200x200 px.
- Recommended 16:9 player size: at least 480x270 px.
- No autoplay until the player is visible and more than half visible.
- Do not overlay or obscure any part of the player or controls.
- Keep YouTube branding and player functionality intact.
- User actions involving YouTube resources must be clearly YouTube actions and initiated by the user.

Product implication:

- Replace the current full `music.youtube.com` WKWebView with a native YouTube search/list UI plus a visible official `youtube.com/embed` player for selected videos/playlists.
- This will play YouTube videos/music videos in PhonoDeck. It will not be a full YouTube Music app clone, but it is a real in-app YouTube playback path.

### Path B: Visible YouTube Music Web Surface

This is weaker. It keeps the official surface visible, but `music.youtube.com` currently rejects the embedded browser as deprecated.

Allowed only if:

- The official UI is visible and not modified/obscured.
- We do not spoof, scrape, hide, or automate around restrictions.
- The site actually supports the browser environment.

Current status:

- `WKWebView` loads `music.youtube.com` but YouTube Music shows "browser deprecated".
- Treat this as unsupported by YouTube Music for PhonoDeck's current WebView environment.
- Do not make this the core playback strategy unless a compliant supported browser integration is found.

### Path C: External Browser

This remains a fallback, not the product's primary playback goal.

## YouTube Data API Surface

Checked via the official discovery document at `https://www.googleapis.com/discovery/v1/apis/youtube/v3/rest`.

Useful resources and methods:

| Resource | Methods | PhonoDeck use |
| --- | --- | --- |
| `search` | `list` | Search public YouTube videos/channels/playlists. Cannot directly search YouTube Music private catalog. |
| `videos` | `list`, `getRating`, `rate`, `insert`, `update`, `delete`, `reportAbuse` | Fetch video metadata/duration/embed-related fields; optionally rate with expanded scopes later. No stream URLs. |
| `channels` | `list`, `update` | Current account/channel identity via `mine=true`; channel metadata and related playlists. |
| `playlists` | `list`, `insert`, `update`, `delete` | Back the YouTube Music playlist surface by reading the user's YouTube account playlists; later create/update playlists with write scopes. |
| `playlistItems` | `list`, `insert`, `update`, `delete` | Read videos in playlists and build playable queues by video ID. |
| `subscriptions` | `list`, `insert`, `delete` | Read subscribed channels and optionally subscribe/unsubscribe later. |
| `activities` | `list` | User activity feed / account context. |
| `commentThreads` / `comments` | list/insert/update/delete/moderation methods | Not P0 for playback. Requires careful UI and scopes. |
| `captions` | list/insert/update/delete/download | Not P0 for playback; caption download is not audio/video content download, but still needs policy care. |

OAuth scopes exposed by discovery:

| Scope | Use |
| --- | --- |
| `https://www.googleapis.com/auth/youtube.readonly` | Current PhonoDeck scope; view YouTube account data. |
| `https://www.googleapis.com/auth/youtube` | Broad account management; avoid until needed. |
| `https://www.googleapis.com/auth/youtube.force-ssl` | See/edit/delete videos, ratings, comments, captions; avoid until write features exist. |
| `https://www.googleapis.com/auth/youtube.upload` | Upload videos; not relevant. |
| Partner scopes | Partner/content-owner workflows; not relevant. |

Live token probe, without printing secrets/tokens:

- `channels?part=snippet,contentDetails&mine=true`: OK, 1 item.
- `playlists?part=snippet,contentDetails&mine=true&maxResults=5`: OK, 5 items from 19 total.
- `subscriptions?part=snippet&mine=true&maxResults=5`: OK, 5 items from 267 total.
- `activities?part=snippet,contentDetails&mine=true&maxResults=5`: OK, 5 items from 20 total.

This proves PhonoDeck can build real account-aware YouTube metadata surfaces with the current read-only scope.

## What PhonoDeck Should Build Next

### P0 Playback Pivot

Replace the current `music.youtube.com` full-site `WKWebView` with:

1. Native search box calls `search.list` for videos.
2. Native results list shows YouTube attribution, video title, channel, thumbnail, duration where available.
3. Selecting a result loads `https://www.youtube.com/embed/VIDEO_ID?enablejsapi=1&origin=...` in a visible `WKWebView` player.
4. Add playlist support by reading `playlists.list` + `playlistItems.list`, then queueing video IDs in the embedded player.
5. Keep all playback user-initiated and visible.

### Do Not Do

- Do not spoof Chrome user-agent to force `music.youtube.com` to load in `WKWebView`.
- Do not call undocumented YouTube Music endpoints.
- Do not extract DASH/HLS/audio streams.
- Do not hide or shrink the player below policy requirements.
- Do not put custom controls over the YouTube player controls.
- Do not request broad write scopes before the corresponding feature exists.

## Practical Meaning

PhonoDeck can be a YouTube-first app that plays YouTube content inside the app. The compliant path is a native shell around the official embedded YouTube player plus Data API metadata. PhonoDeck cannot, using public official APIs, become a native Apple Music clone that streams YouTube Music audio through `AVPlayer`.