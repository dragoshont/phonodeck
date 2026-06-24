# Current Gap, Architecture, UX, and Security Audit

Date: 2026-06-24  
Status: current public repository audit  
Release posture: **NO-GO for public release**

## Executive Summary

PhonoDeck is now a public MIT-licensed repository with a clean single-commit public history, a policy-first architecture direction, passing deterministic test gates, and a credible native macOS foundation. It is not ready for public App Store release. The blockers are evidence and product-completion gaps: live provider smoke, manual accessibility, signing/notarization, provider revocation/cleanup, public privacy/legal copy, release notes, and canonical catalog providers for non-YouTube library surfaces.

The architecture is directionally strong: source adapters, provider readiness, playback routing, Keychain token handling, visible-player policy, and release preflight exist. The largest architectural risks are drift between JSON contracts and Swift implementation, incomplete shared-core extraction for future iOS/Windows/web, and provider-specific visible-player command logic still leaking into app shell code.

The UX is honest but not release-proven. Storybook and the UI map cover many states, but the packaged native app still needs manual VoiceOver, keyboard, contrast, motion, route picker, live provider, and warm-cache validation. Provider Lab, Albums/Artists, planned-source CTAs, and Now Playing inspector consolidation remain release-shaping product decisions.

Security posture is much better than before publication: local secrets are ignored, GitHub Secrets and Azure Key Vault contain the OAuth client values, packaged builds strip the client secret, and public snapshot scans passed. Remaining security work is release/operator work: final OAuth distribution strategy, live revocation tests, OSLog/privacy evidence, entitlement review, and privacy/legal publication.

## Severity Taxonomy

| Severity | Meaning | Release impact |
|---|---|---|
| Blocker | Must be fixed or explicitly accepted before public release or before the named phase can close. | Prevents GO. |
| Critical | High-confidence product, UX, or security truth gap that can create false release confidence. | Usually blocks release evidence until resolved or downgraded with proof. |
| High | Architectural or UX flaw likely to cause rework, platform drift, or accessibility issues. | Blocks expansion phases; may not block current prototype. |
| Medium | Important debt with bounded blast radius or clear mitigation. | Track and schedule. |
| Low | Hygiene, clarity, or future-proofing issue. | Fix opportunistically. |
| Informational | Intentional fixture/status note, not a defect. | No release block. |

## Evidence Base

- `README.md`
- `architrave.config.json`
- `project.yml`
- `contracts/*.json`
- `Sources/PhonoDeck/**`
- `Tests/PhonoDeckTests/**`
- `docs/architecture/overview.md`
- `docs/architecture/playback-session-contract.md`
- `docs/architecture/multiplatform-structure.md`
- `docs/design/phonodeck-ui-map.json`
- `docs/qa/rc-validation-report.md`
- `docs/qa/phase7-ux-accessibility-performance-checklist.md`
- `docs/qa/production-p0-screen-test-matrix.md`
- `docs/security-privacy.md`
- `docs/deployment/macos-release.md`
- `docs/developers/oauth-credentials.md`
- `ui-lab/src/components/PhonoDeck.jsx`
- `ui-lab/src/stories/**`

## Validation Command Table

| Command / check | Result | Notes |
|---|---|---|
| `git diff --check` | PASS | No whitespace errors after audit draft. |
| `jq empty contracts/*.json docs/design/phonodeck-ui-map.json architrave.config.json` | PASS | JSON contracts, design map, and config parse. |
| `make test` | PASS | 153 tests / 0 failures. |
| `make release-preflight` | PASS | Warns when local ignored OAuth secret exists and when signing/notary env is absent. |
| `make package-local` | PASS | Builds unsigned package and strips packaged OAuth secret. |
| Public snapshot scan | PASS | Clean single-commit public history; no old private OAuth setup details exposed. |
| Working-tree sensitive marker scan | PASS with intentional fixture | `Tests/PhonoDeckTests/SecurityPrivacyTests.swift` intentionally uses `client_secret=def` to prove URL redaction. |

## Overall Gap Matrix

| Area | Status | Severity | Summary |
|---|---|---:|---|
| Public repository hygiene | Strong | Low | MIT, clean public history, sanitized public docs, no obvious exposed secrets in public snapshot. |
| Release readiness | Blocked | Blocker | RC report is correctly NO-GO until operator/live/manual evidence is complete. |
| Architecture seams | Good but incomplete | High | Adapter/readiness/playback seams exist; contracts and shared core lag implementation. |
| Multiplatform readiness | Early | High | Repo has scaffolding and contracts, but no extracted Swift core, Windows app, or web app yet. |
| UX state honesty | Good | Medium | Many blocked/limited states are honest; live/manual proof is missing. |
| Native Apple conformance | Mixed | High | Shell uses custom layout instead of native split/sidebar/table/search primitives. |
| Security/privacy | Improved | Medium | Token storage and redaction are good; public OAuth/release strategy still needs operator closure. |
| Provider policy | Strong for YouTube | Medium | YouTube private endpoints are removed; Spotify/Plex/Own Files need deeper live implementation/validation. |
| Test strategy | Good for units/contracts-in-code | Medium | Missing schema-contract conformance tests and live/manual validation evidence. |
| OSS readiness | Partial | Medium | Public MIT repo exists; missing `SECURITY.md`, `CONTRIBUTING.md`, CI, issue templates, and dependency/license review. |

## Architecture Audit

### A1. JSON Contracts Lag The Implemented Playback Model

Severity: High

The public `contracts/playback-session.schema.json` is too coarse. It models route, state, and queue item fields, but omits details present in Swift and the accepted contract: `PlaybackRouteDecision`, system integration ownership, visible-player requirement, ended/current index, typed blocked/failure states, and route ownership. This weakens the contracts as shared truth for future iOS, Windows, and web implementations.

Evidence:

- `contracts/playback-session.schema.json`
- `docs/architecture/playback-session-contract.md`
- `Sources/PhonoDeck/Playback/PlaybackRouter.swift`
- `Sources/PhonoDeck/Playback/PlaybackSession.swift`

Required schema additions:

- route decision kind;
- system integration ownership;
- visible-player requirement;
- ended/current index state;
- blocked and failed variants with user-visible reason;
- queue item route ownership;
- provider/source capability evidence.

Recommended fix:

- Expand `playback-session.schema.json` to match the accepted Swift model.
- Add canonical fixtures in `contracts/fixtures/` for native, visible web player, blocked, failed, and queued sessions.
- Add tests that load JSON fixtures and assert Swift model mapping and policy behavior.

### A2. Multiplatform Structure Exists As Intent, Not Module Reality

Severity: High

The repo has `apps/` and `contracts/` scaffolding, but the actual Swift project is still one macOS app target over `Sources/PhonoDeck`. That is acceptable for the current public snapshot, but iOS should not begin until a small `PhonoDeckCore` target extracts portable source models, playback plans, provider policy, and fixtures.

Evidence:

- `project.yml`
- `docs/architecture/multiplatform-structure.md`
- `Sources/PhonoDeck/**`
- `apps/README.md`

Recommended fix:

- Create `PhonoDeckCore` Swift target for neutral models, source policy, playback plan/session types, and test fixtures.
- Keep SwiftUI/AppKit/WKWebView/AVFoundation/MediaPlayer in platform targets.
- Add iOS only after core extraction tests are green.
- Add Windows .NET against JSON contracts, not Swift implementation details.

### A3. Provider-Specific Visible Player Logic Still Leaks Into Shell

Severity: High

The architecture says playback ownership should route through source-neutral playback/session seams. The current shell still branches on YouTube-backed sources and drives `YouTubePlaybackBridge` directly. This will not scale cleanly to Spotify embed, web, Windows, or iOS.

Evidence:

- `Sources/PhonoDeck/App/PhonoDeckApp.swift`
- `Sources/PhonoDeck/Features/Shell/NowPlayingBar.swift`
- `Sources/PhonoDeck/Features/YouTubeMusic/YouTubePlaybackBridge.swift`
- `Sources/PhonoDeck/Playback/PlaybackRouter.swift`

Recommended fix:

- Introduce a generic visible-player facade in the playback/session layer.
- Route YouTube and future Spotify embeds through the same command capability surface.
- Keep native AVFoundation as the only system Now Playing/media-key owner.

### A4. Spotify Playback Claims Need Either A Bridge Or Lowered Capability

Severity: High

Spotify adapter logic can return embedded playback readiness, but the visible-player implementation is YouTube-specific. Until a Spotify visible-player bridge exists, Spotify should be framed as metadata/library plus future visible-player support, or routed through a generic embed surface.

Evidence:

- `Sources/PhonoDeck/Integrations/Adapters/SpotifyAdapter.swift`
- `Sources/PhonoDeck/Features/YouTubeMusic/YouTubePlaybackBridge.swift`
- `Sources/PhonoDeck/Features/Shell/RootView.swift`
- `docs/architecture/overview.md`

Recommended fix:

- Build generic visible-player route facade first, or lower Spotify in-app playback claims in descriptors/tests until the bridge exists.

### A5. Capability Truth Is Duplicated

Severity: Medium

Provider truth exists in `contracts/provider-policy.json`, Swift descriptors, source feature code, adapter readiness, and tests. There is no visible test proving the JSON policy and Swift capability model agree.

Evidence:

- `contracts/provider-policy.json`
- `Sources/PhonoDeck/Integrations/MediaSource.swift`
- `Sources/PhonoDeck/Integrations/Core/SourceFeature.swift`
- `Tests/PhonoDeckTests/SourceFoundationTests.swift`

Recommended fix:

- Treat `contracts/provider-policy.json` as executable product truth.
- Add contract-conformance tests that compare JSON policy to Swift descriptors/resolver behavior.

### A6. Legacy MediaSource Protocol Remains

Severity: Medium

Legacy `PlexSource`, `SpotifySource`, and `YouTubeMusicSource` still exist alongside the newer adapter model. They mostly throw unavailable/not-configured states, but the duplicate seam can mislead future contributors.

Evidence:

- `Sources/PhonoDeck/Integrations/PlexSource.swift`
- `Sources/PhonoDeck/Integrations/SpotifySource.swift`
- `Sources/PhonoDeck/Integrations/YouTubeMusicSource.swift`
- `Sources/PhonoDeck/Integrations/Core/MusicSourceAdapter.swift`

Recommended fix:

- Prove no remaining production call sites depend on legacy sources.
- Remove or quarantine legacy source types after tests are green.

## UX And Product Audit

### Per-Surface UX Evidence Matrix

| Surface | Current state | Risk | Required evidence before release |
|---|---|---:|---|
| First run / onboarding | Welcome and empty library states exist. | Medium | Native packaged screenshot, keyboard traversal, VoiceOver labels, planned-source CTA copy review. |
| Home / Library | Recently played, discovery, playlists, subscriptions, and limited states exist. | Medium | Warm-cache timing, signed-out state, empty-library state, source-readiness callouts. |
| Search | Song-first official YouTube Data API path exists. | High | Live Google/YouTube smoke, quota/auth/empty states, toolbar/searchable review. |
| Playlists | Official playlist read/write path exists in code/tests. | High | Live write-scope validation, cleanup evidence, quota/auth-expired behavior. |
| Albums | Limited/derived, not canonical. | High | Preserve limited labeling until canonical Plex/Own Files/Spotify metadata exists. |
| Artists | Limited/derived, not canonical. | High | Preserve limited labeling until canonical provider artist metadata exists. |
| Queue | Local queue exists and handles failed embed skip. | Medium | Keyboard/menu traversal, next/previous disabled states, VoiceOver ordering. |
| Now Playing | Visible YouTube player and bottom bar honesty exist. | High | Inspector consolidation, visible-player command facade, VoiceOver player/queue labels. |
| Storage / Downloads | Strong policy-safe cache/storage surface. | Medium | Manual cache clear receipt validation, source retention wording, no fake media downloads. |
| Devices | Route readiness surface avoids fake inventory. | Medium | Packaged-app route picker test, native route availability, external action blocked states. |
| Provider Lab | Diagnostic surface exists but shipping stance unclear. | Critical | Decide debug-gated vs user-facing diagnostics; update sidebar and docs accordingly. |
| Settings | Source account rows and playback/storage controls exist. | Medium | Form keyboard traversal, disconnect warnings, scope disclosure, planned-source wording. |

### U1. Public Release UX Is Still NO-GO

Severity: Blocker

The RC report correctly says release is NO-GO. The app has passing deterministic gates, but live provider, manual accessibility, signing/notarization, privacy/legal, and release notes are not done.

Evidence:

- `docs/qa/rc-validation-report.md`

Recommended fix:

- Do not present the app as release-ready.
- Complete operator live/manual checklist and update RC report before App Store distribution.

### U2. Storybook Coverage Is Strong, But Native App Evidence Is Incomplete

Severity: Blocker

Storybook screenshot coverage exists, but native packaged-app screenshots, VoiceOver, Full Keyboard Access, Increase Contrast, Reduce Motion, and warm-cache timings are still manual/deferred evidence.

Evidence:

- `docs/qa/phase7-ux-accessibility-performance-checklist.md`
- `docs/qa/rc-validation-report.md`
- `scripts/screenshot.sh`

Recommended fix:

- Run a packaged-app UX validation pass.
- Store evidence in `docs/qa/`.
- Mark each manual item PASS/FAIL/DEFERRED with date, OS, app build, and tester.

### U3. P0 Matrix Has Stale PASS Confidence

Severity: Critical

The P0 matrix reports 550 PASS / 0 FAIL, but some PASS rows still contain evidence phrasing that indicates missing or deferred functionality. This makes the matrix less trustworthy as release evidence.

Evidence:

- `docs/qa/production-p0-screen-test-matrix.md`
- `docs/qa/rc-validation-report.md`

Recommended fix:

- Reconcile matrix statuses into distinct states: implemented, Storybook-covered, unit-tested, manually verified, live-provider verified, deferred.
- Do not use `PASS` for rows whose evidence says the actual feature remains missing.

### U4. Provider Lab Shipping Stance Is Unresolved

Severity: Critical

The design map warns Provider Lab can be hidden from shipping navigation, but the native sidebar exposes it under System. This is either a real diagnostics product surface or a developer tool; it should not remain ambiguous.

Evidence:

- `docs/design/phonodeck-ui-map.json`
- `Sources/PhonoDeck/Features/Shell/SidebarView.swift`
- `Sources/PhonoDeck/Features/YouTubeMusic/YouTubeMusicNativeConceptView.swift`

Recommended fix:

- Decide shipping stance.
- If shipping: rewrite it as user-facing diagnostics with support language and clear privacy boundaries.
- If not shipping: debug-gate or move to advanced settings/developer menu.

### U5. Native Shell Should Move Toward Apple Structural Primitives

Severity: High

The app currently composes custom sidebar/content/now-playing layout with fixed shell structure. This works for a prototype, but it makes macOS accessibility/adaptation harder and iOS expansion harder.

Evidence:

- `Sources/PhonoDeck/Features/Shell/RootView.swift`
- `Sources/PhonoDeck/Features/Shell/SidebarView.swift`
- `docs/design/design-system-research.md`
- `docs/design/native-macos-guidelines.md`

Recommended fix:

- Move shell to `NavigationSplitView` with native sidebar `List` behavior.
- Use toolbar search via `.searchable` where possible.
- Use a trailing inspector pattern for Now Playing/Info/Queue.
- Keep bottom mini-player as `safeAreaInset(edge: .bottom)` where appropriate.

### U6. Search And Collection Surfaces Need Native Table/Search Patterns

Severity: High

Search and playlist filtering use custom content fields, and multi-column music lists are hand-rolled. Apple-platform parity wants toolbar search/search scopes and `Table` on macOS for sortable/resizable collection rows.

Evidence:

- `Sources/PhonoDeck/Features/YouTubeMusic/YouTubeMusicNativeConceptView.swift`
- `docs/design/phonodeck-ui-map.json`

Recommended fix:

- Use `.searchable` for primary search.
- Use `Table`/`TableColumn` on macOS for playlist/album/artist detail rows.
- Use compact `List` rows for iOS.

### U7. Albums And Artists Remain Limited/Derived

Severity: High

Albums and Artists are honest as limited/derived surfaces, but not canonical catalog surfaces. They should not be marketed as complete music-library parity until Plex, Own Files, MusicKit, Spotify, or another canonical metadata source backs them.

Evidence:

- `docs/design/phonodeck-ui-map.json`
- `Sources/PhonoDeck/Features/YouTubeMusic/YouTubeMusicNativeConceptView.swift`
- `contracts/provider-policy.json`

Recommended fix:

- Keep limited/derived labels for release.
- Prioritize Plex/Own Files metadata before promoting Albums/Artists as canonical.

### U8. Planned Source CTAs Need Better Copy

Severity: High

First-run and library surfaces can offer Spotify/Plex actions, but if they only produce planned-source messaging, labels should not imply immediate connection.

Evidence:

- `Sources/PhonoDeck/Features/YouTubeMusic/YouTubeMusicNativeConceptView.swift`
- `docs/design/phonodeck-ui-map.json`

Recommended fix:

- Use `Learn about Spotify` / `Plex setup coming soon` copy until connect flows exist.
- Keep real Connect actions only where a working OAuth/auth flow exists.

### U9. Now Playing Inspector Needs Consolidation

Severity: High

The UI map target is a unified right inspector with Now Playing / Up Next / Lyrics / About. The native implementation still has a fixed right panel and older composition.

Evidence:

- `docs/design/phonodeck-ui-map.json`
- `Sources/PhonoDeck/Features/YouTubeMusic/YouTubeMusicNativeConceptView.swift`
- `ui-lab/src/components/PhonoDeck.jsx`

Recommended fix:

- Make Now Playing inspector consolidation a dedicated UX implementation phase.
- Preserve YouTube visible-player policy.

## Security And Privacy Audit

### Threat Model

| Asset / boundary | Current control | Gap |
|---|---|---|
| Google OAuth client secret | Local ignored config, GitHub Secrets, Azure Key Vault; package strips secret. | Public distribution strategy not settled: operator-injected client secret vs no-secret installed-app flow vs future backend-mediated OAuth. |
| User access/refresh tokens | Stored in Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. | Live revocation and provider-side cleanup not proven. |
| Plex server tokens | Stored via Keychain-backed store and token-bearing URLs redacted. | Live Plex disconnect/deletion and token-bearing URL sharing need packaged-app proof. |
| Spotify tokens | Keychain store and official API boundaries. | Live Spotify smoke and disconnect evidence missing. |
| Local metadata/artwork cache | Explicit cache clearing and Google authorized local-data clearing. | Provider storage-window compliance needs live/manual evidence before release. |
| Logs and URLs | `RedactedURL` and OSLog privacy annotations. | Needs targeted OSLog stream review during live provider flows. |
| App sandbox/entitlements | Sandbox, network client/server, user-selected file access documented. | Entitlement minimization should be rechecked before App Store submission. |
| Public repo/history | Clean public snapshot, old private history not published. | Avoid pushing private-history backup branches or run artifacts. |

### Privacy Data Inventory

| Data type | Storage | Current status | Release gap |
|---|---|---|---|
| OAuth client ID/secret | Local ignored config; GitHub Secrets; Azure Key Vault | Present and intentionally not required for build/test. | Decide release injection strategy. |
| Provider access/refresh tokens | Keychain | Implemented for current providers. | Live revocation/cleanup evidence. |
| YouTube account/channel metadata | Memory/cache/UserDefaults as authorized local metadata | Local deletion helper exists. | Storage-window and revocation test evidence. |
| Search/discovery/history metadata | UserDefaults/local cache | Cache clearing exists. | User-facing data retention statement and live smoke. |
| Artwork cache | Disk cache | Measurement/clear evidence exists. | Manual cache clear validation. |
| Plex media URLs/tokens | Runtime only, redacted before logs | Tests cover redaction and non-shareable URLs. | Live Plex smoke. |
| Local files / security-scoped access | User-selected file access planned/partial | Own Files not release-complete. | Import/playback permission smoke. |

### S1. Public Repo Hygiene Is Good, But Keep History Discipline

Severity: Medium

The public repo was published as a clean single-commit snapshot and current scans passed. Old private history had personal OAuth setup details, so do not push old private branches to the public repo.

Evidence:

- GitHub public repo `dragoshont/phonodeck`
- Current public `main` is a clean history.
- Public snapshot scans passed.

Recommended fix:

- Keep old private backup branches local only.
- Do not push private-history backup branches.
- Continue scanning before publishing new docs or artifacts.

### S2. Local, GitHub, And Key Vault Secret Storage Is Now Sane

Severity: Low

Local dev secrets live in ignored `Config/Secrets.xcconfig`. GitHub Secrets and Azure Key Vault entries exist. Build/test/package do not need OAuth secrets. Preflight warns if local secrets exist, and package-local strips packaged secret values.

Evidence:

- `Config/BuildSettings.xcconfig`
- `Config/Secrets.xcconfig.example`
- `scripts/release-preflight.sh`
- `scripts/package-local.sh`
- `docs/developers/oauth-credentials.md`
- GitHub Secrets metadata verified by CLI.
- Azure Key Vault metadata verified by CLI.

Recommended fix:

- Keep secret values out of docs/issues/chat.
- Add CI tests only when a live OAuth smoke workflow exists.
- Keep Key Vault use runtime/backend-only, not desktop runtime fetch.

### S3. OAuth Public Distribution Strategy Is Still Unresolved

Severity: Medium

The app can use a local Desktop OAuth secret for development, but public distribution needs a deliberate strategy: operator-injected release secret, installed-app PKCE flow without client secret if Google accepts it, or a future backend-mediated flow. Current release package intentionally strips the secret.

Evidence:

- `docs/developers/oauth-credentials.md`
- `docs/security-privacy.md`
- `scripts/package-local.sh`
- `Sources/PhonoDeck/Integrations/Google/GoogleOAuthClient.swift`

Recommended fix:

- Write an ADR for public OAuth configuration before App Store release.
- Confirm what Google currently accepts for Desktop OAuth token exchange in release mode.
- Do not ship a secret accidentally; if an App Store build needs one, make it an explicit signed-release decision.

### S4. Revocation And Live Provider Cleanup Are Not Proven

Severity: Medium

Local disconnect behavior is implemented, but live provider revocation and cleanup remain operator-blocked in the RC report.

Evidence:

- `docs/qa/rc-validation-report.md`
- `docs/security-privacy.md`
- `Sources/PhonoDeck/Features/YouTubeMusic/YouTubeAccountViewModel.swift`
- `Sources/PhonoDeck/Support/LocalPrivacyDataStore.swift`

Recommended fix:

- Add test-account live validation scripts or checklists for Google, Spotify, and Plex disconnect/revocation.
- Record cleanup evidence before release GO.

### S5. Release Signing And Notarization Are Not Done

Severity: Medium

Unsigned local packaging works. Public distribution still requires Developer ID/App Store signing, notarization/stapling where applicable, upload/distribution approval, and final go/no-go.

Evidence:

- `docs/deployment/macos-release.md`
- `docs/qa/rc-validation-report.md`
- `scripts/package-local.sh`

Recommended fix:

- Complete signing/notarization outside the repo.
- Record only metadata and pass/fail evidence, never certificate secrets or team credentials.

### S6. Intentional Test Fixture Contains `client_secret=def`

Severity: Informational

The current focused security scan reports a test URL with `client_secret=def`, which is an intentional redaction fixture, not a real secret.

Evidence:

- `Tests/PhonoDeckTests/SecurityPrivacyTests.swift`

Recommended fix:

- Keep it as a fixture, or split the string if future scans require zero literal hits.

### Security Checks To Add

- PKCE and loopback callback review: verify state/code-verifier entropy, callback timeout, localhost binding, and browser-open failure behavior.
- OSLog audit: run `log stream` during Google/Plex/Spotify flows and confirm no titles/tokens/URLs are logged publicly.
- Keychain integration smoke: keep query-construction tests and add live Keychain smoke on macOS if feasible.
- Entitlement review: prove network server entitlement is only for OAuth loopback and file read/write is only for user-selected media.
- Provider deletion evidence: use test accounts to validate disconnect/revoke behavior without leaving remote test artifacts.

## Release And Open-Source Readiness

### Open-Source Readiness Checklist

| Item | Status | Gap |
|---|---|---|
| License | PASS | MIT `LICENSE` exists. |
| Public history | PASS | Public `main` is a clean snapshot; old private history remains local only. |
| README build/run | Partial | Build instructions exist; add first-run OAuth and no-secret CI notes inline or link clearly. |
| Security policy | Missing | Add `SECURITY.md` with vulnerability reporting and no-secret guidance. |
| Contributing guide | Missing | Add `CONTRIBUTING.md` with build/test, design-source, policy boundaries, and secret rules. |
| Code of conduct | Missing | Optional but recommended for public contribution. |
| Issue templates | Missing | Add bug/security/policy/feature templates. |
| CI status | Missing | Public repo has setup workflow only; add public build/test CI when ready. |
| Dependency/license scan | Missing | Run npm/Xcode/Swift dependency review and add notices if needed. |
| Generated/artifact hygiene | Partial | `.gitignore` covers build, DerivedData, `.architrave`, secrets; continue scanning before commits. |
| Wiki | Blocked by GitHub behavior | Wiki flag showed enabled, but `.wiki.git` was not cloneable from CLI. Keep docs in repo until GitHub wiki works. |

Current public repository status:

- MIT license present.
- Public repo is live.
- Public snapshot history is clean and minimal.
- README explains open-source and paid official builds.
- Multi-platform scaffolding exists.
- OAuth docs are public-safe.

Current release status:

- Deterministic gates are green.
- Unsigned local package works.
- Public release is **NO-GO**.

Release blockers:

1. Google OAuth public distribution strategy.
2. Developer ID/App Store signing and notarization/stapling path.
3. Live Google/YouTube smoke.
4. Live Spotify smoke.
5. Live Plex smoke.
6. Own Files smoke.
7. Provider revocation/cleanup evidence.
8. Packaged native accessibility pass.
9. Public privacy/legal copy and release notes.
10. Final operator go/no-go.

## Prioritized Next Phases

All phases below are **not-started**. They are recommended next work, not completed evidence.

### Phase 1: Audit Evidence Closure

Status: not-started

Goal: make the evidence honest and usable.

Tasks:

- Reconcile `docs/qa/production-p0-screen-test-matrix.md` into evidence states.
- Run packaged-app native screenshot/manual accessibility pass.
- Update `docs/qa/rc-validation-report.md` with current OAuth rotation and public repo status.

Gate:

- `make test`
- `make qa-status`
- `make package-local`
- updated RC report
- judge PASS

Out of scope:

- new provider features;
- broad shell redesign;
- public release GO.

### Phase 2: Shared Contract Hardening

Status: not-started

Goal: make `contracts/` executable shared truth.

Tasks:

- Expand `playback-session.schema.json` to match Swift playback/session model.
- Add fixture JSON for native route, visible web route, blocked route, failed route, and queue/session cases.
- Add tests that validate fixtures and compare Swift policy behavior.

Gate:

- schema validation
- Swift tests
- Windows/web-ready fixture docs

Out of scope:

- physical platform app moves;
- new UI surfaces;
- live provider validation.

### Phase 3: PhonoDeckCore Extraction

Status: not-started

Goal: prepare iOS without duplicating product logic.

Tasks:

- Add `PhonoDeckCore` target.
- Move neutral models, source policy, playback plans/session state, and fixtures into core.
- Keep SwiftUI/AppKit/AVFoundation/MediaPlayer in macOS target.

Gate:

- macOS build/test green
- new core tests green
- no UI regressions

Out of scope:

- Windows/web implementation;
- App Store release;
- broad UI redesign.

### Phase 4: Native Apple Shell Alignment

Status: not-started

Goal: improve macOS conformance and unblock iOS adaptation.

Tasks:

- Move shell toward `NavigationSplitView`.
- Use native toolbar search/search scopes.
- Use `Table` for macOS multi-column collection detail.
- Consolidate Now Playing inspector.

Gate:

- Storybook updated first
- SwiftUI implementation second
- accessibility/manual pass

Out of scope:

- provider capability expansion;
- Windows/web UI;
- release signing.

### Phase 5: Provider Completion And Live Smoke

Status: not-started

Goal: convert roadmap surfaces into real release surfaces.

Tasks:

- Plex auth/server/library/native playback live smoke.
- Spotify OAuth/metadata/player stance live smoke.
- Own Files import/playback smoke.
- Google playlist write/revocation cleanup smoke.

Gate:

- live test-account evidence
- cleanup evidence
- RC report moves closer to GO

Out of scope:

- hidden playback or private APIs;
- non-test-account destructive provider changes;
- public distribution before final go/no-go.

## Option Tradeoff For Next Work

| Option | Pros | Cons | Verdict |
|---|---|---|---|
| Evidence closure first | Prevents false confidence and gives every later phase a trustworthy target. | Does not add features. | Recommended. |
| Contract hardening first | Helps iOS/Windows/web alignment. | Can still preserve stale release evidence if matrix/manual gaps remain. | Second. |
| Native shell alignment first | Improves Apple quality and iOS path. | High UI blast radius before evidence is reconciled. | Third. |
| Live provider smoke first | Directly attacks release blockers. | Risky without matrix and cleanup checklist reconciliation. | Do after evidence closure. |

## Recommended Immediate Next Step

Do **Phase 1: Audit Evidence Closure** next. It is the highest-leverage work because it prevents false confidence, makes release readiness legible, and gives future implementation phases a trustworthy target.
