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

The shortcuts are attached in `PanelView` with `.keyboardShortcut`, the same
mechanism the panel already uses for ⌘↩ (Translate). Whether it fires while the
app is *inactive* (the usual state of this `.nonactivatingPanel`) has not been
checked for either shortcut — open question 1.

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
  lines each. Whether that is acceptable, or the minimums should scale, is an
  open question below; it is decided by looking at it, not in advance.
- The default for users who never press the keys is unchanged (system body
  size). PR #1's slider would have moved everyone from 13 pt to 14 pt.
- One new UserDefaults key; `SettingsKey.registerDefaults()` does not register
  it (absence is the meaning).

## Open questions (measured in the prototype, then recorded here)

1. **Key arrival per layout.** Which of ⌘+, ⌘⇧=, ⌘= (US) and ⌘+, ⌘; (JIS)
   trigger the enlarge action with `.keyboardShortcut("+")`; whether an extra
   ⌘= binding is needed. Check each with the app active *and* inactive (panel
   opened by hotkey from another app). Record the observed matrix.
2. **Minimum heights at 28 pt.** Look at the panel at its minimum size with
   the largest text. Decide then whether the 80 pt minimums scale.
3. **IME composition.** Pressing ⌘+ while a kana-kanji conversion is open must
   not commit, cancel or corrupt the marked text.
4. **Output selection and caret.** Changing the size must keep the input's
   caret and selection and the output's scroll position sensible.

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
hand-matching characters per layout. Kept in reserve only if open question 1
shows `.keyboardShortcut` cannot be made to fire on a common layout.

## References

- Apple HIG, *Keyboards* — standard shortcuts table
- App Store Connect Help, *Larger Text evaluation criteria*
- SwiftUI `KeyboardShortcut.Localization`; AppKit
  `NSMenuItem.allowsAutomaticKeyEquivalentLocalization`
- PR #1 and the maintainer's reply — the suggestion this ADR credits
