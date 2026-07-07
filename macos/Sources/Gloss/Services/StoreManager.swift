import StoreKit

/// Pure decision logic for the optimistic unlock cache (#38). Kept free of
/// StoreKit so it can be unit-tested — the real entitlement stream cannot be
/// driven from `swift test`.
enum UnlockCachePolicy {
    enum Action {
        /// Verified now — seed/refresh the cache.
        case record
        /// Definitive refund — clear the cache and lock.
        case revoke
        /// No trustworthy signal (delivery pending / offline / no history) —
        /// keep whatever state the cache granted at launch.
        case hold
    }

    /// - Parameters:
    ///   - currentlyEntitled: a verified entitlement was seen this check.
    ///   - latestKnownRevoked: verdict from `Transaction.latest(for:)` —
    ///     `nil` when StoreKit has no (verified) transaction history yet.
    static func reconcile(currentlyEntitled: Bool, latestKnownRevoked: Bool?) -> Action {
        if currentlyEntitled { return .record }
        if latestKnownRevoked == true { return .revoke }
        return .hold
    }

    /// Launch state: trust the last verified purchase immediately.
    static func launchUnlocked(cachedVerification: Date?) -> Bool {
        cachedVerification != nil
    }
}

/// Manages in-app purchase for Gloss Pro ($9.99 one-time unlock).
/// The product ID keeps the legacy ".full" suffix — existing purchases own it;
/// the user-facing tier name ("Gloss Pro") is set in the storekit config and
/// App Store Connect.
///
/// Unlock state is optimistic (#38): on Developer-ID builds StoreKit can take
/// minutes-to-hours to deliver the entitlement on a freshly signed binary, so
/// launch trusts the last verified purchase (`lastVerifiedUnlockAt`) and lets
/// the async check / transaction stream revoke on refund. Trade-off, accepted:
/// a refund only takes effect once StoreKit reports it, and the flag lives in
/// container defaults — this protects paying customers from the locked window
/// on every release; it was never DRM.
@Observable
@MainActor
final class StoreManager {
    static let productID = "group.michaelcraig.gloss.full"
    static let lastVerifiedUnlockKey = "lastVerifiedUnlockAt"

    private(set) var product: Product?
    private(set) var isUnlocked = false
    private(set) var isPurchasing = false
    /// The last product fetch completed without a product — store unreachable,
    /// or the product doesn't exist in this machine's App Store environment
    /// (e.g. a Developer-ID build signed into production before the app is
    /// live). Drives the paywall's "Try Again" state instead of a fake
    /// perpetual spinner (#59).
    private(set) var productLoadFailed = false
    private(set) var isRestoring = false
    /// Restore ran to completion without finding an entitlement — surfaced in
    /// the paywall so a fruitless restore isn't silent (#59).
    private(set) var restoreFoundNothing = false
    private var transactionListener: Task<Void, Never>?

    init() {
        #if !XCODE_BUILD
        // Local/SPM builds bypass StoreKit — unlock all features
        isUnlocked = true
        #else
        isUnlocked = UnlockCachePolicy.launchUnlocked(
            cachedVerification: UserDefaults.standard.object(forKey: Self.lastVerifiedUnlockKey) as? Date
        )
        transactionListener = listenForTransactions()
        Task { await loadProduct() }
        Task { await checkEntitlement() }
        #endif
    }

    nonisolated deinit {
        // transactionListener is cancelled when Task is deallocated
    }

    /// Load the product from the App Store. Retryable — the paywall calls it
    /// again on open and from its "Try Again" button.
    func loadProduct() async {
        guard product == nil else { return }
        productLoadFailed = false
        do {
            let products = try await Product.products(for: [Self.productID])
            product = products.first
        } catch {
            // Fall through — product stays nil; the failed state drives the UI.
        }
        productLoadFailed = (product == nil)
    }

    /// Purchase Gloss Pro.
    func purchase() async -> Bool {
        guard let product, !isPurchasing else { return false }
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    recordVerifiedUnlock()
                    return true
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            // Purchase failed
        }
        return false
    }

    /// Restore purchases. Reports an in-flight state and whether anything was
    /// actually found, so the paywall can say so instead of silently returning
    /// to the same modal (#59).
    func restore() async {
        guard !isRestoring else { return }
        isRestoring = true
        restoreFoundNothing = false
        defer { isRestoring = false }
        try? await AppStore.sync()
        await checkEntitlement()
        restoreFoundNothing = !isUnlocked
    }

    /// Check if user has a valid entitlement.
    func checkEntitlement() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.productID {
                recordVerifiedUnlock()
                return
            }
        }
        // Nothing in currentEntitlements. That is NOT proof of no purchase —
        // on a freshly signed binary the stream can stay empty for hours
        // (#38). Only a verified revoked transaction is a definitive lock
        // signal; it also catches refunds that landed while we weren't
        // running, which Transaction.updates alone would miss.
        var latestKnownRevoked: Bool?
        if case .verified(let latest)? = await Transaction.latest(for: Self.productID) {
            latestKnownRevoked = latest.revocationDate != nil
        }
        if UnlockCachePolicy.reconcile(currentlyEntitled: false, latestKnownRevoked: latestKnownRevoked) == .revoke {
            revokeUnlock()
        }
    }

    /// Listen for transaction updates (e.g. family sharing, refunds).
    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await MainActor.run {
                        if transaction.productID == StoreManager.productID {
                            if transaction.revocationDate == nil {
                                self.recordVerifiedUnlock()
                            } else {
                                self.revokeUnlock()
                            }
                        }
                    }
                }
            }
        }
    }

    /// A verified purchase was seen — unlock and persist the proof so the
    /// next launch (including the first launch of the next signed binary)
    /// starts unlocked.
    private func recordVerifiedUnlock() {
        isUnlocked = true
        UserDefaults.standard.set(Date(), forKey: Self.lastVerifiedUnlockKey)
    }

    /// Definitive refund/revocation — lock and clear the cached proof.
    private func revokeUnlock() {
        isUnlocked = false
        UserDefaults.standard.removeObject(forKey: Self.lastVerifiedUnlockKey)
    }

    /// Gate a paid feature. Returns true if unlocked. If locked, posts paywall notification.
    func gate(_ feature: PaidFeature) -> Bool {
        if isUnlocked { return true }
        NotificationCenter.default.post(name: .glossShowPaywall, object: feature)
        return false
    }
}

/// Features that require the Gloss Pro purchase.
enum PaidFeature: String, CaseIterable, Identifiable {
    case folderSidebar = "Folder Sidebar"
    case inspector = "Inspector (TOC & Frontmatter)"
    case fullTextSearch = "Full-Text Search"
    case favorites = "Favorites & Recents"
    case wikiLinks = "Wiki-Link Navigation"
    case fontSizeControl = "Font Size Control"
    case graphView = "Graph View"

    var id: String { rawValue }
}
