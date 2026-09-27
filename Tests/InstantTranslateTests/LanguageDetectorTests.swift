import NaturalLanguage
import XCTest
@testable import InstantTranslate

final class LanguageDetectorTests: XCTestCase {
    func testDetectsEnglish() {
        XCTAssertEqual(LanguageDetector.detect("The quick brown fox jumps over the lazy dog."), "en")
    }

    func testDetectsJapanese() {
        XCTAssertEqual(LanguageDetector.detect("これは日本語の文章です。翻訳のテストをしています。"), "ja")
    }

    func testEmptyOrBlankReturnsNil() {
        XCTAssertNil(LanguageDetector.detect(""))
        XCTAssertNil(LanguageDetector.detect("   \n "))
    }

    func testResultIsBaseSubtag() {
        // Chinese may be reported as "zh-Hans"; the detector normalises to "zh".
        if let zh = LanguageDetector.detect("这是一段用来测试语言检测功能的中文文本。") {
            XCTAssertEqual(zh, "zh")
        }
    }

    func testPreferredLanguagesDoNotDisturbAClearWinner() {
        // Unambiguous English must stay English even with ja first in the preferences.
        XCTAssertEqual(
            LanguageDetector.detect("The quick brown fox jumps over the lazy dog.",
                                    preferred: ["ja", "en"]),
            "en")
    }

    // MARK: - resolve(hypotheses:preferred:) — the pure tie-break rule

    func testAmbiguousCandidatesFallToThePreferredLanguage() {
        // The kanji-only coin toss: ja and zh in contention → the preferred ja wins
        // even though zh scored (slightly) higher.
        XCTAssertEqual(
            LanguageDetector.resolve(hypotheses: ["zh-Hans": 0.45, "ja": 0.40],
                                     preferred: ["ja", "en"]),
            "ja")
    }

    func testHigherProbabilityPreferredLanguageBeatsListOrder() {
        // Both preferred languages are in contention — probability decides, not the
        // order of the preference list (ja is listed first but en clearly leads).
        XCTAssertEqual(
            LanguageDetector.resolve(hypotheses: ["en": 0.60, "ja": 0.35],
                                     preferred: ["ja", "en"]),
            "en")
    }

    func testDistantPreferredLanguageCannotSteal() {
        // A preferred language far below the winner is not "in contention".
        XCTAssertEqual(
            LanguageDetector.resolve(hypotheses: ["fr": 0.90, "en": 0.08],
                                     preferred: ["en"]),
            "fr")
    }

    func testNoPreferredMatchKeepsTheRawWinner() {
        XCTAssertEqual(
            LanguageDetector.resolve(hypotheses: ["ko": 0.55, "zh-Hant": 0.30],
                                     preferred: ["ja", "en"]),
            "ko")
    }

    func testScriptVariantsMergeToTheBaseLanguage() {
        // zh-Hans + zh-Hant together outweigh ko once merged by base subtag.
        XCTAssertEqual(
            LanguageDetector.resolve(hypotheses: ["zh-Hans": 0.30, "zh-Hant": 0.25, "ko": 0.40],
                                     preferred: []),
            "zh")
    }

    func testEmptyHypothesesResolveToNil() {
        XCTAssertNil(LanguageDetector.resolve(hypotheses: [:], preferred: ["ja"]))
    }

    // MARK: - hints(preferred:) — the detection prior (ADR-0004)

    func testHintsCoverEveryKnownLanguage() {
        let hints = LanguageDetector.hints(preferred: [])
        XCTAssertEqual(hints.count, LanguageDetector.knownLanguages.count)
        XCTAssertTrue(hints.values.allSatisfy { $0 == 1 }, "no preference means a flat prior")
    }

    func testOwnLanguagesAreWeighted() {
        let hints = LanguageDetector.hints(preferred: ["en", "ko"])
        XCTAssertEqual(hints[.english], LanguageDetector.ownLanguageWeight)
        XCTAssertEqual(hints[.korean], LanguageDetector.ownLanguageWeight)
        XCTAssertEqual(hints[.french], 1)
        XCTAssertEqual(hints.count, LanguageDetector.knownLanguages.count,
                       "every other language keeps a prior — leaving one out makes it undetectable")
    }

    func testChineseCoversBothScripts() {
        let hints = LanguageDetector.hints(preferred: ["zh"])
        XCTAssertEqual(hints[.simplifiedChinese], LanguageDetector.ownLanguageWeight)
        XCTAssertEqual(hints[.traditionalChinese], LanguageDetector.ownLanguageWeight)
    }

    func testRegionalAndUnknownCodesAreMatchedByBase() {
        // A regional secondary language means its base; an unknown code weighs nothing.
        let hints = LanguageDetector.hints(preferred: ["en-GB", "xx"])
        XCTAssertEqual(hints[.english], LanguageDetector.ownLanguageWeight)
        XCTAssertEqual(hints.values.filter { $0 != 1 }.count, 1)
    }

    func testEveryLanguageTheRecognizerReturnsIsKnown() {
        // A language missing from `knownLanguages` would get no prior and never be
        // detected — the same class of defect as constraints with unknown identifiers.
        let samples = [
            "The quick brown fox", "im so small", "안녕하세요", "こんにちは、元気ですか", "我们明天去北京",
            "我們明天去台北", "Bonjour tout le monde", "Ich habe heute keine Zeit.", "¿Dónde está la estación?",
            "Grazie mille per l'aiuto.", "Obrigado pela ajuda.", "Ik heb vandaag geen tijd.",
            "Jag har ingen tid idag.", "Tak for hjælpen.", "Takk for hjelpen.", "Kiitos avusta.",
            "Dziękuję za pomoc.", "Mulțumesc pentru ajutor.", "Köszönöm a segítséget.", "Děkuji za pomoc.",
            "Ďakujem za pomoc.", "Hvala na pomoći.", "Спасибо большое", "Дякую за допомогу", "Благодаря за помощта",
            "Γεια σου", "Merhaba, nasılsın?", "Terima kasih banyak.", "Xin chào các bạn", "שלום לכולם",
            "مرحبا بكم", "سلام، حال شما چطور است؟", "नमस्ते, आप कैसे हैं?", "ধন্যবাদ", "நன்றி", "ధన్యవాదాలు",
            "ಧನ್ಯವಾದಗಳು", "നന്ദി", "ਧੰਨਵਾਦ", "આભાર", "ଧନ୍ୟବାଦ", "ශ්‍රී ලංකාව", "สวัสดีครับ", "ສະບາຍດີ",
            "សួស្តី", "မင်္ဂလာပါ", "გამარჯობა", "Բարև ձեզ", "ሰላም", "Сайн байна уу", "Сәлеметсіз бе",
            "ᏌᏊ ᎢᏳᎾᎵᏍᏔᏅ", "བཀྲ་ཤིས་བདེ་ལེགས།", "Takk fyrir hjálpina.", "Terima kasih, apa khabar?",
        ]
        let known = Set(LanguageDetector.knownLanguages)
        var unknown: Set<String> = []
        for text in samples {
            let recognizer = NLLanguageRecognizer()
            recognizer.processString(text)
            for (language, _) in recognizer.languageHypotheses(withMaximum: 100) where !known.contains(language) {
                unknown.insert(language.rawValue)
            }
        }
        XCTAssertEqual(unknown, [], "add these to LanguageDetector.knownLanguages")
    }

    // MARK: - behaviour against the OS model (ADR-0004)
    //
    // These depend on Apple's language model. If one fails after an OS update,
    // re-measure the weight (ADR-0004's table) — do not just edit the expectation.

    func testShortEnglishIsEnglishForAnEnglishAndKoreanUser() {
        // From issue #2: without the prior these came out Catalan, Swedish and Dutch.
        for text in ["im a cat", "under", "begin"] {
            XCTAssertEqual(LanguageDetector.detect(text, preferred: ["en", "ko"]), "en", text)
        }
    }

    func testChineseSentencesStayChineseForAJapaneseUser() {
        // The regression a larger weight caused: these read as Japanese at 50 and above.
        for text in ["我们明天去北京", "我不知道他在哪里"] {
            XCTAssertEqual(LanguageDetector.detect(text, preferred: ["ja", "en"]), "zh", text)
        }
    }

    func testAClearThirdLanguageSentenceIsNotSwallowed() {
        XCTAssertEqual(LanguageDetector.detect("Bonjour tout le monde", preferred: ["en", "ko"]), "fr")
        XCTAssertEqual(LanguageDetector.detect("Ich habe heute keine Zeit.", preferred: ["en", "ko"]), "de")
    }
}
