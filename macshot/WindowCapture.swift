import AppKit
import ScreenCaptureKit

enum WindowCaptureError: Error {
    case noFocusedWindow
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

        guard let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            throw WindowCaptureError.encodingFailed
        }

        return WindowCaptureResult(
            png: png,
            title: window.title ?? "",
            appName: window.owningApplication?.applicationName ?? ""
        )
    }
}
