import Testing
import Foundation
@testable import Gloss

@Suite("Unlock Cache Policy")
struct UnlockCachePolicyTests {

    @Test("Verified entitlement always records, regardless of history")
    func verifiedRecords() {
        #expect(UnlockCachePolicy.reconcile(currentlyEntitled: true, latestKnownRevoked: nil) == .record)
        #expect(UnlockCachePolicy.reconcile(currentlyEntitled: true, latestKnownRevoked: false) == .record)
        #expect(UnlockCachePolicy.reconcile(currentlyEntitled: true, latestKnownRevoked: true) == .record)
    }

    @Test("Verified revoked latest transaction revokes")
    func revokedLatestRevokes() {
        #expect(UnlockCachePolicy.reconcile(currentlyEntitled: false, latestKnownRevoked: true) == .revoke)
    }

    @Test("Absent entitlement without a revocation signal holds optimistic state")
    func absenceHolds() {
        // No transaction history at all — fresh binary / never purchased.
        #expect(UnlockCachePolicy.reconcile(currentlyEntitled: false, latestKnownRevoked: nil) == .hold)
        // History exists and is NOT revoked, but currentEntitlements is empty
        // (delivery pending) — must not lock a paying customer.
        #expect(UnlockCachePolicy.reconcile(currentlyEntitled: false, latestKnownRevoked: false) == .hold)
    }

    @Test("Launch unlocks if and only if a verification was cached")
    func launchStateFromCache() {
        #expect(UnlockCachePolicy.launchUnlocked(cachedVerification: Date()))
        #expect(UnlockCachePolicy.launchUnlocked(cachedVerification: .distantPast))
        #expect(!UnlockCachePolicy.launchUnlocked(cachedVerification: nil))
    }
}
