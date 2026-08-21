import SwiftUI

struct HotKeyRecorderView: View {
    @Binding var hotKey: HotKeyCombo
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        Button(isRecording ? "Press keys…" : HotKeyFormatter.displayString(for: hotKey)) {
            isRecording ? stopRecording() : startRecording()
        }
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            hotKey = HotKeyCombo(
                keyCode: UInt32(event.keyCode),
                modifiers: HotKeyFormatter.carbonModifiers(from: event.modifierFlags),
                displayKey: (event.charactersIgnoringModifiers ?? "").uppercased()
            )
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }
}
