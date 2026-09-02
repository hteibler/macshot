import AppKit
import UserNotifications

/// Handles interaction with save notifications: shows banners even while
/// macshot is the foreground app, and opens the just-saved screenshot when
/// the user clicks one (if enabled in Settings).
final class CaptureNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = CaptureNotificationDelegate()

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

        ScreenshotOpener.open(URL(fileURLWithPath: path))
    }
}
