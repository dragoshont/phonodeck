# Platform Analysis

This document captures the first official-doc pass for PhonoDeck. The main conclusion is that the product must be service-aware, not a universal extractor. Plex and local files are the native playback foundation. Spotify and YouTube Music require explicit boundaries.

## P0 Feasibility Summary

| Capability | P0 decision | Reason |
| --- | --- | --- |
| Native macOS UI | Yes | Apple HIG encourages Mac-specific layouts, menu bar commands, keyboard shortcuts, resizable windows, and customizable toolbars. |
| Media keys and system controls | Yes | `MPRemoteCommandCenter` and `MPNowPlayingInfoCenter` are available on macOS and support play, pause, next, previous, metadata, and playback state. |
| Plex library playback | Yes | Plex Media Server API supports library sections, metadata, playlists, media part details, playback progress, and server discovery. |
| Local/iTunes import | Yes | User-owned local files and exported iTunes XML/M3U-style playlists can be imported without service policy risk. |
| YouTube Music playback | P0 feasibility gate | YouTube policy requires documented YouTube API Services and forbids separating audio/video, background hidden players, downloads, offline playback, and player modification. |
| Spotify native playback on macOS | Limited | Spotify Web API can control playback and read metadata. Spotify iOS SDK remotes the Spotify app, and streaming scope is for Web Playback SDK/Premium; no official native macOS streaming SDK found. |
| AirPlay to Apple speakers | Yes for native streams | AVFoundation/AVKit provide AirPlay support for app-owned playback. This is most viable for Plex/local media. |
| Chromecast/Cast | P1 investigation | Google Cast supports Web, Android, and iOS sender apps; no first-class native macOS sender was found in the official overview. |
| Downloads/offline | P1 for Plex/local only | Plex supports downloads for personal server media with Plex Pass/permission. YouTube policy forbids offline playback without approval; Spotify offline is not a general macOS third-party API. |

## Apple macOS and Media

Sources reviewed:

- Apple HIG: Designing for macOS
- Apple HIG: Sidebars
- Apple HIG: Toolbars
- Apple Design Resources
- `MPNowPlayingInfoCenter`
- `MPRemoteCommandCenter`
- Apple media streaming/AirPlay overview
- AVFoundation media playback configuration

Design implications:

- Use a sidebar for top-level areas like Listen Now, Library, Search, Downloads, Devices, and Settings.
- Do not hide the sidebar by default; provide a standard toolbar/menu command to toggle it.
- Keep toolbar controls sparse and symbol-first. Every toolbar command must also exist in the menu bar.
- Support resizable windows and a comfortable information density instead of mobile-style stacked navigation.
- Use SF Symbols, SF Pro, system materials, accent color, and standard controls.
- Integrate with system media controls via Now Playing and Remote Command Center.
- AirPlay should use system-standard AVFoundation/AVKit routes where playback is native.

## YouTube and YouTube Music

Official docs reviewed:

- YouTube Data API overview
- YouTube OAuth guide
- YouTube quota/compliance audits
- YouTube API Services Developer Policies
- YouTube IFrame Player API reference entry
- Google Cast overview

Findings:

- YouTube Data API supports search, videos, playlists, channels, uploads, and playlist management, but it is not a YouTube Music-native library/playback SDK.
- Installed desktop apps use OAuth 2.0 for user-authorized data; service accounts are not supported for YouTube account data.
- YouTube API projects have quotas and may require compliance audits for increased quota.
- API clients must use only documented APIs and must not scrape YouTube or reverse engineer undocumented services.
- API clients must not download, import, back up, cache, store copies of YouTube audiovisual content, or make it available for offline playback without prior written approval.
- API clients must not separate, isolate, modify, or promote only the audio or video component of YouTube audiovisual content.
- API clients must not create a background player that is not displayed on the screen the user is viewing.
- API clients must not mimic or replace core YouTube experiences unless they add significant independent value.

Decision:

- Treat YouTube Music as P0, but only through a visible official player surface or approved/native Google route. Hidden web playback is rejected.
- Do not implement YouTube downloads or hidden/background audio extraction.
- Keep YouTube source attribution and branding clear when displaying YouTube content.
- Use the user's Premium subscription only where official YouTube surfaces honor it; do not assume Premium grants third-party download rights.

## Spotify

Official docs reviewed:

- Spotify Web API
- Spotify scopes
- Spotify Player endpoint docs
- Spotify iOS SDK
- Spotify Developer Policy

Findings:

- Web API can retrieve metadata, search, manage playlists/library, and control playback on Spotify clients and Spotify Connect devices.
- Playback control requires scopes like `user-read-playback-state`, `user-modify-playback-state`, and `user-read-currently-playing`.
- The `streaming` scope is documented for Web Playback SDK and requires Spotify Premium.
- `app-remote-control` is documented for Spotify iOS and Android SDKs.
- Spotify policy prohibits apps that mimic or replace Spotify's core user experience without prior written permission.
- Spotify policy prohibits products integrated with streams/content from another service, and prohibits mixing/overlapping Spotify content with other audio content.
- Streaming applications may not be commercial under the policy language reviewed.

Decision:

- P0: support Spotify account connection, metadata surfaces, playlist/library references, currently-playing state, and Spotify Connect remote control.
- Do not plan native Spotify full-track playback on macOS until an official route is identified.
- Do not mix Spotify audio with YouTube/Plex/local audio.
- Keep Spotify-sourced content attributed and source-separated.

## Plex

Docs reviewed:

- Plex developer portal
- PlexAPI.dev OpenAPI index
- Plex downloads overview
- Plex Chromecast/AirPlay support article

Findings:

- Plex now has a public developer portal for Plex Media Server API.
- Available API areas include library sections, metadata, media part details, playlists, playback progress, sessions, sync items, server identity, and server information.
- Plex Downloads apply to personal media on a Plex Media Server, require Plex Pass or Plex Home admin Plex Pass, and require server permission to allow downloads.
- Plex-provided streaming content is not downloadable.
- Plex documents Chromecast and AirPlay behavior in its own apps; for PhonoDeck, AirPlay is strongest when playback is through AVFoundation.

Decision:

- Plex is the primary PhonoDeck source for native playback, offline download, AirPlay, and library ownership.
- P0 should implement auth/token storage, server discovery/manual server URL, music section listing, metadata, artwork, and native AVPlayer playback for direct-playable media.
- P1 should implement Plex downloads only after entitlement checks and explicit server/user permission checks.

## Cast and AirPlay

AirPlay:

- Native AVFoundation playback can expose standard AirPlay routing.
- Best P0/P1 fit: Plex/local playback to HomePod, Apple TV, and AirPlay speakers.
- YouTube/Spotify route support depends on their own official players/devices, not PhonoDeck extracting streams.

Google Cast:

- Official Cast sender platforms are Web, Android, and iOS.
- Cast receivers need media formats supported by Cast, such as HLS or DASH.
- Production Cast with auth/custom logic usually needs a registered custom receiver.
- Native macOS support likely needs a web sender bridge, companion iOS sender, or a deferred P1/P2 route.

## iTunes/Music Compatibility

Target support:

- Import exported iTunes Library XML where available.
- Import M3U/PLS playlists.
- Import local file folders with user-selected permissions.
- Match imported library items against Plex by artist, album, title, duration, track number, and ISRC where available.
- Do not depend on private Music.app database formats.
