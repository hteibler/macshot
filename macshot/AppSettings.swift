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

    var filenameTemplate: String {
        get { defaults.string(forKey: Keys.filenameTemplate) ?? "{hh}-{mm}-{ss}.png" }
        set { defaults.set(newValue, forKey: Keys.filenameTemplate); objectWillChange.send() }
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
