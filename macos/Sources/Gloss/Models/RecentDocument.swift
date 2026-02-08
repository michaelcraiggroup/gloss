import Foundation
import SwiftData

/// A recently opened markdown document, persisted via SwiftData.
@Model
final class RecentDocument {
    var path: String
    var title: String
    var lastOpened: Date
    var documentType: String

    init(path: String, title: String, lastOpened: Date = .now, documentType: String = "generic") {
        self.path = path
        self.title = title
        self.lastOpened = lastOpened
        self.documentType = documentType
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
