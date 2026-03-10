# Changelog

All notable changes to Gloss will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
