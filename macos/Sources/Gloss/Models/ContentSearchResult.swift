import Foundation

/// A single match found during content search across markdown files.
struct ContentSearchResult: Identifiable {
    let id = UUID()
    let fileURL: URL
    let fileName: String
    let lineNumber: Int
    let lineContent: String
    let documentType: DocumentType
}
