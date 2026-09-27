import Foundation

/// Languages understood by NaturalLanguage for source-language detection.
///
/// This is deliberately separate from `LanguageCatalog`: Translation framework
/// identifiers may contain regions (`en-GB`, `pt-PT`) while NaturalLanguage
/// detection works at language/script granularity.
struct DetectionLanguageOption: Identifiable, Equatable {
    let id: String
    let name: String
}

enum DetectionLanguageCatalog {
    private static let documentedIdentifiers = [
        "ar", "hy", "eu", "bn", "bg", "ca", "zh-Hans", "zh-Hant",
        "hr", "cs", "da", "nl", "en", "fi", "fr", "ka", "de", "el",
        "gu", "he", "hi", "hu", "is", "id", "it", "ja", "kn", "ko",
        "lv", "lt", "ms", "mr", "no", "fa", "pl", "pt", "ro", "ru",
        "sk", "sl", "es", "sv", "ta", "te", "th", "tr", "uk", "ur", "vi"
    ]

    /// The identifiers documented for `NLLanguage`. These are deliberately not
    /// derived from Translation's regional catalog: NaturalLanguage detects
    /// language/script, not translation regions.
    static func options(locale: Locale = .current) -> [DetectionLanguageOption] {
        options(supportedTranslationIdentifiers: documentedIdentifiers, locale: locale)
    }

    /// Returns the NaturalLanguage languages that also have a corresponding
    /// language in the app's Translation catalog.
    static func options(supportedTranslationIdentifiers: [String],
                        locale: Locale = .current) -> [DetectionLanguageOption] {
        let supported = Set(supportedTranslationIdentifiers.map(canonicalIdentifier))
        return documentedIdentifiers
            .filter { supported.contains($0) }
            .map { option($0, locale: locale) }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    private static func option(_ id: String,
                               locale: Locale) -> DetectionLanguageOption {
        DetectionLanguageOption(
            id: id,
            name: displayName(for: id, locale: locale))
    }

    /// Converts old selections written from the Translation catalog into the
    /// identifier space used by NaturalLanguage.
    static func canonicalIdentifier(_ id: String) -> String {
        let normalized = id.replacingOccurrences(of: "_", with: "-").lowercased()
        switch normalized {
        case "zh", "zh-cn", "zh-sg", "zh-hans":
            return "zh-Hans"
        case "zh-tw", "zh-hk", "zh-mo", "zh-hant":
            return "zh-Hant"
        default:
            return LanguagePolicy.base(normalized)
        }
    }

    static func name(for id: String, locale: Locale = .current) -> String {
        let canonical = canonicalIdentifier(id)
        return displayName(for: canonical, locale: locale)
    }

    private static func displayName(for id: String, locale: Locale) -> String {
        switch id {
        case "zh-Hans":
            return "\(locale.localizedString(forLanguageCode: "zh") ?? "Chinese") (Simplified)"
        case "zh-Hant":
            return "\(locale.localizedString(forLanguageCode: "zh") ?? "Chinese") (Traditional)"
        default:
            return locale.localizedString(forLanguageCode: id) ?? id
        }
    }
}
