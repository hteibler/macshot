import Foundation

enum AppVersion {
    static var marketingVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    // Manually updated alongside each MARKETING_VERSION bump in project.yml —
    // there's no CI here to auto-stamp a real build date.
    static let buildDate = "2026-09-02"

    static var displayString: String {
        "Version \(marketingVersion) (\(buildDate))"
    }
}
