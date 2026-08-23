import Foundation
import UserNotifications
import os.log

enum CaptureNotifier {
    private static let log = Logger(subsystem: "at.teibler.macshot", category: "notifications")

    // Safe to call every time the toggle switches on: the system caches the
    // user's decision and just returns it without re-prompting once granted
    // or denied.
    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                log.error("Notification authorization failed: \(String(describing: error), privacy: .public)")
            } else if !granted {
                log.notice("Notification authorization denied")
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
            }
        }
    }
}
