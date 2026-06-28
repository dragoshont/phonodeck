# PhonoDeck

PhonoDeck is a native-first macOS music app experiment built while testing Architrave, my judge-gated agent workflow for product and engineering work. It is a personal, exploratory project rather than a polished commercial app, but the current build works with a Google/YouTube account.

The interesting constraint was trying to make a YouTube-backed music app that feels like more than a plain iframe holder. PhonoDeck uses official YouTube account/data APIs for account identity, search, playlists, playlist items, subscriptions, and activity, then uses a visible official YouTube player for playback because YouTube does not expose native third-party audio streams. The surrounding app is SwiftUI: Home, playlists, queue-aware controls, metadata, and source-honest playback chrome.

The product direction is deliberately conservative: feel native, use official/public APIs, and keep provider rules honest. No hidden YouTube playback, no scraped YouTube Music endpoints, and no YouTube downloads/offline playback without approval.

PhonoDeck is open source under the MIT license. The official signed App Store builds may be paid to cover Apple Developer Program and distribution costs; the source code remains available for people who want to build it themselves.

## Current Status

- Open-source repo: `github.com/dragoshont/phonodeck`
- Native scaffold: SwiftUI macOS app generated with XcodeGen
- P0 target: YouTube / YouTube Music account connection, song-first search, account playlists, visible official playback, queue-aware controls, and design rules
- P1 target: richer playlist/library polish, better recommendation surfaces, and clearer provider capability states
- P2 target: companion apps and broader provider experiments, only where official APIs allow them

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
- Spotify full-track playback inside the macOS app is not assumed; treat Spotify as metadata plus official embedded/Connect surfaces until an approved route exists.

## Release Build

GitHub Releases may include an unsigned local macOS build. Because it is unsigned/notarized for local testing only, macOS may require explicit approval in Privacy & Security before opening it.

The app requires your own configured Google OAuth desktop credentials for full YouTube account functionality when building locally. Release artifacts do not include private OAuth secrets.

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
