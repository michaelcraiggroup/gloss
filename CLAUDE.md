# Gloss

> **Gloss through your markdown without touching it.**

A distraction-free markdown reader — VS Code extension and macOS app.

## Project Structure

```
gloss/
├── extension/              # VS Code extension (TypeScript)
│   ├── src/
│   │   ├── extension.ts    # Main extension entry
│   │   └── merrily/        # Merrily integration
│   │       ├── treeProvider.ts   # Sidebar tree view
│   │       └── apiClient.ts      # Merrily API client
│   ├── package.json        # Extension manifest
│   └── tsconfig.json
├── macos/                  # macOS app (Swift/SwiftUI) — future
└── gloss-project-plan.md   # Full product plan
```

## Quick Reference

### Extension Development

```bash
cd extension
npm install
npm run compile      # Build TypeScript
npm run watch        # Watch mode
npm run lint         # ESLint
npm run test         # Run tests
```

**Debug in VS Code:**
- Press F5 to launch Extension Development Host
- Open any .md file to test
- Check Gloss sidebar for Merrily integration

**Package for distribution:**
```bash
npm run package      # Creates .vsix file
```

### Commands

| Command | Description |
|---------|-------------|
| `Gloss: Edit This File` | Switch from preview to editor |
| `Gloss: Toggle Reading Mode` | Enable/disable globally |
| `Gloss: Open in Reading Mode` | Open current file in preview |
| `Gloss: Merrily: Configure Local Folder` | Set mcg-operations path |
| `Gloss: Merrily: Connect to API` | Connect to Merrily instance |
| `Gloss: Merrily: Disconnect` | Disconnect from API |

### Configuration

```jsonc
{
  // Reading mode
  "gloss.enabled": true,
  "gloss.patterns": ["**/*.md"],
  "gloss.exclude": ["**/CHANGELOG.md"],
  "gloss.zenMode": false,
  "gloss.closeSourceTab": true,
  
  // Merrily integration
  "gloss.merrily.localFolder": "/path/to/mcg-operations",
  "gloss.merrily.apiUrl": "http://localhost:3000",
  "gloss.merrily.apiToken": ""
}
```

## Architecture

### Reading Mode

The extension intercepts markdown file opens and:
1. Triggers the built-in markdown preview
2. Closes the source editor tab
3. Creates a "read-only by default" experience

### Merrily Integration

The sidebar tree view provides:
- **Local folder browser** — Navigate mcg-operations or any folder
- **Document type icons** — Visual indicators (💡 pitch, 📊 retro, etc.)
- **API connection** — Live pitches, cycles, retrospectives from Merrily
- **Reading mode** — All documents open distraction-free

## Privacy

No telemetry, no analytics. Network requests only go to your configured Merrily instance.

## Conventions

- **Commits:** Conventional commits with emojis
- **TypeScript:** Strict mode, ESLint enforced
- **Testing:** Integration tests for VS Code API interactions

## Related Docs

- [Full Project Plan](gloss-project-plan.md)
- [Extension README](extension/README.md)
