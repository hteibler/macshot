import AppKit
import ScreenCaptureKit

enum WindowCaptureError: Error {
    case noFocusedWindow
    case noDisplay
    case encodingFailed
}

struct WindowCaptureResult {
    let png: Data
    let title: String
    let appName: String
}

enum WindowCapture {
    static func captureFocusedWindow() async throws -> WindowCaptureResult {
        guard let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier else {
            throw WindowCaptureError.noFocusedWindow
        }

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        guard let window = content.windows.first(where: {
            $0.owningApplication?.processID == frontmostPID && $0.isOnScreen && $0.windowLayer == 0
        }) else {
            throw WindowCaptureError.noFocusedWindow
        }

        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        let center = CGPoint(x: window.frame.midX, y: window.frame.midY)
        let scale = NSScreen.screens.first(where: { $0.frame.contains(center) })?.backingScaleFactor
            ?? NSScreen.main?.backingScaleFactor
            ?? 2
        config.width = Int(window.frame.width * scale)
        config.height = Int(window.frame.height * scale)
        config.showsCursor = false

        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)

        return WindowCaptureResult(
            png: try encodePNG(image),
            title: window.title ?? "",
            appName: window.owningApplication?.applicationName ?? ""
        )
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

        // No single owning window/app for a full-screen capture.
        return WindowCaptureResult(png: try encodePNG(image), title: "", appName: "")
    }

    private static func encodePNG(_ image: CGImage) throws -> Data {
        guard let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            throw WindowCaptureError.encodingFailed
        }
        return png
    }
}
