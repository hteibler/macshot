import Foundation
import UserNotifications
import os.log

enum CaptureNotifier {
    private static let log = Logger(subsystem: "at.teibler.macshot", category: "notifications")

    // Safe to call every time: the system caches the user's decision and
    // just returns it without re-prompting once granted or denied for the
    // app's *current* signing identity. Ad-hoc/local-only signing (no
    // Development Team configured) produces a slightly different identity
    // on every rebuild, so a grant from a previous build doesn't carry
    // over — this needs calling at every launch when the setting is
    // already on, not just when the toggle flips from off to on, or a
    // rebuilt app silently never (re-)requests it.
    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                log.error("Notification authorization failed: \(String(describing: error), privacy: .public)")
            } else {
                log.notice("Notification authorization \(granted ? "granted" : "denied", privacy: .public)")
            }
        }
    }

    static func notify(savedTo url: URL, sound: Bool) {
        let content = UNMutableNotificationContent()
        content.title = "Capture Saved"
        content.body = url.lastPathComponent
        if sound {
            content.sound = .default
        }

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                log.error("Failed to post notification: \(String(describing: error), privacy: .public)")
            } else {
                log.notice("Notification posted for \(url.lastPathComponent, privacy: .public)")
            }
        }
    }
}
