import SwiftUI

struct MenuBarMenu: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("Settings...") {
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        }
        .keyboardShortcut(",")

        Divider()

        Button("Quit macshot") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
