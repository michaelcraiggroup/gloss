import SwiftUI
import UniformTypeIdentifiers

/// Main window layout with file import and toolbar.
struct ContentView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var fileURL: URL?
    @State private var isFileImporterPresented = false

    var body: some View {
        DocumentView(fileURL: fileURL)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        openInEditor()
                    } label: {
                        Label("Open in Editor", systemImage: "pencil.and.outline")
                    }
                    .help("Open in \(settings.editor.displayName) (⌘E)")
                    .disabled(fileURL == nil)
                    .keyboardShortcut("e", modifiers: .command)
                }
            }
            .navigationTitle(fileURL?.lastPathComponent ?? "Gloss")
            .navigationSubtitle(fileURL != nil ? "Reading Mode" : "")
            .fileImporter(
                isPresented: $isFileImporterPresented,
                allowedContentTypes: markdownTypes,
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let url = urls.first {
                    openFile(url)
                }
            }
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                handleDrop(providers)
            }
            .onOpenURL { url in
                openFile(url)
            }
            .focusedSceneValue(\.openFile, FileAction { presentFileImporter() })
            .focusedSceneValue(\.currentFileURL, fileURL)
    }

    private var markdownTypes: [UTType] {
        [UTType(filenameExtension: "md"), UTType(filenameExtension: "markdown"), .plainText]
            .compactMap { $0 }
    }

    private func presentFileImporter() {
        isFileImporterPresented = true
    }

    private func openFile(_ url: URL) {
        _ = url.startAccessingSecurityScopedResource()
        fileURL = url
        settings.lastOpenedFile = url.path
    }

    private func openInEditor() {
        guard let url = fileURL else { return }
        EditorLauncher.open(fileAt: url.path, with: settings.editor)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { data, _ in
            if let data = data as? Data,
               let path = String(data: data, encoding: .utf8),
               let url = URL(string: path),
               url.pathExtension.lowercased() == "md" || url.pathExtension.lowercased() == "markdown" {
                DispatchQueue.main.async {
                    openFile(url)
                }
            }
        }
        return true
    }
}

/// Action wrapper for focused values.
struct FileAction {
    let action: () -> Void
    func callAsFunction() { action() }
}

/// Focused value keys for menu commands.
struct OpenFileKey: FocusedValueKey {
    typealias Value = FileAction
}

struct CurrentFileURLKey: FocusedValueKey {
    typealias Value = URL
}

extension FocusedValues {
    var openFile: FileAction? {
        get { self[OpenFileKey.self] }
        set { self[OpenFileKey.self] = newValue }
    }

    var currentFileURL: URL? {
        get { self[CurrentFileURLKey.self] }
        set { self[CurrentFileURLKey.self] = newValue }
    }
}
