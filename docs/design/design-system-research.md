# PhonoDeck Design System Research

Authoritative, source-cited design rules for building PhonoDeck as a native, modern,
Apple-quality macOS music app. This is the knowledge base the design agents
(`.github/agents/ux-architect.agent.md` and `.github/agents/ui-visual.agent.md`) and the
human team reference. Rules are pulled from official Apple Human Interface Guidelines
(HIG), Apple developer documentation, and Apple Design Resources — not opinion.

- Primary source: Apple Human Interface Guidelines — https://developer.apple.com/design/human-interface-guidelines
- Artifacts: Apple Design Resources — https://developer.apple.com/design/resources
- Fonts: https://developer.apple.com/fonts | SF Symbols app: https://developer.apple.com/sf-symbols
- Quality bar reference: Apple Design Awards — https://developer.apple.com/design/awards
- Research captured: 2026-06-20. Re-verify against the live HIG before major design decisions;
  Apple revises pages (see each page's "Change log"). The current system language is **Liquid Glass** (WWDC25).

> How to read this doc: **MUST** = deterministic HIG rule or measured spec. **SHOULD** = strong HIG
> recommendation. **PhonoDeck** = how the rule applies to this app. Every section cites its HIG page.

---

## 0. Design principles (the lens for every decision)

From *Designing for macOS* and *Layout*
(https://developer.apple.com/design/human-interface-guidelines/designing-for-macos,
https://developer.apple.com/design/human-interface-guidelines/layout):

- **Native first.** Use system controls, the menu bar, standard window chrome, SF Pro, SF Symbols, and
  system materials. Don't reinvent what the system provides; custom chrome that imperfectly mimics the
  system "can make your app feel broken."
- **Library-first density.** Macs have large displays and a 1–3 ft viewing distance. Present more content
  in fewer nested levels at a comfortable density — don't strain the user, don't pad like a marketing site.
- **Respect the user's environment.** Resizable/hideable/movable windows, full-screen support, keyboard
  shortcuts, customization, light/dark/increased-contrast, and the user's chosen system accent color.
- **Controls float above content (Liquid Glass).** Establish a clear hierarchy between the functional
  layer (sidebar, toolbar, now-playing bar) and the content layer (songs, artwork).
- **Source-aware honesty.** PhonoDeck spans YouTube/YouTube Music/Spotify/Plex with different capabilities.
  Never use generic UI to hide a source-specific limitation; never imply control the app doesn't have.

---

## 1. Window & app shell

Source: *Windows* (https://developer.apple.com/design/human-interface-guidelines/windows),
*Designing for macOS*.

- **MUST** use system window appearances for main / key / inactive states. Inactive windows lose vibrancy
  and appear subdued; the system handles this only if you use standard components.
- **MUST NOT** build custom window frames or controls.
- **MUST NOT** put critical info or actions in a window's bottom bar — users routinely drag the bottom edge
  below the screen. Prefer an inspector on the trailing side of a split view for secondary info.
- **SHOULD** use the literal word "window" in user-facing copy.
- **PhonoDeck:** The bottom Now Playing bar is an intentional, persistent media-app exception (see §7), but
  it must stay compact and never be the *only* place a command lives. Min window size must keep the
  3-pane layout (sidebar / list / now-playing) legible; collapse the now-playing panel first when narrow.

---

## 2. Sidebar (primary navigation)

Source: *Sidebars* (https://developer.apple.com/design/human-interface-guidelines/sidebars).

- **MUST** keep to **two levels of hierarchy max**. Deeper structure → use a split view with a content
  list column between the sidebar and the detail view.
- **MUST** let people hide/show the sidebar (View menu `Show Sidebar` / `Hide Sidebar`, toolbar toggle).
  Don't hide it by default.
- **MUST NOT** place critical info/actions at the bottom of the sidebar (window bottom may be off-screen).
- **SHOULD** use SF Symbols for row icons. Icons default to the **app accent color**; the user's chosen
  system accent overrides it — *except* a deliberately fixed-color icon used to convey meaning (e.g. Mail's
  yellow VIP). Use fixed colors sparingly and only for meaning.
- **SHOULD** group with section headers + disclosure groups to manage vertical space; keep labels succinct.
- macOS sidebar row height is **small / medium / large**, chosen by the user in System Settings > General.
  Design rows to look right at all three. The sidebar can auto-collapse as the window shrinks.
- Apple's own **Music app** (cited in the HIG visionOS sidebar example) uses a sidebar for library
  navigation with a grid of playlists in the secondary pane — the canonical reference IA for PhonoDeck.
- **PhonoDeck:** Sidebar is the single source of truth for navigation. Suggested IA, two levels:
  - **PhonoDeck:** Library, Search
  - **Library:** Playlists, Albums, Artists, Queue, Downloads
  - **System:** Devices, Settings (keep developer-only surfaces like Provider Lab out of the default shipping sidebar)
  Source badges (YouTube/Spotify/Plex) belong on rows/items as a small cue, not as a full-width theme.

---

## 3. Toolbar

Source: *Toolbars* (https://developer.apple.com/design/human-interface-guidelines/toolbars).

- Three zones with fixed meaning:
  - **Leading:** back, sidebar toggle, view title, document menu. *Not customizable.*
  - **Center:** common controls; collapse into the **system-managed overflow** as the window narrows.
  - **Trailing:** inspector toggles, **search field**, the **More (overflow) menu**, and **one** primary action.
- **MUST** make every toolbar item also available as a **menu bar command** (the toolbar is customizable/hideable, so it can't be the only home for a command).
- **MUST** give the primary action (e.g. `Done`) the `.prominent` style on the trailing side; only one primary action.
- **SHOULD** prefer borderless SF Symbols (no circle outlines); the system provides hover/selection states.
- **SHOULD** keep to ~3 groups max; separate text-labeled buttons with fixed space so they don't read as one control.
- Window title **< 15 characters**; **never** title a window with the app name.
- **SHOULD NOT** apply custom toolbar backgrounds/tints (they fight system materials). Use a scroll-edge effect to separate bar from content.

---

## 4. Menu bar

Source: *The menu bar* (https://developer.apple.com/design/human-interface-guidelines/the-menu-bar).

- **MUST** support the standard menu set and order: **App, File, Edit, Format, View, [app-specific], Window, Help.**
- **MUST** always show the same items; **disable** (don't hide) unavailable commands so people can learn capabilities.
- **MUST** support standard shortcuts (⌘C/⌘V/⌘X/⌘S/⌘Z…) and not override them.
- **SHOULD** use one-word, title-case menu titles. The View menu owns `Show/Hide Toolbar`, `Show/Hide Sidebar`, `Enter/Exit Full Screen`; titles reflect current state.
- **PhonoDeck:** Provide a custom **Navigate** menu (Library ⌘1, Playlists ⌘2, Albums ⌘3, Artists ⌘4, Queue ⌘5, Search ⌘F, Settings ⌘,) and a **Playback** menu (Play/Pause Space, Next ⌘→, Previous ⌘←). Disable items that don't apply to the active source instead of hiding them.

---

## 5. Layout & spacing

Source: *Layout* (https://developer.apple.com/design/human-interface-guidelines/layout), *Accessibility*.

- **SHOULD** place the most important items top + leading (reading order); respect right-to-left.
- **SHOULD** group related items with negative space / separators / background shapes; keep content vs controls visually distinct.
- **SHOULD** extend content to window edges; use a **background extension effect** beneath the sidebar/inspector instead of a hard seam.
- **MUST** design the full-size layout first; switch to a compact layout only when the full one no longer fits, and hide tertiary columns (inspectors / now-playing panel) first.
- **MUST** respect safe areas and standard margins (templates in Apple Design Resources).
- **Hit targets (from *Accessibility*):** macOS controls **28×28 pt recommended, 20×20 pt minimum**. Spacing: ~**12 pt** padding around bezeled elements, ~**24 pt** around non-bezeled tappable elements.
- **PhonoDeck DesignTokens** already encode spacing (compact 8 / standard 12 / comfortable 20) and an artwork radius — keep new components on those tokens; keep repeated-item corner radius ≤ 8 px.

---

## 6. Typography

Source: *Typography* (https://developer.apple.com/design/human-interface-guidelines/typography).

- **MUST** use **SF Pro** (system font on macOS) via `Font.Design` APIs — never embed system fonts. New York (serif) is available via `Font.Design.serif`.
- macOS default text size **13 pt**, minimum **10 pt**. **macOS has no Dynamic Type** — but still honor larger-text and increased-contrast intent where possible.
- **MUST** avoid Ultralight/Thin/Light weights for UI text; prefer **Regular / Medium / Semibold / Bold**.
- **SHOULD** minimize the number of typefaces; convey hierarchy with weight/size/color via the built-in text styles.
- **macOS built-in text styles** (style: weight, size/leading pt → use these tokens, don't hardcode arbitrary sizes):

  | Style | Weight | Size / Leading (pt) | Emphasized |
  |---|---|---|---|
  | Large Title | Regular | 26 / 32 | Bold |
  | Title 1 | Regular | 22 / 26 | Bold |
  | Title 2 | Regular | 17 / 22 | Bold |
  | Title 3 | Regular | 15 / 20 | Semibold |
  | Headline | Bold | 13 / 16 | Heavy |
  | Body | Regular | 13 / 16 | Semibold |
  | Callout | Regular | 12 / 15 | Semibold |
  | Subheadline | Regular | 11 / 14 | Semibold |
  | Footnote | Regular | 10 / 13 | Semibold |
  | Caption 1 | Regular | 10 / 13 | Medium |
  | Caption 2 | Medium | 10 / 13 | Semibold |

- **PhonoDeck:** Song title = Body/Headline; artist/secondary = Subheadline/Footnote in `secondary`. Section
  headers = Title 2/Title 3. Use SwiftUI semantic styles (`.headline`, `.body`, `.caption`) so the system
  supplies the right size/weight, rather than fixed point sizes.

---

## 7. Playing audio & the Now Playing experience (critical for PhonoDeck)

Source: *Playing audio* (https://developer.apple.com/design/human-interface-guidelines/playing-audio),
*Configuring your app for media playback* (AVFoundation), MediaPlayer / `MPNowPlayingInfoCenter`.

- **MUST** let the **system volume** govern final output; the app only sets relative levels. **Permit audio
  rerouting** (AirPlay / output device) — `MPVolumeView` / `AVRoutePickerView`.
- Use the **Playback** audio category for music (essential audio, can continue in background, ignores silent switch).
- **MUST** respond to remote/hardware transport controls (Control Center, headphones, lock screen, media keys)
  **only** when actively playing or in a clear audio context; **never repurpose** an audio control's meaning;
  if the app doesn't support a control, **don't respond** to it. Pause immediately when headphones disconnect.
- **MUST** publish current-item metadata + artwork to the system via `MPNowPlayingInfoCenter` and register
  supported commands with `MPRemoteCommandCenter`.
- **PhonoDeck honesty rule:** The official visible YouTube embed cannot own an `AVAudioSession`/system Now
  Playing the way native Plex/local playback can. The Now Playing bar **must disable controls the active
  source can't truthfully perform** and must not advertise media-key ownership while a YouTube source is
  active. Native sources (Plex/local) get full `MPNowPlayingInfoCenter` + `MPRemoteCommandCenter` integration.
- **Now Playing bar anatomy (persistent, compact, bottom):** artwork (≤46–56 pt), title (1–2 lines) + artist
  + small source cue, transport (prev / play-pause / next), progress + elapsed/remaining, route control,
  queue button. Only show the bar when there is a real current item (no placeholder "ready" state).

---

## 8. Lists & tables — songs, playlists, queue

Source: *Lists and tables* (https://developer.apple.com/design/human-interface-guidelines/lists-and-tables),
*Collections*.

- macOS: prefer the **bordered list style with alternating row backgrounds** for long tables — easier scanning
  across columns. Use `alternatingContentBackgroundColors`.
- **SHOULD** let people **click a column heading to sort**; clicking the sorted column again reverses it.
  Let people **resize columns**. Column headings are title-case nouns.
- Use an **outline view** (disclosure triangles) for genuinely hierarchical data; a flat table for songs.
- Row anatomy: leading artwork/thumbnail + succinct primary label + secondary label. Keep text succinct;
  use **middle truncation** for long titles to preserve both ends.
- Selection feedback: **persistent highlight** for navigation selection; brief highlight + checkmark for toggles.
- Allow reordering even when add/remove isn't supported (people value reordering a queue/playlist).
- For large image-forward grids (albums/artists/playlist covers), prefer a **collection** (grid), not a table.
- **PhonoDeck playlist/queue patterns** (synthesized from the rules above + Apple Music conventions, which
  Apple treats as the reference for music IA):
  - **Songs/Playlist detail:** a list/table with `#`, artwork+Title, Artist, Album, Time columns; double-click
    or Return plays; the now-playing row is persistently highlighted; right-click context menu (Play, Add to
    Queue, Add to Playlist, Go to Album/Artist, Share, Copy Link, Open). Sortable headers; resizable columns.
  - **Queue ("Up Next"):** ordered list, current item pinned/marked, drag-to-reorder, swipe/secondary action
    to remove, a clear "Clear" affordance, and an honest empty state ("There's nothing in the queue yet").
  - **Albums/Artists:** adaptive grid of square artwork tiles (cover + title + subtitle), opening a detail list.

---

## 9. Color

Source: *Color* (https://developer.apple.com/design/human-interface-guidelines/color), *Dark Mode*.

- **MUST NOT** hard-code system color values — use `Color`/`NSColor` semantic APIs (values shift per release).
- **MUST** use semantic dynamic colors for their intended purpose and not redefine them (e.g. don't use
  `separator` as a text color). Provide light **and** dark variants (+ increased-contrast) for any custom color.
- **MUST NOT** rely on color alone to convey state/info/interactivity — pair with shape/icon/text.
- **macOS app accent color** tints buttons, selection highlight, and sidebar icons; the user's System Settings
  accent **overrides** the app accent unless a sidebar icon uses an intentional fixed color.
- Key macOS semantic colors to use: `labelColor` / `secondaryLabelColor` / `tertiaryLabelColor` /
  `quaternaryLabelColor`, `separatorColor`, `gridColor`, `selectedContentBackgroundColor`,
  `alternatingContentBackgroundColors`, `controlAccentColor`, `controlBackgroundColor`, `windowBackgroundColor`,
  `keyboardFocusIndicatorColor`.
- **PhonoDeck:** Service brand colors (YouTube red, Spotify green, Plex orange/gold) are **small source cues
  only** — never a full-page theme. Lead with system neutrals + the user's accent.

---

## 10. Materials & Liquid Glass

Source: *Materials* (https://developer.apple.com/design/human-interface-guidelines/materials),
*Adopting Liquid Glass*.

- **Liquid Glass = the functional layer** for controls & navigation (toolbar, sidebar, tab/now-playing bar)
  floating above content. **MUST NOT** use Liquid Glass in the **content layer** (exception: transient controls
  like sliders/toggles while active). Use sparingly on custom controls.
- Variants: **regular** (blurs/adjusts luminosity for legibility — use for text-heavy sidebars/popovers/alerts)
  and **clear** (highly translucent — for components over media/artwork; add a ~35% dark dimming layer if the
  background is bright).
- **Standard materials** create separation in the **content layer**: macOS `NSVisualEffectView.Material`,
  SwiftUI `Material` (`.ultraThin/.thin/.regular/.thick`). Thicker = more opaque/contrast; thinner = more
  background context. Put **vibrant** system colors on materials for legibility (not `systemGray` over a blur).
- **PhonoDeck:** Let standard system components pick up Liquid Glass automatically. Keep the artwork/song
  content layer on standard materials; reserve any glass tint for one primary action / status, not many controls.

---

## 11. SF Symbols & iconography

Source: *SF Symbols* (https://developer.apple.com/design/human-interface-guidelines/sf-symbols), *Icons*.

- 4 rendering modes: **monochrome, hierarchical** (one color, per-layer opacity = depth), **palette**, **multicolor**;
  plus gradients (SF Symbols 7) and **variable color** for changing values (e.g. `speaker.wave.3` volume).
- **9 weights** (Ultralight→Black) that match SF font weights; **3 scales** (small / medium-default / large)
  relative to cap height — so symbols align optically with adjacent text.
- **Variants:** outline (default; toolbars/lists alongside text), **fill** (emphasis/selection), **slash**
  (unavailable/disabled state), **enclosed** circle/square (legibility at small sizes).
- **MUST** use system-provided colors so symbols adapt to Dark Mode / vibrancy / accessibility automatically.
- **MUST** provide accessibility labels for icon-only buttons and custom symbols (VoiceOver).
- **MUST NOT** use SF Symbols in app icons/logos; can't customize Apple-product symbols.
- Animations (appear, bounce, pulse, variable-color, replace, breathe, rotate, draw on/off) — use **judiciously**
  and only with clear purpose; honor Reduce Motion.
- **PhonoDeck:** Use `play.fill` / `pause.fill` / `forward.fill` / `backward.fill`, `speaker.wave.*` (variable
  color for volume), `music.note.list` (playlists/queue), `airplayaudio` (route). Use the `slash` variant to
  show a genuinely unsupported control rather than a dead/greyed mystery button.

---

## 12. Accessibility (deterministic requirements)

Source: *Accessibility* (https://developer.apple.com/design/human-interface-guidelines/accessibility), *VoiceOver*, *Typography*.

- **Hit targets:** macOS **28×28 pt** recommended, **20×20 pt** minimum. Padding ~12 pt (bezeled) / ~24 pt (non-bezeled).
- **Contrast (WCAG AA, used by Accessibility Inspector):** text ≤17 pt → **4.5:1**; ≥18 pt → **3:1**; bold → **3:1**.
  Verify in both light and dark; provide a higher-contrast scheme when **Increase Contrast** is on.
- **MUST** convey information by more than color (shape/glyph/text).
- **MUST** support **Full Keyboard Access** and not override system shortcuts; everything reachable by keyboard.
- **MUST** label every control / icon-only button for **VoiceOver**.
- **MUST** honor **Reduce Motion**: cut auto/repetitive animation (zoom/scale/peripheral), replace slide
  transitions with fades, avoid z-axis depth animation, tighten springs.
- **MUST** let people control playback; avoid autoplay without controls. Avoid time-boxed auto-dismissing UI;
  prefer explicit dismissal.
- Support larger text where feasible (≥200% intent). Use system colors for built-in accessible variants.

---

## 13. Search

Source: *Searching* (https://developer.apple.com/design/human-interface-guidelines/searching), *Search fields*.

- **SHOULD** give search a primary position (toolbar search field and/or a dedicated Search area). Offer one
  clear place to search app content; local search can also act as a **filter on the current view** (as iOS
  Music filters songs/albums).
- **MUST** make the current **scope** obvious (descriptive placeholder, scope bar, or title).
- **SHOULD** offer **suggestions**: recent searches before typing, predictive suggestions while typing; allow
  clearing history (privacy).
- **PhonoDeck:** Toolbar search field + a Search section. Show recent searches and quick-suggestion chips before
  typing; clearly label the active source/scope (e.g. "YouTube Music — Songs"). Provide "Load More" pagination
  and honest empty/error states (quota, signed-out, no results).

---

## 14. First-run, onboarding & empty states

Source: *Onboarding* (https://developer.apple.com/design/human-interface-guidelines/onboarding), *Launching*, *Loading*.

- **Ideally the app is understandable by using it.** If onboarding is needed, make it **fast, fun, optional**,
  and **after** launch (not part of the launch sequence).
- **SHOULD** prefer context-specific tips (TipKit) over one long flow; keep content about *your app*, not the system.
- **MUST** provide reasonable defaults and **postpone nonessential setup** so people can start immediately.
  Make any tutorial skippable and not shown again on later launches (findable later in Help/Settings).
- Integrate a permission request into onboarding only when the app can't function without it (explain the
  benefit); otherwise request at first use. Don't show EULAs in onboarding.
- **Empty states** should be quiet, explain what will appear, and offer one clear primary action — not fake
  content or zero-count dashboards.
- **PhonoDeck:** The lean welcome sheet (mission + Continue, optional) and the Apple-Music-style empty Library
  (large glyph, short message, the three connect actions) are correct. Don't fire token-gated API work or show
  "active" source badges while signed out. Hide empty buckets from the first-run surface; reveal richer
  navigation once there's content/an account.

---

## 15. Apple artifacts to use (the "Apple-made" toolkit)

Source: Apple Design Resources (https://developer.apple.com/design/resources).

- **Apple Design Resources — macOS:** UI kits/templates for **Figma, Sketch, Photoshop**; production templates;
  layout guides + safe-area templates.
- **SF Symbols app:** browse the full symbol set, check weights/scales/variants, annotate & export custom symbols,
  preview animations. Download from https://developer.apple.com/sf-symbols.
- **Fonts:** SF Pro + New York — https://developer.apple.com/fonts.
- **WWDC sessions (current design language):** *Meet Liquid Glass* (WWDC25 219), *Get to know the new design
  system* (356), *Build an AppKit app with the new design* (310).
- **Quality bar:** study **Apple Design Award** winners (https://developer.apple.com/design/awards) for what
  "award-caliber" means — depth, craft, accessibility, and platform fit.

---

## 16. PhonoDeck screen-by-screen quick reference

| Screen | Pattern source | Key rules |
|---|---|---|
| App shell | Windows, Sidebars, Toolbars | 3-pane; sidebar ≤2 levels; collapse now-playing first; toolbar 3 zones; every toolbar item also a menu command |
| Library home | Lists/Collections, Layout, Onboarding | Artwork shelves (Recently Played, Made for You, Playlists, Activity, Subscriptions); quiet empty state with connect actions |
| Playlist detail | Lists & tables | Sortable/resizable columns; double-click/Return to play; context menu; now-playing row highlighted |
| Queue / Up Next | Lists & tables | Ordered, current pinned, drag-reorder, remove, Clear, honest empty state |
| Albums / Artists | Collections | Adaptive square-artwork grid → detail list |
| Now Playing (bar + panel) | Playing audio, Materials | Persistent compact bar; honest controls per source; `MPNowPlayingInfoCenter` for native sources; route control |
| Search | Searching, Search fields | Toolbar field + Search area; visible scope; recent/suggestions; pagination; honest empty/error |
| Settings | The menu bar (Settings ⌘,) | Accounts, sources, playback policy, cache, privacy; source capability detail lives here |
| First run | Onboarding, Launching | Fast/optional welcome; defaults; no signed-out token calls; no fake content |

---

## 17. Review checklist (use before shipping any screen)

- [ ] Native components + system materials; no custom window chrome; Liquid Glass only in the control layer.
- [ ] Sidebar ≤ 2 levels; hide/show works; no critical actions at sidebar/window bottom.
- [ ] Every toolbar item has a menu bar command; one prominent primary action; window title < 15 chars, not app name.
- [ ] Text uses semantic styles (no Thin/Light for UI); 13 pt default / 10 pt min; ≤2 typefaces.
- [ ] Colors are semantic system colors; light + dark + increased-contrast; service color is a small cue only.
- [ ] SF Symbols (system colors); icon-only buttons have VoiceOver labels; `slash` for unsupported, not dead buttons.
- [ ] Hit targets ≥ 28×28 pt (20×20 min); contrast ≥ 4.5:1 (3:1 for ≥18 pt/bold); keyboard-navigable; Reduce Motion honored.
- [ ] Now Playing controls are honest about what the active source can do; native sources publish `MPNowPlayingInfoCenter`.
- [ ] Lists: sortable/resizable columns where useful; alternating rows; persistent selection; reorder where it helps.
- [ ] Empty/loading/error states are quiet, explanatory, and offer one clear action; no fake content; no signed-out token calls.
- [ ] Search scope is visible; recent/suggestions offered; pagination + honest empty/error states.
