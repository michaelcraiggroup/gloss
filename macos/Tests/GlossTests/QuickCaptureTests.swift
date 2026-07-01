import Testing
import Foundation
@testable import Gloss

@Suite("Quick Capture")
struct QuickCaptureTests {

    @Test("ScreenCorner maps to the right point in a frame")
    func cornerPoints() {
        let f = CGRect(x: 100, y: 200, width: 800, height: 600) // min (100,200), max (900,800)
        #expect(ScreenCorner.bottomLeft.point(in: f) == CGPoint(x: 100, y: 200))
        #expect(ScreenCorner.bottomRight.point(in: f) == CGPoint(x: 900, y: 200))
        #expect(ScreenCorner.topLeft.point(in: f) == CGPoint(x: 100, y: 800))
        #expect(ScreenCorner.topRight.point(in: f) == CGPoint(x: 900, y: 800))
    }

    @Test("isInCorner hits within radius and misses outside")
    func inCorner() {
        let f = CGRect(x: 0, y: 0, width: 1000, height: 800)
        // bottom-left corner is (0,0)
        #expect(QuickCaptureController.isInCorner(CGPoint(x: 2, y: 3), screenFrame: f, corner: .bottomLeft, radius: 4))
        #expect(QuickCaptureController.isInCorner(CGPoint(x: 0, y: 0), screenFrame: f, corner: .bottomLeft, radius: 4))
        #expect(!QuickCaptureController.isInCorner(CGPoint(x: 20, y: 20), screenFrame: f, corner: .bottomLeft, radius: 4))
        // top-right corner is (1000,800); same point is not near bottom-left
        #expect(QuickCaptureController.isInCorner(CGPoint(x: 998, y: 799), screenFrame: f, corner: .topRight, radius: 4))
        #expect(!QuickCaptureController.isInCorner(CGPoint(x: 998, y: 799), screenFrame: f, corner: .bottomLeft, radius: 4))
    }

    @Test("appendedContent adds a timestamped bullet with a newline boundary")
    func append() {
        // no trailing newline → one is inserted before the bullet
        #expect(QuickCaptureController.appendedContent(existing: "# Today", capture: "buy milk", timestamp: "09:30")
            == "# Today\n- 09:30 buy milk\n")
        // already ends with newline → no blank line inserted
        #expect(QuickCaptureController.appendedContent(existing: "x\n", capture: "note", timestamp: "14:05")
            == "x\n- 14:05 note\n")
        // capture is trimmed; empty existing stays clean
        #expect(QuickCaptureController.appendedContent(existing: "", capture: "  spaced  ", timestamp: "00:00")
            == "- 00:00 spaced\n")
    }
}
