import AppKit
import os.log

/// Opens a saved screenshot with the app configured in Settings ->
/// Notifications (AppSettings.openScreenshotAppPath), or the system default
/// if none is set. Shared by the notification-click handler and the menu
/// bar's "Open Last Screenshot" item so both stay in sync.
enum ScreenshotOpener {
    private static let log = Logger(subsystem: "at.teibler.macshot", category: "notifications")

    static func open(_ url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            log.notice("Screenshot no longer exists at \(url.path, privacy: .public); not opening")
            return
        }

        if let appPath = AppSettings.shared.openScreenshotAppPath {
            let appURL = URL(fileURLWithPath: appPath)
            NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration()) { _, error in
                if let error {
                    log.error("Failed to open screenshot with configured app: \(String(describing: error), privacy: .public)")
                }
            }
        } else {
            NSWorkspace.shared.open(url)
        }
    }
}
