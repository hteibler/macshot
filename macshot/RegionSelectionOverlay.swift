import AppKit

struct RegionSelectionResult {
    let rect: CGRect
    let screen: NSScreen
}

/// Presents a dimmed, click-through-proof overlay on one screen for
/// dragging out a capture rectangle — the macshot equivalent of macOS's
/// built-in Cmd+Shift+4. Runs on the main actor since it's pure AppKit UI;
/// callers `await` it from wherever a hotkey handler happens to run.
@MainActor
final class RegionSelectionOverlay {
    private var window: NSWindow?
    private var continuation: CheckedContinuation<RegionSelectionResult?, Never>?

    /// Resolves with the dragged rect (screen-local points, top-left
    /// origin) once the user releases the mouse, or nil if they pressed Esc
    /// or dragged a zero-size rect.
    func presentOnScreenUnderCursor() async -> RegionSelectionResult? {
        let cursorLocation = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(cursorLocation) }) ?? NSScreen.main else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            present(on: screen)
        }
    }

    private func present(on screen: NSScreen) {
        let view = SelectionView(frame: NSRect(origin: .zero, size: screen.frame.size))
        view.onFinish = { [weak self] rect in self?.finish(rect: rect, screen: screen) }
        view.onCancel = { [weak self] in self?.finish(rect: nil, screen: screen) }

        let window = OverlayWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .screenSaver
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.contentView = view

        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeFirstResponder(view)
    }

    private func finish(rect: CGRect?, screen: NSScreen) {
        window?.orderOut(nil)
        window = nil
        continuation?.resume(returning: rect.map { RegionSelectionResult(rect: $0, screen: screen) })
        continuation = nil
    }
}

// Borderless windows can't become key by default, which means no keyDown
// events — needed so Esc can cancel the selection.
private final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private final class SelectionView: NSView {
    var onFinish: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    private var startPoint: NSPoint?
    private var currentRect: NSRect = .zero

    // Top-left origin to match CGImage's cropping coordinate space directly
    // — see WindowCapture.captureRegion.
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let dimPath = NSBezierPath(rect: bounds)
        if currentRect.width > 0, currentRect.height > 0 {
            dimPath.append(NSBezierPath(rect: currentRect))
        }
        dimPath.windingRule = .evenOdd
        NSColor.black.withAlphaComponent(0.25).setFill()
        dimPath.fill()

        guard currentRect.width > 0, currentRect.height > 0 else { return }

        NSColor.white.setStroke()
        let border = NSBezierPath(rect: currentRect)
        border.lineWidth = 1
        border.stroke()

        drawDimensionLabel(for: currentRect)
    }

    private func drawDimensionLabel(for rect: NSRect) {
        let text = "\(Int(rect.width)) × \(Int(rect.height))"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let textSize = text.size(withAttributes: attrs)
        let padding: CGFloat = 4
        var origin = NSPoint(x: rect.minX, y: rect.minY - textSize.height - padding * 2)
        if origin.y < 0 { origin.y = rect.minY + padding }

        let backgroundRect = NSRect(
            x: origin.x,
            y: origin.y,
            width: textSize.width + padding * 2,
            height: textSize.height + padding * 2
        )
        NSColor.black.withAlphaComponent(0.6).setFill()
        NSBezierPath(roundedRect: backgroundRect, xRadius: 4, yRadius: 4).fill()
        text.draw(at: NSPoint(x: origin.x + padding, y: origin.y + padding), withAttributes: attrs)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        startPoint = point
        currentRect = NSRect(origin: point, size: .zero)
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = startPoint else { return }
        let point = convert(event.locationInWindow, from: nil)
        currentRect = NSRect(
            x: min(start.x, point.x),
            y: min(start.y, point.y),
            width: abs(point.x - start.x),
            height: abs(point.y - start.y)
        )
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard currentRect.width > 2, currentRect.height > 2 else {
            onCancel?()
            return
        }
        onFinish?(currentRect)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            onCancel?()
        } else {
            super.keyDown(with: event)
        }
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }
}
