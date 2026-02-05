# Changelog

All notable changes to Gloss will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

---

## Roadmap

### [0.2.0] — Planned

- Integration tests
- Remote workspace support (WSL, SSH)
- Custom CSS theming

### [1.0.0] — Future

- macOS standalone app
- Quick Look integration
- Multi-folder libraries
