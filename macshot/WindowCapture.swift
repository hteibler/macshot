import AppKit
import ApplicationServices
import ScreenCaptureKit

enum WindowCaptureError: Error {
    case noFocusedWindow
    case noDisplay
}

struct WindowCaptureResult {
    let image: CGImage
    let title: String
    let appName: String
    /// The active tab's URL, when `contentOnly` was requested and the
    /// window belongs to a browser. nil otherwise.
    let browserURL: String?

    init(image: CGImage, title: String, appName: String, browserURL: String? = nil) {
        self.image = image
        self.title = title
        self.appName = appName
        self.browserURL = browserURL
    }
}

enum WindowCapture {
    static func captureFocusedWindow(contentOnly: Bool) async throws -> WindowCaptureResult {
        guard let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier else {
            throw WindowCaptureError.noFocusedWindow
        }

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        let candidates = content.windows.filter {
            $0.owningApplication?.processID == frontmostPID && $0.isOnScreen && $0.windowLayer == 0
        }
        // An app can own several on-screen windows (e.g. Teams chat windows
        // alongside the screen-sharing window); the first in z-order isn't
        // necessarily the focused one, so match the Accessibility focused
        // window's frame when possible.
        let focusedFrame = focusedWindowFrame(forPID: frontmostPID)
        guard let window = candidates.first(where: { candidate in
            guard let focusedFrame else { return false }
            return abs(candidate.frame.origin.x - focusedFrame.origin.x) < 2
                && abs(candidate.frame.origin.y - focusedFrame.origin.y) < 2
                && abs(candidate.frame.width - focusedFrame.width) < 2
                && abs(candidate.frame.height - focusedFrame.height) < 2
        }) ?? candidates.first else {
            throw WindowCaptureError.noFocusedWindow
        }

        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        // window.frame is in ScreenCaptureKit's global space (origin top-left
        // of the primary display, y down). NSScreen.frame is in AppKit's
        // space (origin bottom-left of the primary display, y up) — flip y
        // through the primary screen's height before matching, or this
        // silently fails (and falls back to the wrong display's scale) for
        // any window on a secondary display with a negative Cocoa origin.
        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? 0
        let center = CGPoint(x: window.frame.midX, y: primaryScreenHeight - window.frame.midY)
        let scale = NSScreen.screens.first(where: { $0.frame.contains(center) })?.backingScaleFactor
            ?? NSScreen.main?.backingScaleFactor
            ?? 2
        config.width = Int(window.frame.width * scale)
        config.height = Int(window.frame.height * scale)
        config.showsCursor = false

        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)

        var resultImage = image
        if contentOnly, let contentFrame = await BrowserContentLocator.contentFrame(forPID: frontmostPID) {
            let pixelRect = CGRect(
                x: (contentFrame.origin.x - window.frame.origin.x) * scale,
                y: (contentFrame.origin.y - window.frame.origin.y) * scale,
                width: contentFrame.width * scale,
                height: contentFrame.height * scale
            ).integral.intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))

            if !pixelRect.isEmpty, let cropped = image.cropping(to: pixelRect) {
                resultImage = cropped
            }
        }

        let browserURL = contentOnly ? BrowserContentLocator.documentURL(forPID: frontmostPID) : nil

        return WindowCaptureResult(
            image: resultImage,
            title: window.title ?? "",
            appName: window.owningApplication?.applicationName ?? "",
            browserURL: browserURL
        )
    }

    /// Frame of `pid`'s focused window via Accessibility, in the same
    /// top-left-origin global space as `SCWindow.frame`. nil if Accessibility
    /// isn't granted or the lookup fails (callers fall back to z-order).
    private static func focusedWindowFrame(forPID pid: pid_t) -> CGRect? {
        guard AccessibilityPermission.isGranted else { return nil }
        let app = AXUIElementCreateApplication(pid)
        var windowRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &windowRef) == .success,
              let windowRef, CFGetTypeID(windowRef) == AXUIElementGetTypeID() else { return nil }
        let window = windowRef as! AXUIElement

        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        var origin = CGPoint.zero
        var size = CGSize.zero
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionRef) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let positionRef, let sizeRef,
              AXValueGetValue(positionRef as! AXValue, .cgPoint, &origin),
              AXValueGetValue(sizeRef as! AXValue, .cgSize, &size) else { return nil }
        return CGRect(origin: origin, size: size)
    }

    /// Captures the whole display currently under the mouse cursor (falls
    /// back to the main display if that lookup fails).
    static func captureFullScreen() async throws -> WindowCaptureResult {
        let cursorLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(cursorLocation) }) ?? NSScreen.main
        guard let displayID = (screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value else {
            throw WindowCaptureError.noDisplay
        }

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw WindowCaptureError.noDisplay
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        let scale = screen?.backingScaleFactor ?? 2
        config.width = Int(CGFloat(display.width) * scale)
        config.height = Int(CGFloat(display.height) * scale)
        config.showsCursor = false

        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)

        // No single owning window/app for a full-screen capture — use the
        // screen's position in NSScreen.screens (1-based) as the title instead.
        let screenIDs = NSScreen.screens.compactMap {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
        }
        let screenNumber = (screenIDs.firstIndex(of: displayID) ?? 0) + 1

        return WindowCaptureResult(image: image, title: "Screen\(screenNumber)", appName: "")
    }

    /// Captures `rect` (in `screen`'s local point space, top-left origin —
    /// matching RegionSelectionOverlay's flipped selection view) out of a
    /// full capture of that display, scaled to pixels and cropped.
    static func captureRegion(rect: CGRect, screen: NSScreen) async throws -> WindowCaptureResult {
        guard let displayID = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value else {
            throw WindowCaptureError.noDisplay
        }

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw WindowCaptureError.noDisplay
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        let scale = screen.backingScaleFactor
        config.width = Int(CGFloat(display.width) * scale)
        config.height = Int(CGFloat(display.height) * scale)
        config.showsCursor = false

        let fullImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)

        let imageBounds = CGRect(x: 0, y: 0, width: fullImage.width, height: fullImage.height)
        let pixelRect = CGRect(
            x: rect.origin.x * scale,
            y: rect.origin.y * scale,
            width: rect.width * scale,
            height: rect.height * scale
        ).integral.intersection(imageBounds)

        guard !pixelRect.isEmpty, let cropped = fullImage.cropping(to: pixelRect) else {
            throw WindowCaptureError.noDisplay
        }

        let screenIDs = NSScreen.screens.compactMap {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
        }
        let screenNumber = (screenIDs.firstIndex(of: displayID) ?? 0) + 1

        return WindowCaptureResult(image: cropped, title: "Screen\(screenNumber) Selection", appName: "")
    }
}
