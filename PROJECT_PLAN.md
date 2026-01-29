---
project: "gloss"
title: "Gloss — Distraction-free markdown reading"
status: "active"
phase: "Phase 1 - Foundation"
progress: 0
stack: "TypeScript (VS Code Extension), Swift/SwiftUI (macOS App)"
next_steps:
  - "Scaffold VS Code extension"
  - "Implement document open listener"
  - "Add pattern matching configuration"
  - "Tab management (close source after preview)"
  - "Status bar indicator"
last_updated: "2026-01-28"
---

# Gloss - Project Plan

**Gloss** — Gloss through your markdown without touching it.

A distraction-free markdown reader as a VS Code extension and standalone macOS app.

## Current Focus: VS Code Extension MVP

See [gloss-project-plan.md](gloss-project-plan.md) for full product specification.

### MVP Features (v0.1.0)

- [ ] Auto-preview on open (configurable patterns)
- [ ] Close source tab automatically
- [ ] Disable double-click-to-edit
- [ ] "Edit This File" command
- [ ] Status bar indicator

### Milestones

**Phase 1: Foundation (Week 1)**
- [ ] Scaffold extension
- [ ] Document open listener
- [ ] Configuration schema
- [ ] Manual preview triggering

**Phase 2: Core Features (Week 2)**
- [ ] Pattern matching (include/exclude)
- [ ] Tab closing logic
- [ ] Edit command
- [ ] Status bar

**Phase 3: Polish (Week 3)**
- [ ] Edge cases (remote, WSL, already open)
- [ ] Integration tests
- [ ] README with screenshots
- [ ] Marketplace assets

**Phase 4: Release (Week 4)**
- [ ] Beta testing
- [ ] Marketplace submission
- [ ] Announce on michaelcraig.group
