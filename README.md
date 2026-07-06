# Gloss

> **Like Preview.app, but for markdown.** Opens to read; edits when you ask.

A distraction-free markdown reader — VS Code extension and native macOS app. Reading is the default; editing is explicit.

## The Problem

**In VS Code:** Double-clicking in markdown preview switches to editor. Files always open in code view first. Preview is a separate tab. There's no "just let me read this" mode.

**Outside VS Code:** There's no good way to browse markdown without an editor. Preview.app doesn't render markdown. Every tool wants to edit. Sometimes you just want to _read_.

## The Solution

**Gloss** treats reading and writing as separate concerns. Open to read, explicitly switch to edit. The default is _preservation_, not modification.

## VS Code Extension (Free)

A reader-first markdown experience inside VS Code — edits when you ask.

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

## macOS App (Free + $9.99 Pro unlock)

A native markdown browser — like Preview.app, but for markdown.

### Free

- Single-file reading with full rendering
- **Live-preview editor** (`⇧⌘E`) — CodeMirror 6, Obsidian-style inline rendering, for when you _do_ want to edit
- Open in Editor (Cursor, VS Code, Windsurf, VSCodium, Zed, Sublime Text, System Default, or any custom app)
- Quick Look extension — spacebar preview for `.md` in Finder
- Dark/light theme with Night Owl colors
- Live reload on file changes
- Keyboard navigation (vim-style: `j`/`k`, `gg`/`G`, Space)
- Navigation history (`⌘[` / `⌘]`) — back and forward through your reading trail
- Zen mode (`⌘\`) — hide the chrome, keep the words
- Syntax highlighting, Mermaid diagrams, KaTeX math
- Copy buttons on code blocks, heading anchors
- Find-in-page (`⌘F`) with match navigation
- Print & PDF export (`⌘P`)
- **Fillable templates (md+)** — forms render live in reading mode; "Save Filled Copy" writes a filled copy and never touches the original

### Paid — Gloss Pro ($9.99 one-time)

Use Gloss as a vault, not just a viewer:

- **Folder sidebar** — file tree browser; create, rename, and delete files in place
- **Vault overview** — dashboard of file/link/tag stats, hub documents, recent changes, and orphans
- **Inspector** — table of contents, tags, backlinks, unlinked mentions, and frontmatter properties you can edit in place
- **Wiki-links** — follow `[[link]]` navigation with typed relationships (`[[target::type]]`)
- **Transclusion** — embed live sections of other notes with `![[note#heading]]`
- **Link graph** — D3 force-directed view of how your notes connect, centered on the current file
- **Full-text search** — content search across every file in a folder
- **md+ queries** — live saved searches embedded in your notes, refreshed from the link index
- **Daily notes & Quick Capture** — `⌘T` opens today's note; the menu-bar bolt or a hot corner captures a thought from any app
- **Favorites & recents** — bookmark files, quick access to recent docs
- **Font size control** — adjustable reading size

Powered by a persistent local SQLite link index. No subscription. No ads. Ever.

## Privacy

**Your work belongs to you.** Both the extension and app run entirely locally. No analytics, no telemetry, no data collection. CDN resources (highlight.js, mermaid.js, KaTeX) are loaded for rendering only — nothing is sent anywhere.

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
swift test          # Run tests (373 tests in 43 suites)
xcodegen generate   # Generate Xcode project for release builds
```

## License

MIT — Free to use, modify, and distribute.

---

_Gloss, by [Off-Leash](https://michaelcraig.group) — the privacy-first software studio from Michael Craig Group. Your work belongs to you._
