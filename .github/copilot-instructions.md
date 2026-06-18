# Project Guidelines

## Product Priorities

- P0 is a native macOS music app using SwiftUI/AppKit, AVFoundation, MediaPlayer, and system UI patterns.
- Plex/local media are the primary native playback and download path.
- YouTube Music and Spotify integrations must stay inside official documented APIs and policies.
- P2 iOS/watch work should build on the Mac app's playback/session model, not duplicate service logic.

## Code Style

- Prefer small Swift types with explicit capability models over source-specific conditionals spread through UI code.
- Keep service adapters source-aware and policy-aware.
- Do not add private Apple APIs, scraped service endpoints, or hidden playback extraction.
- Use SF Symbols and native controls for UI. Avoid custom controls unless the system component cannot satisfy the requirement.

## Build and Test

- Generate the Xcode project with `make generate`.
- Build with `make build`.
- Test with `make test`.

## Key Docs

- See `docs/research/platform-analysis.md` before changing source capabilities.
- See `docs/design/native-macos-guidelines.md` before changing layout or visual style.
- See `docs/architecture/overview.md` before adding modules.
