# Multi-Platform Repository Structure

PhonoDeck is a single product with native implementations per platform. Keep it in one repository while the product, contracts, design language, and release process are shared.

## Target Shape

```text
phonodeck/
  apps/
    apple/
      macos/
      ios/
      watchos/
      tvos/
    windows/
    web/
  contracts/
  docs/
  ui-lab/
  scripts/
  gates/
```

## Current Transition Rule

The current macOS app still builds from `Sources/PhonoDeck` and `Tests/PhonoDeckTests`. Do not move those files in a broad sweep until the Swift core is split under test. The first refactor step is additive structure and contracts; physical source moves come later in small, gated phases.

`PhonoDeckCore` now provides that first compile-backed boundary for source-neutral models, provider policy, playback plans, route decisions, and queue/session state. The macOS app still compiles the same source files directly while the migration proceeds; full app consumption of the core module is a later gated phase.

## Shared Truth

Share these across platforms:

- source capability and provider policy contracts;
- playback/session state contracts;
- fixture data and QA cases;
- design language through `ui-lab/` and `docs/design/phonodeck-ui-map.json`;
- security/privacy/release rules.

## Platform-Native Code

Keep these platform-specific:

- SwiftUI/AppKit/UIKit views and Apple media APIs;
- WinUI/.NET views, shell integration, Windows playback/device APIs;
- React web UI and browser-specific media/embed behavior;
- platform signing, store, sandbox, and packaging logic.

## Recommended Implementation Order

1. Extract `PhonoDeckCore` from current Swift models/services/playback session logic while keeping macOS green.
2. Add iOS/tvOS/watchOS Swift targets that consume the shared Swift core.
3. Add Windows `.NET` project that consumes shared JSON contracts and fixtures.
4. Add React web implementation against the same contracts and design source.

## Non-Goals

- Do not share UI code across all platforms.
- Do not use React as the Windows UI shell.
- Do not force Swift implementation details into Windows or web.
- Do not claim a source capability on one platform unless the shared contract and platform implementation support it.