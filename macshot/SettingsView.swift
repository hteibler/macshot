import SwiftUI

// Placeholder configuration window (Milestone 1).
// Real settings (root folder, templates, filters, hotkey) land in Milestone 3 — see TODO.md.
struct SettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("macshot")
                .font(.title2)
            Text("Configuration is not implemented yet.")
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 320, height: 160)
    }
}
