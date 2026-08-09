# Gloss

> **Reading mode for markdown in VS Code.** Opens to read; edits when you ask.

The free Gloss VS Code extension — a distraction-free reading experience
for markdown files. (The native macOS/iOS apps that grew out of this
project now live separately as **Vesta**.)

## Structure

```
gloss/
└── extension/              # VS Code extension (TypeScript)
    ├── src/
    │   ├── extension.ts    # Main extension entry
    │   └── reader/         # Custom webview reader
    │       └── GlossReaderPanel.ts  # Webview with hljs, mermaid, KaTeX
    ├── package.json        # Extension manifest
    └── tsconfig.json
```

## Development

```bash
cd extension
npm install
npm run compile      # Build TypeScript
npm run watch        # Watch mode
npm run lint         # ESLint
npm run test         # Run tests
```

**Debug in VS Code:** press F5 to launch the Extension Development Host,
then open any .md file.

**Package:** `npm run package` produces the .vsix.

## Commands

| Command                       | Description                   |
| ----------------------------- | ----------------------------- |
| `Gloss: Edit This File`       | Switch from preview to editor |
| `Gloss: Toggle Reading Mode`  | Enable/disable globally       |
| `Gloss: Open in Reading Mode` | Open current file in preview  |

## Configuration

```jsonc
{
  "gloss.enabled": true,
  "gloss.patterns": ["**/*.md"],
  "gloss.exclude": ["**/CHANGELOG.md"],
  "gloss.zenMode": false,
  "gloss.closeSourceTab": true,
}
```

## Privacy

No telemetry, no analytics. CDN resources (highlight.js, mermaid.js,
KaTeX) load for rendering only. Nothing is sent anywhere.

## Conventions

- Conventional commits, limited emojis, always bump the extension version
- TypeScript strict mode, ESLint enforced
- Branch → PR to main; never commit directly to main
