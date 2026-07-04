import Foundation
import SwiftData

/// A recently opened markdown document, persisted via SwiftData.
///
/// Rows are scoped by `vaultPath` — the standardized root path of the vault
/// that was open when the document was recorded, or `""` for documents opened
/// with no vault (single-file / Preview.app-style usage). The same file opened
/// in two nested vaults gets one row per vault, keyed on (vaultPath, path).
@Model
final class RecentDocument {
    var path: String
    var title: String
    var lastOpened: Date
    var documentType: String
    var isFavorite: Bool = false
    var vaultPath: String = ""

    init(path: String, title: String, lastOpened: Date = .now, documentType: String = "generic", isFavorite: Bool = false, vaultPath: String = "") {
        self.path = path
        self.title = title
        self.lastOpened = lastOpened
        self.documentType = documentType
        self.isFavorite = isFavorite
        self.vaultPath = vaultPath
    }

    /// The resolved document type enum value.
    var type: DocumentType {
        DocumentType(rawValue: documentType) ?? .generic
    }

    /// The file URL for this document.
    var url: URL {
        URL(fileURLWithPath: path)
    }
}
