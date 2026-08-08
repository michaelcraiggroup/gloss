import Foundation
import Testing
@testable import Gloss

@Suite("UbiquityVaultStore")
struct UbiquityVaultStoreTests {
    @Test func containerIdentifierIsPinned() {
        // The container id latches cloud-side and appears in entitlements,
        // Info.plist NSUbiquitousContainers, and the portal — never drift.
        #expect(UbiquityVaultStore.containerIdentifier == "iCloud.group.michaelcraig.gloss")
    }

    @Test func recognizesMacContainerPaths() {
        let url = URL(fileURLWithPath:
            "/Users/michael/Library/Mobile Documents/iCloud~group~michaelcraig~gloss/Documents/Notes")
        #expect(UbiquityVaultStore.isUbiquitousPath(url))
    }

    @Test func recognizesIOSStyleContainerPaths() {
        let url = URL(fileURLWithPath:
            "/private/var/mobile/Library/Mobile Documents/iCloud~group~michaelcraig~gloss/Documents/Notes")
        #expect(UbiquityVaultStore.isUbiquitousPath(url))
    }

    @Test func rejectsLocalAndForeignContainerPaths() {
        #expect(!UbiquityVaultStore.isUbiquitousPath(URL(fileURLWithPath: "/Users/michael/Notes")))
        #expect(!UbiquityVaultStore.isUbiquitousPath(URL(fileURLWithPath:
            "/Users/michael/Library/Mobile Documents/iCloud~com~apple~Pages/Documents")))
        // Unstandardized path with a dot-segment still resolves to a match.
        #expect(UbiquityVaultStore.isUbiquitousPath(URL(fileURLWithPath:
            "/Users/michael/Library/./Mobile Documents/iCloud~group~michaelcraig~gloss/Documents")))
    }
}
