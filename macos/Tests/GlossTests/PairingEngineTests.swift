import Foundation
import Testing
@testable import Gloss

@Suite("PairingEngine")
struct PairingEngineTests {
    private let container = URL(fileURLWithPath:
        "/Users/x/Library/Mobile Documents/iCloud~group~michaelcraig~gloss")

    private func payload(vault: String = "Documents/Notes") -> PairingPayload {
        PairingPayload(vault: vault, name: "Notes", settings: nil)
    }

    // MARK: - Decision ordering (the contract)

    @Test func invalidCodeBeatsEverything() {
        let decision = PairingEngine.decide(
            payload: nil, containerURL: nil, unlocked: false, vaultExists: { _ in true })
        #expect(decision == .invalidCode)
    }

    @Test func iCloudBeatsPro() {
        let decision = PairingEngine.decide(
            payload: payload(), containerURL: nil, unlocked: false, vaultExists: { _ in true })
        #expect(decision == .needsICloud)
    }

    @Test func proBeatsVaultWork() {
        var probed = false
        let decision = PairingEngine.decide(
            payload: payload(), containerURL: container, unlocked: false,
            vaultExists: { _ in probed = true; return true })
        #expect(decision == .needsPro)
        #expect(!probed)   // no vault probing before the gate
    }

    @Test func locatesWhenAbsentOpensWhenPresent() {
        let expected = container.appendingPathComponent("Documents/Notes", isDirectory: true)
        let absent = PairingEngine.decide(
            payload: payload(), containerURL: container, unlocked: true,
            vaultExists: { _ in false })
        #expect(absent == .locate(vaultURL: expected))
        let present = PairingEngine.decide(
            payload: payload(), containerURL: container, unlocked: true,
            vaultExists: { url in url == expected })
        #expect(present == .open(vaultURL: expected))
    }

    @Test func vaultURLJoinsUnderContainer() {
        let url = PairingEngine.vaultURL(
            for: payload(vault: "Documents/Nested/Deep Vault"), containerURL: container)
        #expect(url.path == container.path + "/Documents/Nested/Deep Vault")
    }

    // MARK: - Settings snapshot

    @Test @MainActor func applySnapshotSetsOnlyCarriedFields() {
        let settings = AppSettings()
        let prior = (settings.appearance, settings.fontSize,
                     settings.dailyNotesFolder, settings.dailyNotesDateFormat)
        defer {
            settings.appearance = prior.0
            settings.fontSize = prior.1
            settings.dailyNotesFolder = prior.2
            settings.dailyNotesDateFormat = prior.3
        }

        PairingEngine.apply(
            .init(appearance: "dark", fontSize: 20,
                  dailyNotesFolder: "Daily", dailyNotesDateFormat: "yyyy/MM/dd"),
            to: settings)
        #expect(settings.appearance == "dark")
        #expect(settings.fontSize == 20)
        #expect(settings.dailyNotesFolder == "Daily")
        #expect(settings.dailyNotesDateFormat == "yyyy/MM/dd")

        // A minimal snapshot touches nothing.
        settings.fontSize = 14
        PairingEngine.apply(
            .init(appearance: nil, fontSize: nil,
                  dailyNotesFolder: nil, dailyNotesDateFormat: nil),
            to: settings)
        #expect(settings.fontSize == 14)
        PairingEngine.apply(nil, to: settings)
        #expect(settings.fontSize == 14)
    }
}
