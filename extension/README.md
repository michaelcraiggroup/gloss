# Gloss - VS Code Extension

> **Gloss through your markdown without touching it.**

A distraction-free markdown reader for VS Code.

## Features

### Reading Mode

- **Auto-preview on open** — Markdown files open in a rendered view by default
- **Close source tab** — Automatically closes the editor tab, leaving only the preview
- **Edit command** — Press `Cmd+Shift+E` to switch to edit mode
- **Pattern matching** — Configure which files open in reading mode
- **Syntax highlighting** — Code blocks with full highlight.js support
- **Mermaid diagrams** — Fenced `mermaid` blocks render as diagrams
- **Find in page** — `Cmd+F` to search within the rendered view
- **Print support** — `Cmd+P` to print the rendered document

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

No telemetry, no analytics, no network requests (except CDN for syntax highlighting and diagram rendering).

## Development

```bash
cd extension
npm install
npm run compile
# Press F5 in VS Code to launch Extension Development Host
```

## License

MIT
