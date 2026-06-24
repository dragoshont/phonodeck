# PhonoDeck Repair Intake - 2026-06-20

This file is the live intake ledger for user-reported repair issues. Capture first, investigate lightly, classify later, then turn the final grouped backlog into GitHub issues.

## Intake Rules

- Preserve the user's report before interpreting it.
- Ask focused clarification questions when the behavior, trigger, or expected result is unclear.
- Do a fast recon only: relevant files, logs, obvious state/cache/auth/player clues, and likely area.
- Do not deep-fix during intake unless the user explicitly pauses intake and asks to repair one issue now.
- Do not clear Google login/Keychain unless the user explicitly requests it.
- Prefer logs from subsystem `ro.hont.phonodeck` when validating runtime behavior.

## Issue Index

| ID | Status | Short Title | Area | Severity | Source Report | Recon Summary | Proposed Group |
| --- | --- | --- | --- | --- | --- | --- | --- |
| R-001 | Recon done | Fresh login/browser first experience after clearing auth/reset | Login | P0 | "lets go with the login... clear auth data"; "this should not be the screen if a user opens the app for the first time. clear all cache and reset all" | Full runtime reset completed. True first launch removes stale Now Playing, but still defaults to Listen Now/loading songs, marks YouTube Music active, hides Connect behind Account, and fires token-gated official calls plus experimental fallback while signed out. | Login and onboarding |

## Open Questions

- R-001: During observation, note whether the app clearly presents signed-out state, whether Connect Google opens the browser, whether the browser copy/context is understandable, and whether the app logs enough to diagnose each step.

## Captured Issues

### R-001 - Fresh Login/Browser First Experience After Clearing Auth

**Status:** Recon done
**Area:** Login
**Severity:** P0
**Reported By User:**

> lets go with the login. lets clear auth data first. we will be looking at the first exp with the application and the login browser

> ok.1 this should not be thescreen if a user opens the app for the first time. clear all cache and reset all

**Clarifying Questions:**

- Should clearing auth also suppress the restored YouTube Now Playing item, or should Now Playing remain visible as local history?
- Should signed-out YouTube/YouTube Music source badges show `Active`, or should they show a signed-out/limited state until Google connects?
- Where should the primary Connect Google call-to-action live on first launch: main content hero, right Now Playing panel, toolbar/account menu, Settings, or multiple places?

**User Answers:**

- User wants auth data cleared before observing the login/browser flow.
- User unavailable for follow-up during recon; working assumptions for later grouping: signed-out first-run should prioritize a clear main-surface Connect Google CTA, old YouTube Now Playing should be hidden or explicitly marked local history, and account-backed YouTube source capabilities should not display as fully active while signed out.
- User then clarified the observed signed-out screen is not acceptable as a first-time user screen and requested a full reset of all cache/state.

**Observed / Expected:**

- Observed: Keychain token deletion succeeded and `security find-generic-password` verified the token item is absent. Fresh PhonoDeck launch logs `No stored Google tokens found; signed out`.
- Observed: Despite signed-out auth, the UI restores the last YouTube Now Playing item (`Eminem - Fuel...`), shows `YouTube` and `YouTube Music` source cards as `Active`, and presents prior/local library content instead of a clear login-first state.
- Observed: Startup logs immediately emit token-gated calls while signed out: `Official search requested without fresh Google tokens` and `Library load requested without fresh Google tokens`.
- Observed: The visible header only says `Account`; it does not communicate `Not connected`. Code shows `Connect` exists inside `accountMenu`, but it is hidden behind a compact borderless menu and was not reliably triggerable during coordinate-based observation. The AX tree exposes an `Account` element, but not a clearly named accessible `Connect Google` button at this level.
- Observed after full reset: Removed Keychain token, defaults domain, preferences plist, `~/Library/Caches/PhonoDeck`, `~/Library/Caches/ro.hont.phonodeck`, `~/Library/WebKit/ro.hont.phonodeck`, `~/Library/HTTPStorages/ro.hont.phonodeck*`, saved app state, container paths if present, and PhonoDeck CrashReporter plist. Verification showed token/defaults/runtime paths absent before relaunch.
- Observed after full reset: Fresh launch logs `No valid saved section; defaulting to listenNow` and `No stored Google tokens found; signed out`. Stale old song is gone, and bottom bar says `Select a song`.
- Observed after full reset: First visible screen still does not look like login/onboarding. It shows Listen Now, `Loading Songs`, `Search Songs`, `YouTube Music`, `Account`, and `Video hidden`; there is no primary `Connect Google` CTA on the main surface.
- Observed after full reset: App immediately creates a new artwork cache and performs automatic discovery using official search attempts, logs missing-token auth errors, then uses experimental fallback and downloads artwork while signed out.
- Expected: App starts signed out, preserves non-auth app state only where it helps, presents a clear connect path, does not fire token-required official API work before auth, opens the OAuth browser flow from an obvious CTA, and logs each login step without secrets.

**Fast Recon:**

- Files/logs checked: `GoogleAccountStore.swift`, `YouTubeAccountViewModel.swift`, `YouTubeMusicNativeConceptView.swift`, Keychain CLI, unified logs for subsystem `ro.hont.phonodeck`, screenshots `/tmp/phonodeck-login-first-experience.png`, `/tmp/phonodeck-account-menu-auth-cleared.png`, `/tmp/phonodeck-account-menu-fullscreen.png`.
- Findings: Google auth tokens are stored via `GoogleAccountStore` in Keychain service `ro.hont.phonodeck.google`, account `youtube-oauth-tokens`. The item was deleted successfully and verified absent.
- Findings: Signed-out launch is correctly detected in logs, but the UI does not behave like a clean first-run login experience. It looks like an already-active music library with stale Now Playing state and active source badges.
- Findings: Search/discovery/library startup paths should gate official token-required requests when signed out, or degrade to a clearly labeled unauthenticated/public/experimental state without logging auth errors as routine startup noise.
- Findings: Account connect is too hidden and may be weakly accessible. The Settings row has an explicit `Connect Google` button in code, but it is not part of the first visible surface.
- Findings: Full reset command was executed with absolute macOS tool paths because the current shell had a stripped PATH. Runtime reset intentionally excluded repo files, build outputs, Xcode DerivedData, and Copilot memory. Relaunch recreated `~/Library/Caches/PhonoDeck/Artwork` because the app immediately fetched discovery artwork.
- Findings: Full-reset screenshot saved at `/tmp/phonodeck-full-reset-first-run.png`.
- Note: One coordinate-click attempt accidentally brought the system Apple Music app forward; that observation is excluded from product findings.
- Likely owner area: Google OAuth and YouTube account UI.

**Proposed GitHub Issue Shape:**

- Title: Repair signed-out first-run Google login experience
- Labels: `p0`, `login`, `oauth`, `first-run`, `youtube`
- Acceptance criteria: Signed-out launch shows obvious `Connect Google` CTA; token-required official API calls are not fired before auth; source capability badges distinguish signed-out from active; stale Now Playing does not make the app look already connected; Connect opens the browser OAuth flow and logs `Google login started` plus subsequent state transitions; account controls are accessible by name.

## GitHub Issue Draft Queue

- Empty until intake is complete and issues are grouped.

## Issue Template

### R-000 - Short Title

**Status:** New / Clarifying / Recon Done / Grouped / Drafted
**Area:** Login / Logout / Now Playing / Playlist / Search / Cache / YouTube Player / Navigation / UI / Tests / Other
**Severity:** P0 / P1 / P2 / Unknown
**Reported By User:**

> Exact user wording or compact quote.

**Clarifying Questions:**

- Question 1

**User Answers:**

- Pending

**Observed / Expected:**

- Observed:
- Expected:

**Fast Recon:**

- Files/logs checked:
- Findings:
- Likely owner area:

**Proposed GitHub Issue Shape:**

- Title:
- Labels:
- Acceptance criteria:
