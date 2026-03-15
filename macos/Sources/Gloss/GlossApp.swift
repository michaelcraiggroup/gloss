import SwiftUI
import SwiftData
import PDFKit
import WebKit

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
    @FocusedValue(\.goBack) var goBack
    @FocusedValue(\.goForward) var goForward
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
                .onOpenURL { url in
                    guard ["md", "markdown"].contains(url.pathExtension.lowercased()) else { return }
                    settings.currentFileURL = url
                    settings.lastOpenedFile = url.path
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
                        EditorLauncher.open(fileAt: url.path, with: settings.editor, customAppPath: settings.customEditorPath)
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

            }
        }

        .commands {
            CommandGroup(replacing: .printItem) {
                Button("Print…") {
                    guard let webView = DropAcceptingWebView.current else { return }
                    let printInfo = NSPrintInfo.shared
                    let paperWidth = printInfo.paperSize.width - printInfo.leftMargin - printInfo.rightMargin
                    let config = WKWebViewConfiguration()
                    let printWebView = WKWebView(frame: NSRect(x: 0, y: 0, width: paperWidth, height: 800), configuration: config)
                    printWebView.setValue(false, forKey: "drawsBackground")
                    objc_setAssociatedObject(webView, "printHelper", printWebView, .OBJC_ASSOCIATION_RETAIN)
                    webView.evaluateJavaScript("document.documentElement.outerHTML") { htmlResult, _ in
                        guard let html = htmlResult as? String else { return }
                        DispatchQueue.main.async {
                            // Force light theme and tighten margins for print
                            var printHTML = html
                                .replacingOccurrences(of: "class=\"dark\"", with: "class=\"light\"")
                                .replacingOccurrences(of: "<html>", with: "<html class=\"light\">")
                            let printStyle = "<style>body { margin: 0 !important; padding: 0 !important; } .gloss-content { padding: 0 !important; margin: 0 !important; max-width: none !important; } h1:first-child, h2:first-child, h3:first-child { margin-top: 0 !important; } .heading-anchor { display: none !important; }</style></head>"
                            printHTML = printHTML.replacingOccurrences(of: "</head>", with: printStyle)
                            class PrintDelegate: NSObject, WKNavigationDelegate {
                                let printWebView: WKWebView
                                let parentWebView: WKWebView
                                init(_ wv: WKWebView, parent: WKWebView) { self.printWebView = wv; self.parentWebView = parent }
                                func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
                                    webView.createPDF { result in
                                        DispatchQueue.main.async {
                                            defer {
                                                objc_setAssociatedObject(self.parentWebView, "printHelper", nil, .OBJC_ASSOCIATION_RETAIN)
                                                objc_setAssociatedObject(self.parentWebView, "printDelegate", nil, .OBJC_ASSOCIATION_RETAIN)
                                            }
                                            guard case .success(let data) = result,
                                                  let pdfImageRep = NSPDFImageRep(data: data) else { return }
                                            let image = NSImage()
                                            image.addRepresentation(pdfImageRep)
                                            let imageView = NSImageView()
                                            imageView.image = image
                                            imageView.frame = NSRect(origin: .zero, size: pdfImageRep.bounds.size)
                                            let op = NSPrintOperation(view: imageView)
                                            op.showsPrintPanel = true
                                            op.showsProgressPanel = true
                                            op.run()
                                        }
                                    }
                                }
                            }
                            let delegate = PrintDelegate(printWebView, parent: webView)
                            objc_setAssociatedObject(webView, "printDelegate", delegate, .OBJC_ASSOCIATION_RETAIN)
                            printWebView.navigationDelegate = delegate
                            printWebView.loadHTMLString(printHTML, baseURL: nil)
                        }
                    }
                }
                .keyboardShortcut("p", modifiers: .command)
                .disabled(settings.currentFileURL == nil)

                Button("Export as PDF…") {
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
                    NotificationCenter.default.post(name: .glossFindInPage, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)

                Button("Find Next") {
                    NotificationCenter.default.post(name: .glossFindNext, object: nil)
                }
                .keyboardShortcut("g", modifiers: .command)

                Button("Find Previous") {
                    NotificationCenter.default.post(name: .glossFindPrevious, object: nil)
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
            }
            CommandGroup(before: .toolbar) {
                Button("Back") {
                    goBack?()
                }
                .keyboardShortcut("[", modifiers: .command)
                .disabled(goBack == nil)

                Button("Forward") {
                    goForward?()
                }
                .keyboardShortcut("]", modifiers: .command)
                .disabled(goForward == nil)

                Divider()
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
