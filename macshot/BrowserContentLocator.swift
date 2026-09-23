import ApplicationServices
import Foundation

/// Locates the web content area of a browser window via the Accessibility
/// API, so "Browser Content Only" captures can crop out the tab bar,
/// bookmarks bar, URL bar, and window chrome that ScreenCaptureKit has no
/// concept of. Browsers built on WebKit/Chromium expose that area as an
/// "AXWebArea" element in the app's accessibility tree.
enum BrowserContentLocator {
    private static let webAreaRole = "AXWebArea"
    private static let maxDepth = 8
    private static let maxVisitedNodes = 400

    /// Returns the web content area's frame for `pid`'s focused window, in
    /// the same top-left-origin global coordinate space as `SCWindow.frame`.
    /// Returns nil for non-browser windows, denied Accessibility permission
    /// (also triggers the system permission prompt in that case), or any AX
    /// lookup failure — callers fall back to the full window capture.
    static func contentFrame(forPID pid: pid_t) async -> CGRect? {
        guard AccessibilityPermission.isGranted else {
            AccessibilityPermission.request()
            return nil
        }

        let app = AXUIElementCreateApplication(pid)
        guard let window = copyElement(app, kAXFocusedWindowAttribute) else { return nil }

        if let frame = webAreaFrame(in: window) {
            return frame
        }

        // Chromium-based browsers only build their full accessibility tree
        // (which includes AXWebArea for the page content) once an assistive
        // technology is detected as active; setting this private attribute
        // triggers that. The tree then populates asynchronously (observed
        // up to ~1s on first use), so poll a few times before giving up —
        // once built it stays built for the rest of that browser session.
        AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
        for _ in 0..<3 {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if let frame = webAreaFrame(in: window) {
                return frame
            }
        }
        return nil
    }

    /// Returns the active tab's URL for `pid`'s focused browser window, via
    /// the window's "AXDocument" attribute — both Safari and Chrome expose
    /// this immediately (unlike AXWebArea, it doesn't need the lazy
    /// accessibility tree). Returns nil if not granted, not a browser
    /// window, or the attribute isn't populated.
    static func documentURL(forPID pid: pid_t) -> String? {
        guard AccessibilityPermission.isGranted else { return nil }
        let app = AXUIElementCreateApplication(pid)
        guard let window = copyElement(app, kAXFocusedWindowAttribute) else { return nil }
        return copyString(window, "AXDocument")
    }

    private static func webAreaFrame(in window: AXUIElement) -> CGRect? {
        var visited = 0
        guard let webArea = findWebArea(in: window, depth: 0, visited: &visited),
              let position = copyPoint(webArea, kAXPositionAttribute),
              let size = copySize(webArea, kAXSizeAttribute) else { return nil }
        return CGRect(origin: position, size: size)
    }

    private static func findWebArea(in element: AXUIElement, depth: Int, visited: inout Int) -> AXUIElement? {
        guard depth <= maxDepth, visited < maxVisitedNodes else { return nil }
        visited += 1

        if copyString(element, kAXRoleAttribute) == webAreaRole {
            return element
        }

        guard let children = copyElements(element, kAXChildrenAttribute) else { return nil }
        for child in children {
            if let found = findWebArea(in: child, depth: depth + 1, visited: &visited) {
                return found
            }
        }
        return nil
    }

    private static func copyElement(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private static func copyElements(_ element: AXUIElement, _ attribute: String) -> [AXUIElement]? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? [AXUIElement]
    }

    private static func copyString(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private static func copyPoint(_ element: AXUIElement, _ attribute: String) -> CGPoint? {
        guard let axValue = copyAXValue(element, attribute) else { return nil }
        var point = CGPoint.zero
        guard AXValueGetValue(axValue, .cgPoint, &point) else { return nil }
        return point
    }

    private static func copySize(_ element: AXUIElement, _ attribute: String) -> CGSize? {
        guard let axValue = copyAXValue(element, attribute) else { return nil }
        var size = CGSize.zero
        guard AXValueGetValue(axValue, .cgSize, &size) else { return nil }
        return size
    }

    private static func copyAXValue(_ element: AXUIElement, _ attribute: String) -> AXValue? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        return (value as! AXValue)
    }
}
