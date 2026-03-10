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

            Text("Unlock Gloss Full")
                .font(.title2)
                .fontWeight(.bold)

            Text("\(feature.rawValue) is a Gloss Full feature.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 8) {
                featureRow("Folder sidebar & file browser")
                featureRow("Table of contents & frontmatter inspector")
                featureRow("Full-text search & find in page")
                featureRow("Wiki-link navigation")
                featureRow("Favorites & recents")
                featureRow("Print & PDF export")
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
            } else {
                ProgressView("Loading…")
                    .controlSize(.small)
            }

            Button("Restore Purchase") {
                Task { await store.restore() }
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)

            Text("One-time purchase. No subscription, ever.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(32)
        .frame(width: 340)
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
