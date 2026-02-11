import SwiftUI

/// Preferences window for configuring editor, appearance, and reading settings.
struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Grid(alignment: .leading, verticalSpacing: 12) {
            GridRow {
                Text("Open files in:")
                    .gridColumnAlignment(.trailing)
                Picker("", selection: $settings.preferredEditor) {
                    ForEach(Editor.allCases) { editor in
                        Text(editor.displayName).tag(editor.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
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
                Stepper("\(settings.fontSize)px", value: $settings.fontSize, in: 12...24, step: 2)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
