import SwiftUI

@main
struct GlossApp: App {
    @StateObject private var settings = AppSettings()
    @FocusedValue(\.openFile) private var openFile
    @FocusedValue(\.currentFileURL) private var currentFileURL

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .preferredColorScheme(settings.colorSchemeAppearance.colorScheme)
                .frame(minWidth: 500, minHeight: 400)
        }
        .defaultSize(width: 900, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open…") {
                    openFile?()
                }
                .keyboardShortcut("o", modifiers: .command)

                Divider()

                Button("Open in Editor") {
                    if let url = currentFileURL {
                        EditorLauncher.open(fileAt: url.path, with: settings.editor)
                    }
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(currentFileURL == nil)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(settings)
        }
    }
}
