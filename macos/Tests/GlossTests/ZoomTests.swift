import Testing
import Foundation
@testable import Gloss

@Suite("Document Zoom")
struct ZoomTests {

    @Test("Step in from actual size")
    func stepIn() {
        #expect(AppSettings.steppedZoom(1.0, by: AppSettings.zoomStep) == 1.1)
    }

    @Test("Step out from actual size")
    func stepOut() {
        #expect(AppSettings.steppedZoom(1.0, by: -AppSettings.zoomStep) == 0.9)
    }

    @Test("Clamps at the maximum")
    func clampsAtMax() {
        #expect(AppSettings.steppedZoom(3.0, by: AppSettings.zoomStep) == 3.0)
        // A large jump can't overshoot the ceiling either.
        #expect(AppSettings.steppedZoom(2.95, by: 1.0) == 3.0)
    }

    @Test("Clamps at the minimum")
    func clampsAtMin() {
        #expect(AppSettings.steppedZoom(0.5, by: -AppSettings.zoomStep) == 0.5)
        #expect(AppSettings.steppedZoom(0.55, by: -1.0) == 0.5)
    }

    @Test("Repeated stepping stays free of Double drift")
    func noFloatDrift() {
        // 0.1 increments on Double accumulate error (0.1 + 0.2 != 0.3) unless
        // rounded — three steps up from 1.0 must land exactly on 1.3.
        var z = 1.0
        z = AppSettings.steppedZoom(z, by: AppSettings.zoomStep)
        z = AppSettings.steppedZoom(z, by: AppSettings.zoomStep)
        z = AppSettings.steppedZoom(z, by: AppSettings.zoomStep)
        #expect(z == 1.3)
    }

    @Test("Range bounds are sane")
    func rangeBounds() {
        #expect(AppSettings.zoomRange.contains(1.0))
        #expect(AppSettings.zoomRange.lowerBound == 0.5)
        #expect(AppSettings.zoomRange.upperBound == 3.0)
    }
}
