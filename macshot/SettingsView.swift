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
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SettingsCard(title: "Startup") {
                        Toggle("Launch at Login", isOn: $launchAtLoginEnabled)
                            .onChange(of: launchAtLoginEnabled) { _, newValue in
                                setLaunchAtLogin(newValue)
                            }
                    }

                    SettingsCard(title: "Root Folder") {
                        HStack(spacing: 10) {
                            Text(settings.rootFolder.path)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer(minLength: 8)
                            Button("Choose…") { chooseRootFolder() }
                        }
                    }

                    SettingsCard(title: "Folder Name") {
                        TextField("", text: Binding(
                            get: { settings.folderNameTemplate },
                            set: { settings.folderNameTemplate = $0 }
                        ), prompt: Text("{YYYY}-{MM}-{DD} {title}"))
                        .textFieldStyle(.roundedBorder)

                        FilterListEditor(filters: Binding(
                            get: { settings.folderNameFilters },
                            set: { settings.folderNameFilters = $0 }
                        ))
                    }

                    SettingsCard(title: "Filename") {
                        TextField("", text: Binding(
                            get: { settings.filenameTemplate },
                            set: { settings.filenameTemplate = $0 }
                        ), prompt: Text("{hh}-{mm}-{ss}.png"))
                        .textFieldStyle(.roundedBorder)
                    }

                    SettingsCard(title: "Hotkeys") {
                        HStack {
                            Text("Window")
                            Spacer()
                            HotKeyRecorderView(hotKey: Binding(
                                get: { settings.hotKey },
                                set: { settings.hotKey = $0 }
                            ))
                        }
                        HStack {
                            Text("Full Screen")
                            Spacer()
                            HotKeyRecorderView(hotKey: Binding(
                                get: { settings.fullScreenHotKey },
                                set: { settings.fullScreenHotKey = $0 }
                            ))
                        }
                    }

                    SettingsCard(title: "Behavior") {
                        Toggle("Copy to Clipboard", isOn: Binding(
                            get: { settings.copyToClipboard },
                            set: { settings.copyToClipboard = $0 }
                        ))
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            HStack {
                Button("Close") { closeWindow() }
                    .keyboardShortcut(.defaultAction)
                Spacer()
                Text("Provided for free by Herbert Teibler. Distributed \"as is\" without warranty of any kind.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
            }
            .padding(12)
        }
        .frame(width: 440, height: 560)
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

private struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
