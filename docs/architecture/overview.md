# Architecture Overview

PhonoDeck is organized around source adapters and a native playback core.

## Layers

| Layer | Responsibility |
| --- | --- |
| App shell | SwiftUI/AppKit window, sidebar, toolbar, menu commands, Now Playing bar |
| Playback | AVFoundation playback, queue, Now Playing metadata, media-key commands, route support |
| Library model | Source-neutral albums, artists, tracks, playlists, downloads, imported files |
| Source adapters | Plex, YouTube Music, Spotify, Local/iTunes import |
| Policy gates | Per-source capability checks for playback, downloads, sharing, cache, and export |
| Persistence | Account tokens in Keychain, library cache, download database, user settings |
| Remote control | Future iOS/watch companion, local network session, playback command API |

## Source Adapter Rules

- Adapters return metadata and explicit `PlaybackPolicy` values.
- Adapters must not expose raw streams unless the service policy and API allow native playback.
- Downloads must be tied to a source capability and user permission check.
- Cross-source search must never imply that one service owns another service's content.

## Native Playback Path

Plex and local files are the first native playback targets:

1. Resolve playable media part URL or local file URL.
2. Build an `AVPlayerItem` with artwork and metadata where available.
3. Play with AVFoundation.
4. Publish metadata to `MPNowPlayingInfoCenter`.
5. Register remote commands with `MPRemoteCommandCenter`.
6. Expose AirPlay route controls through system-supported AVKit/AVFoundation UI.

## Remote Control Path

P2 Apple Watch support should use an iOS companion app with WatchConnectivity. The watch should not talk directly to service APIs. It should command the user's signed-in Mac app or companion iPhone session:

- play/pause
- next/previous
- volume where supported
- current track metadata/artwork
- queue peek
- source/device switching where policy permits
