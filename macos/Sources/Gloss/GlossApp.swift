import SwiftUI
import SwiftData
import PDFKit
import WebKit

class GlossAppDelegate: NSObject, NSApplicationDelegate {
    /// A file/folder open macOS delivered before the SwiftUI window mounted
    /// (cold launch via Finder). The notification below can fire before
    /// ContentView's observer subscribes, so we also stash it here and drain it
    /// from `.onAppear`. Both accesses are on the main thread.
    nonisolated(unsafe) static var pendingOpenURL: URL?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    // Called when the user launches Gloss while it's already running (e.g. clicks the dock icon).
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        sender.windows.first { !($0 is NSPanel) }?.makeKeyAndOrderFront(nil)
        sender.activate(ignoringOtherApps: true)
        return true
    }

    // The single route for a file/folder open (running app OR cold launch).
    // The WindowGroup no longer declares `handlesExternalEvents`, so SwiftUI no
    // longer spawns a second window per external open — the open is routed here
    // and reuses the existing window (#52).
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        Self.pendingOpenURL = url
        NotificationCenter.default.post(name: .glossOpenPath, object: url)
        application.windows.first { !($0 is NSPanel) }?.makeKeyAndOrderFront(nil)
        application.activate(ignoringOtherApps: true)
    }
}

@main
struct GlossApp: App {
    @NSApplicationDelegateAdaptor(GlossAppDelegate.self) var appDelegate
    @StateObject private var settings = AppSettings()
    @State private var fileTree = FileTreeModel()
    @State private var enhancedSearch = EnhancedSearchService()
    @State private var filenameSearch = FilenameSearchService()
    @State private var store = StoreManager()
    @State private var linkIndex = LinkIndex()
    @State private var favoritesService = FavoritesService()
    @State private var vaultOverview = VaultOverviewService()
    @State private var graphService = GraphService()
    @State private var guideService = GlossGuideService()
    @State private var templateFill = TemplateFillService()
    @State private var ubiquityStore = UbiquityVaultStore()
    @StateObject private var quickCapture = QuickCaptureController()
    @FocusedValue(\.toggleFavorite) var toggleFavorite
    @FocusedValue(\.toggleInspector) var toggleInspector
    @FocusedValue(\.goBack) var goBack
    @FocusedValue(\.goForward) var goForward
    @FocusedValue(\.toggleEditMode) var toggleEditMode
    @FocusedValue(\.saveDocument) var saveDocument
    @FocusedValue(\.createNewFile) var createNewFile
    @FocusedValue(\.todaysNote) var todaysNote
    @FocusedValue(\.isEditingDocument) var isEditingDocument
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(.glossAccent)
                .environmentObject(settings)
                .environment(fileTree)
                .environment(enhancedSearch)
                .environment(filenameSearch)
                .environment(store)
                .environment(linkIndex)
                .environment(favoritesService)
                .environment(vaultOverview)
                .environment(graphService)
                .environment(guideService)
                .environment(templateFill)
                .environment(ubiquityStore)
                .preferredColorScheme(settings.colorSchemeAppearance.colorScheme)
                .frame(minWidth: 600, minHeight: 400)
                .onAppear {
                    setAppIcon()
                    ubiquityStore.start()
                    // Repair an interrupted Move-Vault-to-iCloud before the
                    // vault restore reads rootFolderPath (cheap: two stats).
                    VaultMigrator.healPendingMigration(settings: settings)
                    // Reap index directories for vaults that no longer exist
                    // (container vaults keep their index in App Support).
                    Task.detached(priority: .background) {
                        VaultPaths.sweepStaleIndexDirectories()
                    }
                    handleCLIArguments()
                    restoreFolder()
                    // Cold-launch file open (Finder double-click on a not-running
                    // app): the .glossOpenPath notification may have fired before
                    // this view subscribed, so drain the stashed URL here.
                    if let pending = GlossAppDelegate.pendingOpenURL {
                        GlossAppDelegate.pendingOpenURL = nil
                        openPath(pending)
                    }
                    quickCapture.start(settings: settings) { url in
                        fileTree.refreshAfterFileChange()
                        linkIndex.updateIndex(for: url)
                    }
                }
                .onChange(of: store.isUnlocked) { _, unlocked in
                    // restoreFolder() at launch races checkEntitlement(): on a
                    // fresh binary the receipt verification can resolve after
                    // onAppear, silently skipping the vault restore (#38).
                    // Retry once the unlock lands.
                    if unlocked && !fileTree.hasFolder {
                        restoreFolder()
                    }
                }
                .onChange(of: ubiquityStore.state) { _, newState in
                    // A container vault can't be read until the first
                    // url(forUbiquityContainerIdentifier:) call of this launch
                    // resolves (restoreFolder defers in that case) — retry when
                    // the container comes up, mirroring the unlock retry above.
                    if case .available = newState, !fileTree.hasFolder {
                        restoreFolder()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .glossOpenPath)) { note in
                    // Single open route for the running app. Clear the
                    // cold-launch stash so a later onAppear can't re-open.
                    GlossAppDelegate.pendingOpenURL = nil
                    if let url = note.object as? URL {
                        openPath(url)
                    }
                }
        }
        .modelContainer(for: RecentDocument.self)
        .defaultSize(width: 1100, height: 700)
        .windowStyle(.hiddenTitleBar)   // frameless chrome — toolbar blends into the window
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New File") {
                    createNewFile?.run()
                }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(createNewFile == nil || (!fileTree.hasFolder && settings.currentFileURL == nil))

                Button("Today's Note") {
                    todaysNote?.run()
                }
                .keyboardShortcut("t", modifiers: .command)
                // No hasFolder gate: with no vault open, the action reopens
                // the most recent vault (or asks for one) instead of being a
                // dead shortcut at launch (#63).
                .disabled(todaysNote == nil)

                Divider()

                Button("Open…") {
                    openFilePanel()
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("Open Vault…") {
                    guard store.gate(.folderSidebar) else { return }
                    openFolderPanel()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Button("New Vault…") {
                    guard store.gate(.folderSidebar) else { return }
                    newVaultPanel()
                }
                .keyboardShortcut("v", modifiers: [.command, .shift])

                Menu("Open Recent Vault") {
                    ForEach(recentVaultChoices, id: \.self) { path in
                        Button(URL(fileURLWithPath: path).lastPathComponent) {
                            openVault(at: path)
                        }
                    }
                    Divider()
                    Button("Clear Menu") {
                        settings.clearRecentVaults()
                    }
                }
                .disabled(recentVaultChoices.isEmpty)

                Divider()

                Button("Close Vault") {
                    linkIndex.close()
                    SecurityScopedBookmarks.shared.useVault(nil)
                    fileTree.closeFolder()
                    settings.rootFolderPath = ""
                }
                .disabled(!fileTree.hasFolder)

                Divider()

                // Both land on the same sheet — it adapts to the vault's
                // location (local → move flow; container → pairing QR).
                Button("Move Vault to iCloud…") {
                    NotificationCenter.default.post(name: .glossSetUpiPhone, object: nil)
                }
                .disabled(!fileTree.hasFolder)

                Button("Set Up iPhone…") {
                    NotificationCenter.default.post(name: .glossSetUpiPhone, object: nil)
                }
                .disabled(!fileTree.hasFolder)

                Divider()

                Button(isEditingDocument == true ? "Switch to Reading Mode" : "Switch to Edit Mode") {
                    toggleEditMode?.run()
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
                    toggleFavorite?.run()
                }
                .keyboardShortcut("d", modifiers: .command)
                .disabled(toggleFavorite == nil)

                Divider()

                Button("Save Filled Copy…") {
                    NotificationCenter.default.post(name: .glossSaveFilled, object: nil)
                }
                // Only meaningful for documents with fillable content (task
                // lists / md+ template blocks) in read mode — otherwise the
                // fill bridge isn't even injected and the command is a silent
                // no-op (#66).
                .disabled(settings.currentFileURL == nil
                          || !templateFill.currentDocumentIsFillable
                          || isEditingDocument == true)
            }
        }

        .commands {
            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    saveDocument?.run()
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
                    // Strip find highlights first so they don't bake into the printout.
                    webView.evaluateJavaScript("if (typeof clearHighlights === 'function') clearHighlights(); document.documentElement.outerHTML") { htmlResult, _ in
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
                    DropAcceptingWebView.current?.exportToPDF()
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
                    goBack?.run()
                }
                .keyboardShortcut("[", modifiers: .command)
                .disabled(goBack == nil)

                Button("Forward") {
                    goForward?.run()
                }
                .keyboardShortcut("]", modifiers: .command)
                .disabled(goForward == nil)

                Divider()
            }
            CommandGroup(after: .toolbar) {
                Button(settings.isZenMode ? "Exit Zen Mode" : "Enter Zen Mode") {
                    withAnimation { settings.isZenMode.toggle() }
                }
                // ⌃⌘Z, not ⌘\ — 1Password's global autofill hotkey defaults
                // to ⌘\ and swallows the keystroke before Gloss sees it (#69).
                .keyboardShortcut("z", modifiers: [.command, .control])

                Button("Toggle Inspector") {
                    toggleInspector?.run() // gate is in ContentView's focusedSceneValue
                }
                .keyboardShortcut("i", modifiers: [.command, .option])
                .disabled(toggleInspector == nil)

                if GlossFeatures.vaultGraph {
                    Button("Show Vault Graph") {
                        NotificationCenter.default.post(name: .glossShowGraph, object: nil)
                    }
                    .keyboardShortcut("g", modifiers: [.command, .option])
                    .disabled(!fileTree.hasFolder)
                }

                Divider()

                // Read-mode page zoom. ⌘= is the no-Shift zoom-in convention
                // (Safari/Chrome/Xcode bind the "=" key too).
                Button("Zoom In") {
                    settings.zoomIn()
                    postZoomChanged()
                }
                .keyboardShortcut("=", modifiers: .command)
                .disabled(settings.currentFileURL == nil)

                Button("Zoom Out") {
                    settings.zoomOut()
                    postZoomChanged()
                }
                .keyboardShortcut("-", modifiers: .command)
                .disabled(settings.currentFileURL == nil)

                Button("Actual Size") {
                    settings.resetZoom()
                    postZoomChanged()
                }
                .keyboardShortcut("0", modifiers: .command)
                .disabled(settings.currentFileURL == nil)
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

        MenuBarExtra("Gloss Quick Capture", systemImage: "bolt.fill") {
            Button("Quick Capture…") {
                quickCapture.showPanel()
            }
            Divider()
            Button("Quick Capture Settings…") {
                openWindow(id: "settings")
            }
            Button("Quit Gloss") {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    /// Broadcast the current zoom level to the read-mode WebView so it applies
    /// live (no re-render). The persisted `settings.zoomLevel` is the source of
    /// truth; this just carries it to the imperative webview layer.
    private func postZoomChanged() {
        NotificationCenter.default.post(name: .glossZoomChanged, object: settings.zoomLevel)
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
            SecurityScopedBookmarks.shared.save(url)
            settings.currentFileURL = url
            settings.lastOpenedFile = url.standardizedFileURL.path
        }
    }

    private func openFolderPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "Open Vault"
        if panel.runModal() == .OK, let url = panel.url {
            SecurityScopedBookmarks.shared.save(url)
            SecurityScopedBookmarks.shared.useVault(url)
            fileTree.openFolder(url)
            settings.rootFolderPath = url.path
            linkIndex.buildIndex(rootURL: url)
        }
    }

    /// Create a brand-new vault folder and open it (⇧⌘V). The save panel's
    /// grant covers the created directory, so its security-scoped bookmark
    /// can be captured immediately (#65).
    private func newVaultPanel() {
        let panel = NSSavePanel()
        panel.title = "New Vault"
        panel.prompt = "Create"
        panel.nameFieldLabel = "Vault Name:"
        panel.nameFieldStringValue = "New Vault"
        panel.canCreateDirectories = true
        panel.showsTagField = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            // No intermediates: New Vault must not silently adopt an existing
            // folder (and everything in it) as a "new" vault — surface the
            // name collision instead.
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Could Not Create Vault"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
            return
        }
        // The single open route (openPath): bookmark capture, vault swap,
        // index build — identical to every other entry point.
        NotificationCenter.default.post(name: .glossOpenPath, object: url)
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

    /// Recent-vault menu entries: everything but the vault that's already open.
    private var recentVaultChoices: [String] {
        settings.recentVaultPaths.filter { $0 != settings.vaultKey }
    }

    /// Reopen a known vault by path — the openFolderPanel shape minus the
    /// panel. Vanished folders are dropped from the menu instead of no-oping.
    private func openVault(at path: String) {
        guard store.gate(.folderSidebar) else { return }
        let url = URL(fileURLWithPath: path)
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            settings.removeRecentVault(path)
            return
        }
        SecurityScopedBookmarks.shared.useVault(url)
        fileTree.openFolder(url)
        settings.rootFolderPath = url.path
        linkIndex.buildIndex(rootURL: url)
    }

    private func restoreFolder() {
        guard store.isUnlocked else { return }
        let path = settings.rootFolderPath
        guard !path.isEmpty else { return }
        let url = URL(fileURLWithPath: path)
        if UbiquityVaultStore.isUbiquitousPath(url) {
            // The container isn't readable until this launch's ubiquity
            // bootstrap resolves — defer; the ubiquityStore.state onChange
            // re-runs this restore the moment the container is available.
            guard case .available = ubiquityStore.state else { return }
        }
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
            // Resume scoped access to the vault before scanning it — under
            // sandbox the stored path alone can't be read after relaunch (#55).
            SecurityScopedBookmarks.shared.useVault(url)
            fileTree.openFolder(url)
            // Defer indexing one tick so first-frame rendering isn't racing
            // the vault scan (the scan itself is mtime-incremental now).
            Task { @MainActor in
                linkIndex.buildIndex(rootURL: url)
            }
        }
    }

    private func openPath(_ url: URL) {
        // A path delivered via Finder/drag/`open` is user-granted this session —
        // capture a security-scoped bookmark so it stays readable after relaunch
        // (recents/favorites) under the sandbox (#55).
        SecurityScopedBookmarks.shared.save(url)
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
            guard store.gate(.folderSidebar) else { return }
            SecurityScopedBookmarks.shared.useVault(url)
            fileTree.openFolder(url)
            settings.rootFolderPath = url.path
            linkIndex.buildIndex(rootURL: url)
        } else if ["md", "markdown"].contains(url.pathExtension.lowercased()) {
            settings.currentFileURL = url
            settings.lastOpenedFile = url.standardizedFileURL.path
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
        let dest = "/usr/local/bin/gloss"
        let fm = FileManager.default

        // Locate the bundled CLI script. Xcode builds copy it into
        // Contents/Resources (project.yml `buildPhase: resources`); SPM
        // builds process it into the module bundle instead, where only
        // Bundle.module can see it (#67).
        let scriptURL: URL?
        #if XCODE_BUILD
        scriptURL = Bundle.main.url(forResource: "gloss", withExtension: nil)
        #else
        scriptURL = Bundle.module.url(forResource: "gloss", withExtension: nil)
        #endif

        guard let scriptSource = scriptURL?.path, fm.fileExists(atPath: scriptSource) else {
            let alert = NSAlert()
            alert.messageText = "CLI Script Not Found"
            alert.informativeText = "This copy of Gloss is missing the gloss command-line script. Try downloading Gloss again."
            alert.runModal()
            return
        }

        // Quoted: the app can live at a spaced path ("/Applications/Gloss
        // Beta.app"), and an unquoted ln argument splits there.
        let command = "sudo ln -sf \"\(scriptSource)\" \(dest)"

        // Show the installation dialog with command to copy
        let alert = NSAlert()
        alert.messageText = "Install Command Line Tool"
        alert.informativeText = "To install the CLI tool, open Terminal and run:\n\n\(command)\n\nThen paste your Mac password when prompted."
        alert.addButton(withTitle: "Copy Command")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(command, forType: .string)

            let confirmAlert = NSAlert()
            confirmAlert.messageText = "Command Copied"
            confirmAlert.informativeText = "The installation command has been copied to your clipboard.\n\n1. Open Terminal\n2. Paste the command (Cmd+V)\n3. Press Enter\n4. Enter your Mac password"
            confirmAlert.addButton(withTitle: "Open Terminal")
            confirmAlert.addButton(withTitle: "Done")

            if confirmAlert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Utilities/Terminal.app"))
            }
        }
    }
}
