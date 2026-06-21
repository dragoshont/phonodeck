# Roadmap

## P0: Native Foundation

- Native macOS app shell with sidebar, toolbar, menu commands, keyboard shortcuts, and Now Playing bar.
- YouTube Music P0 feasibility gate: visible official player or approved/native Google route, with hidden web playback rejected.
- Source adapters for Plex, YouTube Music, Spotify, and Local/iTunes import.
- Plex account/server connection and music library browsing.
- Native AVFoundation playback for Plex/local media.
- `MPNowPlayingInfoCenter` metadata and `MPRemoteCommandCenter` media-key handling.
- Search UI with source attribution.
- Share sheet support for local app links and source links.
- Privacy/account settings with token revocation paths.

## P1: Ownership Features

- Plex personal media downloads with Plex Pass/permission checks.
- Download manager, storage budget, cache inspection, and deletion.
- AirPlay route control for native playback.
- Cast feasibility prototype using official sender/receiver constraints.
- iTunes XML/M3U import and library matching.
- Playlist editing for Plex/local sources, Spotify playlist management where policy allows, and YouTube Music playlist management only through documented YouTube API scopes.

## P2: Companion Apps

- iOS companion for remote control and setup.
- Apple Watch remote using WatchConnectivity through the iOS companion.
- Compact watch Now Playing, queue peek, source/device indicators, and playback commands.

## Explicitly Out Of Scope Unless Approved

- YouTube/YouTube Music downloads or offline playback.
- YouTube hidden/background player extraction.
- Spotify native full-track playback on macOS without official SDK support.
- Scraped or reverse-engineered service APIs.
