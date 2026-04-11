# Fillable Template Demo

A one-page smoke test for Gloss v1.10.0 fillable markdown. This file exercises
**both** fillable surfaces: GFM task checkboxes and `md+` template blocks.

---

## 1. GFM Task Checkboxes

Click any checkbox — it should toggle in place. When you run
**File → Save Filled Copy…**, the `.md` output will have the brackets
rewritten to match whatever you checked.

### Morning routine

- [ ] Coffee
- [ ] Review calendar
- [x] Daily standup
- [ ] Clear inbox to zero
- [ ] Write journal entry

### Nested list (should also work)

- [ ] Ship v1.10.0
  - [x] Implement md+ parser
  - [x] Add TemplateFillService
  - [ ] Push to origin
  - [ ] Post on Show HN

### Mixed with regular list items (should leave regular items alone)

- [ ] This is a real task
- This is a regular bullet (no checkbox)
- [x] Another real task
- Another regular bullet

### Checkboxes inside a code fence (should NOT be interactive)

```
- [ ] this is inside a fence and should render as literal text
- [x] so is this
```

---

## 2. `md+` Template Block — Daily Check-In

This is the first implementation of the [`md+` spec](../gloss/docs/MD_PLUS_SPEC.md).
The block below should render as a **labeled fieldset** with typed inputs.
Fill them in, then save — the values will be captured back into the YAML as
`value:` keys on each field.

<!--md+
type: template
id: daily-checkin
name: Daily Check-In
fields:
  - name: date
    type: date
    label: Date
  - name: mood
    type: select
    label: How are you feeling?
    options: [great, good, meh, rough]
    default: good
  - name: energy
    type: number
    label: Energy level (1-10)
    default: 7
  - name: wins
    type: text
    label: Today's wins
    multiline: true
  - name: shipped
    type: checkbox
    label: Shipped something today
-->

---

## 3. `md+` Template Block — Run-of-Show

A second block in the same document. Both should render independently, and
saving captures values from **both** into the output.

<!--md+
type: template
id: show-runofshow
name: Show Run-of-Show
fields:
  - name: event
    type: text
    label: Event name
    default: "Rumpus Tucson"
  - name: doors
    type: date
    label: Doors open
  - name: headliner
    type: text
    label: Headliner
  - name: capacity
    type: number
    label: Venue capacity
    default: 150
  - name: sold_out
    type: checkbox
    label: Sold out
-->

---

## 4. Plain Markdown (control)

This section has no fillable content. Nothing here should change when you
save. Angle brackets in code spans like `<word>` should render literally
(this was a bundled bug fix).

> Regular blockquote, untouched.

```python
# Regular code block, untouched
def hello():
    print("Hello, Gloss")
```

---

## What to verify after saving

Open the saved `gloss-fillable-demo-filled.md` and confirm:

1. **Task checkboxes** you clicked now show `- [x]` or `- [ ]` reflecting your choices.
2. **Regular bullets** (`- This is a regular bullet`) are untouched.
3. **Code-fence checkboxes** (section 1, inside the fence) are unchanged.
4. **Template blocks** now have `value: <your-input>` keys under each field.
5. **Plain markdown** sections round-trip byte-for-byte.
