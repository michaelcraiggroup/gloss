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
                FontSizeStepper(fontSize: $settings.fontSize)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
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
