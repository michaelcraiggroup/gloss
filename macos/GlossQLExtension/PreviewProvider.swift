import Cocoa
@preconcurrency import Quartz
import GlossKit

class PreviewViewController: NSViewController, QLPreviewingController {

    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
    }

    nonisolated func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let source = try String(contentsOf: request.fileURL, encoding: .utf8)
        let html = MarkdownRenderer.render(source)
        return QLPreviewReply(dataOfContentType: .html, contentSize: CGSize(width: 800, height: 600)) { _ in
            html.data(using: .utf8)!
        }
    }
}
