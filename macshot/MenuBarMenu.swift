import AppKit
import SwiftUI

struct MenuBarMenu: View {
    @Environment(\.openSettings) private var openSettings
    @ObservedObject private var history = CaptureHistory.shared

    var body: some View {
        Button("Open Last Screenshot") {
            guard let url = history.lastSavedURL else { return }
            ScreenshotOpener.open(url)
        }
        .disabled(history.lastSavedURL == nil)

        Button("Open Last in Finder") {
            guard let url = history.lastSavedURL else { return }
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
        .disabled(history.lastSavedURL == nil)

        Button("Open Root Folder") {
            openRootFolder()
        }

        Divider()

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

    // The root folder may not exist yet if no capture has been saved into
    // it — create it on demand so this always has somewhere to reveal.
    private func openRootFolder() {
        let url = AppSettings.shared.rootFolder
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.open(url)
    }
}
