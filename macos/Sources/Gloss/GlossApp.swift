import SwiftUI
import SwiftData

@main
struct GlossApp: App {
    @StateObject private var settings = AppSettings()
    @State private var fileTree = FileTreeModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environment(fileTree)
                .preferredColorScheme(settings.colorSchemeAppearance.colorScheme)
                .frame(minWidth: 600, minHeight: 400)
                .onAppear {
                    restoreFolder()
                }
        }
        .modelContainer(for: RecentDocument.self)
        .defaultSize(width: 1000, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open…") {
                    openFilePanel()
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("Open Folder…") {
                    openFolderPanel()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Divider()

                Button("Close Folder") {
                    fileTree.closeFolder()
                    settings.rootFolderPath = ""
                }
                .disabled(!fileTree.hasFolder)

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

    private func openFolderPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "Open Folder"
        if panel.runModal() == .OK, let url = panel.url {
            fileTree.openFolder(url)
            settings.rootFolderPath = url.path
        }
    }

    private func restoreFolder() {
        let path = settings.rootFolderPath
        guard !path.isEmpty else { return }
        let url = URL(fileURLWithPath: path)
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
            fileTree.openFolder(url)
        }
    }
}
