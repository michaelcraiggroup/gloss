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
    @State private var enhancedSearch = EnhancedSearchService()
    @State private var store = StoreManager()
    @State private var linkIndex = LinkIndex()
    @State private var vaultOverview = VaultOverviewService()
    @State private var graphService = GraphService()
    @State private var guideService = GlossGuideService()
    @State private var templateFill = TemplateFillService()
    @FocusedValue(\.toggleFavorite) var toggleFavorite
    @FocusedValue(\.toggleInspector) var toggleInspector
    @FocusedValue(\.goBack) var goBack
    @FocusedValue(\.goForward) var goForward
    @FocusedValue(\.toggleEditMode) var toggleEditMode
    @FocusedValue(\.saveDocument) var saveDocument
    @FocusedValue(\.createNewFile) var createNewFile
    @FocusedValue(\.isEditingDocument) var isEditingDocument
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environment(fileTree)
                .environment(enhancedSearch)
                .environment(store)
                .environment(linkIndex)
                .environment(vaultOverview)
                .environment(graphService)
                .environment(guideService)
                .environment(templateFill)
                .preferredColorScheme(settings.colorSchemeAppearance.colorScheme)
                .frame(minWidth: 600, minHeight: 400)
                .onAppear {
                    setAppIcon()
                    handleCLIArguments()
                    restoreFolder()
                }
                .onOpenURL { url in
                    openPath(url)
                }
        }
        .modelContainer(for: RecentDocument.self)
        .defaultSize(width: 1100, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New File") {
                    createNewFile?()
                }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(createNewFile == nil || (!fileTree.hasFolder && settings.currentFileURL == nil))

                Divider()

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

                Button(isEditingDocument == true ? "Switch to Reading Mode" : "Switch to Edit Mode") {
                    toggleEditMode?()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(settings.currentFileURL == nil)

                Button("Open in External Editor") {
                    if let url = settings.currentFileURL {
                        EditorLauncher.open(fileAt: url.path, with: settings.editor, customAppPath: settings.customEditorPath)
                    }
                }
                .disabled(settings.currentFileURL == nil)

                Divider()

                Button("Toggle Favorite") {
                    toggleFavorite?()
                }
                .keyboardShortcut("d", modifiers: .command)
                .disabled(toggleFavorite == nil)

                Divider()

                Button("Save Filled Copy…") {
                    NotificationCenter.default.post(name: .glossSaveFilled, object: nil)
                }
                .disabled(settings.currentFileURL == nil)
            }
        }

        .commands {
            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    saveDocument?()
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(isEditingDocument != true)
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
            CommandGroup(replacing: .appInfo) {
                Button("About Gloss") {
                    let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
                    NSApplication.shared.orderFrontStandardAboutPanel(options: [
                        NSApplication.AboutPanelOptionKey(rawValue: "Version"): "",
                        NSApplication.AboutPanelOptionKey.applicationVersion: shortVersion
                    ])
                }
            }
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    openWindow(id: "settings")
                }
                .keyboardShortcut(",", modifiers: .command)

                Divider()

                Button("Install Command Line Tool…") {
                    installCLI()
                }
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

                Button("Show Vault Graph") {
                    NotificationCenter.default.post(name: .glossShowGraph, object: nil)
                }
                .keyboardShortcut("g", modifiers: [.command, .option])
                .disabled(!fileTree.hasFolder)
            }
            CommandGroup(replacing: .help) {
                Button("Getting Started Tour") {
                    openGuide(.gettingStarted)
                }
                Button("What's New: Tags") {
                    openGuide(.whatsNewTags)
                }
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

    private func openGuide(_ guide: WalkthroughGuide) {
        if let resource = guide.documentResource {
            let bundleURL: URL?
            #if XCODE_BUILD
            bundleURL = Bundle.main.url(forResource: resource, withExtension: "md")
            #else
            bundleURL = Bundle.module.url(forResource: resource, withExtension: "md")
            #endif

            if let bundleURL,
               let content = try? String(contentsOf: bundleURL, encoding: .utf8) {
                let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("gloss-guides", isDirectory: true)
                try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                let tempFile = tempDir.appendingPathComponent("\(resource).md")
                try? content.write(to: tempFile, atomically: true, encoding: .utf8)
                settings.currentFileURL = tempFile
            }
        }
        guideService.start(guide: guide)
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
            linkIndex.buildIndex(rootURL: url)
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
            linkIndex.buildIndex(rootURL: url)
        }
    }

    private func openPath(_ url: URL) {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
            guard store.gate(.folderSidebar) else { return }
            fileTree.openFolder(url)
            settings.rootFolderPath = url.path
            linkIndex.buildIndex(rootURL: url)
        } else if ["md", "markdown"].contains(url.pathExtension.lowercased()) {
            settings.currentFileURL = url
            settings.lastOpenedFile = url.path
        }
    }

    private func handleCLIArguments() {
        let args = ProcessInfo.processInfo.arguments
        guard args.count > 1 else { return }
        for arg in args.dropFirst() {
            guard !arg.hasPrefix("-") else { continue }
            let absPath: String
            if arg.hasPrefix("/") {
                absPath = (arg as NSString).standardizingPath
            } else {
                let cwd = FileManager.default.currentDirectoryPath
                absPath = (("\(cwd)/\(arg)") as NSString).standardizingPath
            }
            let url = URL(fileURLWithPath: absPath)
            guard FileManager.default.fileExists(atPath: absPath) else { continue }
            openPath(url)
            return
        }
    }

    private func installCLI() {
        let appPath = Bundle.main.bundlePath
        let scriptSource = "\(appPath)/Contents/Resources/gloss"
        let dest = "/usr/local/bin/gloss"

        guard FileManager.default.fileExists(atPath: scriptSource) else {
            let alert = NSAlert()
            alert.messageText = "CLI Script Not Found"
            alert.informativeText = "The gloss CLI script was not found in the app bundle."
            alert.runModal()
            return
        }

        let script = "do shell script \"ln -sf '\(scriptSource)' '\(dest)'\" with administrator privileges"
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
            if let error {
                let alert = NSAlert()
                alert.messageText = "Installation Failed"
                alert.informativeText = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
                alert.runModal()
            } else {
                let alert = NSAlert()
                alert.messageText = "Command Line Tool Installed"
                alert.informativeText = "You can now use 'gloss' from the terminal.\n\nUsage:\n  gloss .              Open current folder\n  gloss file.md        Open a file\n  gloss ~/notes        Open a folder"
                alert.runModal()
            }
        }
    }
}
