# md+ Specification

> Extended markdown with executable capabilities — designed for Gloss and beyond.

**Status:** Draft
**Version:** 0.1.0
**Author:** Michael Craig Group
**Date:** 2026-01-30

---

## Overview

md+ is a backward-compatible extension to CommonMark that enables executable capabilities within markdown documents. It's designed to work seamlessly with existing markdown tooling while unlocking interactive features in capable renderers like Gloss.

The core principle: **every md+ document is valid markdown**. Unknown syntax degrades gracefully to hidden comments, ensuring documents remain portable and readable everywhere.

---

## Design Principles

### Lessons from HTML History

| Lesson | HTML History | md+ Application |
|--------|--------------|-----------------|
| **Backward compatibility** | XHTML2 died because it broke existing content; HTML5 won by embracing quirks mode | md+ files are valid CommonMark; unknown syntax renders as-is |
| **Graceful degradation** | Sites work without JavaScript | md+ renders as readable markdown in GitHub, VS Code, any renderer |
| **Forgiving errors** | Browsers auto-close tags, ignore unknown attributes | Invalid md+ blocks show source or nothing, never crash |
| **Separation of concerns** | HTML (structure) / CSS (style) / JS (behavior) | Content / Styling hints / Executable blocks |
| **Docs as data, not code** | Markdoc's declarative approach is safer than MDX's embedded JS | Declarative YAML syntax, not embedded JavaScript |

### Why Not MDX?

MDX embeds JSX/JavaScript directly in markdown:

```mdx
import { Chart } from './Chart'

# Sales Report

<Chart data={salesData} />
```

Problems:
- **Not portable** — Requires JSX runtime, won't render in GitHub/VS Code
- **Security risk** — Arbitrary JavaScript execution
- **Tooling complexity** — Build step required

### Why Not Markdoc?

Markdoc uses custom syntax:

```markdoc
{% callout type="warning" %}
This is important!
{% /callout %}
```

Problems:
- **Not standard markdown** — Breaks in all non-Markdoc renderers
- **Compile step required** — Can't read raw file

### md+ Approach

md+ uses HTML comments (valid in CommonMark) with YAML configuration:

```markdown
<!--md+
type: calculator
formula: principal * (1 + rate/100) ^ years
-->
```

Benefits:
- **Valid markdown** — Comments are hidden in all renderers
- **Human-readable** — YAML is easy to write and understand
- **No build step** — Interpreted at runtime by capable renderers
- **Secure by default** — Declarative, sandboxed execution

---

## Syntax

### Block Structure

md+ blocks are HTML comments starting with `md+`:

```markdown
<!--md+
type: block-type
key: value
nested:
  - item1
  - item2
-->
```

**Rules:**
1. Block must start with `<!--md+` (newline required after)
2. Content is parsed as YAML
3. Block ends with `-->`
4. Whitespace inside is preserved for YAML parsing

### Minimal Example

```markdown
# Compound Interest Calculator

Enter your values to see the result:

<!--md+
type: calculator
formula: principal * (1 + rate/100) ^ years
inputs:
  - name: principal
    label: "Principal ($)"
    default: 1000
  - name: rate
    label: "Interest Rate (%)"
    default: 5
  - name: years
    label: "Years"
    default: 10
-->

The formula uses standard compound interest: P(1 + r)^t
```

**In Gloss:** Interactive calculator with sliders/inputs
**In GitHub:** Hidden comment, visible explanation text
**In VS Code:** Hidden comment, visible explanation text

---

## Block Types

### Phase 1 (MVP)

| Type | Purpose | Security | Parameters |
|------|---------|----------|------------|
| `calculator` | Formula evaluation | Safe | `formula`, `inputs[]`, `output` |
| `chart` | Data visualization | Safe | `chartType`, `data`, `options` |
| `embed` | Include another file | Read-only | `path`, `lines`, `language` |

### Phase 2

| Type | Purpose | Security | Parameters |
|------|---------|----------|------------|
| `shell` | Execute command | **Requires grant** | `command`, `trigger`, `confirm` |
| `fetch` | Load external data | Sandboxed | `url`, `method`, `transform` |

### Phase 3

| Type | Purpose | Security | Parameters |
|------|---------|----------|------------|
| `form` | Interactive input | Safe | `fields[]`, `onSubmit` |
| `state` | Reactive variables | Safe | `variables`, `computed` |
| `conditional` | Show/hide content | Safe | `if`, `then`, `else` |

---

## Block Reference

### calculator

Evaluates mathematical formulas with user inputs.

```yaml
type: calculator
formula: "principal * (1 + rate/100) ^ years"  # Math expression
precision: 2                                    # Decimal places (default: 2)
inputs:
  - name: principal                             # Variable name in formula
    label: "Principal ($)"                      # Display label
    type: number                                # number | range
    default: 1000                               # Initial value
    min: 0                                      # Optional: minimum
    max: 1000000                                # Optional: maximum
    step: 100                                   # Optional: increment
output:
  label: "Future Value"                         # Result label
  format: "$%,.2f"                              # Printf-style format
```

**Supported operations:** `+`, `-`, `*`, `/`, `^` (power), `%` (modulo), `sqrt()`, `log()`, `sin()`, `cos()`, `tan()`, `abs()`, `floor()`, `ceil()`, `round()`

### chart

Renders data visualizations.

```yaml
type: chart
chartType: line                    # line | bar | pie | scatter
title: "Monthly Revenue"
data:
  labels: ["Jan", "Feb", "Mar", "Apr"]
  datasets:
    - label: "2025"
      values: [100, 120, 140, 180]
    - label: "2026"
      values: [150, 160, 200, 250]
options:
  xAxis: "Month"
  yAxis: "Revenue ($K)"
  legend: true
```

### embed

Includes content from another file (read-only).

```yaml
type: embed
path: "./src/config.ts"           # Relative or absolute path
lines: "10-25"                    # Optional: line range
language: "typescript"            # Optional: syntax highlight
title: "Configuration"            # Optional: display title
collapsible: true                 # Optional: collapsed by default
```

**Security:** Only reads files; cannot write or execute. Paths are sandboxed to document directory by default.

### shell (Phase 2)

Executes shell commands with user confirmation.

```yaml
type: shell
command: "scripts/regenerate-dashboard.sh"
trigger: button                   # button | auto | schedule
label: "Regenerate Dashboard"     # Button text
confirm: true                     # Require confirmation dialog
workdir: "."                      # Working directory (default: doc location)
timeout: 30                       # Max seconds (default: 30)
output: stream                    # stream | capture | none
```

**Security:** Requires explicit user grant. Shows confirmation dialog by default. Commands are logged.

### fetch (Phase 2)

Loads data from URLs.

```yaml
type: fetch
url: "https://api.github.com/repos/user/repo/issues"
method: GET
headers:
  Accept: "application/json"
cache: 300                        # Cache seconds (default: 0)
transform: "data.map(i => i.title)"  # Optional: jq-like transform
fallback: "Unable to load issues"
```

**Security:** Sandboxed to allowlisted domains. No cookies/credentials sent by default.

---

## Security Model

### Trust Levels

| Level | Description | Example |
|-------|-------------|---------|
| **Safe** | No external effects | calculator, chart |
| **Read-only** | Can read local files | embed |
| **Network** | Can fetch URLs | fetch |
| **Execute** | Can run commands | shell |

### Configuration

Trust is configured per-directory via `.md+config.yaml`:

```yaml
# .md+config.yaml
version: 1

trust:
  # Shell execution policy
  shell: prompt              # prompt | allow | deny

  # Network access policy
  fetch:
    policy: allowlist        # allowlist | denylist | deny
    allow:
      - "api.github.com"
      - "localhost:*"
    deny: []

  # File embedding policy
  embed:
    policy: allowlist
    allow:
      - "./**/*.md"          # Only markdown in current tree
      - "./**/*.ts"          # TypeScript files
    deny:
      - "**/.env"            # Never embed secrets
      - "**/credentials*"

# Inherit from parent directories
inherit: true
```

### Default Policies

Without `.md+config.yaml`:

- `calculator`, `chart`: Always allowed
- `embed`: Allowed for same-directory files only
- `fetch`: Denied (requires explicit allowlist)
- `shell`: Prompt (shows confirmation dialog)

### Execution Flow

```
┌─────────────────────────────────────────────────────────────┐
│                      md+ Block Parsed                        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  1. Validate YAML schema against block type                  │
│     - Invalid? Show warning, render nothing                  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  2. Check trust level required                               │
│     - Safe? Execute immediately                              │
│     - Higher? Check .md+config.yaml                          │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  3. Apply trust policy                                       │
│     - Allowed? Execute                                       │
│     - Prompt? Show confirmation dialog                       │
│     - Denied? Show "blocked" indicator                       │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  4. Execute in sandbox                                       │
│     - Timeout enforcement                                    │
│     - Resource limits                                        │
│     - Output capture                                         │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  5. Render result                                            │
│     - Success? Show output UI                                │
│     - Error? Show error state (never crash)                  │
└─────────────────────────────────────────────────────────────┘
```

---

## Error Handling

### Philosophy: Forgiving, Not Draconian

HTML succeeded because browsers were forgiving. XHTML2 failed because a single error broke the entire page. md+ follows HTML's lead:

**Errors never break the document.**

### Error States

| Error | Behavior in Gloss | Behavior Elsewhere |
|-------|-------------------|--------------------|
| Invalid YAML | Yellow warning box | Hidden comment |
| Unknown block type | Gray "unsupported" box | Hidden comment |
| Schema violation | Warning with details | Hidden comment |
| Execution failure | Red error box with message | Hidden comment |
| Timeout | "Timed out" indicator | Hidden comment |
| Permission denied | "Blocked by policy" indicator | Hidden comment |

### Example: Parse Error

```markdown
<!--md+
type: calculator
formula: invalid ( syntax here
-->
```

**In Gloss:**
```
┌─────────────────────────────────────┐
│ ⚠️ md+ Parse Error                  │
│ Invalid formula syntax at char 8    │
│                                     │
│ formula: invalid ( syntax here      │
│                  ^ unexpected '('    │
└─────────────────────────────────────┘
```

**In GitHub/VS Code:** Nothing shown (it's a comment)

---

## Gloss Implementation

### Parser

```typescript
// gloss/src/md-plus/parser.ts

interface MdPlusBlock {
  type: string;
  config: Record<string, unknown>;
  raw: string;  // Original YAML for error reporting
  position: {
    start: number;
    end: number;
  };
}

interface ParseResult {
  blocks: MdPlusBlock[];
  errors: ParseError[];
}

const MD_PLUS_PATTERN = /<!--md\+\n([\s\S]*?)-->/g;

export function parseMdPlus(markdown: string): ParseResult {
  const blocks: MdPlusBlock[] = [];
  const errors: ParseError[] = [];

  let match;
  while ((match = MD_PLUS_PATTERN.exec(markdown)) !== null) {
    try {
      const yaml = match[1];
      const config = parseYaml(yaml);

      if (!config.type) {
        errors.push({
          message: 'Block missing required "type" field',
          position: match.index
        });
        continue;
      }

      blocks.push({
        type: config.type,
        config,
        raw: yaml,
        position: {
          start: match.index,
          end: match.index + match[0].length
        }
      });
    } catch (e) {
      errors.push({
        message: `YAML parse error: ${e.message}`,
        position: match.index
      });
    }
  }

  return { blocks, errors };
}
```

### Renderer Registry

```typescript
// gloss/src/md-plus/renderers/index.ts

interface BlockRenderer {
  type: string;
  trustLevel: 'safe' | 'read' | 'network' | 'execute';
  validate(config: unknown): ValidationResult;
  render(config: unknown, context: RenderContext): HTMLElement;
}

const renderers = new Map<string, BlockRenderer>();

export function registerRenderer(renderer: BlockRenderer) {
  renderers.set(renderer.type, renderer);
}

export function getRenderer(type: string): BlockRenderer | undefined {
  return renderers.get(type);
}

// Register built-in renderers
import { calculatorRenderer } from './calculator';
import { chartRenderer } from './chart';
import { embedRenderer } from './embed';

registerRenderer(calculatorRenderer);
registerRenderer(chartRenderer);
registerRenderer(embedRenderer);
```

### Calculator Renderer

```typescript
// gloss/src/md-plus/renderers/calculator.ts

import { evaluate } from 'mathjs';  // or custom safe evaluator

interface CalculatorConfig {
  formula: string;
  precision?: number;
  inputs: Array<{
    name: string;
    label: string;
    type?: 'number' | 'range';
    default: number;
    min?: number;
    max?: number;
    step?: number;
  }>;
  output?: {
    label?: string;
    format?: string;
  };
}

export const calculatorRenderer: BlockRenderer = {
  type: 'calculator',
  trustLevel: 'safe',

  validate(config: unknown): ValidationResult {
    // Validate against schema
    // Check formula doesn't contain dangerous operations
  },

  render(config: CalculatorConfig, context: RenderContext): HTMLElement {
    const container = document.createElement('div');
    container.className = 'md-plus-calculator';

    // Create inputs
    const values: Record<string, number> = {};
    for (const input of config.inputs) {
      values[input.name] = input.default;
      // Create input UI, attach change handlers
    }

    // Calculate and display result
    function updateResult() {
      try {
        const result = evaluate(config.formula, values);
        // Update display
      } catch (e) {
        // Show error state
      }
    }

    return container;
  }
};
```

---

## Integration with blot-up

md+ can extend screenplay authoring with executable metadata:

```markdown
<!--md+
type: breakdown
auto: true
categories:
  - cast
  - props
  - locations
  - vehicles
-->

INT. COFFEE SHOP - DAY

SARAH enters, carrying a LAPTOP BAG. She orders from MIKE, the barista.

                    SARAH
          Grande oat milk latte, please.

MIKE starts making the drink. Sarah checks her PHONE.

<!--md+
type: schedule
scene: 12
location: "Coffee Shop (123 Main St)"
cast: ["Sarah", "Mike"]
props: ["Laptop bag", "Phone", "Coffee cup"]
estimatedTime: 2
-->
```

**In blot-up:**
- Auto-extracts breakdown elements (cast: SARAH, MIKE | props: LAPTOP BAG, PHONE)
- Links to scheduling data
- Generates call sheets

**In standard markdown viewer:**
- Comments hidden
- Screenplay text renders normally

---

## File Extension

md+ files use the standard `.md` extension. The format is identified by the presence of `<!--md+` blocks, not a special extension.

**Rationale:**
- Maximum compatibility with existing tools
- No need to register new file types
- GitHub/GitLab render md+ files correctly
- IDE syntax highlighting works out of the box

---

## Future Considerations

### Potential Block Types

| Type | Purpose | Notes |
|------|---------|-------|
| `diagram` | Mermaid/PlantUML rendering | Already common in markdown tools |
| `quiz` | Interactive questions | Educational content |
| `tabs` | Tabbed content sections | Documentation patterns |
| `accordion` | Collapsible sections | Long-form content |
| `slideshow` | Presentation mode | Could integrate with rabble |
| `video` | Embedded video player | Local files or URLs |
| `audio` | Audio player | Podcasts, voice notes |

### Potential Integrations

- **Gloss macOS app:** Native md+ rendering
- **blot-up:** Screenplay metadata extraction
- **rabble:** Interactive workshop slides
- **Portfolio dashboard:** Live regeneration buttons

### Standardization Path

1. **Phase 1:** Internal use in MCG projects
2. **Phase 2:** Publish spec, gather feedback
3. **Phase 3:** Reference implementation as npm package
4. **Phase 4:** If adoption grows, propose to CommonMark as extension

---

## Changelog

### 0.1.0 (2026-01-30)

- Initial draft specification
- Core block types: calculator, chart, embed
- Security model with trust levels
- Error handling philosophy
- Gloss implementation outline

---

## References

- [CommonMark Spec](https://spec.commonmark.org/)
- [MDX](https://mdxjs.com/)
- [Markdoc](https://markdoc.dev/)
- [HTML Design Principles](https://www.w3.org/TR/html-design-principles/)
- [XHTML2 Post-Mortem](https://www.w3.org/MarkUp/xhtml2-postmortem/)

---

*A [Michael Craig Group](https://michaelcraig.group) specification — extending markdown without breaking it.*
