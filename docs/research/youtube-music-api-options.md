# YouTube Music API Research

## Question

Can PhonoDeck switch from the official YouTube Data API / embedded player approach to a real YouTube Music API so the app behaves like a music player rather than a generic YouTube video browser?

## Short Answer

There is no public, official Google YouTube Music catalog/playback API equivalent to Apple Music MusicKit or Spotify Web API.

There are unofficial YouTube Music APIs. The most mature one is `ytmusicapi`, and another major ecosystem is `YouTube.js` / InnerTube. These can expose YouTube Music-style search, songs, albums, artists, library, playlists, lyrics, history, radios, charts, and uploads. They work by emulating YouTube Music web/internal requests, not by using a Google-supported public YouTube Music API.

## Official Google / YouTube APIs

### YouTube Data API v3

Official docs describe YouTube Data API as a way to add YouTube functionality to an app: search, playlists, subscriptions, channels, videos, uploads, and account metadata.

Relevant official resource families:

- `search`
- `videos`
- `playlists`
- `playlistItems`
- `subscriptions`
- `activities`
- `channels`

This API is official and supports OAuth scopes like:

- `https://www.googleapis.com/auth/youtube.readonly`
- `https://www.googleapis.com/auth/youtube`
- `https://www.googleapis.com/auth/youtube.force-ssl`

But it is YouTube-wide, not a dedicated YouTube Music API. It does not expose native audio stream URLs, YouTube Music catalog entities as first-class music objects, or an Apple Music / Spotify-style official music library API.

### Embedded YouTube Player / IFrame API

Official YouTube player requirements say embedded playback must remain visible, use a supported WebView, identify the app via referer/origin, and keep player controls unobscured. Minimum viewport is 200x200; 16:9 players are recommended at least 480x270.

This is official and policy-safe, but it is visually and technically a visible YouTube player, not native audio playback.

### Developer Policy Constraints

Official policy says API clients must not:

- use undocumented APIs without express permission;
- reverse engineer undocumented YouTube APIs;
- scrape YouTube Applications;
- use technologies other than YouTube API Services to retrieve API Data;
- hide/background the player;
- separate/isolate YouTube audio from video;
- download/cache YouTube audiovisual content without prior written approval.

These constraints are the reason an official-only PhonoDeck cannot simply become a hidden YouTube Music audio engine.

## Unofficial YouTube Music APIs

### `ytmusicapi`

Source: `sigma67/ytmusicapi`, docs at `ytmusicapi.readthedocs.io`.

The project describes itself as:

> Unofficial API for YouTube Music

It says it automates YouTube Music interactions by emulating the web requests that would happen in a browser. The project is not supported or endorsed by Google.

Capabilities listed by the project include:

- YouTube Music search with filters and suggestions;
- artists, albums, songs, videos, singles, related artists;
- song metadata;
- lyrics;
- watch playlists / radio / shuffle queues;
- moods and genre playlists;
- charts;
- library playlists, songs, artists, albums, subscriptions, podcasts, channels;
- play history;
- rating songs/albums/playlists;
- creating, deleting, editing playlists;
- adding/moving/removing playlist tracks;
- uploads.

Authentication modes:

- OAuth setup: as of Nov 2024, docs say it requires a YouTube Data API client ID and secret, using a TV/device flow.
- Browser setup: copy authenticated `music.youtube.com` request headers/cookies from DevTools; credentials remain valid as long as the browser session remains valid.

Important FAQ details:

- It distinguishes songs from videos: songs are actual artist-uploaded songs; videos are regular YouTube videos.
- It exposes `videoType` values such as `ATV` for high-quality song with cover image, `OMV` for official music video, `UGC` for user-generated content, and `OFFICIAL_SOURCE_MUSIC`.
- It says downloads can be done with `youtube-dl`, but that is not something PhonoDeck should implement for YouTube content without approval.

Product implication:

- This is the closest thing to the YouTube Music API the user wants.
- It is not official, can break, and carries policy/compliance risk.
- It would require either embedding/porting a Python library flow, using an equivalent InnerTube client, or writing our own client against undocumented endpoints.

### `YouTube.js` / InnerTube

Source: `LuanRT/YouTube.js`.

The project describes itself as a JavaScript client for YouTube's internal API, known as InnerTube. It is not affiliated with YouTube. It supports Node, Deno, and browsers. It has YouTube Music tests and can interact with internal YouTube/YouTube Music surfaces.

It also exposes low-level session/client knobs such as cookies, client type, user agent, visitor data, Proof of Origin token, JS player retrieval, etc. That is powerful, but it confirms this is internal API work, not a public supported YouTube Music API.

Product implication:

- More natural for a Swift app than Python only if we add a local JS/Node bridge or port the needed protocol.
- Still unofficial/internal.

### Existing Desktop Apps

Electron desktop apps such as the former `th-ch/youtube-music` lineage / `pear-desktop` wrap or extend the YouTube Music web app and use plugins/injection. Their own disclaimers emphasize no affiliation or endorsement by Google/YouTube. This is a different product strategy: use the real `music.youtube.com` web UI instead of building a native music API client.

Product implication:

- This gets closest to real YouTube Music behavior visually and functionally.
- It is web-app wrapping, not native Swift Apple Music-style UI.
- PhonoDeck previously hit embedded-browser rejection/deprecated-browser behavior with `music.youtube.com` in `WKWebView`, so this may require a different browser host strategy and still may be fragile.

## Feasible Product Paths

### Path A: Official Only

Use YouTube Data API + visible embedded YouTube player.

Pros:
- Policy-safe.
- Stable public docs.
- App Store safer.
- OAuth is standard.

Cons:
- Not a true YouTube Music catalog/library API.
- Song vs video is heuristic unless using official YouTube metadata only.
- Playback remains visible YouTube embed.
- Cannot expose true YouTube Music library/albums/artists as first-class official objects.

### Path B: Unofficial YouTube Music Metadata API, Official Player

Use `ytmusicapi`/InnerTube-like calls for YouTube Music search/library/playlists/song metadata, but still use visible official YouTube player for playback.

Pros:
- Much closer to the requested product.
- Can distinguish Songs vs Videos using YouTube Music-specific result types.
- Can expose real YouTube Music library concepts: songs, albums, artists, history, lyrics, radios, moods, charts.

Cons:
- Unofficial/internal endpoints.
- Google can change or block behavior.
- Policy risk: official policy prohibits undocumented APIs without express permission.
- App Store / production risk unless we accept a private/personal-use/non-public stance.

### Path C: YouTube Music Web App Host

Use the actual `music.youtube.com` web app as the source of truth, with native shell around it.

Pros:
- Real YouTube Music UI and behavior.
- Least reverse-engineering of metadata.
- User gets actual YouTube Music service.

Cons:
- Less native Apple Music-like UI.
- WebView/browser compatibility can break.
- Previous `WKWebView` attempt showed unsupported/deprecated-browser behavior.
- Harder to integrate deeply with native controls without interfering with the web app.

### Path D: Seek Official Approval / Partner API

Contact Google/YouTube for a partner or approved route.

Pros:
- Best long-term product path if granted.
- Could unlock real API or allowed integration.

Cons:
- Not immediate.
- May not be available for a personal/private app.

## Recommendation

For PhonoDeck's current private P0, the best technical path is **Path B as the default YouTube Music metadata engine**, while keeping **Path A as the official fallback and the separate YouTube video source**.

Implementation framing:

- Make the visible product YouTube Music-first.
- Keep YouTube and YouTube Music as separate source labels: YouTube Music for songs, YouTube for clips/videos.
- Expose a clear Music / Video / Mixed mode.
- Use the no-cookie experimental YouTube Music metadata provider for public music search/discovery rows after accepting the unofficial API risk for this closed-source project.
- Continue using visible official YouTube playback unless/until an approved playback route exists.
- Do not implement YouTube downloads.

Snappiness implication:

- YouTube Music search metadata should be cached at the app layer because the endpoint is a POST request and source rows are safe to reuse as metadata.
- Listen Now and Library should render cached music rows immediately and refresh provider data in the background.
- Private YouTube Music library/history requires authenticated YouTube Music internals or cookies; PhonoDeck currently avoids copied cookies, so private-library surfaces should use local PhonoDeck history plus official account APIs where available.

This gives the user the music-first experience they want without pretending the official YouTube Data API is a full YouTube Music API.

## Concrete Next Engineering Step

Keep the provider boundary explicit:

```text
YouTubeMusicProvider
  - officialDataAPIProvider      // current stable implementation
  - experimentalInnerTubeProvider // opt-in, music.youtube.com internal API model
```

Then wire UI modes to provider capability:

- Music: prefer `ATV`, `OFFICIAL_SOURCE_MUSIC`, official audio, Topic, album/song objects.
- Video: prefer `OMV`, official music videos, clips.
- Mixed: allow both.

The app should show a Settings toggle:

```text
YouTube Music Engine
[Official / Experimental]
```

Only enable Experimental after a clear warning that it uses unofficial YouTube Music internals and may break.