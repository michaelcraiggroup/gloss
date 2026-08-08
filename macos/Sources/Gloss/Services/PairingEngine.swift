import Foundation

/// The pure half of QR pairing: given a decoded payload and the world's
/// state, decide what happens next. The iOS PairingHandler owns the stateful
/// parts (the metadata query while locating, service calls, UI state) and
/// consumes these decisions — keeping the sequencing rules SPM-testable.
enum PairingEngine {
    enum Decision: Equatable {
        /// Not a Gloss pairing code (decode failed).
        case invalidCode
        /// Signed out of iCloud / container unresolved — retry when it lands.
        case needsICloud
        /// Vaults are Pro; the caller fires the paywall and retries on unlock.
        case needsPro
        /// Vault not visible in the container yet — watch for it (the
        /// wrong-Apple-ID case looks exactly like this, so callers keep
        /// listening forever and only soften the copy after a timeout).
        case locate(vaultURL: URL)
        /// Vault is present — open it.
        case open(vaultURL: URL)
    }

    /// `payload.vault` is codec-validated ("Documents/…", no traversal), so
    /// this is a straight join under the container root.
    nonisolated static func vaultURL(for payload: PairingPayload, containerURL: URL) -> URL {
        containerURL.appendingPathComponent(payload.vault, isDirectory: true)
    }

    /// Order matters and is part of the contract: bad code beats everything
    /// (no point asking for iCloud for a foreign QR), iCloud beats Pro (the
    /// paywall would be noise while nothing can open anyway), Pro beats
    /// locate/open (gate once, before any vault work).
    nonisolated static func decide(
        payload: PairingPayload?,
        containerURL: URL?,
        unlocked: Bool,
        vaultExists: (URL) -> Bool
    ) -> Decision {
        guard let payload else { return .invalidCode }
        guard let containerURL else { return .needsICloud }
        guard unlocked else { return .needsPro }
        let url = vaultURL(for: payload, containerURL: containerURL)
        return vaultExists(url) ? .open(vaultURL: url) : .locate(vaultURL: url)
    }

    /// Apply the Mac's settings snapshot. Only fields the codec validated and
    /// the payload carried are touched — a minimal payload changes nothing.
    @MainActor
    static func apply(_ snapshot: PairingPayload.SettingsSnapshot?, to settings: AppSettings) {
        guard let snapshot else { return }
        if let appearance = snapshot.appearance {
            settings.appearance = appearance
        }
        if let fontSize = snapshot.fontSize {
            settings.fontSize = fontSize
        }
        if let folder = snapshot.dailyNotesFolder {
            settings.dailyNotesFolder = folder
        }
        if let format = snapshot.dailyNotesDateFormat {
            settings.dailyNotesDateFormat = format
        }
    }
}
