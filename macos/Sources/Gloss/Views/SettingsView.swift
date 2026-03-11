import SwiftUI
import UniformTypeIdentifiers

/// Preferences window for configuring editor, appearance, and reading settings.
struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Grid(alignment: .leading, verticalSpacing: 12) {
            GridRow {
                Text("Open files in:")
                    .gridColumnAlignment(.trailing)
                HStack(spacing: 8) {
                    Picker("", selection: $settings.preferredEditor) {
                        ForEach(Editor.allCases.filter { $0 != .custom }) { editor in
                            Text(editor.displayName).tag(editor.rawValue)
                        }
                        Divider()
                        if settings.editor == .custom, let name = customAppName {
                            Text(name).tag(Editor.custom.rawValue)
                        } else {
                            Text("Custom App…").tag(Editor.custom.rawValue)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .onChange(of: settings.preferredEditor) { _, newValue in
                        if newValue == Editor.custom.rawValue && settings.customEditorPath.isEmpty {
                            browseForApp()
                        }
                    }

                    if settings.editor == .custom {
                        Button("Change…") {
                            browseForApp()
                        }
                        .controlSize(.small)
                    }
                }
            }

            GridRow {
                Text("Theme:")
                    .gridColumnAlignment(.trailing)
                Picker("", selection: $settings.appearance) {
                    ForEach(Appearance.allCases) { appearance in
                        Text(appearance.displayName).tag(appearance.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            GridRow {
                Text("Font size:")
                    .gridColumnAlignment(.trailing)
                FontSizeStepper(fontSize: $settings.fontSize)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var customAppName: String? {
        guard !settings.customEditorPath.isEmpty else { return nil }
        let url = URL(fileURLWithPath: settings.customEditorPath)
        return url.deletingPathExtension().lastPathComponent
    }

    private func browseForApp() {
        let panel = NSOpenPanel()
        panel.title = "Choose Editor Application"
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        if panel.runModal() == .OK, let url = panel.url {
            settings.customEditorPath = url.path
            settings.preferredEditor = Editor.custom.rawValue
        } else if settings.customEditorPath.isEmpty {
            // User cancelled without selecting — revert to previous editor
            settings.preferredEditor = Editor.cursor.rawValue
        }
    }
}

/// Font size stepper that gates behind paid tier.
struct FontSizeStepper: View {
    @Binding var fontSize: Int
    @Environment(StoreManager.self) private var store

    var body: some View {
        Stepper("\(fontSize)px", value: $fontSize, in: 12...24, step: 2)
            .onChange(of: fontSize) { oldValue, newValue in
                if newValue != 16 && !store.isUnlocked {
                    fontSize = oldValue
                    _ = store.gate(.fontSizeControl)
                }
            }
    }
}
