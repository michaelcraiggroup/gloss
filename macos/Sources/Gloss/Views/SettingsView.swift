import SwiftUI

/// Preferences window for configuring editor, appearance, and reading settings.
struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Form {
            Section("Editor") {
                Picker("Open files in:", selection: $settings.preferredEditor) {
                    ForEach(Editor.allCases) { editor in
                        Text(editor.displayName).tag(editor.rawValue)
                    }
                }
                .pickerStyle(.menu)
            }

            Section("Appearance") {
                Picker("Theme:", selection: $settings.appearance) {
                    ForEach(Appearance.allCases) { appearance in
                        Text(appearance.displayName).tag(appearance.rawValue)
                    }
                }
                .pickerStyle(.menu)
            }

            Section("Reading") {
                Stepper("Font size: \(settings.fontSize)px", value: $settings.fontSize, in: 12...24, step: 2)
            }
        }
        .formStyle(.grouped)
        .frame(width: 350, height: 220)
    }
}
