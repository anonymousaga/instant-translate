# ADR-0004: A detection prior for the user's own languages

| Field | Value |
|-------|-------|
| Status | **Accepted** |
| Date | 2026-09-28 |
| Binds | instant-translate |
| Decision makers | nlink-jp maintainers |
| Triggered by | Issue #2 (@anonymousaga): short English input is detected as another language, for a user whose languages are English and Korean |

## Context

The reporter uses two languages — English (system) and Korean (secondary) —
and listed short English inputs detected as something else: "im a cat" →
Catalan, "im odd" → Polish, "im so small" → German, "under" → Swedish,
"begin" → Dutch, "over under" → Danish. All six reproduce on macOS 27.0 with
v0.4.0's detector and preferences `[en, ko]`.

**Why the existing tie-break does not help.** Since v0.2.0,
`LanguageDetector.resolve` lets a preferred language win when its
probability is at least half the winner's. On short Latin-script text the
recognizer is confidently wrong, so English never gets near that line:

| Input | Recognizer's top hypotheses |
|---|---|
| im so small | de 0.98, en 0.01 |
| im a cat | ca 0.60, ro 0.25 |
| begin | nl 0.67, en 0.16 |
| over under | da 0.55, nb 0.44, en 0.01 |

**What the reporter proposed** — limit detection to the chosen languages
(`languageConstraints`). Done with correct identifiers it fixes all six, but
every other language becomes undetectable: Japanese input returned no
language at all, and a French sentence became English. (The PR's version
also passed identifiers such as `zh` and `en-GB`, which match nothing — see
the knowledge entry on `languageConstraints`.)

**What the platform offers instead.** `NLLanguageRecognizer.languageHints`
is documented only as "a dictionary that maps languages to their
probabilities in the language identification process". Its behaviour was
measured (macOS 27.0, small hand-picked corpus, 2026-09-28):

- **Hints for only the preferred languages act as a constraint.** With just
  English and Korean hinted, every Latin-script sentence came out English at
  any weight from 0.02 to 0.8; Japanese still came out Japanese (distinct
  script). Languages left out of the dictionary behave as if their prior
  were zero.
- **Hinting every language, with the preferred ones weighted higher, acts as
  a prior.** All 57 `NLLanguage` constants (the documented list, excluding
  `undetermined`) at 1, the preferred languages at *k*. Every language the
  recognizer returned across the corpus (39) was in that list.

Results by *k*:

| *k* | en+ko: short English (21) | en+ko: other-language sentences (13) | ja+en: short English (21) | ja+en: Chinese sentences (7) | ja+en: kanji-only Japanese (9) | close pairs: en+es / en+nb / en+ru |
|---|---|---|---|---|---|---|
| none | 11 | 13 | 12 | 7 | 8 | 7/7 · 5/5 · 3/3 |
| 20 | 18 | 13 | 19 | 7 | 9 | 7/7 · 5/5 · 2/3 |
| 50 | 20 | 13 | 20 | **5** | 9 | 7/7 · **4/5** · 2/3 |
| 1000 | 21 | 13 | 21 | **5** | 9 | 7/7 · **4/5** · **1/3** |

A larger prior fixes more short English but starts to swallow languages that
share a script and vocabulary with a preferred one: Chinese sentences read as
Japanese for a Japanese user, Danish as Norwegian, Ukrainian and Bulgarian as
Russian. At *k* = 20 the only miss in the corpus was one short Bulgarian
sentence for an English + Russian user.

## Decision

### Decision 1: Detect with a prior for the user's own languages

`LanguageDetector.detect` sets `languageHints` before processing: every
language in the documented `NLLanguage` list at 1, the user's local and
secondary languages at **20**. A preferred base subtag maps to its
`NLLanguage` values (`zh` → `zh-Hans` and `zh-Hant`). The existing
`resolve` tie-break is kept and runs on the resulting hypotheses.

The weights are a pure function (preferred languages → hints), unit-tested.
The language list lives in one place.

### Decision 2: When detection is still wrong, the answer is the source picker

Some short inputs stay wrong at *k* = 20 ("im odd", "im so small", "over
under" for the reporter): the recognizer is too confident for a prior of
this size to overturn, and a larger one causes the regressions above. The
panel already has the remedy — the source-language picker pins the input
language and bypasses detection. Automatic detection is a convenience;
when it fails, the user chooses manually, which is what that picker is for.
No restriction setting is added.

### Decision 3: Pin the behaviour in tests, including the list

- The hint weights (pure): every listed language present, preferred ones at
  20, `zh` expanded to both scripts, unknown preferred codes ignored.
- **Every language the recognizer returns over a multilingual sample is in
  the list** — a language missing from the list would become undetectable,
  the same class of defect as the reporter's `zh` / `en-GB`.
- Behaviour against the OS model: the three fixed inputs detect as English
  for `[en, ko]`; Chinese sentences stay Chinese for `[ja, en]`. These depend
  on Apple's model; a failure after an OS update means re-measuring, not
  editing the expectation.

## Consequences

- Short input in the user's own languages is detected correctly more often,
  for every language pair, without a new setting.
- Three of the reporter's six inputs are fixed; the other three still need the
  source picker. The reply to the issue says so.
- Very short input in a *third* language that resembles a preferred one can
  now be taken for the preferred one (in the corpus: one Bulgarian sentence
  for an English + Russian user). The status row names the detected language,
  and the source picker corrects it.
- Detection depends on a 57-language list that Apple could extend; the list
  test catches a returned language that is missing from it.

## Alternatives considered

**A1. A larger prior (*k* = 1000).** Fixes all six reported inputs, but
Chinese sentences became Japanese for a Japanese user, and Danish, Ukrainian
and Bulgarian were taken for the neighbouring preferred language. Rejected:
a regression for the maintainer's own language pair.

**A2. Restrict detection to the chosen languages (the reporter's proposal),
as an opt-in setting.** Fixes all six, but everything else becomes
undetectable, and it adds a setting whose job the source picker already
does. Rejected.

**A3. Hints for the preferred languages only.** Measured to behave as a
constraint (A2 by another name). Rejected.

**A4. A prior that depends on the script or on input length** (large for
Latin-script preferred languages, small for Han; or large only for short
input). Not measured; it adds rules whose boundaries (a seven-character
Chinese sentence is short by length) would need their own evidence. Revisit
only if *k* = 20 proves insufficient in use.

**A5. Keep only the tie-break and lower its threshold.** English sits at
0.01 against 0.98 for "im so small"; no threshold reaches it without letting
the preferred language win everywhere.

## References

- Issue #2; PR #1 (the reporter's original restriction, closed)
- Apple: `NLLanguageRecognizer.languageHints`, `languageConstraints`,
  `NLLanguage`
- nlink-jp/knowledge, macos-gui: an identifier `languageConstraints` does not
  know makes that language undetectable
- Measurements: 2026-09-28, macOS 27.0, the maintainer's machine
