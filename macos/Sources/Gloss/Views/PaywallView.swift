import SwiftUI

/// Purchase UI shown when a paid feature is triggered in the free tier.
struct PaywallView: View {
    let feature: PaidFeature
    @Environment(StoreManager.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundStyle(.tint)

            Text("Unlock Gloss Pro")
                .font(.title2)
                .fontWeight(.bold)

            Text("\(feature.rawValue) is a Gloss Pro feature.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 8) {
                featureRow("Folder sidebar & file browser")
                featureRow("Table of contents, frontmatter & backlinks")
                featureRow("Full-text content search")
                featureRow("Wiki-link navigation")
                featureRow("Favorites & recents")
                featureRow("Link graph view")
                featureRow("Font size control")
            }
            .padding(.vertical, 8)

            if let product = store.product {
                Button {
                    Task { await store.purchase() }
                } label: {
                    if store.isPurchasing {
                        ProgressView()
                            .controlSize(.small)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Unlock for \(product.displayPrice)")
                            .frame(maxWidth: .infinity)
                    }
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .disabled(store.isPurchasing)
            } else if store.productLoadFailed {
                // Distinguish "failed" from "still fetching" — a perpetual
                // fake spinner here left users stuck with no way forward (#59).
                VStack(spacing: 6) {
                    Text("Couldn't load the App Store product.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Try Again") {
                        Task { await store.loadProduct() }
                    }
                    .controlSize(.small)
                }
            } else {
                ProgressView("Loading…")
                    .controlSize(.small)
            }

            Button {
                Task { await store.restore() }
            } label: {
                if store.isRestoring {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Text("Restore Purchase")
                }
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)
            .disabled(store.isRestoring)

            if store.restoreFoundNothing {
                Text("No purchase found for this Apple Account.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Text("One-time purchase. No subscription, ever.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(32)
        .frame(width: 340)
        .task {
            // Re-request the product every time the paywall opens — the
            // launch-time fetch may have failed (offline, store hiccup).
            await store.loadProduct()
        }
        .onChange(of: store.isUnlocked) {
            if store.isUnlocked { dismiss() }
        }
    }

    private func featureRow(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)
            Text(text)
                .font(.callout)
        }
    }
}
