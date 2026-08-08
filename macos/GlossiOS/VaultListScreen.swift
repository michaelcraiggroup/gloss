import SwiftUI

/// The sidebar's top level: discovered vaults + the pairing entry point.
/// In milestone C's interim state the catalog lists app-sandbox Documents
/// folders; PR 9 swaps the source to the iCloud container (same rows), and
/// PR 11 enables the pairing scanner.
struct VaultListScreen: View {
    let catalog: any VaultCatalogProviding
    let pairingHandler: LoggingPairingHandler

    @EnvironmentObject private var settings: AppSettings
    @Environment(FileTreeModel.self) private var fileTree
    @Environment(StoreManager.self) private var store
    @Environment(LinkIndex.self) private var linkIndex
    @Environment(UbiquityVaultStore.self) private var ubiquityStore
    @State private var showingSettings = false

    var body: some View {
        List {
            iCloudStatusSection

            if catalog.vaults.isEmpty {
                emptyState
            } else {
                Section("Vaults") {
                    ForEach(catalog.vaults) { vault in
                        Button {
                            open(vault)
                        } label: {
                            vaultRow(vault)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section {
                Label("Pair with Mac…", systemImage: "qrcode.viewfinder")
                    .foregroundStyle(.tertiary)
            } footer: {
                Text("Scan-to-connect arrives with the pairing milestone. Vaults in your iCloud appear here automatically.")
            }
        }
        .navigationTitle("Gloss")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsScreen()
        }
        .task { await catalog.refresh() }
        .refreshable { await catalog.refresh() }
        .onChange(of: ubiquityStore.state) {
            Task { await catalog.refresh() }
        }
    }

    /// Only surfaces when iCloud is the reason vaults can't appear —
    /// signed-out is actionable, resolution-pending is quiet spinner.
    @ViewBuilder
    private var iCloudStatusSection: some View {
        switch ubiquityStore.state {
        case .unknown:
            Section {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Checking iCloud…")
                        .foregroundStyle(.secondary)
                }
            }
        case .unavailable where !ubiquityStore.isSignedIntoICloud:
            Section {
                Label {
                    Text("Sign in to iCloud in Settings to see your synced vaults here.")
                        .font(.caption)
                } icon: {
                    Image(systemName: "icloud.slash")
                }
                .foregroundStyle(.secondary)
            }
        default:
            EmptyView()
        }
    }

    private var isOpen: (VaultDescriptor) -> Bool {
        { vault in settings.vaultKey == vault.rootURL.standardizedFileURL.path }
    }

    @ViewBuilder
    private func vaultRow(_ vault: VaultDescriptor) -> some View {
        HStack {
            Label(vault.name, systemImage: "books.vertical")
            Spacer()
            if isOpen(vault) {
                Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
                    .accessibilityLabel("Open")
            }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var emptyState: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("No vaults yet")
                    .font(.headline)
                Text("On your Mac: File → Move Vault to iCloud… Your vault appears here automatically once it syncs.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    /// Mirrors the macOS vault-open shape minus panels and bookmarks (the
    /// app's own container and sandbox Documents need neither):
    /// openFolder → rootFolderPath → buildIndex. Gated like every other
    /// folder open (`.folderSidebar`).
    private func open(_ vault: VaultDescriptor) {
        guard store.gate(.folderSidebar) else { return }
        fileTree.openFolder(vault.rootURL)
        settings.rootFolderPath = vault.rootURL.path
        linkIndex.buildIndex(rootURL: vault.rootURL)
    }
}
