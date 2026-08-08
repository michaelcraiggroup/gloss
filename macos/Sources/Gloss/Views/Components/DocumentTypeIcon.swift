import SwiftUI

/// The one place a document-type icon is rendered: emoji on macOS (the
/// sidebar's shipped signature), SF Symbols on iOS (native weight, crisp in
/// dark mode, Dynamic Type + accessibility for free). Folders carry the
/// brand amber; documents stay quiet.
struct DocumentTypeIcon: View {
    let type: DocumentType

    var body: some View {
        #if os(macOS)
        Text(type.icon)
        #else
        Image(systemName: type.symbol)
            .foregroundStyle(type == .folder ? Color.glossAccent : Color.secondary)
        #endif
    }
}
