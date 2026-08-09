import Foundation
import Observation

/// Seam the pairing arc implements for `gloss://pair` URLs (PR 11).
@MainActor
protocol PairingURLHandling: AnyObject {
    func handle(_ url: URL)
}

// The production conformer is PairingHandler (PairingHandler.swift) — the
// QR/deep-link state machine that consumes PairingEngine's decisions.
