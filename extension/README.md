# Gloss - VS Code Extension

> **Gloss through your markdown without touching it.**

A distraction-free markdown reader for VS Code with Merrily integration for browsing operational documents.

## Features

### Reading Mode

- **Auto-preview on open** — Markdown files open in preview mode by default
- **Close source tab** — Automatically closes the editor tab, leaving only the preview
- **Edit command** — Press `Cmd+Shift+E` to switch to edit mode
- **Pattern matching** — Configure which files open in reading mode

### Merrily Integration

Browse your operational documents and Merrily data directly in VS Code:

- **Local Documents** — Browse your mcg-operations folder (or any folder)
- **Pitches** — View pitches from your Merrily instance
- **Cycles** — View cycles and their status
- **Retrospectives** — Read cycle retrospectives

All documents open in Gloss's distraction-free reading mode.

## Configuration

```jsonc
{
  // Reading mode
  "gloss.enabled": true,
  "gloss.patterns": ["**/*.md", "**/*.markdown"],
  "gloss.exclude": ["**/CHANGELOG.md"],
  "gloss.zenMode": false,
  "gloss.closeSourceTab": true,
  "gloss.showStatusBar": true,

  // Merrily integration
  "gloss.merrily.localFolder": "/path/to/mcg-operations",
  "gloss.merrily.apiUrl": "http://localhost:3000",
  "gloss.merrily.apiToken": "your-jwt-token"
}
```

## Commands

| Command | Keybinding | Description |
|---------|------------|-------------|
| `Gloss: Edit This File` | `Cmd+Shift+E` | Switch from preview to editor |
| `Gloss: Toggle Reading Mode` | — | Enable/disable globally |
| `Gloss: Open in Reading Mode` | — | Open current file in preview |
| `Gloss: Merrily: Configure Local Folder` | — | Set your docs folder |
| `Gloss: Merrily: Connect to API` | — | Connect to Merrily instance |
| `Gloss: Merrily: Disconnect` | — | Disconnect from API |

## Merrily Sidebar

The Gloss sidebar shows:

1. **📁 Local Documents** — Your configured folder tree
   - Subfolders expand to show contents
   - Click any `.md` or `.mdx` file to open in reading mode
   - Icons indicate document type (💡 pitch, 📊 retro, 🎯 strategy, etc.)

2. **📝 Pitches** — Pitches from Merrily API
3. **🔄 Cycles** — Cycles with status badges
4. **📊 Retrospectives** — Published retrospectives

## Privacy

No telemetry, no analytics, no network requests except to your configured Merrily instance.
All data stays local or goes only to your own API.

## Development

```bash
cd extension
npm install
npm run compile
# Press F5 in VS Code to launch Extension Development Host
```

## License

MIT
