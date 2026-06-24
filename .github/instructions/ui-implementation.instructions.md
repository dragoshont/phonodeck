---
description: "Use when implementing or changing any PhonoDeck macOS UI (SwiftUI views, screens, settings, components, layout, visuals, SF Symbols). Enforces designing from the EXISTING Storybook + ui-map before writing SwiftUI, so the app matches the established design instead of reinventing it."
applyTo: ["Sources/PhonoDeck/Features/**", "Sources/PhonoDeck/Views/**", "Sources/PhonoDeck/Design/**", "ui-lab/**", "docs/design/**"]
---
# PhonoDeck UI — design-source-of-truth first

The macOS app is native SwiftUI. `ui-lab/` (Storybook) + `docs/design/phonodeck-ui-map.json` are the **canonical design**; they are design-only previews and are never shipped into the app target.

## Hard rule
Before adding or changing any UI, **find and reproduce the existing design. Never invent a new design when one already exists.** A design agent's spec is advisory — the Storybook component + the ui-map `glossary` are the source of truth.

## Required order
1. **Locate the existing design** for the screen/component:
   - Storybook: the matching story in `ui-lab/src/` (run `cd ui-lab && npm run storybook` → http://localhost:6007). The real components live in `ui-lab/src/components/PhonoDeck.jsx` with styles in `ui-lab/src/phonodeck.css` and SF-Symbol stand-ins in `ui-lab/src/icons.jsx`.
   - Map: the screen/component entry + `glossary` in `docs/design/phonodeck-ui-map.json`.
2. **If it exists → reproduce it** in SwiftUI by its glossary name: same anatomy, spacing, `DesignTokens`, SF Symbols, and treatment. Use UX Architect / UI Visual only to REVIEW or extend it — not to greenfield.
3. **If it does NOT exist → design it first**: UX Architect (flow/state) + UI Visual (look), mock or update it in Storybook, confirm with the user, then implement.
4. **Match Apple design**: cite `docs/design/design-system-research.md`; reuse system controls/materials; source brand tints are small cues only (e.g. ~16% tinted tile + brand-colored SF Symbol) — no saturated fills, no full-page brand themes, no color-only meaning.
5. **Keep `docs/design/phonodeck-ui-map.json` in sync FIRST**, then Storybook, then SwiftUI. Refer to components by their real `glossary` names.
6. **Verify**: `make generate` (after adding Swift files) → `make build` → `make test`; launch and screenshot to confirm it matches the Storybook reference; then sweep the app for sibling instances of the same pattern and keep them consistent.

## Anti-pattern (this caused real rework)
Building SwiftUI from a design agent's "ideal" spec without first reading the existing Storybook component → a reinvented, off-brand screen (e.g. saturated tiles + a colored capability grid instead of the established `.srow`: a subtle tinted icon tile + name + one-line detail + soft status). Always start from the existing component.
