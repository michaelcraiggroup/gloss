import Foundation

/// What the Mac's Set Up iPhone QR code carries: which vault to open, its
/// display name, and an optional snapshot of reading settings so the phone
/// comes up matching the Mac. **No secrets, no authority** — the Apple
/// Account is the security boundary; a leaked QR is inert (it names a folder
/// the scanner's iCloud either has or doesn't).
struct PairingPayload: Codable, Equatable {
    var v: Int = PairingPayloadCodec.currentVersion
    /// Container-relative vault path, always under "Documents/".
    var vault: String
    /// Display name for the connect UI.
    var name: String
    var settings: SettingsSnapshot?

    struct SettingsSnapshot: Codable, Equatable {
        var appearance: String?
        var fontSize: Int?
        var dailyNotesFolder: String?
        var dailyNotesDateFormat: String?
    }
}

/// `gloss://pair?v=1&d=<base64url(JSON)>` — encoder (Mac) and hardened
/// decoder (iOS). Decode failures return nil; the caller shows "not a Gloss
/// pairing code", never a crash.
enum PairingPayloadCodec {
    static let scheme = "gloss"
    static let host = "pair"
    static let currentVersion = 1
    /// Cap checked BEFORE any decode work — QR payloads are small; anything
    /// bigger is not ours.
    static let maxEncodedBytes = 4096

    nonisolated static let fontSizeRange = 12...24

    // MARK: - Encode

    static func url(for payload: PairingPayload) -> URL? {
        guard let json = try? JSONEncoder().encode(payload) else { return nil }
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.queryItems = [
            URLQueryItem(name: "v", value: String(payload.v)),
            URLQueryItem(name: "d", value: base64urlEncode(json)),
        ]
        return components.url
    }

    // MARK: - Decode (hardened)

    static func decode(from url: URL) -> PairingPayload? {
        guard url.scheme?.lowercased() == scheme,
              url.host?.lowercased() == host,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let encoded = components.queryItems?.first(where: { $0.name == "d" })?.value,
              encoded.utf8.count <= maxEncodedBytes,
              let data = base64urlDecode(encoded),
              var payload = try? JSONDecoder().decode(PairingPayload.self, from: data),
              payload.v == currentVersion,
              isSafeVaultPath(payload.vault),
              !payload.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }

        // Clamp/normalize the optional settings snapshot rather than reject.
        if var snapshot = payload.settings {
            if let size = snapshot.fontSize {
                snapshot.fontSize = min(max(size, fontSizeRange.lowerBound), fontSizeRange.upperBound)
            }
            if let appearance = snapshot.appearance, Appearance(rawValue: appearance) == nil {
                snapshot.appearance = nil
            }
            payload.settings = snapshot
        }
        return payload
    }

    /// Container-relative, under Documents/, with something after the prefix
    /// and no traversal or empty segments (a "Documents/" prefix also rules
    /// out absolute paths).
    nonisolated static func isSafeVaultPath(_ vault: String) -> Bool {
        guard vault.hasPrefix("Documents/"),
              vault.count > "Documents/".count
        else { return false }
        let components = vault.components(separatedBy: "/")
        return !components.contains("..")
            && !components.contains(".")
            && !components.contains("")
    }

    // MARK: - base64url

    nonisolated static func base64urlEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    nonisolated static func base64urlDecode(_ string: String) -> Data? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64.append("=") }
        return Data(base64Encoded: base64)
    }
}
