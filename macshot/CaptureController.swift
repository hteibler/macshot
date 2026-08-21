import Combine
import Foundation
import os.log

/// Wires the configured hotkey to permission-checked window capture,
/// rendering the destination path from the user's folder/filename templates.
final class CaptureController {
    private let log = Logger(subsystem: "at.teibler.macshot", category: "capture")
    private let settings = AppSettings.shared
    private var hotKeyManager: HotKeyManager?
    private var cancellable: AnyCancellable?
    private var registeredHotKey: HotKeyCombo?

    init() {
        let manager = HotKeyManager { [weak self] in
            Task { await self?.handleHotKey() }
        }
        hotKeyManager = manager
        applyHotKey(settings.hotKey)

        // objectWillChange fires for every settings edit, not just the hotkey,
        // since AppSettings uses computed properties over UserDefaults rather
        // than per-field publishers — cheap enough to just re-check each time.
        cancellable = settings.objectWillChange.sink { [weak self] in
            guard let self else { return }
            self.applyHotKey(self.settings.hotKey)
        }
    }

    private func applyHotKey(_ hotKey: HotKeyCombo) {
        guard hotKey != registeredHotKey else { return }
        registeredHotKey = hotKey
        hotKeyManager?.update(keyCode: hotKey.keyCode, modifiers: hotKey.modifiers)
    }

    private func handleHotKey() async {
        guard ScreenRecordingPermission.isGranted else {
            log.notice("Screen Recording permission not granted; requesting")
            ScreenRecordingPermission.request()
            return
        }

        do {
            let result = try await WindowCapture.captureFocusedWindow()
            let url = try save(result)
            log.notice("Saved capture to \(url.path, privacy: .public)")
        } catch {
            log.error("Capture failed: \(String(describing: error), privacy: .public)")
        }
    }

    private func save(_ result: WindowCaptureResult) throws -> URL {
        let context = CaptureContext(date: Date(), title: result.title, appName: result.appName)

        var folderName = TemplateRenderer.render(settings.folderNameTemplate, context: context)
        for filter in settings.folderNameFilters {
            folderName = folderName.replacingOccurrences(of: filter.search, with: filter.replace)
        }
        let fileName = TemplateRenderer.render(settings.filenameTemplate, context: context)

        let dir = settings.rootFolder.appendingPathComponent(folderName)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let url = dir.appendingPathComponent(fileName)
        try result.png.write(to: url)
        return url
    }
}
