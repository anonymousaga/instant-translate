# ADR-0003: Panel Layout and Minimum Size

| Field | Value |
|-------|-------|
| Status | **Accepted** |
| Date | 2026-09-27 |
| Binds | instant-translate |
| Decision makers | nlink-jp maintainers |
| Triggered by | Checking ADR-0002 at its largest text size: shrinking the panel broke its layout — at the default size too. PR #1 (@anonymousaga) had reported the same row as "cramped" |

## Context

The panel's minimum size was a fixed 320 × 320 pt. The row under the input —
source picker, "(language)" hint, arrow, target picker, hint, Translate — needs
more than that: each menu picker is as wide as its longest language name, so
at 320 pt the two pickers alone fill the row. What was left went to the hints,
which wrapped one character per line; the row grew tall, the Translate button
shrank to a sliver, and the Copy / Quit row was pushed out of the panel. The
row ignores the text size, so this was a v0.3.1 bug, not an ADR-0002 one.

The needed width is not a constant: it depends on the longest language name,
i.e. on the OS language and on which languages the Translation framework
offers. The needed height grows when the failure block appears.

## Decision

### Decision 1: The hints sit under their pickers

Each picker is followed by a blank caption-height line; its hint is overlaid on
that line. As an overlay the hint is offered the picker's width and adds no
width to the row; a name longer than that truncates in the middle, keeping
both parentheses (which mark it as a hint, not a selection). The line is there
even when there is no hint, so the row never changes height. A fixed gap of
about half a line separates the hints from the status row.

The pickers, the arrow and the button never compress, so the row's minimum
width is theirs alone, and it no longer changes as the detected language does.

### Decision 2: The panel's minimum is measured from the laid-out content

`PanelView` reports laid-out sizes (`onGeometryChange`) and the pure
`PanelMinimumSize.compute` derives the minimum:

- **height** = the content stack's height − how far each of the two text
  fields is stretched beyond its 80 pt minimum + the title bar inset;
- **width** = source picker + arrow + target picker + button + gaps + padding.

The content stack is measured before the frame that fills the panel, so when
the panel is too small it reports the height it needs rather than the height
it was given. Anything else that appears — the failure block — is included
automatically. `AppController.setPanelMinimum` applies it as `contentMinSize`,
on the next run-loop turn, capped to the screen, and grows the panel (keeping
its top edge under the menu bar item) if it is smaller.

### Decision 3: The hosting view stays out of window sizing

`NSHostingView` gets `sizingOptions = []` and sits inside a plain container
view instead of being the window's `contentView`.

## Consequences

- The panel can no longer be shrunk into a broken layout, with any OS language
  or text size. Its minimum width is set by the longest language names; on the
  maintainer's machine (Japanese UI) it measured 560–574 pt during development.
- A failure block that appears in a minimal panel grows the panel instead of
  being clipped.
- The row costs one caption line more height than the old one-line row.
- Every stretchy view in the panel must be subtracted in `compute`; a new one
  that isn't makes the minimum grow with the panel (see A5).

## Alternatives considered

**A1. A larger fixed minimum.** Simplest. Rejected: the needed width follows
the language names, which vary with the OS language and the framework's
language list, so any constant is wrong somewhere.

**A2. Let `NSHostingView` report the minimum (`sizingOptions: .minSize`, also
part of the default).** Tried. The option measures under a 0 × 0 proposal,
which text cannot answer: an unconstrained single-line text reports zero height
(the minimum came out 16–29 pt short and the bottom margin was eaten), and a
text held at its natural height wraps one character per line (the minimum
jumped to 646 pt). The multi-line failure block cannot be made to answer
honestly at all.

**A3. Keep the hints beside the pickers, reserving the longest hint's width.**
Stops the panel from growing as the hint changes, but reserves the longest
name twice more on top of the pickers: the minimum width reached 863 pt.

**A4. Hints beside the pickers when the row is wide enough, under them when
not.** Built and dropped by the maintainer: the controls shifted as the layout
switched (the Translate button moved vertically), which looked wrong. The
switch was decided by the longest possible hint so typing never flipped it,
and the minimum height was kept equal in both layouts; the shifting remained.

**A5. Measure the row's width minus a `Spacer`.** Rejected after it ran away:
wrapped in a measuring modifier, a `Spacer` is no longer a stack spacer and
stretches vertically too. The row absorbed spare height that `compute` did not
subtract, so growing the panel to its minimum raised the minimum again, up to
the height of the screen. The button is now pushed right by a frame instead,
and the pickers and button are measured directly.

**A6. `NSHostingView` as the window's `contentView` with `sizingOptions = []`.**
Crashed at launch: as `contentView` it still resizes the window in
`windowDidLayout` (`updateAnimatedWindowSize`), which fought the measured
minimum inside the layout pass until AppKit threw ("needs another update
constraints pass"). A plain container view removes the hosting view from
window sizing entirely.

## References

- Apple: `NSHostingView.sizingOptions`, `NSHostingSizingOptions.minSize`
  ("the size that fits a proposal of width: 0, height: 0"),
  `View.onGeometryChange(for:of:action:)`, `NSWindow.contentMinSize`
- ADR-0002 — the text-size check that exposed this
- PR #1 — the "cramped" report and the hints-under-the-pickers idea
