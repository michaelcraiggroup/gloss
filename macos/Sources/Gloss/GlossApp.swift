import SwiftUI

@main
struct GlossApp: App {
    @StateObject private var settings = AppSettings()

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
                    openFilePanel()
                }
                .keyboardShortcut("o", modifiers: .command)

                Divider()

                Button("Open in Editor") {
                    if let url = settings.currentFileURL {
                        EditorLauncher.open(fileAt: url.path, with: settings.editor)
                    }
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(settings.currentFileURL == nil)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(settings)
        }
    }

    private func openFilePanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText]
        panel.allowsMultipleSelection = false
        panel.title = "Open Markdown File"
        if panel.runModal() == .OK, let url = panel.url {
            settings.currentFileURL = url
            settings.lastOpenedFile = url.path
        }
    }
}
