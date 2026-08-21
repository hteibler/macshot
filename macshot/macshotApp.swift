import SwiftUI

@main
struct MacshotApp: App {
    var body: some Scene {
        MenuBarExtra("macshot", systemImage: "camera.viewfinder") {
            MenuBarMenu()
        }

        Settings {
            SettingsView()
        }
    }
}
