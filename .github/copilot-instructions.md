# Project Guidelines

## Design language (always)

Always develop in the established PhonoDeck design language — for **both frontend and backend**. Ground in the source of truth FIRST and reproduce/extend existing patterns; never reinvent.

- **Frontend (SwiftUI / UI):** the canonical design is Storybook (`ui-lab/`) + `docs/design/phonodeck-ui-map.json`. Reproduce components by their `glossary` name; the design agents review/extend, they don't greenfield. Full rules: `.github/instructions/ui-implementation.instructions.md`.
- **Backend (services / integrations / playback / models):** the canonical patterns are `docs/architecture/overview.md` + the ADRs + the existing source abstraction (`MusicSourceAdapter`/`SourceRegistry`, neutral `MusicTrack`…, `SourceCapabilityResolver`, `PlaybackRouter`/`PlaybackPlan`). Extend those; don't add parallel abstractions or per-source conditionals. Full rules: `.github/instructions/backend-architecture.instructions.md`.
- When a pattern legitimately must change, update the source-of-truth doc FIRST, then the code. Keep `make build` / `make test` green.

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

## UI/UX Development Flow

- The macOS app is **native SwiftUI**. `ui-lab/` (Storybook) and any HTML mockups are **design-only** previews — never ship them or port them into the app target.
- **Validate UI before implementing natively.** When a change affects layout/visual/UX, mock or update it in Storybook (`cd ui-lab && npm run storybook` → http://localhost:6007), confirm with the user, then build it in SwiftUI to match.
- **Always validate against Apple design.** Cite `docs/design/design-system-research.md` (re-verify the live HIG for big calls). Don't reinvent solved patterns — most concerns map to an existing Apple / Apple Music pattern.
- Use the design agents: **UX Architect** (how it works) and **UI Visual** (how it looks). See `docs/design/design-process.md`.
- **On feedback/changes, do a full-app consistency check:** search the codebase for every place the same pattern/component/state appears and apply the change consistently — don't fix one screen and leave siblings inconsistent.
- **Keep `docs/design/phonodeck-ui-map.json` in sync** (the source of truth for flows, components, and sources + integration details). Update it first, then Storybook, then SwiftUI.
- Refer to components by their **real names** from the JSON map's `glossary` (e.g. sidebar toggle, `NowPlayingBar`, `nowPlayingPanel`, `SongResultRow`).

## Build and Test

- Generate the Xcode project with `make generate`.
- Build with `make build`.
- Test with `make test`.

## Key Docs

- See `docs/research/platform-analysis.md` before changing source capabilities.
- See `docs/design/native-macos-guidelines.md` before changing layout or visual style.
- See `docs/architecture/overview.md` before adding modules.
