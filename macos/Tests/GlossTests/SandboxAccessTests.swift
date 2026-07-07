import Testing
import Foundation
@testable import Gloss

@Suite("Sandbox access")
struct SandboxAccessTests {

    @Test("Cocoa no-permission error is classified as denied")
    func cocoaPermissionDenied() {
        let error = NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError)
        #expect(SecurityScopedBookmarks.isPermissionDenied(error))
    }

    @Test("Missing-file error is NOT denied (keeps the plain error state)")
    func missingFileIsNotDenied() {
        let error = NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoSuchFileError)
        #expect(!SecurityScopedBookmarks.isPermissionDenied(error))
    }

    @Test("POSIX EACCES / EPERM are denied")
    func posixDenied() {
        #expect(SecurityScopedBookmarks.isPermissionDenied(
            NSError(domain: NSPOSIXErrorDomain, code: Int(EACCES))))
        #expect(SecurityScopedBookmarks.isPermissionDenied(
            NSError(domain: NSPOSIXErrorDomain, code: Int(EPERM))))
    }

    @Test("POSIX denial wrapped under a generic Cocoa error is denied")
    func underlyingPosixDenied() {
        let posix = NSError(domain: NSPOSIXErrorDomain, code: Int(EACCES))
        let wrapped = NSError(domain: NSCocoaErrorDomain, code: NSFileReadUnknownError,
                              userInfo: [NSUnderlyingErrorKey: posix])
        #expect(SecurityScopedBookmarks.isPermissionDenied(wrapped))
    }

    @Test("A real chmod-000 read throws an error classified as denied")
    func realDeniedRead() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gloss-sandbox-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("locked.md")
        try "# locked".write(to: file, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: file.path)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: file.path)
            try? FileManager.default.removeItem(at: dir)
        }
        do {
            _ = try String(contentsOf: file, encoding: .utf8)
            Issue.record("read unexpectedly succeeded (running as root?)")
        } catch {
            #expect(SecurityScopedBookmarks.isPermissionDenied(error))
        }
    }
}
