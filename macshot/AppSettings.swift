import Carbon.HIToolbox
import Combine
import Foundation

struct FilterRule: Codable, Identifiable, Equatable {
    var id = UUID()
    var search: String
    var replace: String
}

struct HotKeyCombo: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32
    var displayKey: String
}

/// Settings are backed directly by UserDefaults (computed properties, no
/// cached stored state) so there's a single source of truth and no
/// init-ordering/didSet pitfalls to reason about.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let rootFolder = "rootFolder"
        static let folderNameTemplate = "folderNameTemplate"
        static let folderNameFilters = "folderNameFilters"
        static let filenameTemplate = "filenameTemplate"
        static let hotKey = "hotKey"
        static let fullScreenHotKey = "fullScreenHotKey"
        static let copyToClipboard = "copyToClipboard"
        static let imageFormat = "imageFormat"
        static let jpegQuality = "jpegQuality"
        static let sequenceNumber = "sequenceNumber"
        static let notifyOnSave = "notifyOnSave"
        static let notifySound = "notifySound"
    }

    private static var defaultRootFolder: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Pictures/macshot")
    }

    private static let defaultHotKey = HotKeyCombo(
        keyCode: UInt32(kVK_ANSI_9),
        modifiers: UInt32(cmdKey | shiftKey),
        displayKey: "9"
    )

    private static let defaultFullScreenHotKey = HotKeyCombo(
        keyCode: UInt32(kVK_ANSI_8),
        modifiers: UInt32(cmdKey | shiftKey),
        displayKey: "8"
    )

    // Persist before sending objectWillChange: subscribers (including our own
    // CaptureController) may read `settings.<field>` synchronously from
    // inside the notification, and objectWillChange fires before the write
    // completes if these are the other way around, so they'd observe the
    // stale value.

    var rootFolder: URL {
        get { defaults.string(forKey: Keys.rootFolder).map(URL.init(fileURLWithPath:)) ?? Self.defaultRootFolder }
        set { defaults.set(newValue.path, forKey: Keys.rootFolder); objectWillChange.send() }
    }

    var folderNameTemplate: String {
        get { defaults.string(forKey: Keys.folderNameTemplate) ?? "{YYYY}-{MM}-{DD} {title}" }
        set { defaults.set(newValue, forKey: Keys.folderNameTemplate); objectWillChange.send() }
    }

    // No extension here — the image format setting supplies it (see
    // CaptureController.applyExtension). Stripped on both read and write so
    // a value persisted before this became automatic (e.g. an old
    // "...{ss}.png") doesn't keep showing a now-misleading extension.
    var filenameTemplate: String {
        get { Self.strippingExtension(defaults.string(forKey: Keys.filenameTemplate) ?? "{hh}-{mm}-{ss}") }
        set { defaults.set(Self.strippingExtension(newValue), forKey: Keys.filenameTemplate); objectWillChange.send() }
    }

    private static func strippingExtension(_ value: String) -> String {
        let stem = (value as NSString).deletingPathExtension
        return stem.isEmpty ? value : stem
    }

    var folderNameFilters: [FilterRule] {
        get { load([FilterRule].self, key: Keys.folderNameFilters) ?? [] }
        set { save(newValue, key: Keys.folderNameFilters); objectWillChange.send() }
    }

    var hotKey: HotKeyCombo {
        get { load(HotKeyCombo.self, key: Keys.hotKey) ?? Self.defaultHotKey }
        set { save(newValue, key: Keys.hotKey); objectWillChange.send() }
    }

    var fullScreenHotKey: HotKeyCombo {
        get { load(HotKeyCombo.self, key: Keys.fullScreenHotKey) ?? Self.defaultFullScreenHotKey }
        set { save(newValue, key: Keys.fullScreenHotKey); objectWillChange.send() }
    }

    var copyToClipboard: Bool {
        get { defaults.bool(forKey: Keys.copyToClipboard) }
        set { defaults.set(newValue, forKey: Keys.copyToClipboard); objectWillChange.send() }
    }

    var imageFormat: ImageFormat {
        get { ImageFormat(rawValue: defaults.string(forKey: Keys.imageFormat) ?? "") ?? .png }
        set { defaults.set(newValue.rawValue, forKey: Keys.imageFormat); objectWillChange.send() }
    }

    var jpegQuality: Double {
        get { defaults.object(forKey: Keys.jpegQuality) != nil ? defaults.double(forKey: Keys.jpegQuality) : 0.9 }
        set { defaults.set(newValue, forKey: Keys.jpegQuality); objectWillChange.send() }
    }

    var notifyOnSave: Bool {
        get { defaults.bool(forKey: Keys.notifyOnSave) }
        set { defaults.set(newValue, forKey: Keys.notifyOnSave); objectWillChange.send() }
    }

    var notifySound: Bool {
        get { defaults.bool(forKey: Keys.notifySound) }
        set { defaults.set(newValue, forKey: Keys.notifySound); objectWillChange.send() }
    }

    /// Not settings-UI-bound, so no objectWillChange — this is an internal
    /// counter consumed once per save, not a field someone edits.
    /// `integer(forKey:)` returns 0 for a missing key, so the first capture
    /// naturally yields 1.
    func nextSequenceNumber() -> Int {
        let next = defaults.integer(forKey: Keys.sequenceNumber) + 1
        defaults.set(next, forKey: Keys.sequenceNumber)
        return next
    }

    private func save<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }

    private func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
