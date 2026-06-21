---
description: "Use when writing or changing PhonoDeck backend Swift: service integrations, adapters, OAuth, playback routing, capability/tier model, neutral library models, devices, or app state. Enforces grounding in the architecture docs + the existing source/capability abstraction and extending those patterns instead of reinventing them."
applyTo: ["Sources/PhonoDeck/Integrations/**", "Sources/PhonoDeck/Playback/**", "Sources/PhonoDeck/Library/**", "Sources/PhonoDeck/Models/**", "Sources/PhonoDeck/Services/**", "Sources/PhonoDeck/Media/**", "Sources/PhonoDeck/Devices/**", "Sources/PhonoDeck/Support/**", "Sources/PhonoDeck/App/**", "Tests/**"]
---
# PhonoDeck backend — established patterns first

The service / integration / playback layer has an established design language. Before adding or changing it, **ground in the architecture source-of-truth and extend the existing patterns — never introduce a parallel abstraction or per-source conditionals.**

## Ground first
- `docs/architecture/overview.md` — read before adding modules.
- `docs/architecture/adrs/0001-native-macos-first.md` and `0002-service-policy-boundaries.md` — the binding decisions.
- `docs/research/platform-analysis.md` — read before changing source capabilities.

## Reuse the abstraction (don't reinvent)
- **Sources** go through `MusicSourceAdapter` / `BaseSourceAdapter` + `SourceRegistry` — not bespoke per-service paths or `if source == …` branches.
- **Models**: map every provider DTO to the neutral `MusicTrack` / `MusicAlbum` / `MusicArtist` / `MusicPlaylist` (`Library/` + `Integrations/Core`). UI and playback consume the neutral types.
- **Accounts**: model connection with `SourceConnectionState` and tier with `SourceAccountTier`; resolve per-feature capability HONESTLY (free vs paid) through `SourceCapabilityResolver` — keep the matrix truthful, never imply a capability a source/tier can't perform.
- **Playback**: route through `PlaybackRouter` / `PlaybackPlan`. ONLY `nativeAV` owns the system Now Playing + media keys (`MPNowPlayingInfoCenter` / `MPRemoteCommandCenter`); web embeds and Connect-style remotes must NOT claim them.
- **Auth**: follow the existing OAuth pattern — PKCE + loopback (`Integrations/OAuth/OAuthSupport`, `OAuthLoopbackServer`) + a Keychain account store (`Integrations/Google`, `Integrations/Spotify`, `Integrations/Plex`). Secrets live only in `Config/Secrets.xcconfig` → Info.plist; never in code, logs, or chat.

## Policy (ADR 0002 — non-negotiable)
- Keep adapters source-aware AND policy-aware.
- NO private/undocumented Apple APIs, NO scraped or undocumented service endpoints, NO hidden/background players or stream extraction, NO unauthorized downloads/offline. YouTube and Spotify stay inside official documented APIs.

## Concurrency
- `MusicSourceAdapter` / `BaseSourceAdapter` / `SourceRegistry` / `PlaybackRouter` are `@MainActor`. Respect `Sendable` boundaries — copy a local `let api = self.api` before `async let`, and make adapter-touching tests `@MainActor`.

## Keep in sync + verify
- When a pattern legitimately changes, update `docs/architecture/overview.md` (and the relevant ADR / capability doc) FIRST, then the code.
- Add tests with the existing fixture + mock-`URLSession` pattern (`Tests/PhonoDeckTests/`). Run `make build` → `make test` (green); `make generate` after adding Swift files.
