import Foundation
import Testing
@testable import Gloss

@Suite("PairingPayload codec")
struct PairingPayloadTests {
    private func makePayload() -> PairingPayload {
        PairingPayload(
            vault: "Documents/Field Notes",
            name: "Field Notes",
            settings: .init(
                appearance: "dark",
                fontSize: 18,
                dailyNotesFolder: "Daily",
                dailyNotesDateFormat: "yyyy-MM-dd"))
    }

    @Test func roundtripsFullPayload() throws {
        let payload = makePayload()
        let url = try #require(PairingPayloadCodec.url(for: payload))
        #expect(url.scheme == "gloss")
        #expect(url.host == "pair")
        let decoded = try #require(PairingPayloadCodec.decode(from: url))
        #expect(decoded == payload)
    }

    @Test func roundtripsMinimalPayload() throws {
        let payload = PairingPayload(vault: "Documents/N", name: "N", settings: nil)
        let url = try #require(PairingPayloadCodec.url(for: payload))
        #expect(PairingPayloadCodec.decode(from: url) == payload)
    }

    @Test func rejectsForeignURLs() {
        #expect(PairingPayloadCodec.decode(from: URL(string: "https://pair?d=x")!) == nil)
        #expect(PairingPayloadCodec.decode(from: URL(string: "gloss://open?d=x")!) == nil)
        #expect(PairingPayloadCodec.decode(from: URL(string: "gloss://pair")!) == nil)
        #expect(PairingPayloadCodec.decode(from: URL(string: "gloss://pair?d=!!!notbase64!!!")!) == nil)
    }

    @Test func rejectsOversizedPayloads() {
        let huge = String(repeating: "A", count: PairingPayloadCodec.maxEncodedBytes + 1)
        #expect(PairingPayloadCodec.decode(from: URL(string: "gloss://pair?v=1&d=\(huge)")!) == nil)
    }

    @Test func rejectsWrongVersion() throws {
        var payload = makePayload()
        payload.v = 2
        let url = try #require(PairingPayloadCodec.url(for: payload))
        #expect(PairingPayloadCodec.decode(from: url) == nil)
    }

    @Test func rejectsUnsafeVaultPaths() throws {
        for vault in [
            "Documents/../Library/evil",
            "Documents//",
            "Documents/",
            "Documents/a/../../b",
            "Documents/./x",
            "Elsewhere/vault",
            "/etc/passwd",
        ] {
            var payload = makePayload()
            payload.vault = vault
            let url = try #require(PairingPayloadCodec.url(for: payload))
            #expect(PairingPayloadCodec.decode(from: url) == nil, "should reject \(vault)")
        }
        #expect(PairingPayloadCodec.isSafeVaultPath("Documents/Nested/Vault"))
    }

    @Test func rejectsEmptyName() throws {
        var payload = makePayload()
        payload.name = "   "
        let url = try #require(PairingPayloadCodec.url(for: payload))
        #expect(PairingPayloadCodec.decode(from: url) == nil)
    }

    @Test func clampsAndNormalizesSettings() throws {
        var payload = makePayload()
        payload.settings = .init(
            appearance: "neon", fontSize: 99,
            dailyNotesFolder: nil, dailyNotesDateFormat: nil)
        let url = try #require(PairingPayloadCodec.url(for: payload))
        let decoded = try #require(PairingPayloadCodec.decode(from: url))
        #expect(decoded.settings?.fontSize == 24)      // clamped into 12...24
        #expect(decoded.settings?.appearance == nil)   // unknown value dropped
    }

    @Test func base64urlUsesURLSafeAlphabet() {
        let data = Data([0xfb, 0xff, 0xfe, 0x00, 0x01])
        let encoded = PairingPayloadCodec.base64urlEncode(data)
        #expect(!encoded.contains("+") && !encoded.contains("/") && !encoded.contains("="))
        #expect(PairingPayloadCodec.base64urlDecode(encoded) == data)
    }
}
