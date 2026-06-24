# ADR 0002: Service Policy Boundaries

## Status

Accepted

## Context

YouTube, Spotify, and Plex expose different rights and APIs. A universal app that pretends all sources support the same playback, downloads, casting, and metadata rules would create legal, technical, and UX risk.

## Decision

Every source adapter must expose capabilities explicitly. The app will disable or hide features that are not permitted or not technically available for a source.

## Consequences

- YouTube content is not downloaded, background-extracted, or audio-separated.
- Spotify is treated as Connect/metadata/control until an official native macOS streaming path exists.
- Plex personal media is the primary native playback/download path.
- UI copy must explain source-specific limitations without blaming the user.
