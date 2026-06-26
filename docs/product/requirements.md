# Product Requirements

PhonoDeck is a native macOS music app for people who like Apple Music's Mac interface but want a service-aware player/library that brings together Plex personal music, YouTube Music, Spotify, local files, and later Apple Watch remote control.

## Product Promise

Give the user a quiet, native, Apple-quality music desk for browsing, playing, controlling, and organizing music across owned and subscribed sources without violating source rules.

## Primary User

- Uses macOS as the main listening workstation.
- Has YouTube Music Premium.
- Has or wants a Plex music library.
- May also use Spotify.
- Wants Apple Watch remote control later.
- Values native macOS behavior more than a cross-platform web shell.

## P0 Requirements

| Area | Requirement | Acceptance signal |
| --- | --- | --- |
| Native app | SwiftUI/AppKit macOS app with sidebar, toolbar, menu bar commands, keyboard shortcuts, and resizable layout | App builds and opens as a macOS app |
| Playback core | AVFoundation-backed playback path for Plex/local media | Play/pause/next/previous state flows through a central coordinator |
| System media | Keyboard media keys, Control Center, and Now Playing metadata | Uses `MPRemoteCommandCenter` and `MPNowPlayingInfoCenter` |
| Source model | Plex, YouTube Music, Spotify, and Local adapters expose explicit capabilities | UI can query source policy before offering a feature |
| Plex | Connect to Plex, browse music libraries, read metadata/artwork, play direct-playable tracks | Library appears in native UI and plays through native player |
| YouTube Music | P0 feasibility path for official playback plus search/discovery | Hidden web playback is rejected; native playback needs an approved Google route |
| Spotify | OAuth, metadata, playlists/library references, currently playing state, and Spotify Connect control | No fake native macOS streaming path |
| Sharing | Share source links and PhonoDeck deep links where possible | Standard macOS share UI available from toolbar/menu |
| iTunes compatibility | Import iTunes XML/M3U/local folders | Imported items appear as local/library records |
| Privacy | Keychain token storage, account disconnect, data deletion paths | Tokens never written to repo or plain config |

## P1 Requirements

| Area | Requirement | Notes |
| --- | --- | --- |
| Downloads | Plex personal media downloads with Plex Pass and server permission checks | YouTube/Spotify downloads remain out of scope unless official approval/API exists |
| AirPlay | AirPlay route support for native AVFoundation playback | Best for Plex/local media |
| Cast | Investigate official Cast route | Native macOS sender support is not first-class in official Cast overview |
| Playlists | Create/edit Plex/local playlists and manage Spotify/YouTube Music playlists only with proper scopes | Keep source attribution and consent explicit |
| Library matching | Match Plex/local/Spotify/YouTube metadata by title, artist, album, duration, track number, and ISRC where available | Avoid derived service metrics |

## P2 Requirements

| Area | Requirement | Notes |
| --- | --- | --- |
| iOS companion | Remote control and setup companion | Uses the Mac app/session as source of truth |
| Apple Watch | WatchConnectivity remote for playback, queue peek, current track, and output route | No direct service-token handling on watch |

## iPhone Interaction Notes

- Markdown editing on iPhone should use live preview with focused source editing, visible mode controls, and accessible gesture alternatives. See [iPhone Markdown Edit and Preview UX](iphone-markdown-edit-preview.md).

## P0 YouTube Music Acceptance

- The app does not attempt to extract streams, run background-only playback, hide a web player, or download YouTube content.
- The app can use native controls only with a visible official player surface or an approved Google/YouTube playback API.
- If embedded sign-in or playback is blocked by Google, the fallback is an external official surface, not hidden playback.
- A true Apple Music-style native YouTube Music engine is a partner/API approval dependency.

## Open Questions

- Can Google Cast be supported cleanly from macOS through an official Web Sender bridge inside the app, or should it wait for iOS companion support?
- What exact Plex auth flow should P0 use: manual token entry first, plex.tv OAuth/PIN, or both?
- Should PhonoDeck reserve a domain now while `phonodeck.app`/`.fm`/`.music` appear available?
- Is distribution personal-only/TestFlight-style initially, or intended for broader public release after policy review?
