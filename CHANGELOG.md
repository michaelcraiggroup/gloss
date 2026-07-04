# Changelog

All notable changes to Gloss will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
