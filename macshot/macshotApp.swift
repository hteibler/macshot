import SwiftUI

@main
struct MacshotApp: App {
    private let captureController = CaptureController()

    var body: some Scene {
        MenuBarExtra("macshot", systemImage: "camera.viewfinder") {
            MenuBarMenu()
        }

        Settings {
            SettingsView()
        }
    }
}
