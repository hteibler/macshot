import AppKit
import Combine
import Foundation
import os.log

/// Wires the configured hotkeys (window + full-screen) to permission-checked
/// capture, rendering the destination path from the user's folder/filename
/// templates and optionally copying the result to the clipboard / posting a
/// save notification.
final class CaptureController {
    private let log = Logger(subsystem: "at.teibler.macshot", category: "capture")
    private let settings = AppSettings.shared

    private var windowHotKeyManager: HotKeyManager?
    private var fullScreenHotKeyManager: HotKeyManager?
    private var registeredWindowHotKey: HotKeyCombo?
    private var registeredFullScreenHotKey: HotKeyCombo?
    private var cancellable: AnyCancellable?

    init() {
        let windowManager = HotKeyManager(id: 1) { [weak self] in
            Task { await self?.handleHotKey(capture: WindowCapture.captureFocusedWindow) }
        }
        windowHotKeyManager = windowManager
        applyWindowHotKey(settings.hotKey)

        let fullScreenManager = HotKeyManager(id: 2) { [weak self] in
            Task { await self?.handleHotKey(capture: WindowCapture.captureFullScreen) }
        }
        fullScreenHotKeyManager = fullScreenManager
        applyFullScreenHotKey(settings.fullScreenHotKey)

        // Re-request every launch, not just when the Settings toggle flips
        // on — see CaptureNotifier.requestAuthorization for why.
        if settings.notifyOnSave {
            CaptureNotifier.requestAuthorization()
        }

        // objectWillChange fires for every settings edit, not just the hotkeys,
        // since AppSettings uses computed properties over UserDefaults rather
        // than per-field publishers — cheap enough to just re-check each time.
        cancellable = settings.objectWillChange.sink { [weak self] in
            guard let self else { return }
            self.applyWindowHotKey(self.settings.hotKey)
            self.applyFullScreenHotKey(self.settings.fullScreenHotKey)
        }
    }

    private func applyWindowHotKey(_ hotKey: HotKeyCombo) {
        guard hotKey != registeredWindowHotKey else { return }
        registeredWindowHotKey = hotKey
        windowHotKeyManager?.update(keyCode: hotKey.keyCode, modifiers: hotKey.modifiers)
    }

    private func applyFullScreenHotKey(_ hotKey: HotKeyCombo) {
        guard hotKey != registeredFullScreenHotKey else { return }
        registeredFullScreenHotKey = hotKey
        fullScreenHotKeyManager?.update(keyCode: hotKey.keyCode, modifiers: hotKey.modifiers)
    }

    private func handleHotKey(capture: @escaping () async throws -> WindowCaptureResult) async {
        guard ScreenRecordingPermission.isGranted else {
            log.notice("Screen Recording permission not granted; requesting")
            ScreenRecordingPermission.request()
            return
        }

        do {
            let result = try await capture()
            let url = try save(result)
            log.notice("Saved capture to \(url.path, privacy: .public)")

            if settings.copyToClipboard {
                copyToClipboard(result.image)
            }
            if settings.notifyOnSave {
                CaptureNotifier.notify(savedTo: url, sound: settings.notifySound)
            }
        } catch {
            log.error("Capture failed: \(String(describing: error), privacy: .public)")
        }
    }

    private func save(_ result: WindowCaptureResult) throws -> URL {
        let context = CaptureContext(
            date: Date(),
            title: result.title,
            appName: result.appName,
            sequenceNumber: settings.nextSequenceNumber()
        )

        var folderName = TemplateRenderer.render(settings.folderNameTemplate, context: context)
        for filter in settings.folderNameFilters {
            folderName = folderName.replacingOccurrences(of: filter.search, with: filter.replace)
        }

        let format = settings.imageFormat
        let renderedFileName = TemplateRenderer.render(settings.filenameTemplate, context: context)
        let fileName = Self.applyExtension(to: renderedFileName, format: format)

        let dir = settings.rootFolder.appendingPathComponent(folderName)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let url = dir.appendingPathComponent(fileName)
        let data = try ImageEncoder.encode(result.image, format: format, jpegQuality: settings.jpegQuality)
        try data.write(to: url)
        return url
    }

    // The filename template no longer carries an extension (see
    // AppSettings.filenameTemplate) — whatever's rendered gets whatever
    // trailing extension it happens to have stripped, then the correct one
    // for the selected format appended, so the file's actual bytes always
    // match its name.
    private static func applyExtension(to fileName: String, format: ImageFormat) -> String {
        let stem = (fileName as NSString).deletingPathExtension
        return "\(stem.isEmpty ? fileName : stem).\(format.fileExtension)"
    }

    // Always PNG regardless of the save format setting — lossless, and
    // universally readable by whatever the user pastes into.
    private func copyToClipboard(_ image: CGImage) {
        guard let png = try? ImageEncoder.encode(image, format: .png, jpegQuality: 1) else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(png, forType: .png)
    }
}
