# Gloss for iOS — Companion App & Vault Sync Strategy

> Decision doc for [#68](https://github.com/michaelcraiggroup/gloss/issues/68). Written 2026-07-09. **Status: proposed — awaiting go/no-go on the v1 recommendation below.**

## TL;DR

Ship an iOS companion **reader-first**, using **iCloud Drive as the vault** (Option 1). It is the only option that requires zero servers, preserves the folder model Gloss is built on, inherits end-to-end encryption for free (Advanced Data Protection), and keeps the one-time-purchase promise intact. CloudKit (Option 2) and self-hosted/WebDAV (Option 3) stay on the table as *later* upgrades, not v1.

The important discovery that makes this cheap: **`GlossKit` is entirely UI-framework-free** — it imports only `Foundation`, `Markdown`, and `Yams`. The whole rendering/parsing/md+/index engine already compiles for iOS unchanged. The iOS project is a new SwiftUI shell around a library we already ship, not a rewrite.

---

## 1. Constraints (non-negotiable)

From the portfolio's core principle — *your data belongs to you* — and the privacy architecture strategy:

- **No server we own may hold plaintext.** This eliminates any "Gloss sync service."
- **No telemetry, no analytics.** Already true on macOS; must stay true on iOS.
- **No subscription for sync.** The macOS app is free + a one-time $9.99 "Pro" unlock ([PaidFeature](../macos/Sources/Gloss/Services/StoreManager.swift)). iOS must not introduce a recurring charge to make files sync.
- **Local-first.** The app must be fully usable offline; sync is a convenience layer over local files, never a dependency.

These constraints do most of the deciding for us.

---

## 2. What a vault is (and why it keeps options open)

A Gloss vault is **a plain folder** of `.md` files plus a `.gloss/` subfolder holding derived state:

| Path | Contents | Syncable? |
|------|----------|-----------|
| `*.md` | The user's notes — the actual data | **Yes** — this is the vault |
| `.gloss/favorites.json` | Vault-scoped favorites, relative paths | Yes (small, human-mergeable JSON) |
| `.gloss/index.sqlite` | GRDB link/tag/property index — **derived**, mtime-incremental ([LinkDatabase](../macos/Sources/Gloss/Services/LinkDatabase.swift)) | **No — rebuild on device** |

The data is just files, so any sync transport that moves a folder works. The `.gloss/index.sqlite` is the one thing we must *not* sync: SQLite over a file-sync layer corrupts on partial/concurrent writes, and it is cheap to regenerate (already incremental). **Decision: the index is per-device local, rebuilt from the synced markdown on first open.** Favorites JSON is small and last-writer-wins-tolerable, so it can ride along in the vault.

---

## 3. What already ports for free

| Layer | Status on iOS |
|-------|---------------|
| `GlossKit` — `MarkdownRenderer`, `MdPlusParser`, wiki-link/tag extraction, template-fill rewrite | **Compiles unchanged** (Foundation + Markdown + Yams only) |
| Read-mode rendering (`WKWebView` + themed HTML) | WebKit is cross-platform; `NSViewRepresentable` → `UIViewRepresentable` |
| `StoreManager` / StoreKit 2 (`group.michaelcraig.gloss.full`) | StoreKit 2 is cross-platform; universal purchase viable (§6) |
| SwiftData recents, GRDB index | Both iOS-native already |

What is macOS-only and needs an iOS counterpart (mostly the shell):

- **Menus & keyboard commands** ([GlossApp](../macos/Sources/Gloss/GlossApp.swift)) → iOS toolbar + gestures; no menu bar.
- **`NSOpenPanel`/`NSSavePanel`, security-scoped bookmarks** ([SecurityScopedBookmarks](../macos/Sources/Gloss/Services/SecurityScopedBookmarks.swift)) → `UIDocumentPickerViewController` + `UIDocument`/`NSFileCoordinator`; iCloud ubiquity URLs instead of app-scoped bookmarks.
- **Hot-corner Quick Capture** ([QuickCaptureController](../macos/Sources/Gloss/Services/QuickCaptureController.swift)) → Share Extension + Home-Screen/Lock-Screen widget (§5).
- **External-editor launch** ([EditorLauncher](../macos/Sources/Gloss/Services/EditorLauncher.swift)) → **dropped** on iOS (no concept).
- **Save Filled Copy** panel ([TemplateFillService](../macos/Sources/Gloss/Services/TemplateFillService.swift)) → `UIDocumentPicker` export.

Estimate: the *engine* is done; the work is a new `Sources/GlossiOS` app target + adding `.iOS(.v17)` to [Package.swift](../macos/Package.swift) and gating the AppKit shell behind `#if os(macOS)`.

---

## 4. The three sync options, scored against §1

### Option 1 — iCloud Drive folder as the vault ✅ recommended for v1

The vault lives in the app's iCloud container (or a user-picked iCloud Drive folder). Files sync via the system; the app reads/writes through `UIDocument`/`NSFileCoordinator`.

- **Server holding plaintext?** No — Apple's, and encrypted end-to-end when the user has **Advanced Data Protection** on. We never see it.
- **Infra we run?** None.
- **Folder model?** Preserved exactly — this *is* the folder, in a synced location.
- **Conflicts?** Handled by iCloud (`NSFileVersion` conflict versions surfaced to the user).
- **Subscription?** None from us. (User's own iCloud tier is theirs.)
- **Cost to build?** Lowest — it's the file-provider plumbing plus the shell.

Weaknesses: iCloud-only (no Android/web); conflict UX is coarse (whole-file versions, not merges); requires the user to be in the Apple ecosystem. All acceptable for a Mac/iOS reader-first companion.

### Option 2 — CloudKit private database

Per-note records synced through the user's private CloudKit DB with delta sync.

- **Server plaintext?** CloudKit private DB is the user's iCloud, not ours — acceptable, though not E2E unless we add our own crypto layer.
- **Merge quality?** Best of the three (record-level deltas, `CKServerChangeToken`).
- **Cost?** High — a real sync engine, plus a **migration off the folder model** (the vault stops being "just files"), which fights the reader-first "it's your folder" story.

Verdict: **deferred.** Only worth it if real usage shows whole-file conflict versions are painful. It is an optimization of merge semantics, not a v1 requirement — and it partially undermines the "your data is a folder you own" pitch.

### Option 3 — Standards-based / self-hosted (WebDAV or similar)

The strongest "your data belongs to you" story: point Gloss at your own server.

- **Server plaintext?** The user's own box — the ideal.
- **Portfolio fit?** *Adjacent to* Tempo (our privacy-first CalDAV server) philosophically — same "run your own" ethos — but Tempo is **CalDAV, not file sync**, so this is net-new capability, not reuse.
- **Cost?** Highest, and it asks users to run infrastructure — a power-user feature, not a v1 default.

Verdict: **deferred to a "bring your own server" power feature**, likely after the KB scope matures. Worth designing the vault-location abstraction (§7) so this can slot in without a rewrite.

---

## 5. Open questions — resolved

**Reader-first scope for v1?** — **Yes, reader-first.** v1 = browse the vault tree, read (full `GlossKit` render parity incl. mermaid/KaTeX/highlighting), search, favorites, recents, and wiki-link navigation. This is the differentiator ("opens to read") and is ~90% reuse. **Editing is v2** (CodeMirror-in-`WKWebView` already works cross-platform, but the editing *shell* — toolbars, save flow — is the added surface).

**Quick Capture on iOS?** — **Both, phased.** A **Share Extension** first (send text/URL from any app into the vault's capture target) — highest leverage, mirrors the macOS hot-corner intent. A **widget** (Home/Lock Screen "new note") second. This matches how Zephster already ships widgets.

**`.gloss/` index — sync or rebuild?** — **Rebuild on device** (§2). Never sync the SQLite. Favorites JSON syncs.

**Pro unlock parity?** — **Universal Purchase.** Ship the iOS app under the **same bundle identifier lineage** and configure Universal Purchase in App Store Connect so the existing `group.michaelcraig.gloss.full` entitlement unlocks both platforms from one $9.99 purchase. StoreManager's StoreKit 2 code already keys off that product ID; `Transaction.currentEntitlements` resolves across platforms under Universal Purchase. **This must be decided before the first iOS TestFlight** — retrofitting Universal Purchase after separate SKUs ship is painful.

**Zephster/Syncopate patterns?** — Reuse: SwiftUI + SwiftData app scaffold, widget/App-Intent structure (Zephster), and the `@Observable` service-injection pattern already used here. Gloss iOS is the third SwiftUI-on-iOS app in the portfolio, so the shell is well-trodden.

---

## 6. Scope map (PROJECT_PLAN-style)

```
iOS-M0  Foundations
  - Package.swift: add .iOS(.v17); confirm GlossKit builds for iOS sim
  - New Gloss iOS app target; #if os(macOS) gate the AppKit shell
  - Vault-location abstraction (protocol) — local container | iCloud | (future) WebDAV
  - Universal Purchase set up in App Store Connect  ← gating decision

iOS-M1  Reader (v1 ship)
  - iCloud Drive vault: UIDocument/NSFileCoordinator open + live update
  - File tree + read-mode WKWebView (GlossKit render parity)
  - Search, favorites (shared .gloss/favorites.json), recents (SwiftData)
  - On-device .gloss/index.sqlite rebuild; wiki-link nav; inspector (TOC/backlinks)
  - Pro gate parity via Universal Purchase
  - Quick Look-equivalent: Share-sheet "Open in Gloss" for .md

iOS-M2  Capture
  - Share Extension → append/create in capture target
  - Today/daily-note; Home & Lock Screen widgets

iOS-M3  Edit
  - CodeMirror live-preview editor (WKWebView) + save via file coordination
  - Conflict UX: surface NSFileVersion conflict versions

Later / not v1
  - CloudKit delta sync (only if whole-file conflicts prove painful)
  - Bring-your-own-server (WebDAV) via the vault-location protocol
```

## 7. Design seam that keeps 2 & 3 open

Introduce a `VaultLocation` protocol in M0 (open/enumerate/read/write/observe over a root), with a `LocalFileVaultLocation` (covers both on-device and iCloud-ubiquity URLs). CloudKit and WebDAV later become alternative conformers. This is the single abstraction that prevents the iCloud choice from becoming a lock-in — the reader doesn't care where bytes come from.

## 8. Risks & non-goals

- **Risk: iCloud conflict UX.** Whole-file conflict versions can confuse. Mitigation: surface them explicitly (don't auto-pick); revisit CloudKit if it bites.
- **Risk: Universal Purchase mis-config.** Decide *before* first TestFlight (§5).
- **Non-goal (v1):** Android, web, real-time collab, editing.
- **Non-goal:** any Gloss-operated sync server, ever.

## 9. Decision needed

1. **Approve iCloud-Drive-as-vault for v1?** (recommended)
2. **Confirm Universal Purchase** (one $9.99 unlocks macOS + iOS) vs. a separate iOS SKU.
3. **Reader-first v1, edit in v2** — approve the cut line?

On approval, the implementation plan gets archived to `mcg-operations/plans/gloss/` and iOS-M0 starts.
