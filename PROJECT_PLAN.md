---
project: "gloss"
title: "Gloss — Distraction-free markdown reading"
status: "active"
phase: "macOS App - Polish & Release"
progress: 90
stack: "TypeScript (VS Code Extension), Swift/SwiftUI (macOS App)"
next_steps:
  - "Code signing + notarization"
  - "DMG packaging or App Store submission"
  - "VS Code integration tests"
  - "Custom CSS theme support"
last_updated: "2026-02-18"
---

# Gloss - Project Plan

**Gloss** — Gloss through your markdown without touching it.

A distraction-free markdown reader as a VS Code extension and standalone macOS app.

## Current Focus: VS Code Extension MVP

See [gloss-project-plan.md](gloss-project-plan.md) for full product specification.

### MVP Features (v0.1.0)

- [x] Auto-preview on open (configurable patterns)
- [x] Close source tab automatically
- [x] Disable double-click-to-edit (custom webview)
- [x] "Edit This File" command
- [x] Status bar indicator
- [x] **Merrily Integration** — Browse operational docs in sidebar

### Merrily Integration Features

- [x] Sidebar tree view with folder browser
- [x] Local folder configuration
- [x] Document type icons (pitch, retro, strategy, etc.)
- [x] Merrily API client (pitches, cycles, retrospectives)
- [x] API connection/disconnection commands
- [x] Open documents in reading mode

### Milestones

**Phase 1: Foundation (Week 1)** ✅

- [x] Scaffold extension
- [x] Document open listener
- [x] Configuration schema
- [x] Manual preview triggering
- [x] Merrily tree provider

**Phase 2: Core Features (Week 2)**

- [x] Pattern matching (include/exclude)
- [x] Tab closing logic
- [x] Edit command
- [x] Status bar
- [ ] Integration tests

**Phase 3: Polish (Week 3)**

- [ ] Edge cases (remote, WSL, already open)
- [ ] README with screenshots
- [ ] Marketplace assets
- [ ] Merrily API authentication flow

**Phase 4: Release (Week 4)** ✅

- [x] Beta testing
- [x] Marketplace submission
- [x] Announce on michaelcraig.group

---

## macOS Standalone App

### macOS Phase 1: Foundation ✅

- [x] Swift Package with swift-markdown dependency
- [x] MarkdownRenderer (swift-markdown → HTML with Gloss CSS theme)
- [x] WKWebView wrapper (NSViewRepresentable)
- [x] Editor model with URL schemes (Cursor, Windsurf, VS Code, VSCodium, System)
- [x] AppSettings with @AppStorage persistence
- [x] ContentView with file importer, drag-and-drop, toolbar
- [x] DocumentView with empty/error/render states
- [x] SettingsView (editor picker, appearance picker)
- [x] GlossApp entry point with menu commands
- [x] Dark/light theme ported from VS Code extension
- [x] highlight.js syntax highlighting (CDN)
- [x] 13 passing tests (MarkdownRenderer + Editor)

### macOS Phase 2: File Browser ✅

- [x] NavigationSplitView with sidebar + detail
- [x] Recursive file tree using FileManager
- [x] Document type icons (pitch, retro, strategy, etc.)
- [x] Folder picker via NSOpenPanel
- [x] RecentDocument SwiftData model
- [x] File watcher for live reload (DispatchSource)
- [x] Content search (full-text across folder)
- [x] Filename search with scoped subfolder support
- [x] Favorites system (SwiftData, star/unstar, context menus)
- [x] Recent documents list

### macOS Phase 3: Quick Look & Polish ✅

- [x] Quick Look extension target
- [x] Bundle highlight.js locally (remove CDN)
- [x] Keyboard shortcuts (j/k scroll, Space page up/down, gg/G)
- [x] App icon
- [x] Find in page (Cmd+F)
- [x] Copy button on code blocks
- [x] Print support (Cmd+P via native NSPrintOperation)
- [x] Font size controls
- [x] Zen mode
- [ ] Custom CSS theme support

### macOS Phase 4: Sidebar Improvements & Release

- [x] Full directory path in sidebar header
- [x] Periodic directory polling (3s) to detect new/deleted files
- [x] Sortable file list (Name/Date, ascending/descending)
- [ ] Code signing + notarization
- [ ] DMG packaging or App Store submission

---

### Future: md+ Executable Markdown

- [ ] md+ block parser (HTML comments with YAML)
- [ ] Calculator block type
- [ ] Chart block type
- [ ] Embed block type (include other files)
- [ ] Shell block type (with security model)
- [ ] Trust configuration system (.md+config.yaml)

See [docs/MD_PLUS_SPEC.md](docs/MD_PLUS_SPEC.md) for full specification.
