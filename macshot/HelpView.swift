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
        ("{title}", "Captured window's title. For full-screen captures there's no window, so this is \"Screen1\", \"Screen2\", etc. instead."),
        ("{app}", "Captured window's owning app name. Empty for full-screen captures."),
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

                    Text("Menu bar & notifications")
                        .font(.headline)
                    Text("The menu bar dropdown has \"Open Last in Finder\" and \"Open Root Folder\" shortcuts. Clicking a save notification opens that screenshot — enable \"Open Screenshot on Click\" in Settings → Notifications, and optionally pick which app to use.")
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420, height: 420)
    }
}
