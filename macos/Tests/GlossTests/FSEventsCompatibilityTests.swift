import Foundation
import Testing

/// Tests for FSEvents API availability.
/// Verifies that FSEvents can be used for directory watching on macOS.
@Suite("FSEvents API")
struct FSEventsCompatibilityTests {

    /// Verify FSEvents API constants are defined.
    @Test("FSEvents API constants available")
    func fseventsConstantsAvailable() {
        let fileEventsFlag = UInt32(kFSEventStreamCreateFlagFileEvents)
        let watchRootFlag = UInt32(kFSEventStreamCreateFlagWatchRoot)

        #expect(fileEventsFlag > 0, "kFSEventStreamCreateFlagFileEvents should exist")
        #expect(watchRootFlag > 0, "kFSEventStreamCreateFlagWatchRoot should exist")
    }

    /// Verify FSEventStreamCreate can be called (API availability).
    @Test("FSEventStreamCreate is available")
    func fseventsCreateAvailable() {
        let tmpDir = FileManager.default.temporaryDirectory
        let paths = [tmpDir.path] as CFArray

        let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            { _, _, _, _, _, _ in },
            nil,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.3,
            UInt32(kFSEventStreamCreateFlagFileEvents)
        )

        #expect(stream != nil, "FSEventStreamCreate should work")

        if let stream = stream {
            FSEventStreamInvalidate(stream)
        }
    }
}
