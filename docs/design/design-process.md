# PhonoDeck Design Process

How PhonoDeck designs screens to a native, Apple-quality bar — and how to use the design agents.
This is the documented, repeatable process the user asked for. It is deliberately deterministic:
decisions trace back to cited Apple rules in `design-system-research.md`, not personal taste.

## Roles (the design agents)

PhonoDeck uses three complementary VS Code custom agents under `.github/agents/`:

| Agent | Owns | Invoke for |
|---|---|---|
| **UX Architect** (`ux-architect.agent.md`) | *How it works* — IA, navigation, flows, interaction, keyboard model, state design (empty/loading/error), content/labels, accessibility behavior, per-source capability handling | "Where does this live?", "What happens when…", queue/playlist/search behavior, first-run flow |
| **UI Visual** (`ui-visual.agent.md`) | *How it looks* — layout/spacing metrics, SF Pro typography, system color, materials/Liquid Glass, SF Symbols, component appearance, polish | "Make this screen Apple-quality", typography/color/material/spacing specs, dark mode, visual review |
| **Native Design** (`native-design.agent.md`, pre-existing) | Broad native HIG direction & cross-cutting reviews | High-level "is this native?" reviews, IA+visual together for small asks |

All three are read/search/web only (no edits) — they produce specs and reviews; implementation happens in the
default agent. They are grounded in `docs/design/design-system-research.md`.

Invoke an agent from the chat agent picker, or let the primary agent delegate to one by name based on the
task description.

## The knowledge base

- `docs/design/design-system-research.md` — **the rule base.** Source-cited HIG specs (typography tables,
  hit targets, color, materials/Liquid Glass, SF Symbols, audio, lists/tables, search, onboarding) plus a
  per-screen quick reference (§16) and a ship checklist (§17). Every design decision should cite a section here.
- `docs/design/native-macos-guidelines.md` — existing principles (kept; complementary).
- `docs/design/phonodeck-ui-map.json` — **the source of truth** for flows, screens, components (real Swift
  names + glossary), sources + integration details, playback, and state. Update it first when anything changes.
- `ui-lab/` — **Storybook** design-validation workbench (see below).
- Live Apple HIG — https://developer.apple.com/design/human-interface-guidelines (re-verify before big calls;
  pages carry a change log). Apple Design Resources — https://developer.apple.com/design/resources (Figma/Sketch
  templates, SF Symbols app, fonts).

## UI mockups & validation (Storybook)

PhonoDeck validates UI **before** implementing it natively, using **Storybook** in `ui-lab/`
(`cd ui-lab && npm run storybook` → http://localhost:6007). Stories are named after the real Swift
components (`SidebarView`, `NowPlayingBar`, `SongResultRow`, `PlaylistArtworkCard`, …) and grouped as
Screens / Shell / Components / Onboarding, with a Light/Dark toolbar toggle and the Accessibility addon.

- Storybook (and any HTML mockups) are **design-only** — the app itself is native SwiftUI. Never ship or
  port them into the app target.
- Flow: mock/update the change in Storybook → review (Light + Dark + a11y) → get sign-off → implement in
  SwiftUI to match → update `docs/design/phonodeck-ui-map.json`.
- The earlier single-file `docs/design/phonodeck-ui-mockup.html` is **superseded by Storybook** (kept only
  as a quick static reference).

## Workflow for any screen or component

1. **Define the job** (UX Architect). State the user goal and where it lives in the IA. Identify the source(s)
   involved and their capability limits.
2. **Design behavior** (UX Architect). Produce the state table (empty / loading / partial / populated / error),
   interaction + keyboard/menu mapping, and per-source honesty rules. Output is implementation-ready behavior.
3. **Design appearance** (UI Visual). Produce the component spec (text style → color/material → spacing/size →
   SF Symbol) for each state, with light/dark + contrast + Reduce-Motion notes and exact SwiftUI tokens/APIs.
4. **Implement** (default agent). Build on `DesignTokens`, semantic system colors, semantic text styles, and
   system components. Mirror every toolbar action in the menu bar.
5. **Review against the checklist** (§17 of the research doc). Run `make test`; verify VoiceOver labels,
   keyboard reachability, contrast, dark mode, and honest per-source controls.
6. **Validate live** (optional). Build into `build/Debug` (see repo memory build note), relaunch, and inspect
   at compact + large window sizes in light and dark.

## Definition of done (Apple-quality bar)

A screen is done when it passes the **§17 review checklist** AND:

- It uses native components + system materials; Liquid Glass only in the control layer.
- Typography is the macOS text-style scale via semantic SwiftUI styles; colors are semantic and adapt to
  light/dark/increased-contrast; service color appears only as a small cue.
- Hit targets ≥ 28×28 pt; contrast ≥ 4.5:1 (3:1 for ≥18 pt/bold); fully keyboard-navigable; Reduce Motion honored.
- Now Playing controls are honest about what the active source can do; native sources publish
  `MPNowPlayingInfoCenter` / `MPRemoteCommandCenter`.
- Empty/loading/error states are quiet, explanatory, and offer one clear action — no fake content, no
  signed-out token calls.
- Every non-obvious decision cites a `design-system-research.md` section / HIG page.

## When the rules might be stale

Apple updates the HIG (each page has a "Change log"). Before a major design decision, have UX Architect or UI
Visual re-fetch the relevant HIG page with the `web` tool and reconcile any change into
`design-system-research.md` (note the date). The current system design language is **Liquid Glass** (WWDC25).

## Auth walls / paywalled material

The Apple HIG, Apple developer docs, Apple Design Resources, SF Symbols, and the Apple fonts are public and
need no sign-in. If a future source requires authentication or is paywalled, the agent must **stop and tell the
user** rather than guess, and (where permitted) use the Playwright/browser tools to reach the content with the
user's involvement. Never fabricate specs to get past a wall.
