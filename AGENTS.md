# AGENTS.md — instant-translate

## What this is

A lightweight macOS menu-bar app (SwiftUI, `MenuBarExtra`, `LSUIElement`) that
translates text via the OS **Translation framework** (`TranslationSession`,
on-device). The lightweight sibling of `quick-translate` (local LLM) — same UX,
different backend. GUI-only, macOS 26+, Apple silicon. Signed + notarized SwiftPM
`.app` (no `.xcodeproj`).

## Build & test

```sh
make run        # swift run (debug)
make build      # swift build -c release
make build-app  # signed .app → dist/
make package    # build-app + notarize + staple + zip
make verify-release  # gate: .notarized marker + stapler validate (run before upload)
make test       # swift test
```

Needs the macOS 26 SDK (recent Xcode / CLT).

## Structure

```
Sources/InstantTranslate/
  Entry.swift            @main; single-instance guard, then InstantTranslateApp.main()
  SingleInstance.swift   singleInstanceDecision() — startup duplicate-
                         instance guard (pure; pids in, decision out)
  App.swift              NSApplicationDelegateAdaptor(AppController) + placeholder Settings scene
  AppController.swift    NSStatusItem + translation NSPanel (hosts PanelView) + settings NSWindow; show/hide/focus; openSettings
  LanguagePolicy.swift   PURE routing: local / secondary / auto-swap → target lang
  LanguageDetector.swift NLLanguageRecognizer detection → base subtag; PURE preferred-language tie-break (resolve)
  LoginItem.swift        SMAppService.mainApp wrapper ("launch at login" toggle)
  Languages.swift        curated fallback language list + localized name
  LanguageCatalog.swift  async OS-supported languages → LanguageOption list (region-qualified when needed)
  HotKey.swift           HotKeyCombo (persist/display/Carbon) + GlobalHotKey (RegisterEventHotKey)
  HotKeyRecorder.swift   click-to-record shortcut control (local keyDown monitor) + × to remove
  SettingsStore.swift    UserDefaults keys/defaults + snapshot; builds LanguagePolicy
  TranslationModel.swift ObservableObject; UI state + phase + failure + volatile last entry; DI seam
  TranslationFailure.swift  classify(Error) → named failure; PURE message(sourceName:targetName:)
  TranslationStatus.swift   TranslationPhase + PURE display() → status-row symbol/text/spinner/tone
  TextTranslating.swift  protocol + EchoTranslator stub (tests/previews)
  TextSize.swift         PURE ⌘+/⌘− ladder stepping + effective size (ADR-0002)
  PanelMinimumSize.swift PURE panel minimum from laid-out sizes (ADR-0003)
  PanelView.swift        the panel; owns the real TranslationSession via .translationTask
  SettingsView.swift     settings content (@AppStorage); reports its height to fit the window
Tests/InstantTranslateTests/
  LanguagePolicyTests, SettingsStoreTests, TranslationModelTests,
  TranslationFailureTests, TranslationStatusTests, SingleInstanceTests
Info.plist               LSUIElement=true, LSMinimumSystemVersion=26.0
scripts/                 codesign / notarize / make-icns / gen-brew / release-brew.mk / cask.rb.tmpl
assets/                  AppIcon-1024.png (→ AppIcon.icns at build; absent for now)
docs/{en,ja}/            RFP + adr/
```

## Gotchas / conventions

- **The release build pins the linked SDK.** macOS decides which generation of
  window chrome to draw from `LC_BUILD_VERSION`'s sdk field, and the Xcode 27 /
  Swift 6.4 `swift build` stamps it with the deployment target, not the SDK it
  compiled against — an app shipped that way draws with the previous design
  (square window corners). `make build` passes `-platform_version macos
  $(MACOS_MIN) $(MACOS_SDK)` (the minimum read from Package.swift, so it is
  stated once), and `make verify-release` fails if the built bundle's sdk is not
  the current one. Signing, notarization and every test pass either way, so the
  gate is the only thing that can catch it.
- **`TranslationSession` is view-bound** — never instantiated directly; delivered
  into `.translationTask` and bound to the view's lifetime. Same-target re-run =
  `configuration.invalidate()`; new target = new `Configuration`. Closed-panel
  paths (Phase 2 hotkey / selected text) require a resident hidden host view.
- **Keep the routing pure** — all target-language logic lives in `LanguagePolicy`
  (no UI / framework imports) so it stays unit-testable. `TranslationModel` is
  `@MainActor` and takes an injected `TextTranslating` for tests/previews; the real
  session path is in `PanelView`.
- **Never show a raw `TranslationError`** — `localizedDescription` is
  `"Unable to Translate"` for seven of its eight cases and every case bridges to
  `NSError` domain `Translation.TranslationError` **code 1**, so the thrown error
  is neither showable nor distinguishable by shape. `TranslationError` is a struct
  with a custom `~=`, and that operator *does* discriminate cleanly (verified as an
  exact 8×8 diagonal), so `TranslationFailure.classify` matches on it and is the
  only place in the app that touches the framework's error type. `message(...)` is
  pure. Unplaced errors become `.unknown` carrying `failureReason ??
  localizedDescription` plus domain/code — never drop that, it is all an
  unanticipated error leaves behind. ADR-0001.
- **Every state the panel is in must be nameable** — `TranslationPhase` covers the
  states that *withhold* a translation on purpose (IME composition, undetectable
  input, debounce armed, echo) as well as the ones doing work. Before it existed
  they were all indistinguishable from a hang. A new "quietly do nothing" branch
  needs a phase and a line in `TranslationStatus.display`, not a bare `return`.
  ADR-0001.
- **`isTranslating` is derived, not stored** — it is `phase == .preparing ||
  .translating`. Setting a phase is the only way to move the UI; there is no second
  source of truth to drift.
- **History is volatile** — most-recent entry only, in memory, never persisted.
- **Text size is ⌘+ / ⌘− / ⌘0 on invisible buttons in `PanelView`** (ADR-0002) —
  there is no menu bar to hold them. `.keyboardShortcut` matches modifiers
  *exactly*, so enlarge is bound three times: `"+"`+⌘⇧ (main-row `+`, shifted on
  US and JIS), `"+"`+⌘ (keypad `+`, unshifted) and `"="`+⌘ (US alias). Dropping
  one silently breaks that key — it falls through to the text view and beeps.
  Only the input, its placeholder and the output scale. `SettingsKey.textSize`
  is deliberately *not* registered: absence means the system body size, and ⌘0
  removes it. `SourceTextView` defers a font change while IME text is marked.
  When testing shortcuts with synthetic `CGEvent`s, remember key codes are
  positions: US code 24 (`=`) is `^` on JIS — the first automated probe sent
  neither `+` nor `=`.
- **Settings persist via UserDefaults** — `SettingsStore` reads; `SettingsView`
  binds the same keys via `@AppStorage`. `SettingsKey.registerDefaults()` runs at
  launch in `App.init`.
- **AppKit shell, not `MenuBarExtra`** — the menu bar is an `NSStatusItem` and the
  panel is a resizable `NSPanel` hosting `PanelView` (`NSHostingView`, inside a
  plain container view — see the minimum-size entry). Reason: a
  MenuBarExtra popover can't be user-resized and can't reliably focus a text field.
  The panel autosaves its size and re-anchors under the status item each open;
  focus-on-open = `AppController.focusToken` → `PanelView` `@FocusState`.
  `AppController.showPanel()` is also the Phase 2 hotkey entry point.
- **The panel's minimum size is measured, not declared** (ADR-0003). `PanelView`
  reports laid-out sizes via `onGeometryChange`; the pure `PanelMinimumSize.compute`
  turns them into a minimum (content height − the two fields' stretch beyond
  80 pt + title bar; pickers + arrow + button + gaps + padding);
  `AppController.setPanelMinimum` applies it next run-loop turn, capped to the
  screen, growing a too-small panel. Three traps, each hit once:
  (1) `NSHostingView`'s own `.minSize` (also in the default `sizingOptions`) measures
  under a 0 × 0 proposal — single-line text reports 0 height, fixed-height text wraps
  per character — so it is set to `[]`; (2) as the window's `contentView` the hosting
  view still resizes the window in `windowDidLayout`, which fought the measured
  minimum until AppKit threw, so it lives in a plain container view; (3) every
  stretchy view must be subtracted in `compute`, or the minimum grows with the
  panel and runs away — a `Spacer` wrapped in a measuring modifier stretches
  vertically too, so the row pushes the button right with a frame, not a `Spacer`.
  The "(language)" hints are overlaid on a blank line *under* their pickers, so they
  add no width; beside the pickers (always, or only when wide enough) was tried and
  dropped.
- **The menu bar item is not shown pressed while the panel is open — a known
  limitation, accepted to keep the resizable panel and the hotkey (user's decision,
  2026-09-22).** The user saw it by hand on macOS 27; task-clock-gui, which has the
  same panel, was filmed (the item's rect at 60 fps): lit while the mouse button is
  held, dark from the release until the panel closes. macOS keeps an item lit during a
  panel only for `NSPopover` and SwiftUI `MenuBarExtra`, through private AppKit
  machinery; `button.highlight(true)` / `isHighlighted` never reach the screen, and the
  private calls are not used (no behaviour guarantee — user policy). What each public
  container would cost here: a popover has no user resizing, and whether its text field
  takes typing right after a hotkey open from another app is unmeasured; a
  `MenuBarExtra` window cannot be resized and, as far as is known (not verified), has no
  public API to open it, so ⌥⌘T would lose its panel. Mechanism: knowledge macos-gui,
  "メニューバー項目の『開いている間のハイライト』は器が決める".
- **Global hotkey** — `GlobalHotKey` wraps Carbon `RegisterEventHotKey` (no external
  dep, no Accessibility). `AppController` registers `HotKeyCombo.current()` at launch
  and re-registers on `UserDefaults.didChangeNotification` when the combo changes.
  Hotkey-open (`hotKeyPressed` → `showPanel(seedClipboard: true)`) seeds the source
  from the clipboard when the setting is on; the status-item click doesn't seed. The
  recorder swallows keys via a local `keyDown` monitor while capturing. The × beside
  it stores `HotKeyCombo.disabled` (no modifiers) — a *value*, because removing the
  defaults would bring back the registered ⌥⌘T; `register` skips it as invalid. It is
  not named `none`, which reads as `Optional.none` where a combo is optional.
- **Panel is `.nonactivatingPanel`** (don't remove) — an ordinary NSPanel only renders
  while the app is active, and macOS 14+ focus-stealing prevention can deny activation
  for ~30 s after launch, so the panel was `isVisible` but never shown ("won't open
  after launch", fixed 0.1.1). Non-activating renders + takes input without activation.
- **Panel toggle: never `hidesOnDeactivate` on a toggled `NSPanel`** — it auto-hides
  on deactivation but leaves `isVisible == true`, so a `isVisible ? orderOut : show`
  toggle then no-ops instead of opening (the "clicking the icon doesn't open it" bug).
  Dismiss on deactivation yourself via `applicationDidResignActive` → `orderOut`, which
  keeps `isVisible` truthful. `position()` also clamps the panel size to the current
  screen (an autosaved size from a bigger display would otherwise push it off-screen).
- **Auto-translate is debounced** — `PanelView.scheduleAutoTranslate` fires ~600 ms
  after the input stops changing; each change cancels the pending `Task`. Gated by the
  `autoTranslate` setting; a manual `translate()` cancels any pending auto-run.
- **Auto-translate must never run mid-IME-composition** — the source field is a custom
  `SourceTextView` (`NSTextView`), not `TextEditor`, precisely because `TextEditor`
  can't tell you about *marked* (uncommitted) IME text. Translating a half-done
  kana-kanji conversion produced garbage and made the OS raise its source-language
  picker over the panel, blocking typing (the 0.1.2 bug). `ComposingTextView` reports
  composition edges from `setMarkedText`/`unmarkText`/`insertText` — `textDidChange`
  alone is not enough, because committing a composition can leave the string
  byte-identical and emit no change at all. State lands in
  `TranslationModel.isComposing`; the rules live in the pure, unit-tested
  `AutoTranslatePolicy` (`action(forSourceText:…)` to arm, `mayRun(…)` at fire time).
  `mayRun` also stands down when the *resolved* source (pin, else detection) is `nil` —
  undetectable input is exactly what triggers that OS picker; a pinned source always
  passes. Manual translate is never gated.
- **The caret must be visible in the empty input** — focus is applied by
  `SourceTextView.updateNSView` calling `makeFirstResponder` when `focusToken` changes
  (a monotonic counter, since a `Bool` can't re-trigger focus when already `true`);
  `@FocusState` on `TextEditor` did not reliably land. An empty field also shows a
  placeholder overlay so focus is unmistakable.
- **First responder is not enough — an `NSTextView` draws its caret only in a *key*
  window.** Opening the panel by hotkey from another app does *not* activate the app
  (macOS denies it; verified — the other app stays frontmost), so key status is the only
  thing that makes the caret appear. Three parts, all needed: `TranslationPanel`
  overrides `canBecomeKey` (a `.nonactivatingPanel` is exactly the case where a window
  holds key status while the app is inactive); `showPanel` calls `makeKey()` and
  re-asserts key + focus one runloop turn later, since `NSApp.activate()` is async and
  may be refused; and the `SourceTextView` coordinator observes
  `NSWindow.didBecomeKeyNotification` to reclaim first responder and call
  `updateInsertionPointStateAndRestartTimer`, which covers any remaining ordering.
- **The version must stay visible in the UI** — `AppInfo.version` reads
  `CFBundleShortVersionString` (injected by `make build-app` from `git describe`) and is
  shown in the panel header and at the foot of Settings. This app has no menu bar and no
  About item, so removing those labels leaves users with no way to identify their build.
  Under `make run` there's no bundle, so it reads `dev` — that's expected, not a bug.
- **Pickers show only OS-supported languages, regional variants distinguished** —
  `LanguageCatalog.load()` fetches `LanguageAvailability().supportedLanguages` (async)
  and builds `[LanguageOption]` (id = `minimalIdentifier` e.g. "en-GB"; name
  region-qualified only when a base language has >1 variant — `options(from:)` is
  unit-tested). Pickers bind to `options` (curated fallback until loaded). The chosen
  variant is preserved: `LanguagePolicy` compares by `base(...)` but returns the full
  identifier as the target; `TranslationModel.resolveTarget` keeps `targetOverride`
  verbatim. `PanelView.run` pre-checks `status(from:to:)` for a clear unsupported message.
- **The model download is prepared explicitly, not stumbled into** — `PanelView.run`
  checks `session.isReady` and, when false, enters `.preparing` and calls
  `session.prepareTranslation()` before translating. The OS raises its download
  consent for that pair either way; doing it here moves it to a moment the panel has
  already labelled, instead of an unexplained multi-second freeze inside
  `session.translate`. Gate on `isReady` (the session's own answer for the exact
  configuration about to run), not on `LanguageAvailability.status == .supported`;
  `status` keeps its separate job of rejecting unsupported pairs up front. This is
  narrower than the blanket "never let the OS raise a dialog" stance below — that one
  is about the *source-language* picker, which is avoidable and interrupts typing.
  ADR-0001.
- **Launch at login** — `LoginItem` wraps `SMAppService.mainApp`; `SMAppService` is the
  source of truth (the Settings toggle mirrors `status`, refreshes `.onAppear`, no
  persisted flag). Registration only works from the signed `.app`, not `swift run`.
- **No special permissions** — selected-text translation (which would have needed
  Accessibility) was descoped. The app needs no TCC grant; only the OS's own
  language-model download consent. Don't reintroduce Accessibility casually.
- **Manual target override** — `TranslationModel.targetOverride` (base subtag, nil =
  Auto) wins in `resolveTarget()` over the policy. It's in-memory only (resets to Auto
  on restart). The panel's "Auto + languages" picker binds it; changing it re-translates.
- **Source pin** — `TranslationModel.sourceOverride` (base subtag, nil = Auto) mirrors
  the target override: in-memory only, bound to the panel's left picker (which lists
  `LanguageCatalog.sourceOptions` — base languages only, variants collapsed), changing
  it re-translates. `model.resolvedSource` (`sourceOverride ?? detectedSource`) is what
  everything downstream uses — routing, the no-op echo check, `mayRun`, the pre-flight
  status check, and the session configuration. A pin satisfies `mayRun` even when the
  text is undetectable.
- **Detect before routing, and hand the source to the framework** —
  `PanelView.translate()` runs `LanguageDetector` (biased toward the local + secondary
  languages via the pure `resolve(hypotheses:preferred:)` tie-break) to set
  `model.detectedSource`, *then* `LanguagePolicy` resolves the target. Without
  detection the target defaulted to the local language and native input became a
  same-language pair, which the framework rejects (the "Japanese errors" bug). Same
  base source==target → echo, don't call the session. The resolved source is passed
  **explicitly** in `TranslationSession.Configuration(source:…)` — leaving it `nil`
  made the framework re-detect on its own and raise the OS source-language picker
  whenever *it* was unsure, even when we weren't. `nil` reaches the framework only
  for a manual ⌘↩ on genuinely undetectable input (deliberate: the OS dialog is the
  last resort there). Note the config rebuild check compares source *and* target.
- **Settings is a separate AppKit `NSWindow`** (`AppController.openSettings`), not the
  SwiftUI `Settings` scene / `showSettingsWindow:` (unreliable for a menu-only
  `LSUIElement` app). An in-panel 3D card flip was tried and reverted — the 180°
  `rotation3DEffect` inverts hit-test z-order so the flipped Back button wasn't
  clickable (only Esc worked). `Settings { EmptyView() }` is a placeholder only.
  If a flip is ever revisited: don't put interactive controls inside a statically
  180°-rotated layer. The window's height is fitted to the content: `SettingsView`
  reports its natural height (measured *inside* its scroll view, so resizing the
  window can't feed back) and `AppController.fitSettingsWindow` applies it on the
  next run-loop turn, keeping the top edge, capped to the screen. The hosting view
  sits in a plain container with `sizingOptions = []`, for the same reason as the
  panel's (ADR-0003).
- **Notification clicks launch by bundle ID — enforce a single instance.**
  Clicking a banner makes notificationd open the app via LaunchServices,
  which resolves `jp.nlink.instant-translate` among *all* registered
  copies (`dist/` dev builds, release-verification extractions,
  `/Applications`) and may start a different copy than the running one →
  two menu bar items, duplicated work. Guarded at two layers:
  `LSMultipleInstancesProhibited` (Info.plist, stops LaunchServices
  launches) and a startup check in `Entry.main`
  (`singleInstanceDecision`, pure + tested) that exits with a stderr note
  (covers direct exec / `open -n`). Side effect: to run a `dist/` build,
  quit the installed instance first — a second copy now refuses to start.
- **Signing**: pure SwiftUI/AppKit → no entitlements (Hardened Runtime alone);
  notarize + staple.
- **macOS 26 platform pin** — `Package.swift` uses `.macOS("26.0")` (string form;
  the `.v26` enum may be absent in older toolchains).

## Status

Phase 1 (core translate) + Phase 2 done: global hotkey (⌥⌘T, rebindable) + clipboard
seed, manual target picker, `LanguageAvailability` (supported-language pickers +
unsupported-pair messaging). **Selected-text translation was descoped** (would have
needed Accessibility) — the app needs no TCC grant. See the RFP (with its scope note).

Post-0.2.0: the panel reports its state (`TranslationPhase` + status row) and
classifies framework failures into actionable messages (`TranslationFailure`) —
ADR-0001.

## Design reference

- RFP: `docs/ja/instant-translate-rfp.ja.md`
- ADR-0001 — panel feedback and failure messages:
  `docs/en/adr/0001-panel-feedback-and-failure-messages.md`
  (`docs/ja/adr/0001-panel-feedback-and-failure-messages.ja.md`)
- ADR-0002 — panel text size (⌘+ / ⌘− / ⌘0):
  `docs/en/adr/0002-panel-text-size.md`
  (`docs/ja/adr/0002-panel-text-size.ja.md`)
- ADR-0003 — panel layout and minimum size:
  `docs/en/adr/0003-panel-layout-and-minimum-size.md`
  (`docs/ja/adr/0003-panel-layout-and-minimum-size.ja.md`)
- Sibling: https://github.com/nlink-jp/quick-translate
