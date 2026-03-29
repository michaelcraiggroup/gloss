---
tags: [guide, features, tags, gloss]
title: "What's New: Tags"
---

# Tags in Gloss

Gloss now reads **tags** from your YAML frontmatter and makes them browsable across your entire vault.

## How It Works

Add a `tags` field to your frontmatter:

```yaml
---
tags: [swift, macos, tutorial]
---
```

Gloss indexes all tags when you open a folder. Tags appear in two places:

1. **Sidebar** — browse all tags with file counts, click to filter
2. **Inspector** — see the current document's tags as clickable pills

## Tag Formats

Gloss supports both YAML array and comma-separated formats:

```yaml
# Array format
tags: [design, ux, research]

# Also works
tags:
  - design
  - ux
  - research
```

## Searching by Tag

Use the **Tags** search scope in the sidebar to find tags by name. Type a partial tag name and matching tags appear instantly.

## Try It

This document has four tags: `guide`, `features`, `tags`, and `gloss`. Open the Inspector to see them as interactive pills.
