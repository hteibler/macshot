import AppKit
import ServiceManagement
import SwiftUI
import os.log

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var launchAtLoginEnabled = SMAppService.mainApp.status == .enabled

    private let log = Logger(subsystem: "at.teibler.macshot", category: "settings")

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Startup") {
                    Toggle("Launch at Login", isOn: $launchAtLoginEnabled)
                        .onChange(of: launchAtLoginEnabled) { _, newValue in
                            setLaunchAtLogin(newValue)
                        }
                }

                Section("Root Folder") {
                    HStack {
                        Text(settings.rootFolder.path)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button("Choose…") { chooseRootFolder() }
                        Spacer()
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

            Divider()

            HStack {
                Button("Close") { closeWindow() }
                    .keyboardShortcut(.defaultAction)
                Spacer()
            }
            .padding(12)
        }
        .frame(width: 420)
    }

    private func closeWindow() {
        NSApp.keyWindow?.performClose(nil)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            log.error("Failed to \(enabled ? "register" : "unregister", privacy: .public) launch-at-login: \(String(describing: error), privacy: .public)")
            launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
        }
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
