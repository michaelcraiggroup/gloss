import SwiftUI

/// iOS settings: appearance, reading font size (Pro-gated, matching the
/// macOS SettingsView gate), purchase state, and the visible version number
/// (portfolio convention: the version is always visible in the running app).
struct SettingsScreen: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(StoreManager.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: themeBinding) {
                        ForEach(Appearance.allCases) { appearance in
                            Text(appearance.displayName).tag(appearance)
                        }
                    }
                    Stepper(
                        "Reading font size: \(settings.fontSize)pt",
                        value: fontSizeBinding,
                        in: 12...24
                    )
                }

                Section("Gloss Pro") {
                    if store.isUnlocked {
                        Label("Unlocked", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button {
                            Task { await store.restore() }
                        } label: {
                            if store.isRestoring {
                                ProgressView()
                            } else {
                                Text("Restore Purchase")
                            }
                        }
                        .disabled(store.isRestoring)
                        if store.restoreFoundNothing {
                            Text("No purchase found for this Apple Account.")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }

                Section {
                    LabeledContent("Version", value: appVersion)
                } footer: {
                    Text("Gloss by Off-Leash — no accounts, no analytics, no telemetry.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var themeBinding: Binding<Appearance> {
        Binding(
            get: { settings.colorSchemeAppearance },
            set: { settings.colorSchemeAppearance = $0 }
        )
    }

    /// Same gate call site shape as macOS SettingsView: the stepper works
    /// for Pro, and posts the paywall (write dropped) for the free tier.
    private var fontSizeBinding: Binding<Int> {
        Binding(
            get: { settings.fontSize },
            set: { newValue in
                guard store.gate(.fontSizeControl) else { return }
                settings.fontSize = newValue
            }
        )
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }
}
