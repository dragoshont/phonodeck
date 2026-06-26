# iPhone Markdown Edit and Preview UX

Status: Recommendation
Last reviewed: 2026-06-26

## Decision

Use a live editor as the default iPhone Markdown experience. The document should read like preview most of the time, while the currently focused block becomes editable Markdown source.

Do not make users constantly switch to a separate preview just to trust their formatting. Full Preview remains available for proofreading, export, and sharing, but it is not the primary writing surface.

## Recommended Model

### Default: Live Preview With Focused Source Editing

- Surrounding blocks render as final content.
- The active paragraph, heading, list item, quote, or code block shows editable Markdown source with the caret.
- Leaving the block renders it again.
- Parse issues stay local to the affected block and show a small inline warning.

This gives the confidence of preview without the cost of mode switching.

### Secondary Modes

Provide visible mode controls, not gesture-only controls:

- `Edit` or `Live`: the default writing surface.
- `Preview`: full rendered document for review/export.
- Optional advanced `Source`: full raw Markdown for power users.

If we use three modes, keep `Source` in an overflow or document setting until there is evidence users need it often. The default iPhone control should stay simple.

## Controls

### Top Bar

Use the top bar for document-level actions:

- Back
- Title
- Preview/Edit mode control
- Share
- More

The Preview/Edit control must be visible and stateful. A segmented control is acceptable if it fits Dynamic Type; otherwise use a toolbar button that changes label between `Preview` and `Edit`.

### Keyboard Accessory Bar

When the keyboard is visible, show a compact Markdown accessory bar:

- Heading
- Bold
- Italic
- Link
- Checklist
- Quote
- Code
- Attachment or More

This is the primary command surface on iPhone. It is more discoverable and accessible than custom gestures.

### Preview Behavior

Preview opens at the current scroll location or focused block. Returning to edit restores the same insertion point.

Preview must not jump to the top of the document.

## Gestures

Gestures are shortcuts only. Every gesture must have a visible button or menu equivalent.

Recommended gesture:

- Horizontal swipe between Edit and Preview only when the keyboard is dismissed or on the rendered preview surface.

Avoid:

- Edge swipes for preview, because they conflict with navigation back.
- Gestures inside the active text view, because they fight cursor placement, selection handles, scroll, and text editing gestures.
- Three-finger gestures, because iOS reserves them for undo, redo, copy, and paste.
- Gesture-only mode switching.

## Accessibility Requirements

The interaction is acceptable only if all of these are true:

- Preview/Edit mode can be changed by visible controls.
- Controls have at least 44 x 44 pt hit targets.
- VoiceOver announces the current mode and the selected state of the mode control.
- VoiceOver exposes a clear `Edit block` action for rendered blocks.
- Switch Control and Voice Control can operate all mode and formatting actions.
- Full Keyboard Access can reach the mode control and accessory actions.
- Dynamic Type does not truncate the primary mode control beyond recognition.
- Reduce Motion replaces swipe/page transitions with a simple fade or no animation.
- Inline warnings include text and icon, not color alone.

## Hardware Keyboard Shortcuts

Recommended shortcuts:

| Shortcut | Action |
| --- | --- |
| Cmd-B | Bold |
| Cmd-I | Italic |
| Cmd-K | Insert or edit link |
| Cmd-Option-1...6 | Heading levels |
| Cmd-F | Find in document |
| Cmd-Z | Undo |
| Shift-Cmd-Z | Redo |
| Esc | Leave transient panels or dismiss mode overlays |
| Tab | Indent list item |
| Shift-Tab | Outdent list item |

Do not override standard iOS text editing shortcuts.

## UX States

| State | Content | Primary action |
| --- | --- | --- |
| Empty | Title field, blank body, starter insertion row | Start typing |
| Editing block | Active block shows raw Markdown with caret; surrounding blocks render | Type and format |
| Live preview idle | All non-focused blocks render | Tap block to edit |
| Full preview | Rendered document at current location | Edit |
| Parse issue | Affected block remains raw with inline warning | Fix Markdown |
| Export/share | Rendered preview plus export choices | Share/Export |

## Product Rules

- iPhone does not use permanent side-by-side editor and preview.
- Full Preview is a review/export destination, not the core writing loop.
- The active block is the only place where raw Markdown must be exposed by default.
- Visible controls outrank gestures.
- A gesture may accelerate switching, but it must never be required.

## References

Product patterns reviewed:

- Bear: inline Markdown/live styling.
- iA Writer: Auto-Markdown and focused writing.
- Obsidian: Source, Live Preview, Reading modes.
- Drafts: editor-first workflow and keyboard action bar.
- Notion: Markdown shortcuts becoming rendered blocks.
- Apple Notes: simple visible formatting controls.

Platform grounding:

- Apple HIG Gestures: custom gestures should be discoverable, simple, and never the only path.
- Apple HIG Accessibility: visible alternatives, clear labels, Dynamic Type, VoiceOver, Switch Control, Voice Control.
- Apple HIG Text Views/Text Fields: preserve normal text editing behaviors.
- Apple HIG Segmented Controls and Toolbars: use visible mode controls for closely related states when space permits.
