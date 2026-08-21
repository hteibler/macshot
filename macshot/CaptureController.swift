import Carbon.HIToolbox
import Foundation
import os.log

/// Wires the hotkey to permission-checked window capture.
/// Save location below is a fixed placeholder — Milestone 3 replaces it
/// with the configurable root folder / folder+filename templates.
final class CaptureController {
    private let log = Logger(subsystem: "at.teibler.macshot", category: "capture")
    private var hotKeyManager: HotKeyManager?

    init() {
        hotKeyManager = HotKeyManager(
            keyCode: UInt32(kVK_ANSI_9),
            modifiers: UInt32(cmdKey | shiftKey)
        ) { [weak self] in
            Task { await self?.handleHotKey() }
        }
    }

    private func handleHotKey() async {
        guard ScreenRecordingPermission.isGranted else {
            log.notice("Screen Recording permission not granted; requesting")
            ScreenRecordingPermission.request()
            return
        }

        do {
            let png = try await WindowCapture.captureFocusedWindowPNG()
            let url = try Self.save(png)
            log.notice("Saved capture to \(url.path, privacy: .public)")
        } catch {
            log.error("Capture failed: \(String(describing: error), privacy: .public)")
        }
    }

    private static func save(_ data: Data) throws -> URL {
        let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Pictures/macshot")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let url = dir.appendingPathComponent("\(formatter.string(from: Date())).png")

        try data.write(to: url)
        return url
    }
}
