# Phase 7 UX, Accessibility, Performance Checklist

This checklist is the Phase 7 evidence target for screenshot, keyboard, VoiceOver, contrast, reduced-motion, and warm-cache validation. It is intentionally scoped to implemented surfaces; broad navigation/table refactors are recorded as deferrals unless a check proves they block release use.

## Screenshot Targets

Storybook targets:

- Screens: Home, First Run, Library, Playlist, Albums, Artists, Queue, Search, Settings.
- Now Playing: no selection, YouTube iframe, Spotify embed, native, blocked, failed, lyrics unavailable, About unavailable/native.
- Phase 5 readiness states.
- Phase 6 operational states.

Native targets:

- Library/Home, Search, Playlists, Albums, Artists, Queue, Settings, Now Playing, Storage, Devices, Provider Lab.

Viewports and appearances:

- 940x640, 1200x760, 1400x900.
- Light and Dark appearance.
- Increase Contrast and Reduce Motion when system settings are available.

### Screenshot Results

Status: PASS for automated Storybook representative coverage.

Evidence:

- `.architrave/screenshots/phase7/storybook-screenshots.json`
- `.architrave/screenshots/phase7/*.png`
- Harness assertion: every captured story waits for `.pd` rendered content and fails if the screenshot file is too small to be credible.
- Spot-checked rendered samples: `screens-home-min.png` and `phase6-providerlab-failed-wide.png` contain visible Storybook content.

Captured representative stories at `940x640`, `1200x760`, and `1400x900`:

- Home, Library, Search, Settings.
- Now Playing no-selection and visible YouTube iframe.
- Phase 5 Albums/Artists limited surfaces.
- Phase 6 Storage, Devices, Provider Lab success/failure surfaces.

Native app golden screenshots: DEFERRED to Phase 7 manual pass / Phase 10 RC because this phase restored the configured screenshot harness and captured Storybook targets, but no reliable native window automation is installed in-repo yet. The harness now fails for missing Storybook/Playwright/Edge prerequisites instead of passing with only a desktop smoke shot.

## Accessibility Checks

- Icon-only buttons have labels or help text.
- Disabled controls explain why.
- Rows announce title, artist/channel, source, selected/current state, and action hint.
- Source identity is text/label-backed, not color-only.
- Full Keyboard Access order: sidebar -> toolbar/search -> content rows/tables -> row actions -> right panel -> bottom bar.
- Space does not steal text input focus from search fields.
- Menus expose navigation/playback commands and keep unavailable commands visible/disabled.

### Accessibility Results

Status: PARTIAL PASS with explicit deferrals.

Automated/static evidence:

- `get_errors` clean for SwiftUI, tests, Storybook source, screenshot script, and this checklist.
- Storybook a11y addon is installed and Storybook builds successfully.
- Source badges/callouts include visible text labels or accessibility labels in SwiftUI and Storybook.
- Phase 7 added View menu sidebar toggle and disabled playback commands for unsupported states.

Manual checks deferred:

- Full Accessibility Inspector sweep of every native surface.
- VoiceOver traversal of every golden native surface.
- Increase Contrast visual inspection of native surfaces.
- Reduced Motion behavior inspection.

Deferral owner: Phase 7 manual pass if continuing interactively with the app window; otherwise Phase 10 RC validation.

## Performance Checks

- Warm-cache Home/Search/Library/Storage surfaces show cached or stale evidence within roughly 500 ms after view appear.
- No spinner-only state remains over 1 s when warm cache exists.
- Section switches and cached scrolling do not visibly stall over roughly 100 ms.
- Provider Lab keeps previous diagnostic results visible while a new comparison runs.

### Performance Results

Status: PARTIAL PASS with explicit deferrals.

Automated/static evidence:

- `gates/checks.sh` and `gates/backend-checks.sh` both pass with 145 tests / 0 failures.
- Phase 2/6 service tests cover warm-cache/fallback and Provider Lab diagnostic evidence behavior.
- Storybook static build completes successfully for the current design workbench.

Manual/perf measurements deferred:

- Native warm-cache time-to-stable measurements for Home/Search/Library/Storage.
- Native section switch and cached scrolling stall measurements.
- Provider Lab visible previous-results behavior under live UI timing.

Deferral owner: Phase 7 manual pass when an app automation/performance harness is available; otherwise Phase 10 RC validation.

## Deferral Rules

- Full `NavigationSplitView` shell parity may be deferred only with screenshot/accessibility evidence and a target follow-up phase.
- Full playlist/album native `Table` parity may be deferred only with evidence that current rows remain usable and accessible.

## Phase 7 Deferrals

- `NavigationSplitView` shell parity: deferred. Current custom shell passed build/test and has a toolbar/sidebar menu path; full native shell rewrite is too broad for the validation phase unless manual accessibility proves it blocks use.
- Native playlist/album `Table` parity: deferred. Current rows remain accessible enough for the current tests and Storybook previews; replacing them with `Table` is a broader Phase 7/10 decision after manual UX validation.
- Native full screenshot automation: deferred. Storybook screenshots are automated; native window capture requires an app/window automation harness not currently present in the repo.
- Full VoiceOver/Accessibility Inspector report: deferred to manual Phase 7 continuation or Phase 10 RC validation.