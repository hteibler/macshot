import AppKit
import UserNotifications
import os.log

/// Handles interaction with save notifications: shows banners even while
/// macshot is the foreground app, and opens the just-saved screenshot when
/// the user clicks one (if enabled in Settings).
final class CaptureNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = CaptureNotificationDelegate()

    private let log = Logger(subsystem: "at.teibler.macshot", category: "notifications")

    private override init() {
        super.init()
    }

    // Without a delegate, UNUserNotificationCenter suppresses banners while
    // the posting app is frontmost. macshot has no windows most of the
    // time, but Settings can be open, so this still matters.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }

        // Only the banner-body click, not a dismiss/other action.
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else { return }
        guard AppSettings.shared.openScreenshotOnClick else { return }
        guard let path = response.notification.request.content.userInfo[CaptureNotifier.savedURLUserInfoKey] as? String else { return }

        openScreenshot(at: URL(fileURLWithPath: path))
    }

    private func openScreenshot(at url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            log.notice("Screenshot no longer exists at \(url.path, privacy: .public); not opening")
            return
        }

        if let appPath = AppSettings.shared.openScreenshotAppPath {
            let appURL = URL(fileURLWithPath: appPath)
            NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration()) { [log] _, error in
                if let error {
                    log.error("Failed to open screenshot with configured app: \(String(describing: error), privacy: .public)")
                }
            }
        } else {
            NSWorkspace.shared.open(url)
        }
    }
}
