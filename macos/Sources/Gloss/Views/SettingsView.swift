import SwiftUI

/// Preferences window for configuring editor and appearance.
struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Form {
            Picker("Open files in:", selection: $settings.preferredEditor) {
                ForEach(Editor.allCases) { editor in
                    Text(editor.displayName).tag(editor.rawValue)
                }
            }
            .pickerStyle(.menu)

            Picker("Appearance:", selection: $settings.appearance) {
                ForEach(Appearance.allCases) { appearance in
                    Text(appearance.displayName).tag(appearance.rawValue)
                }
            }
            .pickerStyle(.menu)
        }
        .formStyle(.grouped)
        .frame(width: 350, height: 150)
    }
}
