# ADR-0002: Panel Text Size

| Field | Value |
|-------|-------|
| Status | **Accepted** |
| Date | 2026-09-27 |
| Binds | instant-translate |
| Decision makers | nlink-jp maintainers |
| Triggered by | PR #1 (@anonymousaga) proposed an adjustable font size as a Settings slider; the idea was accepted, the form was not |

## Context

The input and translation text are drawn at the system body size (13 pt on
macOS 26/27) and cannot be changed. PR #1 added a Settings slider (10–28 pt)
for it, bundled with five unrelated changes. The need is reasonable; the
form is not how macOS apps do this.

What the platform documents:

- **⌘+ and ⌘− are standard shortcuts.** The HIG's standard table lists
  Shift-Command-Equal sign (⌘+) as "Increase the size of the selection" and
  Command-Hyphen (⌘−) as "Decrease the size of the selection", and says not to
  repurpose standard shortcuts. ⌘0 is not in that table, but Safari, Preview
  and browsers use it for "Actual Size", and it is the reset people reach for.
- **Scale the content, not the chrome.** Apple's Larger Text evaluation
  criteria: "prioritize scaling the main content areas before repeated,
  predictable navigational elements", and enlarge body text "to at least 200%"
  of the default.
- **The system text-size setting barely reaches third-party apps on macOS.**
  Only secondary sources say so explicitly (Finder, Mail and sidebars honour
  it); Apple's criteria allow an in-app control and recommend following the
  system setting where one applies. Not verified on this machine — changing
  the system setting to test it is left to the maintainer.
- **Shortcuts are remapped for other keyboard layouts automatically**
  (`KeyboardShortcut.Localization`, `NSMenuItem.allowsAutomaticKeyEquivalentLocalization`,
  on by default), but only when the key is *unreachable* on the current layout.
  On a JIS keyboard `+` is reachable (Shift-;), so no remap is expected; how
  ⌘+ actually arrives there, and whether ⌘= without Shift works on a US
  keyboard, is not documented and must be measured.

The app has no menu bar (`LSUIElement`), so nothing in the app can show that a
shortcut exists.

## Decision

### Decision 1: ⌘+ / ⌘− / ⌘0 in the panel, no Settings control

While the panel is key, ⌘+ enlarges, ⌘− shrinks and ⌘0 resets the text size.
Settings gets **no slider**. It gets one line of help text naming the three
shortcuts (the only in-app place a user can learn them), and the README
documents them.

The shortcuts are attached in `PanelView` with `.keyboardShortcut` on invisible
buttons, the same mechanism the panel already uses for ⌘↩ (Translate). A
shortcut matches its modifiers **exactly**, so enlarge is bound three times:

| Binding | What produces it |
|---------|------------------|
| `"+"` + ⌘⇧ | the main-row `+`, shifted on both US (`=` key) and JIS (`;` key) layouts; also Shift + keypad `+` |
| `"+"` + ⌘ | the keypad `+`, which arrives unshifted |
| `"="` + ⌘ | ⌘= on a US layout — the unshifted alias browsers accept |

⌘− (main row or keypad) and ⌘0 need one binding each.

### Decision 2: What scales

Only the content: the **input text**, its **placeholder**, and the
**translation text**. The header, pickers and their "(…)" hints, the status
row, the failure block and the buttons keep their sizes. This follows Apple's
"content before chrome" guidance and answers the balance concern directly:
controls that stay put are what keeps the layout stable as text grows.

### Decision 3: A fixed ladder anchored on the system body size

Sizes step through a ladder that widens as it grows:

```
10 · 11 · 12 · 13 · 14 · 16 · 18 · 20 · 24 · 28   (pt)
```

28 pt is 215% of the 13 pt body — past Apple's 200% bar. One-point steps were
rejected because reaching 28 from 13 would take fifteen presses.

The stored value is **"no preference"** until the user presses ⌘+ or ⌘−, and
⌘0 returns to it. With no preference the fields use the system body size, so
if the system text-size setting ever does reach this app, the default follows
it. From any current size, ⌘+ / ⌘− move to the next ladder entry strictly
larger / smaller, so a body size that is not on the ladder still steps
cleanly. At either end the key does nothing.

The stepping rule is a **pure function** (current size, direction → next size),
unit-tested like `LanguagePolicy` and `AutoTranslatePolicy`.

### Decision 4: Persist the choice

The chosen size is stored in UserDefaults (absent = no preference) and
restored at launch. Readability needs don't change per session, and ⌘0 is
always one press away. Unlike the source pin and target override, which are
per-text and volatile by design, this is a per-person preference.

## Consequences

- A standard, discoverable-by-habit way to change text size; no new Settings
  control, one new help line in Settings.
- Controls never grow, so the panel can't overflow horizontally at large sizes.
- At 28 pt the input and output keep their 80 pt minimum heights — about two
  lines each. Whether that is acceptable, or the minimums should scale, is
  decided by looking at it, not in advance — see result 2 below.
- The default for users who never press the keys is unchanged (system body
  size). PR #1's slider would have moved everyone from 13 pt to 14 pt.
- One new UserDefaults key; `SettingsKey.registerDefaults()` does not register
  it (absence is the meaning).

## Results of the open questions (prototype, 2026-09-27)

Measured by the maintainer by hand on a JIS-arranged keyboard with the
Kawasemi input method, in both its Japanese and Roman modes, with a temporary
build that logged every ⌘ key event (`keyCode`, characters, modifiers, whether
the panel handled it). An earlier automated probe was discarded: it posted US
virtual key codes, which on this layout are different keys (key code 24 is `^`
on JIS, not `=`), so it never sent `+` or `=` at all.

1. **Key arrival.**

   | Key pressed | Arrives as | Handled |
   |-------------|------------|---------|
   | ⌘ + main-row `+` (Shift-`;`, key code 41) | `"+"`, ⌘⇧ | yes |
   | ⌘ + keypad `+` (key code 69) | `"+"`, ⌘ | only after adding the `"+"` + ⌘ binding |
   | ⌘ + Shift + keypad `+` | `"+"`, ⌘⇧ | yes |
   | ⌘ + main-row `-` (key code 27) / keypad `-` (78) | `"-"`, ⌘ | yes |
   | ⌘ + keypad `0` (key code 82) | `"0"`, ⌘ | yes |

   Identical in the Japanese and Roman modes. An unhandled ⌘ key ends in the
   text view and beeps — that is how the missing keypad binding showed itself.
   **Not measured:** a US layout (⌘⇧= and ⌘=), and the app *inactive* — in
   every trial the panel's hotkey open left the app active.
2. **Minimum size.** Shrinking the panel to its minimum broke the layout —
   but at the default 13 pt as well: the fixed-width language pickers fill the
   row, the "(…)" hint wraps one character per line, the Translate button is
   squeezed to a sliver and the Copy / Quit row is pushed out. The picker row
   ignores the text size, so this is a pre-existing bug of the panel's minimum
   size (320 × 320 pt), fixed separately. The 80 pt field minimums are
   re-checked at 28 pt after that fix.
3. **IME composition.** ⌘+ during a kana-kanji conversion leaves the marked
   text untouched; the new size is applied once the conversion is committed
   (the size change waits for `hasMarkedText()` to clear, like the text
   rewrite in `SourceTextView.updateNSView`).
4. **Caret.** The caret stayed in place across size changes. The output's
   scroll position with a long translation was not specifically checked.

## Alternatives considered

**A1. Settings slider (PR #1's form).** Rejected: not how macOS apps change
text size, and it moves the default for everyone (13 → 14 pt). Decided by the
maintainer.

**A2. Follow the system text-size setting only.** Rejected as the sole
mechanism: on macOS it reaches few apps, and there would be nothing to press.
Kept as the default: "no preference" means the system body size.

**A3. Scale the whole panel (controls too).** Rejected by Apple's own
guidance; enlarged pickers and buttons crowd the single control row first.

**A4. One-point steps.** Rejected: fifteen presses from default to 200%.

**A5. Menu commands (a `CommandGroup` in a View menu).** The app has no
visible menu bar, so the menu adds nothing a user can see, and key-equivalent
routing through the main menu while the non-activating panel is key and the
app is inactive is unverified. `.keyboardShortcut` is already in use in this
panel (⌘↩).

**A6. A local `keyDown` monitor matching characters.** Works regardless of
view state, but bypasses the system's keyboard-layout remapping and means
hand-matching characters per layout. Not needed: result 1 shows
`.keyboardShortcut` fires on a JIS layout once each arriving form is bound.

## References

- Apple HIG, *Keyboards* — standard shortcuts table
- App Store Connect Help, *Larger Text evaluation criteria*
- SwiftUI `KeyboardShortcut.Localization`; AppKit
  `NSMenuItem.allowsAutomaticKeyEquivalentLocalization`
- PR #1 and the maintainer's reply — the suggestion this ADR credits
