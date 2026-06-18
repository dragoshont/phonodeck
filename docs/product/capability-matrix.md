# Capability Matrix

This matrix is the app's guardrail. UI should query source capabilities before showing actions.

| Capability | Plex personal media | Local/iTunes files | YouTube Music | Spotify |
| --- | --- | --- | --- | --- |
| Native metadata browsing | Yes | Yes | Limited via YouTube Data API where applicable | Yes via Web API |
| Native full-track playback | Yes, for playable server media | Yes | No, use visible official player/surface only | Not on macOS unless official supported path is found |
| Hidden/background extraction | No need | No need | No | No |
| Downloads/offline | P1 with Plex Pass/permission | Yes, user-owned files | No without YouTube prior written approval | No general third-party offline API for macOS |
| Media keys | Yes | Yes | Only if controlling an allowed visible player/session | Spotify Connect control only |
| Now Playing metadata | Yes | Yes | Limited/only for allowed playback surface | For remote state display, not local stream ownership |
| AirPlay | Yes through AVFoundation | Yes through AVFoundation | Not by stream extraction; official player route only | Use Spotify's own device ecosystem where applicable |
| Google Cast | P1 investigation | P1 investigation | Use YouTube/Cast official surfaces only | Spotify Connect, not custom casting |
| Playlist read | Yes | Yes for imported playlists | Yes where YouTube Data API supports it with scopes | Yes with scopes |
| Playlist write | Yes | Yes locally | Yes only through documented user-authorized API scopes | Yes with scopes |
| Sharing | Plex/local/deep links | File/deep links | YouTube links with attribution | Spotify links with attribution |
| Account token storage | Plex token in Keychain | None unless file bookmarks | Google OAuth token in Keychain | Spotify OAuth token in Keychain |

## Capability Types For Code

- `metadataRead`
- `metadataWrite`
- `nativePlayback`
- `embeddedPlayback`
- `externalRemoteControl`
- `download`
- `airPlay`
- `cast`
- `playlistRead`
- `playlistWrite`
- `share`

Each capability should include a source, status, required entitlement/scope, and denial reason for UI display.
