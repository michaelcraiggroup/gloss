---
project: "gloss"
title: "Gloss — Distraction-free markdown reading"
status: "active"
phase: "Phase 1 - Foundation"
progress: 40
stack: "TypeScript (VS Code Extension), Swift/SwiftUI (macOS App)"
next_steps:
  - "Test extension in VS Code"
  - "Polish Merrily tree view icons"
  - "Add integration tests"
  - "Edge cases (remote, WSL, already open)"
last_updated: "2026-01-29"
---

# Gloss - Project Plan

**Gloss** — Gloss through your markdown without touching it.

A distraction-free markdown reader as a VS Code extension and standalone macOS app.

## Current Focus: VS Code Extension MVP

See [gloss-project-plan.md](gloss-project-plan.md) for full product specification.

### MVP Features (v0.1.0)

- [x] Auto-preview on open (configurable patterns)
- [x] Close source tab automatically
- [ ] Disable double-click-to-edit
- [x] "Edit This File" command
- [x] Status bar indicator
- [x] **Merrily Integration** — Browse operational docs in sidebar

### Merrily Integration Features

- [x] Sidebar tree view with folder browser
- [x] Local folder configuration (mcg-operations)
- [x] Document type icons (pitch, retro, strategy, etc.)
- [x] Merrily API client (pitches, cycles, retrospectives)
- [x] API connection/disconnection commands
- [x] Open documents in reading mode

### Milestones

**Phase 1: Foundation (Week 1)** ✅
- [x] Scaffold extension
- [x] Document open listener
- [x] Configuration schema
- [x] Manual preview triggering
- [x] Merrily tree provider

**Phase 2: Core Features (Week 2)**
- [x] Pattern matching (include/exclude)
- [x] Tab closing logic
- [x] Edit command
- [x] Status bar
- [ ] Integration tests

**Phase 3: Polish (Week 3)**
- [ ] Edge cases (remote, WSL, already open)
- [ ] README with screenshots
- [ ] Marketplace assets
- [ ] Merrily API authentication flow

**Phase 4: Release (Week 4)**
- [ ] Beta testing
- [ ] Marketplace submission
- [ ] Announce on michaelcraig.group
