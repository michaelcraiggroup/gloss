import SwiftUI
import SwiftData

/// File browser sidebar with recursive file tree, search, and recent documents.
struct SidebarView: View {
    @Environment(FileTreeModel.self) private var fileTree
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecentDocument.lastOpened, order: .reverse)
    private var recentDocuments: [RecentDocument]

    var body: some View {
        @Bindable var tree = fileTree

        List(selection: Binding(
            get: { fileTree.selectedFileURL },
            set: { selectFile($0) }
        )) {
            if let results = fileTree.searchResults {
                Section("Search Results") {
                    if results.isEmpty {
                        Text("No matches")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(results) { node in
                            FileTreeRow(node: node)
                                .tag(node.url)
                        }
                    }
                }
            } else {
                if let root = fileTree.rootNode {
                    Section(root.name) {
                        ForEach(root.children ?? []) { node in
                            fileTreeItem(node)
                        }
                    }
                }

                if !recentDocuments.isEmpty {
                    Section("Recent Documents") {
                        ForEach(recentDocuments.prefix(10)) { doc in
                            Label {
                                Text(doc.title)
                                    .lineLimit(1)
                            } icon: {
                                Text(doc.type.icon)
                            }
                            .tag(doc.url)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $tree.searchQuery, prompt: "Search files")
        .toolbar {
            ToolbarItem {
                Button {
                    openFolderFromSidebar()
                } label: {
                    Label("Open Folder", systemImage: "folder.badge.plus")
                }
                .help("Open Folder (⇧⌘O)")
            }
        }
    }

    private func fileTreeItem(_ node: FileTreeNode) -> AnyView {
        if node.isDirectory {
            AnyView(
                DisclosureGroup(isExpanded: Binding(
                    get: { node.isExpanded },
                    set: { expanded in
                        if expanded && node.children == nil {
                            node.loadChildren()
                        }
                        node.isExpanded = expanded
                    }
                )) {
                    ForEach(node.children ?? []) { child in
                        fileTreeItem(child)
                    }
                } label: {
                    FileTreeRow(node: node)
                }
            )
        } else {
            AnyView(
                FileTreeRow(node: node)
                    .tag(node.url)
            )
        }
    }

    private func selectFile(_ url: URL?) {
        fileTree.selectedFileURL = url
        guard let url else { return }
        settings.currentFileURL = url
        settings.lastOpenedFile = url.path
        recordRecent(url: url)
    }

    private func recordRecent(url: URL) {
        let path = url.path
        let filename = url.lastPathComponent
        let parentFolder = url.deletingLastPathComponent().lastPathComponent
        let docType = DocumentType.detect(filename: filename, folderName: parentFolder)

        // Update existing or insert new
        let descriptor = FetchDescriptor<RecentDocument>(
            predicate: #Predicate { $0.path == path }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.lastOpened = .now
            existing.documentType = docType.rawValue
        } else {
            let title = filename.replacingOccurrences(of: ".md", with: "")
                .replacingOccurrences(of: ".markdown", with: "")
            let doc = RecentDocument(path: path, title: title, documentType: docType.rawValue)
            modelContext.insert(doc)
        }
    }

    private func openFolderFromSidebar() {
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
}
