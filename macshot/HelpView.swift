import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    private let tokens: [(token: String, description: String)] = [
        ("{YYYY}", "4-digit year"),
        ("{MM}", "2-digit month"),
        ("{DD}", "2-digit day"),
        ("{hh}", "2-digit hour (24h)"),
        ("{mm}", "2-digit minute"),
        ("{ss}", "2-digit second"),
        ("{title}", "Captured window's title. Full-screen captures have no window, so this is \"Screen1\", \"Screen2\", etc. instead; region captures use \"Screen1 Selection\", etc."),
        ("{app}", "Captured window's owning app name. Empty for full-screen and region captures."),
        ("{NUM}", "Incrementing counter, 6 digits, shared across both hotkeys."),
        ("{RRR...}", "Random alphanumeric characters — the number of R's sets the length, e.g. {RRR} = 3 random characters."),
        ("{hashN}", "Unique hash derived from the destination folder name, truncated to N characters, e.g. {hash5} = 5 characters. Same value for every file saved into that folder — usable in the folder name and/or the filename."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Template Variables")
                .font(.title2)

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(tokens, id: \.token) { entry in
                        HStack(alignment: .top, spacing: 12) {
                            Text(entry.token)
                                .font(.system(.body, design: .monospaced))
                                .frame(width: 90, alignment: .leading)
                            Text(entry.description)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Divider()
                        .padding(.vertical, 4)

                    Text("Nested folders")
                        .font(.headline)
                    Text("Use \"/\" in the Folder Name template to create nested subfolders, e.g. \"{YYYY}/{MM}-{DD}\" creates a year folder containing a month-day folder inside it.")
                        .foregroundStyle(.secondary)

                    Divider()
                        .padding(.vertical, 4)

                    Text("Capture modes")
                        .font(.headline)
                    Text("Three independent hotkeys, each configurable in Settings → Hotkeys: Window (the focused window), Full Screen, and Region — drag out a rectangle on the dimmed overlay, release to capture just that area, or press Esc to cancel.")
                        .foregroundStyle(.secondary)

                    Divider()
                        .padding(.vertical, 4)

                    Text("Browser Content Only")
                        .font(.headline)
                    Text("Settings → Behavior → \"Browser Content Only\" (also toggleable from the menu bar dropdown) limits the Window hotkey to just a browser's web page content — no tab bar, bookmarks bar, URL bar, or window border. Only applies to window captures; Full Screen and Region are unaffected. The first capture with this enabled prompts for Accessibility permission (System Settings → Privacy & Security → Accessibility); until granted, or for non-browser windows, the full window is captured instead.")
                        .foregroundStyle(.secondary)

                    Divider()
                        .padding(.vertical, 4)

                    Text("Menu bar & notifications")
                        .font(.headline)
                    Text("The menu bar dropdown has \"Open Last Screenshot\", \"Open Last in Finder\", and \"Open Root Folder\" shortcuts, plus a \"Browser Content Only\" checkbox that mirrors the Settings → Behavior toggle of the same name. Clicking a save notification also opens that screenshot — enable \"Open Screenshot on Click\" in Settings → Notifications. Both use the same configurable app (or the system default).")
                        .foregroundStyle(.secondary)
                }
            }

            HStack(alignment: .center) {
                Text(AppVersion.displayString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420, height: 420)
    }
}
