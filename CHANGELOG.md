# Changelog

All notable changes to Gloss will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.24.1]

### Fixed

Four device-only defects found (and fixed) during the first two-device QA
pass — none reproducible in the simulator, which has no real iCloud:

- **iPhone vaults now stay live.** The iOS metadata observer's path-key
  predicate silently matched nothing on real devices (the path attribute
  isn't reliably queryable, and iOS reports files under `/private/var` while
  the app's paths say `/var`) — so synced edits never refreshed the reader
  and newly downloaded notes never entered the link index, leaving
  wiki-links, content search, and backlinks empty. The query now uses the
  canonical name predicate with in-code vault scoping on normalized paths,
  on both the vault observer and the pairing locate watch.
- **Wiki-link taps navigate across folders on iPhone.** WKWebView's file
  sandbox (scoped by `loadHTMLString` to the note's own directory) silently
  refused to start navigations to file URLs outside it — cross-folder
  wiki-links were dead on arrival. iOS wiki hrefs now ride a `glosswiki://`
  scheme that always reaches the navigation delegate and decodes back to the
  target file.
- **The iPhone inspector no longer freezes the app.** Its spotlight-anchor
  modifier dereferenced the macOS-only walkthrough service, which iOS never
  injects — a fatal on first open. The anchor is now inert when the service
  is absent.
- **Backing out of the last note reveals the sidebar** instead of stranding
  the reader on an empty placeholder page (#98 — the structural cleanup of
  the compact navigation stack stays open).

## [1.24.0] - 2026-08-08

### Added

- **Gloss for iOS — the companion app** (arc
  [#76](https://github.com/michaelcraiggroup/gloss/issues/76)–[#79](https://github.com/michaelcraiggroup/gloss/issues/79),
  PRs #80–#91, one day). Reader-first v1 under the **same bundle identifier**
  as the Mac app (Universal Purchase — one "Gloss Pro" unlock covers both):
  vault browsing with favorites/recents shelves, full GlossKit render parity
  (wiki-links, transclusion, queries, Mermaid, KaTeX, the amber theme),
  wiki-link navigation with Back/Forward history, filename + full-text
  search with in-reader highlights, the knowledge inspector (TOC, tags,
  typed forward/backlinks), and per-file download states.
- **Vault sync via your own iCloud.** Vaults live in the app's container —
  "iCloud Drive → Gloss" — a plain folder you own; no server, no
  subscription. **Move Vault to iCloud…** migrates a local vault with a
  crash-healing journal; **Set Up iPhone…** shows a QR
  (`gloss://pair` — carries no secrets; the Apple Account is the boundary)
  plus live upload status. iPhones pair by Camera scan, in-app scanner, or
  pasted link — and vaults also appear automatically on any device signed
  into the same Apple Account. The SQLite index never syncs (per-device,
  Application Support for container vaults); `favorites.json` syncs with a
  two-writer merge so neither device clobbers the other; markdown downloads
  eagerly on the phone and indexes as it lands; evicted or still-syncing
  files show a "Downloading from iCloud" state on both platforms and
  self-heal when bytes arrive.

- **macOS iCloud foundation** — the app now carries the iCloud Documents
  entitlements for its container (`iCloud.group.michaelcraig.gloss`,
  published in iCloud Drive as "Gloss"). `UbiquityVaultStore` resolves the
  container off-main and defers container-vault restore until it's ready;
  security-scoped bookmarks correctly no-op for container paths (the sandbox
  already extends there). Release signing is now per-target in project.yml —
  the app embeds the "Gloss Developer ID iCloud" profile (iCloud is a
  restricted entitlement), the Quick Look extension stays profile-free — and
  `release-dmg.sh` preflights the profile and verifies the embedded
  entitlements post-archive. Portal state and one-time steps:
  `docs/ICLOUD_SETUP.md`.

- **Notes answer from system search.** Every indexed note is now a Core
  Spotlight item (title, snippet, full text) on both platforms — ⌘Space on
  the Mac or the iOS search screen finds your notes and opens them straight
  in the reader, even when Gloss isn't running. Kept in lockstep with the
  link index (added on build/save, removed on delete, purged and re-added
  when a vault moves to iCloud). Spotlight's index is on-device — nothing
  leaves the machine.

### Changed

- Version aligned to 1.24.0 across all three targets (macOS app, Quick Look
  extension, iOS app). No macOS behavior change in this release.

## [macOS 1.23.0] - 2026-08-05

### Changed

- **The sidebar now reads top-down: your vault first, everything else second** — the file tree sits under a branded vault header (vault or scoped-folder name, its path, an amber spine), and the quick-access shelves beneath it (Favorites, Recently Changed, Tags, Recent Documents) drop to quiet uppercase captions with a rule marking where the vault's documents end

### Removed

- **Vault Graph (⌥⌘G) is shelved** — the View-menu item, the sidebar toolbar button, the shortcut, and the paywall's "Link graph view" row are all gone, and the graph no longer rebuilds vault-wide node/edge data when a vault opens. The implementation stays in the codebase behind `GlossFeatures.vaultGraph`; flip that flag to bring every entry point back ([#12](https://github.com/michaelcraiggroup/gloss/issues/12)). Gloss Pro now gates six features, not seven — README and App Store listing copy updated to match

## [macOS 1.22.0] - 2026-07-09

### Added

- **New Vault… (⇧⌘V)** — create a vault folder from inside Gloss and open it immediately, instead of making one in Finder first; refuses to silently adopt an existing folder of the same name ([#65](https://github.com/michaelcraiggroup/gloss/issues/65))
- **Today's Note (⌘T) works from launch** — with no vault open it now reopens your most recent vault (or asks you to pick one), then opens today's note, instead of sitting disabled until a vault is opened ([#63](https://github.com/michaelcraiggroup/gloss/issues/63))

### Changed

- **"Open Folder" is now "Open Vault"** across the File menu, sidebar toolbar, open panels, Quick Capture, and the built-in guides — matching what it actually opens ("Close Folder" → "Close Vault" too) ([#64](https://github.com/michaelcraiggroup/gloss/issues/64))
- **Zen mode moved to ⌃⌘Z** (was ⌘\) — 1Password's global autofill hotkey defaults to ⌘\ and swallowed the shortcut before Gloss ever saw it ([#69](https://github.com/michaelcraiggroup/gloss/issues/69))

### Fixed

- **Install Command Line Tool works in release builds** — the `gloss` script was never bundled into Xcode-built apps (xcodegen silently ignored the invalid `resources:` key in project.yml), so installing always failed with "CLI Script Not Found" ([#67](https://github.com/michaelcraiggroup/gloss/issues/67))
- **Save Filled Copy… is only enabled when it can do something** — documents with fillable content (task lists or md+ template blocks) in read mode; previously it was clickable-but-inert for every document ([#66](https://github.com/michaelcraiggroup/gloss/issues/66))
- **Vaults opened from the sidebar toolbar now survive relaunch** — that path skipped capturing a security-scoped bookmark, so the sandboxed app couldn't restore the vault on next launch; it now routes through the same open pipeline as every other entry point ([#64](https://github.com/michaelcraiggroup/gloss/issues/64))
- **Files opened by drag-and-drop stay readable after relaunch** — the drop path was the last entry point that never captured a security-scoped bookmark, so drop-opened files in Recents hit "Grant Access" after restarting ([#64](https://github.com/michaelcraiggroup/gloss/issues/64))

## [macOS 1.21.4] - 2026-07-08

### Fixed

- **Clicking Clear on Recent Documents no longer crashes the app** — emptying the recents removed the entire sidebar section, including the header row the cursor was on (Clear lives in that header), and AppKit's next tracking-area update probed the deallocated header row and segfaulted. The Favorites and Recent Documents sections now always render, showing a quiet "No favorites yet" / "No recent documents" row when empty, and Clear appears only when there is something to clear. Un-starring the last favorite had the same latent crash and is covered by the same fix ([#61](https://github.com/michaelcraiggroup/gloss/issues/61))

## [macOS 1.21.3] - 2026-07-07

### Fixed

- **Paywall no longer pretends to load forever** — when the App Store product can't be fetched (offline, or the app isn't visible in this machine's App Store environment), the paywall now says so and offers **Try Again**, instead of a perpetual "Loading…" spinner; the product is also re-requested every time the paywall opens ([#59](https://github.com/michaelcraiggroup/gloss/issues/59))
- **Restore Purchase now reports its outcome** — a spinner while it runs, and a clear "No purchase found for this Apple Account." message when it completes without finding an entitlement, instead of silently returning to the same modal ([#59](https://github.com/michaelcraiggroup/gloss/issues/59))

## [macOS 1.21.2] - 2026-07-07

### Fixed

- **One-click re-grant instead of the dead-end red error** — clicking a Recent or favorite that Gloss no longer has permission to read (e.g. anything recorded before 1.21.1 kept access grants) now shows a **"Grant Access…"** prompt that opens an Open panel pre-selected on that exact file. Picking it stores the access grant on the spot, so the file opens straight from Recents from then on. Genuinely missing files keep the plain error ([#57](https://github.com/michaelcraiggroup/gloss/issues/57))
- `release-dmg.sh` now falls back to `hdiutil makehybrid` when `create-dmg` can't drive Finder (headless/resumed sessions), so release packaging can't strand a signed build without a DMG

## [macOS 1.21.1] - 2026-07-06

### Fixed

- **Recent Documents / favorites / vault restore now work in the signed build** — the sandboxed release could not re-read files from a stored path (clicking a recent gave "could not read file"), because it kept no security-scoped bookmarks. The app now captures a bookmark whenever you grant access (Open panel, Finder open, drag-in) and resolves it on re-open, so access survives relaunch. Note: a file added to recents *before* this update must be opened once (Finder or Open) to capture its bookmark; afterward it opens straight from Recents ([#55](https://github.com/michaelcraiggroup/gloss/issues/55))
- **Opening a file no longer spawns a duplicate window** — an external open (Finder double-click, `open`, drag) now reuses the existing window instead of opening a second one; the `WindowGroup` no longer claims all external events, and opens route through a single handler ([#52](https://github.com/michaelcraiggroup/gloss/issues/52))

### Changed

- **Zoom ceiling raised to 500%** (was 300%) and the step widened to 25% per ⌘=/⌘−, so large Mermaid diagrams can be enlarged further and faster

## [macOS 1.21.0] - 2026-07-06

### Added

- **Document zoom** — **⌘=** (zoom in), **⌘−** (zoom out), and **⌘0** (actual size) scale the entire rendered page, so large **Mermaid diagrams**, images, and tables become readable — not just text. (The existing Font Size control only affects text.) The zoom level persists across documents and app launches, and is a free feature ([#53](https://github.com/michaelcraiggroup/gloss/issues/53))

### Fixed

- **PDF export is now zoom-independent** — exporting while zoomed in produced an oversized PDF; exports are now always captured at actual size regardless of the on-screen zoom

## [macOS 1.20.2] - 2026-07-04

### Fixed

- **Post-upgrade locked window eliminated** — the app now trusts the last verified purchase at launch instead of waiting for StoreKit, which on freshly signed Developer-ID builds could take minutes to hours to re-deliver the entitlement (locking Pro features and silently skipping the vault restore on the first launch after every update). Refunds still revoke, including ones that happen while the app isn't running. The cache seeds on this install's first successful verification — or one click of Restore Purchases ([#38](https://github.com/michaelcraiggroup/gloss/issues/38))

## [macOS 1.20.1] - 2026-07-04

### Changed

- Paid tier is now presented as **Gloss Pro** at **$9.99 one-time** everywhere — paywall, StoreKit test config, App Store metadata, docs — matching the published Off-Leash pricing (decision 2026-07-03). The IAP product ID is unchanged; existing purchases are unaffected ([#44](https://github.com/michaelcraiggroup/gloss/issues/44))

## [macOS 1.20.0] - 2026-07-04

Vault-scoped memory: favorites and recents now belong to the vault you're
in, instead of one app-global list that bled across vaults.

### Added

- **Favorites live in the vault** — stored as relative paths in `.gloss/favorites.json`, so they travel with the folder (sync, backup, machine moves) and each vault shows only its own. Loose files opened without a vault keep their own favorites list
- **Vault-scoped recents** — Recent Documents shows only files opened in the current vault; switching vaults no longer shows the previous vault's list
- **Recents cover every navigation path** — wiki-links, backlinks, breadcrumbs, graph clicks, back/forward, and CLI opens now land in Recent Documents (previously only sidebar clicks did)
- **Clear button** on the Recent Documents section
- **Open Recent Vault** submenu in the File menu (last 5 vaults)
- **Missing favorites dim with a badge** instead of failing silently, and heal when the file returns (e.g. sync catches up)

### Fixed

- Favorites/recents written with mismatched path forms (standardized vs raw) could duplicate entries for the same file on symlinked paths
- Renaming or deleting a file (or folder) now updates matching favorites and recents instead of orphaning them into "Could not read file"
- Dead recents entries are pruned when a vault opens

### Changed

- Existing favorites and recents migrate into the vault's scope the first time that vault is opened in 1.20

## [macOS 1.19.1] - 2026-07-02

### Fixed

- **Stranded loading spinner on cold-launch external opens** — when the vault restored after the first document had already rendered, the resulting identical re-render never navigated, so the spinner never cleared. Identical renders now clear the loading state directly, and unchanged content skips the re-render entirely ([#40](https://github.com/michaelcraiggroup/gloss/issues/40))
- **Vault silently not reopening on first launch of a fresh binary** — folder restore raced the App Store entitlement check with no retry; the restore now re-runs when the unlock lands ([#38](https://github.com/michaelcraiggroup/gloss/issues/38))
- **`make-app.sh` refuses unsubstituted Info.plists** — a dev bundle built from a post-xcodegen working tree shipped a literal `$(PRODUCT_BUNDLE_IDENTIFIER)` identity that LaunchServices registered as a second app named "Gloss", hijacking name-based launches ([#39](https://github.com/michaelcraiggroup/gloss/issues/39))

## [macOS 1.19.0] - 2026-07-02

Performance overhaul: fixes sustained high CPU, main-thread hangs, and
multi-GB memory growth when the open vault is (or contains) a development
workspace ([#35](https://github.com/michaelcraiggroup/gloss/issues/35)).

### Fixed

- **Dev build artifacts excluded everywhere** — `target`, `dist`, `build`, `DerivedData`, `Pods`, `.venv`, and other standard artifact folders are now ignored by the folder watcher, the sidebar tree, and the link index. Per-vault overrides via `.gloss/config.json` (`excludeAdd` / `excludeRemove`)
- **Watcher batches debounced** — sustained churn (builds, git, agent sessions) coalesces into one reconcile + index pass per window instead of one per FSEvents callback
- **Targeted tree reconciliation** — file-system events re-list only the loaded parent directories of the changed paths; the whole-tree re-enumeration that pegged the main thread is gone
- **Filename search & wiki-links query the index** — no more force-loading the entire vault tree on the main thread during search or when a wiki-link can't resolve
- **Serialized, incremental indexing** — index mutations run on one cancellable pipeline; rebuilds skip files whose mtime hasn't changed; watcher-triggered full rebuilds are rate-limited and coalesced
- **Indexed link resolution** — per-save resolution is incremental and index-backed; the O(links × files) full-table scan after every save is gone
- **Dashboard/graph refresh gated by visibility** — vault-wide aggregates and the full graph no longer rebuild on every index tick while hidden (the graph was also refreshing twice per tick when visible)
- **Symlinked-vault rebuild bug** — stale-file cleanup compared unresolved against resolved paths, wiping and re-indexing the whole vault on every build for vaults under `/tmp`-style roots

### Added

- Large-workspace notice in the sidebar (one-time) pointing at `.gloss/config.json`
- Launch restore defers indexing off the first frame

## [0.2.2] - 2026-03-10

### Added

- **KaTeX math rendering** — Inline `$...$`, display `$$...$$`, and LaTeX delimiters `\(...\)` / `\[...\]`
- KaTeX CSS and fonts loaded from CDN, only when math content is detected

### Fixed

- **YAML frontmatter stripping** — Frontmatter is now removed before rendering
- **Local image rendering** — Relative image paths resolve correctly in webview; CSP updated with `img-src`
- KaTeX auto-render polling fallback for reliable initialization in VS Code webview

## [0.2.1] - 2026-02-19

### Changed

- Removed Merrily integration references from user-facing commands and UI

### Fixed

- Markdown files now reliably reopen in reading mode via `onDidChangeActiveTextEditor` listener

## [0.2.0] - 2026-02-19

### Added

- **Mermaid diagram rendering** — Fenced ` ```mermaid ` blocks render as diagrams via mermaid.js (v11.12.0)
- Conditional CDN loading — Mermaid script only loaded when source contains mermaid blocks
- Theme-aware diagrams — Dark/light mode detection for diagram rendering

## [0.1.3] - 2026-02-19

### Added

- **Print support** — `Cmd+P` / `Ctrl+P` to print rendered documents with print-optimized CSS
- **Find-in-page** — `Cmd+F` to search within rendered view, `Cmd+G` / `Cmd+Shift+G` to navigate matches
- Print CSS hides toolbar, find bar, and copy buttons; optimizes layout for paper

## [0.1.2] - 2026-02-05

### Fixed

- Table of contents anchor links now scroll to their target sections
- Added heading ID generation (required since marked v5+ removed built-in IDs)
- Anchor click handling for smooth in-page navigation within the webview

## [0.1.1] - 2026-01-29

### Changed

- Updated documentation wording for clarity

## [0.1.0] - 2026-01-29

### Added

- **Custom Gloss Reader Panel** — True read-only markdown viewing with no double-click-to-edit
- **Merrily Integration** — Sidebar for browsing operational documents
  - Local folder browser with document type icons
  - Merrily API connection for pitches, cycles, retrospectives
- **Reading Mode Commands**
  - `Gloss: Edit This File` (Cmd+Shift+E) — Switch to editor
  - `Gloss: Toggle Reading Mode` — Enable/disable globally
  - `Gloss: Open in Reading Mode` — Open current file in preview
- **Configuration Options**
  - Pattern matching for auto-preview
  - Exclude patterns
  - Zen mode option
  - Auto-close source tab
- **Status Bar Indicator** — Shows reading mode status
- **Syntax Highlighting** — Code blocks rendered with highlight.js
- **Copy Buttons** — One-click copy for code blocks

### Privacy

- Zero telemetry
- No analytics
- Network requests only to user-configured Merrily instance
