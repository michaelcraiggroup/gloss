# Gloss

> **Gloss through your markdown without touching it.**

A distraction-free markdown reader — VS Code extension and macOS app.

## Project Structure

```
gloss/
├── extension/          # VS Code extension (TypeScript)
├── macos/              # macOS app (Swift/SwiftUI) — future
├── docs/               # Shared documentation
└── gloss-project-plan.md  # Full product plan
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

**Package for distribution:**
```bash
npm run package      # Creates .vsix file
```

### Commands

| Command | Description |
|---------|-------------|
| `Gloss: Edit This File` | Switch from preview to editor |
| `Gloss: Toggle Reading Mode` | Enable/disable globally |

### Configuration

```jsonc
{
  "gloss.enabled": true,
  "gloss.patterns": ["**/*.md"],
  "gloss.exclude": ["**/CHANGELOG.md"],
  "gloss.zenMode": false
}
```

## Architecture

The extension intercepts markdown file opens and:
1. Triggers the built-in markdown preview
2. Closes the source editor tab
3. Disables double-click-to-edit in preview

This creates a "read-only by default" experience.

## Privacy

No telemetry, no analytics, no network requests. Everything runs locally.

## Conventions

- **Commits:** Conventional commits, no emojis
- **TypeScript:** Strict mode, ESLint enforced
- **Testing:** Integration tests for VS Code API interactions

## Related Docs

- [Full Project Plan](gloss-project-plan.md)
- [Extension README](extension/README.md)
