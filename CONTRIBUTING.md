# Contributing to Gloss

Thanks for your interest in contributing to Gloss! This document outlines how to get involved.

## Code of Conduct

Be respectful and constructive. We're all here to build useful tools.

## Getting Started

### Prerequisites

- Node.js 18+
- VS Code (for extension development)
- Xcode (for macOS app, when available)

### Setup

```bash
# Clone the repo
git clone https://github.com/michaelcraiggroup/gloss.git
cd gloss

# Install extension dependencies
cd extension
npm install
npm run compile

# Debug in VS Code
# Press F5 to launch Extension Development Host
```

## Project Structure

```
gloss/
├── extension/          # VS Code extension (TypeScript)
│   ├── src/
│   │   ├── extension.ts
│   │   ├── merrily/    # Merrily integration
│   │   └── reader/     # Custom webview panel
│   └── package.json
├── macos/              # macOS app (Swift) — future
└── docs/               # Documentation — future
```

## How to Contribute

### Reporting Bugs

1. Check existing [issues](https://github.com/michaelcraiggroup/gloss/issues)
2. Create a new issue with:
   - VS Code version
   - Gloss version
   - Steps to reproduce
   - Expected vs actual behavior

### Suggesting Features

Open an issue with the `enhancement` label. Describe:

- The problem you're solving
- Your proposed solution
- Any alternatives you considered

### Pull Requests

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run linting: `npm run lint`
5. Test your changes manually in VS Code (F5)
6. Commit with conventional commits (`feat:`, `fix:`, `docs:`, etc.)
7. Push and open a PR

### Code Style

- TypeScript strict mode
- ESLint + Prettier (run `npm run lint:fix` and `npm run format`)
- Conventional commits

## Areas for Contribution

### VS Code Extension

- [ ] Integration tests
- [ ] Edge cases (remote workspaces, WSL)
- [ ] Additional document type icons
- [ ] Custom CSS theming for reader

### macOS App (Future)

- [ ] Swift/SwiftUI implementation
- [ ] Quick Look extension
- [ ] File browser sidebar

### Documentation

- [ ] Usage examples
- [ ] Screenshots/GIFs
- [ ] Configuration recipes

## Questions?

Open an issue or reach out at [michaelcraig.group](https://michaelcraig.group).

---

_A [Michael Craig Group](https://michaelcraig.group) project_
