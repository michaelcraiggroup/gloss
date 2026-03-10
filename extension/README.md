# Gloss - VS Code Extension

> **Gloss through your markdown without touching it.**

A distraction-free markdown reader for VS Code. Open to read, explicitly switch to edit.

## Features

### Reading Mode

- **Auto-preview on open** — Markdown files open in a beautifully rendered view by default
- **Close source tab** — Automatically closes the editor tab, leaving only the preview
- **Edit command** — Press `Cmd+Shift+E` to switch to edit mode instantly
- **Pattern matching** — Configure which files open in reading mode with glob patterns
- **Zen mode** — Optionally enter Zen Mode when opening markdown

### Rich Rendering

- **Syntax highlighting** — Code blocks with full highlight.js support
- **Mermaid diagrams** — Fenced ` ```mermaid ` blocks render as interactive diagrams
- **KaTeX math** — Inline `$...$`, display `$$...$$`, and LaTeX delimiters `\(...\)` / `\[...\]`
- **YAML frontmatter stripping** — Frontmatter is hidden from the rendered view
- **Image rendering** — Local and remote images display inline
- **Copy buttons** — Hover over any code block to copy with one click
- **Theme awareness** — Automatically matches your VS Code dark/light theme
- **Heading anchors** — Click TOC links to navigate within the document

### Tools

- **Find in page** — `Cmd+F` to search within the rendered view, `Cmd+G` to navigate matches
- **Print support** — `Cmd+P` to print with optimized layout (no chrome, clean page breaks)

## Configuration

```jsonc
{
  "gloss.enabled": true,
  "gloss.patterns": ["**/*.md", "**/*.markdown"],
  "gloss.exclude": ["**/CHANGELOG.md"],
  "gloss.zenMode": false,
  "gloss.closeSourceTab": true,
  "gloss.showStatusBar": true
}
```

## Commands

| Command                       | Keybinding    | Description                   |
| ----------------------------- | ------------- | ----------------------------- |
| `Gloss: Edit This File`      | `Cmd+Shift+E` | Switch from preview to editor |
| `Gloss: Toggle Reading Mode` | —             | Enable/disable globally       |
| `Gloss: Open in Reading Mode`| —             | Open current file in preview  |

## Privacy

No telemetry, no analytics. Gloss runs entirely locally.

**CDN dependencies** (loaded only when needed):
- **highlight.js** — Syntax highlighting for code blocks (loaded on every render)
- **mermaid.js** — Diagram rendering (loaded only when the document contains ` ```mermaid ` blocks)
- **KaTeX** — Math rendering (loaded only when the document contains `$`, `$$`, `\(`, or `\[` delimiters)

No other network requests are made. No data is sent anywhere.

## Development

```bash
cd extension
npm install
npm run compile
# Press F5 in VS Code to launch Extension Development Host
```

## License

MIT
