import AppKit
import Carbon.HIToolbox
import SwiftUI

/// A click-to-record control for a global hotkey. Clicking starts capture; the next
/// key press with at least one modifier becomes the combo. Esc cancels. While
/// recording, key events are swallowed (a local monitor returning nil) so they don't
/// type into the settings window. The × beside it removes the shortcut, like the
/// clear button of a search field; it is shown only when there is one to remove,
/// and its space is kept so the recorder never moves.
struct HotKeyRecorder: View {
    @Binding var combo: HotKeyCombo
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 4) {
            Button(action: toggle) {
                Text(recording ? "Press shortcut…" : combo.label)
                    .monospaced()
                    .frame(minWidth: 96)
            }
            .help(recording ? "Press a shortcut, or Esc to cancel" : "Click to change the shortcut")

            let removable = combo.isValid && !recording
            Button { combo = .disabled } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Remove the shortcut")
            .accessibilityLabel("Remove the shortcut")
            .opacity(removable ? 1 : 0)
            .disabled(!removable)
        }
        .onDisappear(perform: stop)
    }

    private func toggle() { recording ? stop() : start() }

    private func start() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) { stop(); return nil }
            let mods = event.modifierFlags
                .intersection(.deviceIndependentFlagsMask)
                .intersection([.command, .option, .control, .shift])
            let candidate = HotKeyCombo(keyCode: event.keyCode, modifiers: mods.rawValue)
            if candidate.isValid {
                combo = candidate
                stop()
            }
            return nil   // swallow all keys while recording
        }
    }

    private func stop() {
        recording = false
        if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
    }
}
