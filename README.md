# Gloss

> **Gloss through your markdown without touching it.**

A distraction-free markdown reader — as a VS Code extension and a standalone macOS app. Read your docs, don't edit them.

## The Problem

**In VS Code:** Double-clicking in markdown preview switches to editor. Files always open in code view first. Preview is a separate tab. There's no "just let me read this" mode.

**Outside VS Code:** There's no good way to browse markdown without an editor. Preview.app doesn't render markdown. Every tool wants to edit. Sometimes you just want to *read*.

## The Solution

**Gloss** treats reading and writing as separate concerns. Open to read, explicitly switch to edit. The default is *preservation*, not modification.

## Components

### VS Code Extension (Free)

- Auto-opens markdown in preview mode
- Closes the source editor tab
- Prevents accidental editing via double-click
- Quick command to switch to edit mode when needed

📦 [Install from Marketplace](https://marketplace.visualstudio.com/items?itemName=michaelcraig.gloss)

### macOS App ($9.99) — Coming Soon

- Native markdown browser (like Preview.app, but for markdown)
- File browser sidebar for navigating folders
- Quick Look integration (spacebar preview in Finder)
- "Open in Editor" sends to Cursor, VS Code, or Windsurf

## Privacy

**Your reading habits are yours.** Both the extension and app run entirely locally. No analytics, no telemetry, no network requests. There's no server to send data to.

## Development

```bash
# Extension
cd extension
npm install
npm run watch   # Development mode
# Press F5 in VS Code to debug
```

## License

MIT — Free to use, modify, and distribute.

---

*A [Michael Craig Group](https://michaelcraig.group) project — sharp tools that don't spy on you.*
