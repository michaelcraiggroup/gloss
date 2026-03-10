import SwiftUI
import SwiftData

class GlossAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct GlossApp: App {
    @NSApplicationDelegateAdaptor(GlossAppDelegate.self) var appDelegate
    @StateObject private var settings = AppSettings()
    @State private var fileTree = FileTreeModel()
    @State private var contentSearch = ContentSearchService()
    @State private var store = StoreManager()
    @FocusedValue(\.toggleFavorite) var toggleFavorite
    @FocusedValue(\.toggleInspector) var toggleInspector
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environment(fileTree)
                .environment(contentSearch)
                .environment(store)
                .preferredColorScheme(settings.colorSchemeAppearance.colorScheme)
                .frame(minWidth: 600, minHeight: 400)
                .onAppear {
                    setAppIcon()
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
                    guard store.gate(.folderSidebar) else { return }
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

                Divider()

                Button("Toggle Favorite") {
                    toggleFavorite?()
                }
                .keyboardShortcut("d", modifiers: .command)
                .disabled(toggleFavorite == nil)

                Divider()

                Button("Print…") {
                    guard store.gate(.printExport) else { return }
                    NotificationCenter.default.post(name: .glossPrint, object: nil)
                }
                .keyboardShortcut("p", modifiers: .command)
                .disabled(settings.currentFileURL == nil)

                Button("Export as PDF…") {
                    guard store.gate(.printExport) else { return }
                    NotificationCenter.default.post(name: .glossExportPDF, object: nil)
                }
                .keyboardShortcut("e", modifiers: [.command])
                .disabled(settings.currentFileURL == nil)
            }
        }

        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    openWindow(id: "settings")
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            CommandGroup(after: .textEditing) {
                Button("Find…") {
                    guard store.gate(.findInPage) else { return }
                    NotificationCenter.default.post(name: .glossFindInPage, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)

                Button("Find Next") {
                    guard store.gate(.findInPage) else { return }
                    NotificationCenter.default.post(name: .glossFindNext, object: nil)
                }
                .keyboardShortcut("g", modifiers: .command)

                Button("Find Previous") {
                    guard store.gate(.findInPage) else { return }
                    NotificationCenter.default.post(name: .glossFindPrevious, object: nil)
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
            }
            CommandGroup(after: .toolbar) {
                Button(settings.isZenMode ? "Exit Zen Mode" : "Enter Zen Mode") {
                    withAnimation { settings.isZenMode.toggle() }
                }
                .keyboardShortcut("\\", modifiers: .command)

                Button("Toggle Inspector") {
                    toggleInspector?() // gate is in ContentView's focusedSceneValue
                }
                .keyboardShortcut("i", modifiers: [.command, .option])
                .disabled(toggleInspector == nil)
            }
        }

        Window("Gloss Settings", id: "settings") {
            SettingsView()
                .environmentObject(settings)
                .environment(store)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 320, height: 140)
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

    private func setAppIcon() {
        #if XCODE_BUILD
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: url) {
            NSApplication.shared.applicationIconImage = icon
        }
        #else
        if let url = Bundle.module.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: url) {
            NSApplication.shared.applicationIconImage = icon
        }
        #endif
    }

    private func restoreFolder() {
        guard store.isUnlocked else { return }
        let path = settings.rootFolderPath
        guard !path.isEmpty else { return }
        let url = URL(fileURLWithPath: path)
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
            fileTree.openFolder(url)
        }
    }
}
