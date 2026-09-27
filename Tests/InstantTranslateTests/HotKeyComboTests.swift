import AppKit
import Carbon.HIToolbox
import XCTest
@testable import InstantTranslate

final class HotKeyComboTests: XCTestCase {
    private func ephemeral() -> UserDefaults {
        let suite = "instant-translate-hk-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return d
    }

    func testDefaultIsOptionCommandT() {
        XCTAssertEqual(HotKeyCombo.default.displayString, "⌥⌘T")
        XCTAssertTrue(HotKeyCombo.default.isValid)
    }

    func testValidityRequiresACoreModifier() {
        // Shift alone is not a valid hotkey modifier.
        let shiftOnly = HotKeyCombo(keyCode: UInt16(kVK_ANSI_T),
                                    modifiers: NSEvent.ModifierFlags.shift.rawValue)
        XCTAssertFalse(shiftOnly.isValid)
        // No modifier at all.
        XCTAssertFalse(HotKeyCombo(keyCode: UInt16(kVK_ANSI_T), modifiers: 0).isValid)
    }

    func testCarbonModifiersBits() {
        let m = HotKeyCombo.default.carbonModifiers
        XCTAssertNotEqual(m & UInt32(cmdKey), 0)
        XCTAssertNotEqual(m & UInt32(optionKey), 0)
        XCTAssertEqual(m & UInt32(controlKey), 0)
        XCTAssertEqual(m & UInt32(shiftKey), 0)
    }

    func testDisplayStringModifierOrderAndKeys() {
        let all = HotKeyCombo(keyCode: UInt16(kVK_Space),
                              modifiers: NSEvent.ModifierFlags([.control, .option, .shift, .command]).rawValue)
        XCTAssertEqual(all.displayString, "⌃⌥⇧⌘Space")
    }

    func testKeyName() {
        XCTAssertEqual(HotKeyCombo.keyName(UInt16(kVK_ANSI_T)), "T")
        XCTAssertEqual(HotKeyCombo.keyName(UInt16(kVK_Space)), "Space")
        XCTAssertEqual(HotKeyCombo.keyName(UInt16(kVK_Return)), "↩")
    }

    func testSaveCurrentRoundTrip() {
        let d = ephemeral()
        let combo = HotKeyCombo(keyCode: UInt16(kVK_ANSI_K),
                                modifiers: NSEvent.ModifierFlags([.command, .shift]).rawValue)
        combo.save(d)
        XCTAssertEqual(HotKeyCombo.current(d), combo)
    }

    func testCurrentFallsBackToDefault() {
        XCTAssertEqual(HotKeyCombo.current(ephemeral()), .default)
    }

    // MARK: - No shortcut

    func testDisabledIsNotAValidHotkey() {
        // `GlobalHotKey.register` skips invalid combos — that is what removes it.
        XCTAssertFalse(HotKeyCombo.disabled.isValid)
    }

    func testRemovedShortcutStaysRemovedAcrossLaunches() {
        // Persisted as a value, not as missing defaults, which would mean ⌥⌘T.
        let d = ephemeral()
        HotKeyCombo.disabled.save(d)
        XCTAssertEqual(HotKeyCombo.current(d), .disabled)
        XCTAssertFalse(HotKeyCombo.current(d).isValid)
    }

    func testLabelShowsTheComboOrNone() {
        XCTAssertEqual(HotKeyCombo.default.label, "⌥⌘T")
        XCTAssertEqual(HotKeyCombo.disabled.label, "None")
        // An unusable stored value (shift only) registers nothing, so it reads None too.
        let shiftOnly = HotKeyCombo(keyCode: UInt16(kVK_ANSI_T),
                                    modifiers: NSEvent.ModifierFlags.shift.rawValue)
        XCTAssertEqual(shiftOnly.label, "None")
    }
}
