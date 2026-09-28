import Foundation
import NaturalLanguage

/// On-device dominant-language detection for the input text, used to route the
/// translation target (see `LanguagePolicy`) and — since the source is now passed
/// explicitly to the Translation framework — to keep the OS from raising its own
/// source-language picker. Kept separate from the pure policy so the routing rule
/// stays testable without a model, and so the detector can be swapped/expanded
/// independently.
enum LanguageDetector {
    /// Candidates whose probability is at least this fraction of the winner's are
    /// "in contention": close enough that a preferred language beats the raw winner.
    static let ambiguityRatio = 0.5

    /// Weight of the user's own languages in the detection prior (). Measured
    /// on macOS 27.0 through the whole pipeline (prior, then `resolve`): 20 fixes most
    /// short input in the user's languages ("under", "begin", "im a cat", "im odd" for
    /// English + Korean); 50 took Danish for Norwegian.
    static let ownLanguageWeight = 20.0

    /// Languages written in Han characters. They never get the prior: Japanese and
    /// Chinese share the script, so weighting either swallows the other from the
    /// smallest weight measured (kanji-only Japanese read as Chinese for a Chinese
    /// user, a Chinese sentence as Japanese for a Japanese user). That collision is
    /// the `resolve` tie-break's job, as it was before the prior ().
    static let hanScriptLanguages: Set<String> = ["ja", "zh"]

    /// Every language `NLLanguageRecognizer` documents, `undetermined` aside, plus one it
    /// was seen to return without a documented constant (`iu-Cans`). A language missing
    /// here gets no prior — hints act on the listed languages only — and loses to any
    /// neighbour sharing its script (a language with a script of its own is still
    /// detected). A test checks the list against what the recognizer returns for a
    /// multilingual sample: a tripwire, not a proof of completeness.
    static let knownLanguages: [NLLanguage] = [
        .amharic, .arabic, .armenian, .bengali, .bulgarian, .burmese, .catalan, .cherokee,
        .croatian, .czech, .danish, .dutch, .english, .finnish, .french, .georgian, .german,
        .greek, .gujarati, .hebrew, .hindi, .hungarian, .icelandic, .indonesian, .italian,
        .japanese, .kannada, .kazakh, .khmer, .korean, .lao, .malay, .malayalam, .marathi,
        .mongolian, .norwegian, .oriya, .persian, .polish, .portuguese, .punjabi, .romanian,
        .russian, .simplifiedChinese, .sinhalese, .slovak, .spanish, .swedish, .tamil,
        .telugu, .thai, .tibetan, .traditionalChinese, .turkish, .ukrainian, .urdu, .vietnamese,
        NLLanguage(rawValue: "iu-Cans"),
    ]

    /// The detection prior (): every known language at 1, the user's own
    /// languages — matched by base subtag, so `en-GB` means English — at
    /// `ownLanguageWeight`, except `hanScriptLanguages`. Hinting only the own languages
    /// would act as a restriction (measured): everything else would stop being detected.
    static func hints(preferred: [String]) -> [NLLanguage: Double] {
        let own = Set(preferred.map(LanguagePolicy.base)).subtracting(hanScriptLanguages)
        var hints: [NLLanguage: Double] = [:]
        for language in knownLanguages {
            hints[language] = own.contains(LanguagePolicy.base(language.rawValue)) ? ownLanguageWeight : 1
        }
        return hints
    }

    /// The dominant language of `text` as a base subtag ("ja", "en", "zh"), or `nil`
    /// when the text is empty or undetectable.
    ///
    /// `preferred` (typically the user's local + secondary languages) is used twice:
    /// as a prior, so short input in the user's own languages is not taken for a
    /// neighbouring language the recognizer is wrongly sure of (); and to break
    /// ties, when the candidates are close — kanji-only text is a classic ja/zh coin
    /// toss — the highest-probability preferred language in contention wins over the
    /// raw winner. When detection is still wrong, the source picker pins the language.
    static func detect(_ text: String, preferred: [String] = [], constraints: [String] = []) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let recognizer = NLLanguageRecognizer()
        recognizer.languageHints = hints(preferred: preferred)
        if !constraints.isEmpty {
            recognizer.languageConstraints = constraints.map { NLLanguage($0) }
        }
        recognizer.processString(trimmed)
        guard let dominant = recognizer.dominantLanguage else { return nil }
        let hypotheses = recognizer.languageHypotheses(withMaximum: 8)
            .reduce(into: [String: Double]()) { $0[$1.key.rawValue] = $1.value }
        return resolve(hypotheses: hypotheses, preferred: preferred)
            ?? LanguagePolicy.base(dominant.rawValue)
    }

    /// The pure tie-break rule, split out for unit testing.
    ///
    /// Probabilities are merged by base subtag (zh-Hans + zh-Hant → zh). Among the
    /// candidates within `ambiguityRatio` of the winner, the highest-probability
    /// preferred language wins (ties go to the earlier entry in `preferred`);
    /// otherwise the raw winner stands. Returns `nil` only for empty input.
    static func resolve(hypotheses: [String: Double], preferred: [String]) -> String? {
        var merged: [String: Double] = [:]
        for (lang, p) in hypotheses { merged[LanguagePolicy.base(lang), default: 0] += p }
        guard let top = merged.values.max(), top > 0 else { return nil }
        let floor = top * ambiguityRatio
        var best: (lang: String, p: Double)?
        for lang in preferred.map(LanguagePolicy.base) {
            guard let p = merged[lang], p >= floor else { continue }
            if best == nil || p > best!.p { best = (lang, p) }
        }
        if let best { return best.lang }
        return merged.max { $0.value < $1.value }?.key
    }
}
