# PhonoDeck UI Lab (Storybook)

A **design-validation workbench** for PhonoDeck's UI. You browse every component **by its real
name**, switch screens instantly, toggle Light/Dark, and run the accessibility addon — so we
validate UI/UX **before** implementing it natively.

> ⚠️ This is **not** the app. The real PhonoDeck macOS app is **native SwiftUI** in
> `Sources/PhonoDeck`. These stories are lightweight React mocks of the same visual language,
> kept in sync with `docs/design/phonodeck-ui-map.json` and grounded in
> `docs/design/design-system-research.md` (cited Apple HIG rules). Validate here, then build in SwiftUI.

## Run

```bash
cd ui-lab
npm install
npm run storybook   # http://localhost:6007
```

Build a static site (shareable) with `npm run build-storybook` → `storybook-static/`.

## How it maps to the app

- Story names use the **real Swift component names** (`SidebarView`, `NowPlayingBar`,
  `SongResultRow`, `PlaylistArtworkCard`, `SubscriptionAvatarCard`, …) so we share vocabulary.
- `Screens/*` = full window compositions (Library, First run, Playlist, Queue, Search, Settings).
- `Shell/*` and `Components/*` = isolated parts you can tweak via Controls.
- Source of truth for names/flows/sources: `docs/design/phonodeck-ui-map.json`.

## Workflow

1. Propose/adjust a component or screen here and eyeball it (Light + Dark, a11y addon).
2. Get sign-off in Storybook.
3. Implement natively in SwiftUI to match.
4. Keep `phonodeck-ui-map.json` updated when components/flows change.
