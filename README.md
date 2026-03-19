# Gloss

> **Gloss through your markdown without touching it.**

A distraction-free markdown reader — VS Code extension and native macOS app. Reading is the default; editing is explicit.

## The Problem

**In VS Code:** Double-clicking in markdown preview switches to editor. Files always open in code view first. Preview is a separate tab. There's no "just let me read this" mode.

**Outside VS Code:** There's no good way to browse markdown without an editor. Preview.app doesn't render markdown. Every tool wants to edit. Sometimes you just want to _read_.

## The Solution

**Gloss** treats reading and writing as separate concerns. Open to read, explicitly switch to edit. The default is _preservation_, not modification.

## VS Code Extension (Free)

A true read-only markdown experience inside VS Code.

- Auto-opens markdown files in rendered preview
- Closes the source editor tab — no split view clutter
- Prevents accidental editing via double-click
- `Cmd+Shift+E` to switch to edit mode when needed
- Syntax highlighting with highlight.js
- Mermaid diagram rendering
- KaTeX math rendering (inline and display)
- Find-in-page (`Cmd+F`)
- Print support (`Cmd+P`)
- Copy buttons on code blocks
- YAML frontmatter stripping

📦 [Install from Marketplace](https://marketplace.visualstudio.com/items?itemName=michaelcraiggroup.gloss)

## macOS App (Free + $4.99 unlock)

A native markdown browser — like Preview.app, but for markdown.

### Free

- Single-file reading with full rendering
- Open in Editor (Cursor, VS Code, Windsurf, VSCodium)
- Quick Look extension — spacebar preview for `.md` in Finder
- Dark/light theme with Night Owl colors
- Live reload on file changes
- Keyboard navigation (vim-style: `j`/`k`, `gg`/`G`, Space)
- Syntax highlighting, Mermaid diagrams, KaTeX math
- Copy buttons on code blocks, heading anchors

### Paid ($4.99 one-time)

- **Folder sidebar** — file tree browser with drag-and-drop
- **Inspector** — table of contents, YAML frontmatter viewer, backlinks panel
- **Wiki-links** — `[[link]]` resolution with typed relationships (`[[target::type]]`)
- **Link index** — persistent SQLite index with backlinks and tag extraction
- **Full-text search** — content search across all files in a folder
- **Favorites & recents** — bookmark files, quick access to recent docs
- **Find-in-page** — `Cmd+F` with match navigation
- **Editor mode** — CodeMirror 6 live preview with Obsidian-style inline rendering
- **File management** — create, rename, delete files from the sidebar
- **Print & PDF export** — `Cmd+P` to print, export to PDF
- **Font size controls** — adjustable reading size

No subscription. No ads. Ever.

## Privacy

**Your reading habits are yours.** Both the extension and app run entirely locally. No analytics, no telemetry, no data collection. CDN resources (highlight.js, mermaid.js, KaTeX) are loaded for rendering only — nothing is sent anywhere.

## Development

```bash
# VS Code Extension
cd extension
npm install
npm run watch       # Development mode
# Press F5 in VS Code to debug

# macOS App
cd macos
swift build         # Build via SPM
swift test          # Run tests (171 tests)
xcodegen generate   # Generate Xcode project for release builds
```

## License

MIT — Free to use, modify, and distribute.

---

_A [Michael Craig Group](https://michaelcraig.group) project — sharp tools that don't spy on you._
