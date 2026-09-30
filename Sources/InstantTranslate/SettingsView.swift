import SwiftUI

/// The settings window's content. Binds the same `UserDefaults` keys as
/// `SettingsStore` reads, via `@AppStorage`. Shown in a separate AppKit window
/// (`AppController.openSettings`), which provides the title bar and close button.
///
/// The window is sized to fit: the content reports its natural height through
/// `onContentHeight`, and `AppController` fits the window to it — a fixed height left
/// a blank band under the last group, and text length varies with the OS language.
/// Should the content ever be taller than the screen, it scrolls; its width is capped.
struct SettingsView: View {
    /// Called with the content's natural height whenever it changes.
    var onContentHeight: (CGFloat) -> Void = { _ in }

    @EnvironmentObject private var catalog: LanguageCatalog
    @AppStorage(SettingsKey.secondaryLanguage) private var secondaryLanguage = SettingsStore.systemDefaultSecondary()
    @AppStorage(SettingsKey.autoSwapEnabled) private var autoSwapEnabled = true
    @AppStorage(SettingsKey.autoTranslate) private var autoTranslate = true
    @AppStorage(SettingsKey.clipboardAutoTranslate) private var clipboardAutoTranslate = true
    @AppStorage(SettingsKey.copyOnTranslate) private var copyOnTranslate = false
    @AppStorage(SettingsKey.hideOnDeactivate) private var hideOnDeactivate = true
    @AppStorage(SettingsKey.hotKeyKeyCode) private var hotKeyKeyCode = Int(HotKeyCombo.default.keyCode)
    @AppStorage(SettingsKey.hotKeyModifiers) private var hotKeyModifiers = Int(bitPattern: HotKeyCombo.default.modifiers)
    @AppStorage(SettingsKey.detectionLanguages) private var detectionLanguages = ""

    @State private var launchAtLogin = LoginItem.isEnabled

    private var hotKeyBinding: Binding<HotKeyCombo> {
        Binding(
            get: { HotKeyCombo(keyCode: UInt16(truncatingIfNeeded: hotKeyKeyCode),
                               modifiers: UInt(bitPattern: hotKeyModifiers)) },
            set: { hotKeyKeyCode = Int($0.keyCode); hotKeyModifiers = Int(bitPattern: $0.modifiers) }
        )
    }

    /// `SMAppService` is the source of truth; the toggle mirrors it and applies changes.
    private var launchAtLoginBinding: Binding<Bool> {
        Binding(get: { launchAtLogin },
                set: { launchAtLogin = $0; LoginItem.setEnabled($0) })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                GroupBox("General") {
                    Toggle("Launch at login", isOn: launchAtLoginBinding)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                GroupBox("Language") {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("Secondary language", selection: $secondaryLanguage) {
                            ForEach(catalog.options) { opt in Text(opt.name).tag(opt.id) }
                        }
                        Toggle("Auto-swap when input is my language", isOn: $autoSwapEnabled)
                        Text("Output goes to your system language. When the input is already your language, it goes to the secondary language instead.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer().frame(height: 2)
                        Text("Restrict which languages can be used to detect the input language. If none are selected, all languages are allowed.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Menu("Detection Languages") {
                            ForEach(DetectionLanguageCatalog.options(
                                supportedTranslationIdentifiers: catalog.options.map(\.id))) { opt in
                                Toggle(opt.name, isOn: detectionLanguageBinding(for: opt.id))
                            }
                        }
                        Text(detectionRuleText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                GroupBox("Shortcut") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Open panel")
                            Spacer()
                            HotKeyRecorder(combo: hotKeyBinding)
                        }
                        Text(hotKeyBinding.wrappedValue.isValid
                             ? "Press this shortcut anywhere to open instant-translate-enhanced."
                             : "No shortcut — open instant-translate-enhanced from its menu bar icon.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        // The panel's text-size keys have no menu to be found in, so
                        // this line is the only place in the app that names them ().
                        Text("In the panel, ⌘+ / ⌘− / ⌘0 make the text bigger, smaller, or back to normal.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                GroupBox("Behaviour") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Translate automatically as you type", isOn: $autoTranslate)
                        Toggle("Seed from clipboard when opened by hotkey", isOn: $clipboardAutoTranslate)
                        Toggle("Copy result automatically", isOn: $copyOnTranslate)
                        Toggle("Hide panel when clicking away", isOn: $hideOnDeactivate)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                // Settings is where people habitually look for a version number.
                VStack(spacing: 2) {
                    Link("https://github.com/anonymousaga/instant-translate-enhanced",
                        destination: URL(string: "https://github.com/anonymousaga/instant-translate-enhanced")!)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .textSelection(.enabled)
                    Text("instant-translate-enhanced — fork of nlink-jp/instant-translate")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(16)
            .frame(maxWidth: 480, alignment: .leading)   // don't stretch on a wide window
            .frame(maxWidth: .infinity)                   // …and center the capped content
            // Inside the scroll view, so this is the content's own height, not the
            // window's — fitting the window to it can't feed back into it.
            .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { onContentHeight($0) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { launchAtLogin = LoginItem.isEnabled }   // reflect external changes
    }

    private var selectedDetectionLanguages: [String] {
        detectionLanguages
            .split(separator: ",")
            .map { DetectionLanguageCatalog.canonicalIdentifier(String($0)) }
            .reduce(into: [String]()) { result, language in
                if !result.contains(language) { result.append(language) }
            }
    }

    private var detectionRuleText: String {
        let selected = selectedDetectionLanguages
        guard !selected.isEmpty else {
            return "Detecting from all languages."
        }
        let names = selected.map { DetectionLanguageCatalog.name(for: $0) }
        return "Detecting from: \(names.joined(separator: ", "))."
    }

    private func detectionLanguageBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: { selectedDetectionLanguages.contains(id) },
            set: { selected in
                var languages = selectedDetectionLanguages
                if selected {
                    if !languages.contains(id) { languages.append(id) }
                } else {
                    languages.removeAll { $0 == id }
                }
                detectionLanguages = languages.joined(separator: ",")
            })
    }
}
