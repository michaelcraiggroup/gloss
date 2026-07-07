import Testing
import Foundation
@testable import Gloss

@Suite("Document Zoom")
struct ZoomTests {

    @Test("Step in from actual size")
    func stepIn() {
        #expect(AppSettings.steppedZoom(1.0, by: AppSettings.zoomStep) == 1.25)
    }

    @Test("Step out from actual size")
    func stepOut() {
        #expect(AppSettings.steppedZoom(1.0, by: -AppSettings.zoomStep) == 0.75)
    }

    @Test("Clamps at the maximum")
    func clampsAtMax() {
        #expect(AppSettings.steppedZoom(5.0, by: AppSettings.zoomStep) == 5.0)
        // A large jump can't overshoot the ceiling either.
        #expect(AppSettings.steppedZoom(4.9, by: 1.0) == 5.0)
    }

    @Test("Clamps at the minimum")
    func clampsAtMin() {
        #expect(AppSettings.steppedZoom(0.5, by: -AppSettings.zoomStep) == 0.5)
        #expect(AppSettings.steppedZoom(0.55, by: -1.0) == 0.5)
    }

    @Test("Repeated stepping stays free of Double drift")
    func noFloatDrift() {
        // Step increments must not accumulate Double error — three steps up
        // from 1.0 at 0.25 each must land exactly on 1.75.
        var z = 1.0
        z = AppSettings.steppedZoom(z, by: AppSettings.zoomStep)
        z = AppSettings.steppedZoom(z, by: AppSettings.zoomStep)
        z = AppSettings.steppedZoom(z, by: AppSettings.zoomStep)
        #expect(z == 1.75)
    }

    @Test("Range bounds are sane")
    func rangeBounds() {
        #expect(AppSettings.zoomRange.contains(1.0))
        #expect(AppSettings.zoomRange.lowerBound == 0.5)
        #expect(AppSettings.zoomRange.upperBound == 5.0)
    }
}
