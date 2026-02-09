import QuickLookUI
import GlossKit

class PreviewProvider: QLPreviewProvider {
    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let source = try String(contentsOf: request.fileURL, encoding: .utf8)
        let html = MarkdownRenderer.render(source) // isDark=nil, uses prefers-color-scheme
        return QLPreviewReply(dataOfContentType: .html, contentSize: CGSize(width: 800, height: 600)) { _ in
            html.data(using: .utf8)!
        }
    }
}
