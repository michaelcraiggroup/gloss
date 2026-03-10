import StoreKit

/// Manages in-app purchase for Gloss Full ($4.99 one-time unlock).
@Observable
@MainActor
final class StoreManager {
    static let productID = "group.michaelcraig.gloss.full"

    private(set) var product: Product?
    private(set) var isUnlocked = false
    private(set) var isPurchasing = false
    private var transactionListener: Task<Void, Never>?

    init() {
        transactionListener = listenForTransactions()
        Task { await loadProduct() }
        Task { await checkEntitlement() }
    }

    nonisolated deinit {
        // transactionListener is cancelled when Task is deallocated
    }

    /// Load the product from the App Store.
    func loadProduct() async {
        guard product == nil else { return }
        do {
            let products = try await Product.products(for: [Self.productID])
            product = products.first
        } catch {
            // Silently fail — product unavailable
        }
    }

    /// Purchase Gloss Full.
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
                    isUnlocked = true
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

    /// Restore purchases.
    func restore() async {
        try? await AppStore.sync()
        await checkEntitlement()
    }

    /// Check if user has a valid entitlement.
    func checkEntitlement() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.productID {
                isUnlocked = true
                return
            }
        }
        // If we get here, no valid entitlement found
        // Don't reset isUnlocked if it was already true (edge case during refresh)
    }

    /// Listen for transaction updates (e.g. family sharing, refunds).
    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await MainActor.run {
                        if transaction.productID == StoreManager.productID {
                            self.isUnlocked = transaction.revocationDate == nil
                        }
                    }
                }
            }
        }
    }

    /// Whether a specific feature requires the paid tier.
    static func requiresPaid(_ feature: PaidFeature) -> Bool {
        true // All paid features are gated the same way
    }
}

/// Features that require Gloss Full purchase.
enum PaidFeature: String, CaseIterable {
    case folderSidebar = "Folder Sidebar"
    case inspector = "Inspector (TOC & Frontmatter)"
    case fullTextSearch = "Full-Text Search"
    case favorites = "Favorites & Recents"
    case findInPage = "Find in Page"
    case wikiLinks = "Wiki-Link Navigation"
    case printExport = "Print & PDF Export"
    case fontSizeControl = "Font Size Control"
}
