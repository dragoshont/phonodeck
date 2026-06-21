# Feature evaluation rubric (the Evaluator)

The criteria the **Adversarial Judge** applies to grade a PhonoDeck *proposal* (pre‑implementation) or *implementation* (post‑implementation) against its specs and the established design language. It is the canonical rubric for the judge gates inside the **Feature Builder** harness.

Grounded in modern eval practice:
- **Anthropic** — *evaluator–optimizer* loop with clear criteria + stopping conditions; SMART success criteria; LLM‑graded rubrics where the judge **reasons first, then emits a verdict**, and grades in a **separate context from the generator**.
- **OpenAI** — an eval is a **dataset + graders**; treat it like **BDD** (specify behavior before building); combine **code graders** (deterministic) with **model graders** (LLM‑as‑judge).
- **IBM** — combine **rule‑based + semantic (LLM‑as‑judge)** evaluation; assess **each step and the whole path**, plus **policy‑adherence, prompt‑injection and bias** dimensions, not just final text.

## Two grading layers (use both)
1. **Deterministic gates (code‑graded — rule‑based):** `scripts/feature-check.sh` (xcodegen generate + `make build` + `make test` + `phonodeck-ui-map.json` valid) and the `.github/hooks` checks. These are objective ground truth and **override optimistic claims**. They must be green.
2. **Semantic gate (LLM‑as‑judge):** this rubric, applied adversarially by the Adversarial Judge.

## Before grading: derive acceptance criteria (BDD)
Restate the request + the source‑of‑truth (Storybook/ui‑map for UI; `docs/architecture/overview.md` + ADRs + `docs/research/platform-analysis.md` for backend) as a **numbered, testable acceptance‑criteria checklist**. Grade against the checklist, not vibes.

## Rubric dimensions
Score each **Pass / Concern / Fail** with a severity and cite evidence (a spec line or doc rule).

1. **Spec & acceptance‑criteria conformance** — every criterion met; no scope drift; honest about anything not done.
2. **Design‑language conformance**
   - *Frontend:* reproduces the existing Storybook component + `phonodeck-ui-map.json` glossary entry (anatomy, `DesignTokens`, SF Symbols, subtle source cues — no saturated fills, no reinvented component); ui‑map kept in sync.
   - *Backend:* uses `MusicSourceAdapter`/`SourceRegistry`, neutral `MusicTrack…` models, honest `SourceCapabilityResolver` tiers, and `PlaybackRouter`/`PlaybackPlan` (only `nativeAV` owns `MPNowPlayingInfoCenter`/`MPRemoteCommandCenter`); no parallel abstractions or per‑source conditionals.
3. **Adversarial robustness & edge cases** — empty / loading / partial / error states (quota, signed‑out, no‑results, offline, revoked token); concurrency (`@MainActor`/`Sendable`); resilience to prompt‑injection in tool/web/service output; never claims a capability the source/tier can’t truthfully perform.
4. **Policy & security (ADR‑0002 + OWASP)** — no private Apple APIs, scraped/undocumented endpoints, hidden/background playback, stream extraction, or unauthorized downloads; secrets only in `Config/Secrets.xcconfig`, never in code/logs; input validated at boundaries.
5. **Accessibility & HIG** — VoiceOver labels/order, full keyboard reachability, no color‑only meaning, Reduce Motion, hit targets ≥ 28 pt; cite `docs/design/design-system-research.md`.
6. **Tests** — fixture + mock‑`URLSession` pattern; cover the new logic **plus ≥ 1 adversarial/edge case** and the capability/tier honesty; deterministic and green.
7. **Verification & ground truth** — `scripts/feature-check.sh` green; for UI, a screenshot matches the Storybook reference; sibling‑instance consistency sweep done.

## Severity
**Blocker** (ship‑stopper / policy / spec miss) · **Major** (wrong but recoverable) · **Minor** (quality) · **Nit** (polish).

## Verdict rules
- **PASS** — all acceptance criteria met, **zero Blockers**, deterministic gates green.
- **REVISE** — fixable issues (≥ 1 Blocker/Major) with concrete required fixes.
- **FAIL** — fundamentally off‑spec or off‑pattern (e.g., reinvented an existing component, dishonest capability, policy violation).

## Bias mitigation (judge discipline)
- Judge in a **separate context** from the implementer; never grade your own reasoning.
- **Reason first, then emit the verdict.** Cite evidence for every finding.
- Don’t reward verbosity or confident tone; deterministic‑gate results outrank claims.
- Prefer specific, empirical statements over generic praise.

## Stopping condition (human‑in‑the‑loop)
The harness caps each judge gate at **3 revise loops**. On a 3rd consecutive non‑PASS, stop and escalate to the user with the findings rather than looping.

## Required judge output format
1. **Acceptance criteria** — checklist: `criterion → met? → evidence`.
2. **Dimension scores** — table: `dimension → Pass/Concern/Fail → severity → evidence (spec/doc ref) → required fix`.
3. **Blockers** (must‑fix) and **Concerns** (should‑fix).
4. **Specs not covered.**
5. **VERDICT: PASS | REVISE | FAIL** + a one‑line rationale.
