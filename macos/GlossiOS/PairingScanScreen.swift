import SwiftUI
import VisionKit

/// The in-app pairing doorway: a live QR scanner where supported (real
/// devices), and a paste-the-link fallback everywhere (simulator, no-camera,
/// accessibility — and it makes AirDropped pairing links work too). Both
/// funnel into the same PairingHandler as the Camera-app deep link.
struct PairingScanScreen: View {
    let handler: PairingHandler

    @Environment(\.dismiss) private var dismiss
    @State private var pastedLink = ""

    var body: some View {
        NavigationStack {
            Group {
                if handler.state == .idle {
                    scannerOrFallback
                } else {
                    PairingStatusView(handler: handler)
                }
            }
            .navigationTitle("Pair with Mac")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(doneTitle) {
                        if case .done = handler.state {} else { handler.reset() }
                        dismiss()
                    }
                }
            }
        }
        .interactiveDismissDisabled(false)
        .onChange(of: handler.state) { _, newState in
            // A successful pair lands in the vault — close the doorway.
            if case .done = newState {
                Task {
                    try? await Task.sleep(for: .seconds(1))
                    dismiss()
                }
            }
        }
    }

    private var doneTitle: String {
        if case .done = handler.state { return "Done" }
        return handler.state == .idle ? "Cancel" : "Close"
    }

    @ViewBuilder
    private var scannerOrFallback: some View {
        if QRScannerView.isSupported {
            VStack(spacing: 0) {
                QRScannerView { code in
                    if let url = URL(string: code) {
                        handler.handle(url)
                    }
                }
                Text("Point at the code in Gloss on your Mac — File → Set Up iPhone…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
            }
        } else {
            fallback
        }
    }

    /// No live camera (simulator, restricted devices): the Camera app can
    /// still scan the code (it deep-links straight into Gloss), or the link
    /// can be pasted/AirDropped.
    private var fallback: some View {
        Form {
            Section {
                Label {
                    Text("This device can't scan in-app. Use the iPhone Camera app on the code — it opens Gloss directly — or paste the pairing link below.")
                        .font(.callout)
                } icon: {
                    Image(systemName: "qrcode.viewfinder")
                }
            }
            Section("Pairing link") {
                TextField("gloss://pair?…", text: $pastedLink)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Connect") {
                    if let url = URL(string: pastedLink.trimmingCharacters(in: .whitespacesAndNewlines)) {
                        handler.handle(url)
                    }
                }
                .disabled(pastedLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

/// Live pairing progress + the failure copy. Shown by the scan screen and by
/// RootView when the Camera-app deep link arrives with no scanner open.
struct PairingStatusView: View {
    let handler: PairingHandler

    /// Softens the locating copy after this long — the wrong-Apple-ID case
    /// looks exactly like "still syncing", so we advise rather than fail,
    /// and the screen self-heals if the vault lands.
    static let slowLocateThreshold: Duration = .seconds(30)
    @State private var locateIsSlow = false

    var body: some View {
        VStack(spacing: 16) {
            switch handler.state {
            case .idle:
                EmptyView()

            case .invalidCode:
                ContentUnavailableView {
                    Label("Not a Gloss pairing code", systemImage: "qrcode")
                } description: {
                    Text("Scan the code shown by Gloss on your Mac — File → Set Up iPhone…")
                }
                Button("Try Again") { handler.reset() }
                    .buttonStyle(.borderedProminent)

            case .needsICloud:
                ContentUnavailableView {
                    Label("iCloud is off", systemImage: "icloud.slash")
                } description: {
                    Text("Sign in to iCloud in Settings and turn on iCloud Drive — the vault syncs through your own iCloud.")
                }

            case .needsPro:
                ContentUnavailableView {
                    Label("Vaults are a Gloss Pro feature", systemImage: "sparkles")
                } description: {
                    Text("Unlock once and the pairing continues automatically.")
                }

            case .locating(let name):
                ProgressView()
                    .controlSize(.large)
                Text("Looking for “\(name)” in your iCloud…")
                    .font(.headline)
                if locateIsSlow {
                    Text("Still looking. Make sure this iPhone is signed into the same Apple Account as your Mac (Settings → your name), and give large vaults a moment to upload — it connects the instant the vault appears.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

            case .done(let name):
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.green)
                Text("Connected to “\(name)”")
                    .font(.headline)
            }
        }
        .padding(24)
        .task(id: handler.state) {
            locateIsSlow = false
            if case .locating = handler.state {
                try? await Task.sleep(for: Self.slowLocateThreshold)
                if case .locating = handler.state { locateIsSlow = true }
            }
        }
    }
}

/// Minimal DataScanner wrapper: first recognized QR wins.
private struct QRScannerView: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    static var isSupported: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onCode: onCode)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            isHighlightingEnabled: true)
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {}

    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) {
        controller.stopScanning()
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onCode: (String) -> Void
        private var fired = false

        init(onCode: @escaping (String) -> Void) {
            self.onCode = onCode
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            guard !fired else { return }
            for item in addedItems {
                if case .barcode(let barcode) = item,
                   let payload = barcode.payloadStringValue {
                    fired = true
                    dataScanner.stopScanning()
                    onCode(payload)
                    return
                }
            }
        }
    }
}
