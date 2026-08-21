import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section("Root Folder") {
                HStack {
                    Text(settings.rootFolder.path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Choose…") { chooseRootFolder() }
                }
            }

            Section("Folder Name") {
                TextField("Template", text: Binding(
                    get: { settings.folderNameTemplate },
                    set: { settings.folderNameTemplate = $0 }
                ))
                .textFieldStyle(.roundedBorder)

                FilterListEditor(filters: Binding(
                    get: { settings.folderNameFilters },
                    set: { settings.folderNameFilters = $0 }
                ))
            }

            Section("Filename") {
                TextField("Template", text: Binding(
                    get: { settings.filenameTemplate },
                    set: { settings.filenameTemplate = $0 }
                ))
                .textFieldStyle(.roundedBorder)
            }

            Section("Hotkey") {
                HotKeyRecorderView(hotKey: Binding(
                    get: { settings.hotKey },
                    set: { settings.hotKey = $0 }
                ))
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    private func chooseRootFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = settings.rootFolder

        if panel.runModal() == .OK, let url = panel.url {
            settings.rootFolder = url
        }
    }
}
