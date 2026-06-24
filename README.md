# PhonoDeck

PhonoDeck is a native-first macOS music app concept: an Apple-style library and player for personal Plex music, YouTube Music discovery/playback where official policy allows it, and Spotify metadata plus Connect control.

The product direction is deliberately conservative: feel native on day one, use official/public APIs, and keep each service's playback and download rules visible in the architecture.

PhonoDeck is open source under the MIT license. The official signed App Store builds may be paid to cover Apple Developer Program and distribution costs; the source code remains available for people who want to build it themselves.

## Current Status

- Open-source repo: `github.com/dragoshont/phonodeck`
- Native scaffold: SwiftUI macOS app generated with XcodeGen
- P0 target: Native macOS shell, YouTube Music feasibility path, library model, Plex/local playback path, system media keys, Now Playing metadata, source adapters, and design rules
- P1 target: Offline downloads for eligible Plex personal media, AirPlay for AVFoundation-backed playback, Cast investigation, richer library sync
- P2 target: iOS companion and Apple Watch remote control

## Platform Direction

PhonoDeck is a multi-platform product with native implementations per platform:

- Apple platforms: Swift and SwiftUI.
- Windows: native .NET / WinUI.
- Web: React / TypeScript.

Shared behavior should live in contracts, provider policy, fixtures, and docs. Platform UI and OS media APIs stay platform-native.

See [docs/architecture/multiplatform-structure.md](docs/architecture/multiplatform-structure.md).

## Build

Requirements on this Mac are already present: Xcode 26.5, Swift 6.3, and XcodeGen.

```sh
make generate
make build
```

Open the generated project with:

```sh
open PhonoDeck.xcodeproj
```

## Non-Negotiables

- Native macOS is P0. Use SwiftUI, AppKit where needed, AVFoundation, MediaPlayer, and system controls.
- Do not use private Apple APIs, scraped YouTube/YouTube Music endpoints, or unofficial Spotify streaming routes.
- YouTube Music is P0, but hidden web playback is not acceptable. The only safe paths are a visible official player surface or an approved/native Google route. YouTube downloads/offline playback are not in scope unless YouTube grants prior written approval.
- Spotify full-track playback inside the macOS app is not assumed; treat Spotify as metadata plus Spotify Connect control until an official native route exists.
- Plex personal music is the primary path for true native playback, downloads, AirPlay, and library ownership.

## Key Docs

- [LICENSE](LICENSE)
- [docs/open-source.md](docs/open-source.md)
- [docs/developers/oauth-credentials.md](docs/developers/oauth-credentials.md)
- [docs/architecture/multiplatform-structure.md](docs/architecture/multiplatform-structure.md)
- [docs/research/platform-analysis.md](docs/research/platform-analysis.md)
- [docs/design/native-macos-guidelines.md](docs/design/native-macos-guidelines.md)
- [docs/architecture/overview.md](docs/architecture/overview.md)
- [docs/roadmap.md](docs/roadmap.md)
- [docs/security-privacy.md](docs/security-privacy.md)
- [docs/setup/google-youtube.md](docs/setup/google-youtube.md)

## Working Product Name

PhonoDeck is the working product name for this repository and app.
