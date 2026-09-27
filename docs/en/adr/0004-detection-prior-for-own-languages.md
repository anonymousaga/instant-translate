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
  `undetermined`) at 1, the preferred languages at *k*; all at 1 behaves
  exactly like no hints.

Results by *k*, measured through the app's whole pipeline — the prior, then
the `resolve` tie-break. (An earlier draft of this record measured the prior
alone; the tie-break on top makes the real effect stronger, which the review
before release caught.)

| *k* | en+ko: reported (6) | en+ko: short English (21) | en+ko: other-language sentences (13) | ja+en: Chinese sentences (8) | ja+en: kanji-only Japanese (13) | zh+en: kanji-only Japanese (13) | close pairs: en+es / en+nb / en+ru |
|---|---|---|---|---|---|---|---|
| 1 (= v0.4.0) | 0 | 12 | 13 | 8 | 12 | 7 | 7/7 · 6/6 · 3/3 |
| 5 | 2 | 17 | 13 | **7** | 13 | **4** | 7/7 · 6/6 · 3/3 |
| 10 | 3 | 18 | 13 | **7** | 13 | **3** | 7/7 · 6/6 · 2/3 |
| 20 | 4 | 19 | 13 | **7** | 13 | **2** | 7/7 · 5/6 · 2/3 |
| 50 | 5 | 20 | 13 | **5** | 13 | **2** | 7/7 · 4/6 · 2/3 |
| **20, Han excluded** | **4** | **19** | **13** | **8** | **12** | **7** | 7/7 · 5/6 · 2/3 |

Two things follow. A prior helps short Latin-script input steadily. But for
the two languages written in Han characters it hurts from the smallest
weight: Japanese and Chinese share the script, so a prior on either swallows
the other — "人工智能研究所" read as Japanese for a Japanese user, and
"東京都新宿区西新宿二丁目八番一号" or "株式会社" as Chinese for a Chinese user
(2 of 13 kanji-only Japanese strings survived at *k* = 20, against 7 without
a prior). That collision is what the v0.2.0 tie-break already settles.
Leaving Japanese and Chinese out of the prior keeps every CJK result exactly
as in v0.4.0 while keeping the whole gain for everything else.

## Decision

### Decision 1: Detect with a prior for the user's own languages — except Japanese and Chinese

`LanguageDetector.detect` sets `languageHints` before processing: every
language the recognizer knows at 1, the user's local and secondary languages
at **20** — unless the language is written in Han characters (`ja`, `zh`),
which stays at 1 and is left to the existing tie-break. A preferred language
is matched by base subtag (`en-GB` means English). The `resolve` tie-break
runs on the resulting hypotheses as before.

The weights are a pure function (preferred languages → hints), unit-tested.
The language list and the Han exclusion each live in one place.

### Decision 2: When detection is still wrong, the answer is the source picker

Some short inputs stay wrong ("im so small" and "over under" for the
reporter): the recognizer is too sure for this prior to overturn, and a
larger one takes neighbouring languages. The panel already has the remedy —
the source-language picker pins the input language and bypasses detection.
Automatic detection is a convenience; when it fails, the user chooses
manually, which is what that picker is for. No restriction setting is added.

### Decision 3: Pin the behaviour in tests, including the list

- The hint weights (pure): every listed language present, preferred ones at
  20, Japanese and Chinese never weighted, unknown codes ignored.
- **Every language the recognizer returns over a multilingual sample is in
  the list.** The recognizer also returns a value that is not a documented
  constant — `iu-Cans` (Inuktitut syllabics) — so the list carries it too. The
  test only sees languages its samples provoke; it is a tripwire, not a proof
  of completeness.
- Behaviour against the OS model: the reported inputs that are fixed detect
  as English for `[en, ko]`; Chinese sentences stay Chinese for `[ja, en]`;
  kanji-only Japanese stays Japanese for `[zh, en]`. These depend on Apple's
  model; a failure after an OS update means re-measuring, not editing the
  expectation.

## Consequences

- Short input in the user's own languages is detected correctly more often
  for every pair that is not Japanese–Chinese, without a new setting.
  Japanese and Chinese detection is unchanged from v0.4.0.
- Four of the reporter's six inputs are fixed; "im so small" and "over under"
  still need the source picker. The reply to the issue says so.
- Very short input in a *third* language close to a preferred one can now be
  taken for the preferred one — in the corpus, the one word "Tack" (Swedish)
  for a Norwegian + English user and a short Bulgarian sentence for a
  Russian + English user; one-word greetings such as "merci" read as English
  for an English user. The status row names the detected language, and the
  source picker corrects it.
- A language missing from the list gets no prior and loses to neighbours
  that share its script (measured: with Swedish removed, Swedish sentences
  came out Norwegian and Finnish); a language with a script of its own is
  still detected. The list follows Apple's documented constants plus what
  the recognizer was seen to return.

## Alternatives considered

**A1. A larger prior (*k* = 50 or 1000).** Fixes one more reported input at
50 and all six at 1000 (measured on the prior alone), but Danish, Ukrainian
and Bulgarian were taken for the neighbouring preferred language, and
without the Han exclusion Chinese sentences became Japanese. Rejected.

**A2. Restrict detection to the chosen languages (the reporter's proposal),
as an opt-in setting.** Fixes all six, but everything else becomes
undetectable, and it adds a setting whose job the source picker already
does. Rejected.

**A3. Hints for the preferred languages only.** Measured to behave as a
constraint (A2 by another name). Rejected.

**A4. Weight Japanese and Chinese like every other language.** The first
version of this decision. Measured to break CJK both ways from *k* = 5 (table
above). Rejected; the Han exclusion replaced it.

**A5. A prior that depends on input length** (large only for short input).
Not measured; a seven-character Chinese sentence is short by length, so the
boundary would need its own evidence. Revisit only if *k* = 20 proves
insufficient in use.

**A6. Keep only the tie-break and lower its threshold.** English sits at
0.01 against 0.98 for "im so small"; no threshold reaches it without letting
the preferred language win everywhere.

## References

- Issue #2; PR #1 (the reporter's original restriction, closed)
- Apple: `NLLanguageRecognizer.languageHints`, `languageConstraints`,
  `NLLanguage`
- nlink-jp/knowledge, macos-gui: an identifier `languageConstraints` does not
  know makes that language undetectable
- Measurements: 2026-09-28, macOS 27.0, the maintainer's machine
