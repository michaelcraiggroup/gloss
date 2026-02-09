import Foundation

/// Searches file contents across a folder of markdown files.
/// Debounces queries, runs file I/O concurrently, and caps results.
@Observable
@MainActor
final class ContentSearchService {
    var results: [ContentSearchResult] = []
    var isSearching: Bool = false

    private var searchTask: Task<Void, Never>?
    private static let maxResults = 100
    private static let debounceNanoseconds: UInt64 = 300_000_000 // 300ms

    /// Search for a query string across all markdown files under rootURL.
    /// Cancels any in-flight search and debounces by 300ms.
    func search(query: String, rootURL: URL?) {
        searchTask?.cancel()

        guard let rootURL, !query.isEmpty else {
            results = []
            isSearching = false
            return
        }

        isSearching = true

        searchTask = Task {
            // Debounce
            try? await Task.sleep(nanoseconds: Self.debounceNanoseconds)
            guard !Task.isCancelled else { return }

            let files = collectMarkdownFiles(under: rootURL)
            guard !Task.isCancelled else { return }

            let searchResults = await searchFiles(files, for: query)
            guard !Task.isCancelled else { return }

            results = searchResults
            isSearching = false
        }
    }

    /// Cancel any in-flight search.
    func cancel() {
        searchTask?.cancel()
        isSearching = false
    }

    // MARK: - Private

    /// Recursively collect all markdown files under a directory.
    private func collectMarkdownFiles(under url: URL) -> [URL] {
        let fm = FileManager.default
        var files: [URL] = []

        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        while let itemURL = enumerator.nextObject() as? URL {
            let name = itemURL.lastPathComponent

            // Skip excluded directories
            if FileTreeNode.excludedNames.contains(name) {
                enumerator.skipDescendants()
                continue
            }

            let isDir = (try? itemURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if !isDir && FileTreeNode.markdownExtensions.contains(itemURL.pathExtension.lowercased()) {
                files.append(itemURL)
            }
        }

        return files
    }

    /// Search file contents concurrently using a TaskGroup.
    private func searchFiles(_ files: [URL], for query: String) async -> [ContentSearchResult] {
        let lowerQuery = query.lowercased()

        return await withTaskGroup(of: [ContentSearchResult].self) { group in
            for fileURL in files {
                group.addTask {
                    guard !Task.isCancelled else { return [] }
                    return Self.searchFile(fileURL, for: lowerQuery)
                }
            }

            var allResults: [ContentSearchResult] = []
            for await fileResults in group {
                allResults.append(contentsOf: fileResults)
                if allResults.count >= Self.maxResults {
                    break
                }
            }

            return Array(allResults.prefix(Self.maxResults))
        }
    }

    /// Search a single file for matching lines. Runs off the main actor.
    private nonisolated static func searchFile(_ fileURL: URL, for lowerQuery: String) -> [ContentSearchResult] {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return [] }

        let fileName = fileURL.lastPathComponent
        let parentFolder = fileURL.deletingLastPathComponent().lastPathComponent
        let docType = DocumentType.detect(filename: fileName, folderName: parentFolder)
        let lines = content.components(separatedBy: .newlines)

        var matches: [ContentSearchResult] = []
        for (index, line) in lines.enumerated() {
            if line.lowercased().contains(lowerQuery) {
                matches.append(ContentSearchResult(
                    fileURL: fileURL,
                    fileName: fileName,
                    lineNumber: index + 1,
                    lineContent: String(line.prefix(200)).trimmingCharacters(in: .whitespaces),
                    documentType: docType
                ))
            }
        }
        return matches
    }
}
