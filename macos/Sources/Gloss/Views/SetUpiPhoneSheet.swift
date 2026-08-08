import SwiftUI
import CoreImage
import AppKit

/// "Set Up iPhone…" / "Move Vault to iCloud…" — one sheet, two states:
///
/// - **Local vault**: explains the move, runs the VaultMigrator with the
///   app-state choreography around it (quiesce → move → reopen from the
///   container → migrate the recents bucket).
/// - **Container vault**: shows the pairing QR (scan with the iPhone camera)
///   plus a live upload status, and reminds that vaults also appear
///   automatically on devices signed into the same Apple Account.
struct SetUpiPhoneSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var settings: AppSettings
    @Environment(FileTreeModel.self) private var fileTree
    @Environment(LinkIndex.self) private var linkIndex
    @Environment(UbiquityVaultStore.self) private var ubiquityStore
    @State private var migrator = VaultMigrator()
    @State private var uploadStatus = VaultUploadStatus()

    var body: some View {
        VStack(spacing: 16) {
            if let root = fileTree.rootNode?.url {
                if UbiquityVaultStore.isUbiquitousPath(root) {
                    pairedState(root: root)
                } else {
                    moveState(root: root)
                }
            } else {
                ContentUnavailableView(
                    "Open a vault first",
                    systemImage: "books.vertical",
                    description: Text("Set Up iPhone shares the currently open vault."))
            }

            Button("Done") { dismiss() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(28)
        .frame(width: 420)
        .onDisappear { uploadStatus.stop() }
    }

    // MARK: - Container vault → QR

    @ViewBuilder
    private func pairedState(root: URL) -> some View {
        Text("Set Up iPhone")
            .font(.title2.bold())

        if let payloadURL = pairingURL(for: root),
           let qr = Self.qrImage(for: payloadURL) {
            Image(nsImage: qr)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: 220, height: 220)
                .accessibilityLabel("Gloss pairing code")

            Text("Scan with your iPhone camera — Gloss opens “\(root.lastPathComponent)” with this Mac's reading settings.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        } else {
            ContentUnavailableView(
                "Couldn't build the pairing code",
                systemImage: "qrcode",
                description: Text("The vault must live inside iCloud Drive → Gloss."))
        }

        uploadStatusLine
            .onAppear { uploadStatus.start(vaultRoot: root) }

        Text("No code handy? Vaults in iCloud appear on any device signed into the same Apple Account — automatically.")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
    }

    @ViewBuilder
    private var uploadStatusLine: some View {
        switch uploadStatus.pendingUploads {
        case .none:
            EmptyView()
        case .some(0):
            Label("Vault is uploaded to iCloud", systemImage: "checkmark.icloud")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .some(let n):
            Label("Uploading — \(n) item\(n == 1 ? "" : "s") to go", systemImage: "arrow.up.to.line.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Container-relative payload: "Documents/<vault name>".
    private func pairingURL(for root: URL) -> URL? {
        guard case .available(let container) = ubiquityStore.state else { return nil }
        let containerPath = container.standardizedFileURL.path
        let rootPath = root.standardizedFileURL.path
        guard rootPath.hasPrefix(containerPath + "/") else { return nil }
        let relative = String(rootPath.dropFirst(containerPath.count + 1))
        let payload = PairingPayload(
            vault: relative,
            name: root.lastPathComponent,
            settings: .init(
                appearance: settings.appearance,
                fontSize: settings.fontSize,
                dailyNotesFolder: settings.dailyNotesFolder.isEmpty ? nil : settings.dailyNotesFolder,
                dailyNotesDateFormat: settings.dailyNotesDateFormat))
        return PairingPayloadCodec.url(for: payload)
    }

    // MARK: - Local vault → move flow

    @ViewBuilder
    private func moveState(root: URL) -> some View {
        Text("Move Vault to iCloud")
            .font(.title2.bold())

        Text("“\(root.lastPathComponent)” lives on this Mac only. Moving it into iCloud Drive → Gloss syncs it to your iPhone and other Macs — it stays a plain folder you own.")
            .font(.callout)
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)

        switch migrator.phase {
        case .moving:
            ProgressView("Moving vault…")
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.callout)
                .foregroundStyle(.orange)
            moveButton(root: root, title: "Try Again")
        case .idle, .done:
            moveButton(root: root, title: "Move to iCloud")
        }
    }

    private func moveButton(root: URL, title: String) -> some View {
        Button(title) {
            Task { await performMove(source: root) }
        }
        .buttonStyle(.borderedProminent)
        .disabled(!iCloudReady)
        .help(iCloudReady ? "" : "Sign in to iCloud and enable iCloud Drive first.")
    }

    private var iCloudReady: Bool {
        if case .available = ubiquityStore.state { return true }
        return false
    }

    /// The app-state choreography the migrator deliberately doesn't own.
    private func performMove(source: URL) async {
        guard case .available(let container) = ubiquityStore.state else { return }
        let documents = container.appendingPathComponent("Documents", isDirectory: true)

        // Quiesce — nothing may hold the vault or its SQLite open mid-move.
        settings.currentFileURL = nil
        linkIndex.close()
        fileTree.closeFolder()
        SecurityScopedBookmarks.shared.useVault(nil)

        do {
            let destination = try await migrator.move(
                vaultRoot: source, containerDocuments: documents)
            // Reopen from the container (no bookmarks needed there).
            fileTree.openFolder(destination)
            settings.rootFolderPath = destination.path
            linkIndex.buildIndex(rootURL: destination)
            RecentsStore.migrateBucket(oldRoot: source, newRoot: destination, in: modelContext)
            settings.removeRecentVault(source.path)
            settings.recordRecentVault(destination.path)
            uploadStatus.start(vaultRoot: destination)
        } catch {
            // The source is intact on failure — reopen it.
            SecurityScopedBookmarks.shared.useVault(source)
            fileTree.openFolder(source)
            settings.rootFolderPath = source.path
            linkIndex.buildIndex(rootURL: source)
        }
    }

    // MARK: - QR rendering

    static func qrImage(for url: URL, scale: CGFloat = 12) -> NSImage? {
        let filter = CIFilter(name: "CIQRCodeGenerator")
        filter?.setValue(Data(url.absoluteString.utf8), forKey: "inputMessage")
        filter?.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter?.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let rep = NSCIImageRep(ciImage: scaled)
        let image = NSImage(size: rep.size)
        image.addRepresentation(rep)
        return image
    }
}

/// Presentation wiring for the sheet, extracted as a modifier — ContentView's
/// body sits at the type-checker's expression budget (the FolderWatchHandler
/// "type-checker relief" pattern).
struct SetUpiPhonePresenter: ViewModifier {
    @State private var isPresented = false

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                SetUpiPhoneSheet()
            }
            .onReceive(NotificationCenter.default.publisher(for: .glossSetUpiPhone)) { _ in
                isPresented = true
            }
    }
}

/// Live "is the vault uploaded yet?" line under the QR: an NSMetadataQuery
/// counting not-yet-uploaded items beneath the vault root.
@Observable
@MainActor
final class VaultUploadStatus {
    private var query: NSMetadataQuery?
    private var observers: [any NSObjectProtocol] = []
    /// nil while gathering; 0 = fully uploaded.
    private(set) var pendingUploads: Int?

    func start(vaultRoot: URL) {
        stop()
        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        query.predicate = NSPredicate(
            format: "%K BEGINSWITH %@", NSMetadataItemPathKey,
            vaultRoot.resolvingSymlinksInPath().path + "/")
        for name in [Notification.Name.NSMetadataQueryDidFinishGathering, .NSMetadataQueryDidUpdate] {
            observers.append(NotificationCenter.default.addObserver(
                forName: name, object: query, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.recount() }
            })
        }
        self.query = query
        query.start()
    }

    func stop() {
        query?.stop()
        query = nil
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers = []
        pendingUploads = nil
    }

    private func recount() {
        guard let query else { return }
        query.disableUpdates()
        var pending = 0
        for index in 0..<query.resultCount {
            guard let item = query.result(at: index) as? NSMetadataItem else { continue }
            let uploaded = item.value(
                forAttribute: NSMetadataUbiquitousItemIsUploadedKey) as? Bool ?? true
            if !uploaded { pending += 1 }
        }
        query.enableUpdates()
        pendingUploads = pending
    }
}
