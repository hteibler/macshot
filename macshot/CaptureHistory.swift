import Foundation

/// Tracks the most recently saved capture for UI that needs it — currently
/// the menu bar's "Open Last in Finder" item. Runtime-only, not persisted:
/// there's nothing meaningful to show until the first capture of a session.
final class CaptureHistory: ObservableObject {
    static let shared = CaptureHistory()

    @Published private(set) var lastSavedURL: URL?

    private init() {}

    func recordSave(_ url: URL) {
        lastSavedURL = url
    }
}
