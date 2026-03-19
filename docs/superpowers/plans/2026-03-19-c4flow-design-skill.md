# c4flow:design Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the `/c4flow:design` skill — a workflow phase between SPEC and BEADS that generates a design system and screen mockups via Pencil MCP, embedding Impeccable design principles.

**Architecture:** Main skill file (`skills/design/SKILL.md`) orchestrates the 3-phase flow: (1) interactive main agent for screen analysis, design tokens, reusable components, and hero screen; (2) sequential sub-agents for remaining screens; (3) gate verification. Six reference files embed Impeccable methodology. Orchestrator and BEADS skill updated to wire the new state into the workflow.

**Tech Stack:** Markdown skill files, Pencil MCP tools (batch_design, batch_get, set_variables, get_screenshot, etc.), Impeccable design principles (Apache 2.0), c4flow `.state.json` state machine.

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `skills/design/references/design-principles.md` | Impeccable design direction, context protocol, AI slop test, all DO/DON'T rules |
| Create | `skills/design/references/color-and-contrast.md` | OKLCH colors, tinted neutrals, 60-30-10, WCAG, dark mode |
| Create | `skills/design/references/typography.md` | Modular scale, font pairing, alternatives to defaults, vertical rhythm |
| Create | `skills/design/references/spatial-design.md` | 4pt spacing, grid systems, squint test, card usage rules |
| Create | `skills/design/references/component-patterns.md` | Eight interaction states, focus rings, form design, loading/empty/error states, motion rules |
| Create | `skills/design/references/quality-checklist.md` | AI slop detection, visual hierarchy, accessibility audit, polish checklist |
| Modify | `skills/c4flow/references/phase-transitions.md` | Replace weak DESIGN gate with 7-point gate condition |
| Modify | `skills/c4flow/SKILL.md` | Wire DESIGN state: table, transitions, dispatch block, catch-all fix |
| Modify | `skills/beads/SKILL.md` | Add MASTER.md and screen-map.md to Input section |
| Create | `skills/design/SKILL.md` | Main skill: full 3-phase execution flow with Pencil MCP tool calls |

---

## Task 1: Create `design-principles.md` reference

**Files:**
- Create: `skills/design/references/design-principles.md`

- [ ] **Step 1: Create the file**

```markdown
---
source: Adapted from Impeccable (github.com/pbakaus/impeccable) — Apache 2.0 License
---

# Design Principles

## Context Gathering Protocol

Design skills produce generic output without project context. Before any design work, confirm:

- **Target audience**: Who uses this product and in what context?
- **Use cases**: What jobs are they trying to get done?
- **Brand personality/tone**: How should the interface feel?

**You cannot infer this from the codebase.** Code tells you what was built, not who it's for.

Context sources (in order):
1. Current session context (spec.md, design.md, proposal.md)
2. User Q&A during Step 1.1 screen analysis
3. If still unclear, ask the user directly before proceeding

## Design Direction

Commit to a BOLD aesthetic direction. Pick an extreme and execute it with precision:
- Brutally minimal, maximalist chaos, retro-futuristic, organic/natural, luxury/refined
- Playful/toy-like, editorial/magazine, brutalist/raw, art deco/geometric, soft/pastel
- Industrial/utilitarian, geometric precision, warm humanist, cold corporate, etc.

Bold maximalism and refined minimalism both work — the key is **intentionality**, not intensity.

**Ask yourself**: What makes this UNFORGETTABLE? What's the one thing someone will remember?

## The AI Slop Test

**Critical quality check before presenting any work to the user.**

If you showed this interface to someone and said "AI made this," would they believe you immediately? If yes, that's the problem.

A distinctive interface should make someone ask "how was this made?" not "which AI made this?"

## Typography DO/DON'T

**DO**: Use a modular type scale with 5 levels max (caption, secondary, body, subheading, heading)
**DO**: Pair fonts with genuine contrast (serif + sans, geometric + humanist)
**DO**: Vary font weights and sizes to create clear visual hierarchy
**DON'T**: Use overused fonts — Inter, Roboto, Arial, Open Sans, Lato, Montserrat
**DON'T**: Use monospace typography as lazy shorthand for "technical" vibes
**DON'T**: Put large icons with rounded corners above every heading

Better alternatives:
- Instead of Inter → Instrument Sans, Plus Jakarta Sans, Outfit
- Instead of Roboto → Onest, Figtree, Urbanist
- Instead of Open Sans → Source Sans 3, Nunito Sans, DM Sans
- For editorial/premium → Fraunces, Newsreader, Lora

## Color DO/DON'T

**DO**: Use OKLCH for all colors — perceptually uniform
**DO**: Tint neutrals toward brand hue (chroma 0.01 is enough)
**DO**: Use 60-30-10 rule for visual weight
**DON'T**: Use pure black (#000) or pure white (#fff) — always tint
**DON'T**: Use pure gray neutrals — add subtle color tint
**DON'T**: Put gray text on colored backgrounds — use a shade of the background color
**DON'T**: Use the AI color palette: cyan-on-dark, purple-to-blue gradients, neon accents on dark
**DON'T**: Use gradient text for "impact" — especially on metrics or headings
**DON'T**: Default to dark mode with glowing accents

## Layout DO/DON'T

**DO**: Create visual rhythm through varied spacing — tight groupings, generous separations
**DO**: Use asymmetry and unexpected compositions — break the grid intentionally for emphasis
**DON'T**: Wrap everything in cards — not everything needs a container
**DON'T**: Nest cards inside cards — flatten the hierarchy
**DON'T**: Use identical card grids — same-sized cards with icon + heading + text, repeated endlessly
**DON'T**: Use the hero metric layout — big number, small label, supporting stats, gradient accent
**DON'T**: Center everything — left-aligned text with asymmetric layouts feels more designed

## Visual Details DO/DON'T

**DON'T**: Use glassmorphism everywhere — blur effects used decoratively rather than purposefully
**DON'T**: Use rounded elements with thick colored border on one side — lazy accent
**DON'T**: Use sparklines as decoration — tiny charts that convey nothing meaningful
**DON'T**: Use rounded rectangles with generic drop shadows — safe, forgettable
**DON'T**: Use modals unless there is truly no better alternative

## Motion DO/DON'T

**DO**: Use exponential easing (ease-out-quart/quint/expo) for natural deceleration
**DO**: Use motion to convey state changes — entrances, exits, feedback
**DON'T**: Animate layout properties (width, height, padding, margin) — use transform and opacity only
**DON'T**: Use bounce or elastic easing — they feel dated and tacky
```

- [ ] **Step 2: Verify file was created correctly**

Run: `head -5 skills/design/references/design-principles.md`
Expected: frontmatter + "# Design Principles"

- [ ] **Step 3: Commit**

```bash
git add skills/design/references/design-principles.md
git commit -m "feat(design): add design-principles reference from Impeccable"
```

---

## Task 2: Create `color-and-contrast.md` reference

**Files:**
- Create: `skills/design/references/color-and-contrast.md`

- [ ] **Step 1: Create the file**

```markdown
---
source: Adapted from Impeccable (github.com/pbakaus/impeccable) — Apache 2.0 License
---

# Color & Contrast

## Use OKLCH, Not HSL

OKLCH is perceptually uniform — equal steps in lightness look equal. HSL is not.

```css
/* OKLCH: lightness (0-100%), chroma (0-0.4+), hue (0-360) */
--primary:       oklch(60% 0.15 250);   /* Blue */
--primary-light: oklch(85% 0.08 250);   /* Same hue, lighter — reduce chroma! */
--primary-dark:  oklch(35% 0.12 250);   /* Same hue, darker */
```

**Key rule**: As you move toward white or black, reduce chroma. High chroma at extreme lightness looks garish (e.g., oklch(90% 0.15 250) is an ugly washed-out blue — use oklch(90% 0.06 250) instead).

## Tinted Neutrals — Never Pure Gray

```css
/* Dead — no personality */
--gray-100: oklch(95% 0 0);

/* Warm-tinted (subtle warmth toward brand) */
--gray-100: oklch(95% 0.01 60);   /* Chroma 0.01 is enough */
--gray-900: oklch(15% 0.01 60);

/* Cool-tinted (tech, professional) */
--gray-100: oklch(95% 0.01 250);
--gray-900: oklch(15% 0.01 250);
```

Never use pure black (`#000`) or pure white (`#fff`) for large areas. Even chroma 0.005 feels natural.

## Required Color Tokens

| Role | Pencil Variable Name | Purpose |
|------|---------------------|---------|
| Primary | `--primary` | CTAs, links, key actions |
| Background | `--bg` | Page background |
| Foreground | `--fg` | Body text |
| Muted | `--muted` | Secondary text |
| Border | `--border` | Borders, dividers |
| Card | `--card` | Card/surface backgrounds |
| Destructive | `--destructive` | Errors, delete actions |
| Success | `--success` | Confirmations |
| Warning | `--warning` | Warnings |

## 60-30-10 Rule (Visual Weight)

- **60%** Neutral backgrounds, white space, base surfaces
- **30%** Secondary — text, borders, inactive states
- **10%** Accent — CTAs, highlights, focus states

Overusing accent color kills its power. Rare = powerful.

## WCAG Contrast Requirements

| Content | AA Minimum | AAA Target |
|---------|------------|------------|
| Body text | 4.5:1 | 7:1 |
| Large text (18px+ or 14px bold) | 3:1 | 4.5:1 |
| UI components, icons | 3:1 | 4.5:1 |
| Placeholders | 4.5:1 | — |

**Gray text on colored backgrounds always fails** — use a darker shade of the background color or transparency instead.

## Dark Mode

Dark mode requires different decisions, not just inverted colors:

| Light Mode | Dark Mode |
|------------|-----------|
| Shadows for depth | Lighter surfaces for depth |
| Dark text on light | Light text on dark (reduce font weight slightly) |
| Vibrant accents | Desaturate accents slightly |
| White backgrounds | Never pure black — use oklch(12-18% 0.01 250) |

Use semantic tokens (redefine `--bg`, `--fg`, `--card` per theme) not primitive tokens.
```

- [ ] **Step 2: Verify**

Run: `grep -c "oklch" skills/design/references/color-and-contrast.md`
Expected: output >= 5 (confirms OKLCH examples are present)

- [ ] **Step 3: Commit**

```bash
git add skills/design/references/color-and-contrast.md
git commit -m "feat(design): add color-and-contrast reference from Impeccable"
```

---

## Task 3: Create `typography.md` reference

**Files:**
- Create: `skills/design/references/typography.md`

- [ ] **Step 1: Create the file**

```markdown
---
source: Adapted from Impeccable (github.com/pbakaus/impeccable) — Apache 2.0 License
---

# Typography

## Type Scale — 5 Sizes Max

Use fewer sizes with more contrast. Too many sizes close together = muddy hierarchy.

| Role | Size | Line-height | Letter-spacing |
|------|------|-------------|----------------|
| `--text-h1` | 36px | 1.2 | -0.02em |
| `--text-h2` | 28px | 1.25 | -0.01em |
| `--text-h3` | 22px | 1.3 | 0 |
| `--text-body` | 16px | 1.5 | 0 |
| `--text-small` | 14px | 1.4 | 0 |
| `--text-caption` | 12px | 1.4 | 0.01em |

Use a consistent ratio between levels: 1.25 (major third) or 1.333 (perfect fourth).

## Avoid Invisible Default Fonts

These are everywhere — they make design feel generic:
- Inter, Roboto, Arial, Open Sans, Lato, Montserrat, system-ui without customization

Better alternatives:
- **Body (humanist sans)**: Instrument Sans, Plus Jakarta Sans, Outfit, Figtree, Onest, DM Sans
- **Editorial/premium**: Fraunces (serif), Newsreader (serif), Lora (serif)
- **Geometric sans**: Urbanist, Raleway

## Font Pairing

One well-chosen font family in multiple weights often beats two competing typefaces.

When pairing, contrast on multiple axes:
- Serif + Sans (structure contrast)
- Geometric + Humanist (personality contrast)
- Condensed display + Wide body (proportion contrast)

**Never pair fonts that are similar but not identical** (e.g., two geometric sans-serifs). They create visual tension without clear hierarchy.

## Hierarchy Through Multiple Dimensions

Don't rely on size alone. Combine:
- Size + weight (bold heading, regular body)
- Color (muted secondary text)
- Spacing (more space above heading than below)

## Vertical Rhythm

Line-height × base size = base unit for ALL vertical spacing.
- 16px × 1.5 = 24px base unit
- Spacing values should be multiples: 24px, 48px, 72px

## Readability Rules

- Body text minimum: 16px (never below)
- Optimal line length: 45-75 characters (`max-width: 65ch`)
- Line-height for light on dark: add 0.05-0.1 (text feels lighter, needs more room)
- Use `rem` not `px` for font sizes (respects browser zoom)
- Tabular numbers for data: `font-variant-numeric: tabular-nums`

## Pencil Typography Tokens

In `set_variables()`:
```json
{
  "font-heading": "'Instrument Sans', sans-serif",
  "font-body": "'Plus Jakarta Sans', sans-serif",
  "text-h1-size": 36,
  "text-h2-size": 28,
  "text-h3-size": 22,
  "text-body-size": 16,
  "text-small-size": 14,
  "text-caption-size": 12
}
```
```

- [ ] **Step 2: Verify**

Run: `grep "Instrument Sans" skills/design/references/typography.md`
Expected: line found (confirms alternatives are present)

- [ ] **Step 3: Commit**

```bash
git add skills/design/references/typography.md
git commit -m "feat(design): add typography reference from Impeccable"
```

---

## Task 4: Create `spatial-design.md` reference

**Files:**
- Create: `skills/design/references/spatial-design.md`

- [ ] **Step 1: Create the file**

```markdown
---
source: Adapted from Impeccable (github.com/pbakaus/impeccable) — Apache 2.0 License
---

# Spatial Design

## 4pt Spacing Scale (Not 8pt — Too Coarse)

4pt gives granularity for tight UI without arbitrary values:

```
4 · 8 · 12 · 16 · 24 · 32 · 48 · 64 · 96
```

Pencil variable names: `space-xs` (4), `space-sm` (8), `space-md` (16), `space-lg` (32), `space-xl` (64)

Use `gap` not margins for sibling spacing — eliminates margin collapse hacks.

## Visual Rhythm

Create rhythm through varied spacing — not the same padding everywhere:

- **Tight grouping** (8-12px): Related elements within a component
- **Medium separation** (16-24px): Between items in a list
- **Generous separation** (48-96px): Between distinct page sections

Without rhythm, layouts feel monotonous. Same spacing everywhere = no hierarchy.

## The Squint Test

Blur your eyes (or screenshot and blur). Can you still identify:
1. The most important element?
2. The second most important?
3. Clear content groupings?

If everything looks equal weight when blurred, you have a hierarchy problem.

**Run this test after every screen composition.**

## Card Usage Rules

Cards are overused. Spacing and alignment create visual grouping naturally.

Use cards ONLY when:
- Content is truly distinct and actionable
- Items need visual comparison in a grid
- Content needs clear interaction boundaries

**Never nest cards inside cards** — use spacing, typography, and subtle dividers for hierarchy within a card.

## Screen Dimension Defaults

| Platform | Default Size |
|----------|-------------|
| Web app (desktop) | 1440 × 900 |
| Web app (tablet) | 768 × 1024 |
| Web app (mobile) | 375 × 812 |
| Mobile app (iPhone) | 375 × 812 |
| Mobile app (iPhone Pro) | 390 × 844 |
| Landing page | 1440 × 900+ (scrollable) |
| Landscape | Rotate dimensions (e.g. 812 × 375) |

If `tech-stack.md` specifies a target platform, use that. Otherwise default to 1440 × 900 for web.

## Hierarchy Through Multiple Dimensions

| Dimension | Strong | Weak |
|-----------|--------|------|
| Size | 3:1 ratio+ | <2:1 ratio |
| Weight | Bold vs Regular | Medium vs Regular |
| Color | High contrast | Similar tones |
| Position | Top/left (primary) | Buried |
| Space | Surrounded by whitespace | Crowded |

Best hierarchy uses 2-3 dimensions at once.
```

- [ ] **Step 2: Verify**

Run: `grep "Squint Test" skills/design/references/spatial-design.md`
Expected: line found

- [ ] **Step 3: Commit**

```bash
git add skills/design/references/spatial-design.md
git commit -m "feat(design): add spatial-design reference from Impeccable"
```

---

## Task 5: Create `component-patterns.md` reference

**Files:**
- Create: `skills/design/references/component-patterns.md`

- [ ] **Step 1: Create the file**

```markdown
---
source: Adapted from Impeccable (github.com/pbakaus/impeccable) — Apache 2.0 License
---

# Component Patterns

## The Eight Interaction States

Every interactive component needs all states designed. Missing states create broken experiences.

| State | When | Visual Treatment |
|-------|------|-----------------|
| Default | At rest | Base styling |
| Hover | Pointer over | Subtle lift, color shift |
| Focus | Keyboard/programmatic | Visible ring (2-3px, offset) |
| Active | Being pressed | Pressed in, darker fill |
| Disabled | Not interactive | Reduced opacity, no pointer |
| Loading | Processing async action | Spinner or skeleton |
| Error | Invalid/failed state | Destructive color, message |
| Success | Completed | Success color, confirmation |

**The common miss**: Designing hover without focus. Keyboard users never see hover states — they are different and both required.

## Focus Rings

Never remove focus indicators without replacement. Use `:focus-visible` to show only for keyboard:

Focus ring design rules:
- 2-3px thick, offset from element (not inside)
- High contrast: 3:1 minimum against adjacent colors
- Use `--primary` or `--accent` color
- Consistent across ALL interactive elements

## Form Design

- Labels are always visible — placeholders are NOT labels (they disappear on input)
- Validate on blur, not on keystroke (exception: password strength)
- Error messages below fields with clear description
- Required indicators consistent and clear

## Loading States

- Skeleton screens > spinners — they preview content shape and feel faster
- Optimistic updates for low-stakes actions (likes, toggles) — update immediately, rollback on failure
- Never use optimistic updates for payments, destructive actions, or irreversible operations

## Destructive Actions

Undo toast > confirmation dialog. Users click through confirmations mindlessly.

Pattern: Remove from UI → show undo toast (5 seconds) → actually delete on expiry.

Use confirmation dialog ONLY for: truly irreversible actions, high-cost actions, batch operations.

## Motion Rules for Components

Duration guidelines:
- 100-150ms: Instant feedback (button press, toggle, color change)
- 200-300ms: State changes (menu open, tooltip, hover state)
- 300-500ms: Layout changes (accordion, drawer)

Easing:
- ease-out (cubic-bezier(0.16, 1, 0.3, 1)): Elements entering
- ease-in: Elements leaving
- ease-in-out: State toggles

**Never**: bounce, elastic, or spring easing. They feel dated. Real objects decelerate smoothly.
**Only animate**: transform and opacity. Never width/height/padding/margin.
For height: animate `grid-template-rows: 0fr → 1fr` instead.

Always respect `prefers-reduced-motion`.

## Empty States

Empty states should TEACH the interface, not just say "nothing here."

Good empty state:
- Explains what this area is for
- Shows the action to get started
- Has a CTA button or link

Bad empty state: Just "No items found."

## Progressive Disclosure

Start simple, reveal sophistication through interaction:
- Basic options first, advanced behind expandable sections
- Hover states that reveal secondary actions
- Not every button should be primary — use ghost, text links, secondary styles
- Hierarchy matters: one primary action per screen area
```

- [ ] **Step 2: Verify**

Run: `grep "Eight Interaction States" skills/design/references/component-patterns.md`
Expected: line found

- [ ] **Step 3: Commit**

```bash
git add skills/design/references/component-patterns.md
git commit -m "feat(design): add component-patterns reference from Impeccable"
```

---

## Task 6: Create `quality-checklist.md` reference

**Files:**
- Create: `skills/design/references/quality-checklist.md`

- [ ] **Step 1: Create the file**

```markdown
---
source: Adapted from Impeccable (github.com/pbakaus/impeccable) — Apache 2.0 License
---

# Quality Checklist

Run this after EVERY `get_screenshot` call. Fix issues before presenting to user.

## Step 1: AI Slop Detection (CRITICAL — run first)

**This is the most important check.** Does this look like every other AI-generated interface?

Check against these fingerprints of AI-generated work:
- [ ] No cyan-on-dark or purple-to-blue gradients
- [ ] No gradient text on headings or metrics
- [ ] No glassmorphism used decoratively
- [ ] No sparklines as decoration
- [ ] No identical card grids (icon + heading + text, repeated)
- [ ] No hero metric layout (big number, small label, stats, gradient)
- [ ] No rounded rectangles with generic drop shadows
- [ ] No dark mode with glowing neon accents
- [ ] No pure gray neutrals (must be tinted)
- [ ] No pure black (#000) backgrounds

**If any boxes are unchecked → fix before proceeding.**

## Step 2: Visual Hierarchy (Squint Test)

Blur your eyes. Ask:
- [ ] Can you identify the primary element in 2 seconds?
- [ ] Is there a clear second-level element?
- [ ] Are content groupings visible as regions?

## Step 3: Color Contrast

- [ ] Body text contrast ≥ 4.5:1
- [ ] Large text (18px+) contrast ≥ 3:1
- [ ] UI components (buttons, inputs) contrast ≥ 3:1
- [ ] Focus indicators contrast ≥ 3:1 against adjacent colors
- [ ] No gray text on colored backgrounds

## Step 4: Typography

- [ ] No invisible defaults (Inter, Roboto, Arial, Open Sans) unless intentional
- [ ] Clear hierarchy — heading vs body identifiable at a glance
- [ ] Body text ≥ 16px
- [ ] Consistent weights (same role = same weight throughout)

## Step 5: Spacing & Layout

- [ ] Spacing uses the 4pt scale (values from the spacing tokens)
- [ ] Related elements grouped tightly (8-12px), sections separated generously (48-96px)
- [ ] No card nesting (max 1 level)
- [ ] Layout passes squint test for hierarchy

## Step 6: Consistency

- [ ] All colors use design tokens (no hard-coded hex values)
- [ ] Same elements styled the same way throughout
- [ ] Interactive elements have clear affordance
- [ ] Components match the approved design system

## Step 7: Structural Check (via `snapshot_layout`)

After visual check, always call `snapshot_layout({problemsOnly: true})`:
- [ ] No overlapping elements
- [ ] No clipped content
- [ ] No misaligned items

## Pass / Fail Verdict

If ALL boxes are checked → PASS, present to user.
If ANY box is unchecked → FIX first, then re-screenshot, then re-check.

Do NOT present a design to the user that fails the AI Slop Detection check.
```

- [ ] **Step 2: Verify**

Run: `grep -c "\- \[ \]" skills/design/references/quality-checklist.md`
Expected: output >= 20 (confirms all checklist items are present)

- [ ] **Step 3: Commit**

```bash
git add skills/design/references/quality-checklist.md
git commit -m "feat(design): add quality-checklist reference from Impeccable"
```

---

## Task 7: Update `phase-transitions.md`

**Files:**
- Modify: `skills/c4flow/references/phase-transitions.md` (line 12 — DESIGN gate)

Current line 12:
```
| DESIGN → BEADS | Design system + mockups approved | User confirmation |
```

- [ ] **Step 1: Replace the DESIGN gate row**

Replace:
```
| DESIGN → BEADS | Design system + mockups approved | User confirmation |
```

With:
```
| DESIGN → BEADS | (1) `MASTER.md` exists, (2) `screen-map.md` exists, (3) `.pen` file has Design System frame with reusable components, (4) `.pen` file has ≥1 screen frame, (5) all screens in `screen-map.md` have frames in `.pen`, (6) AI Slop Test + squint test passed on hero screen, (7) user approved final review | Check files exist + user approval |
```

- [ ] **Step 2: Verify the change**

Run: `grep "DESIGN → BEADS" skills/c4flow/references/phase-transitions.md`
Expected: line contains "MASTER.md exists" and "screen-map.md exists"

- [ ] **Step 3: Commit**

```bash
git add skills/c4flow/references/phase-transitions.md
git commit -m "feat(design): update DESIGN→BEADS gate with 7-point condition"
```

---

## Task 8: Update `skills/c4flow/SKILL.md`

**Files:**
- Modify: `skills/c4flow/SKILL.md`

Four targeted changes:

- [ ] **Step 1: Update state table — change DESIGN status**

Find:
```
| `DESIGN` | 2: Design | ⏳ Not implemented |
```
Replace with:
```
| `DESIGN` | 2: Design | ✅ Implemented |
```

- [ ] **Step 2: Wire DESIGN into SPEC transition**

The RESEARCH and SPEC states share a generic handler. Split them so SPEC has an explicit next-state.

Find (exact text, lines 88–96):
```
### If state is RESEARCH or SPEC (implemented skills)
- Check for partial output from a previous interrupted session:
  - RESEARCH: check if `docs/specs/{feature.slug}/research.md` exists
  - SPEC: check which of `proposal.md`, `tech-stack.md`, `spec.md`, `design.md` exist in `docs/specs/{feature.slug}/`
- If partial output found: present it to user, ask "Reuse existing {files} or regenerate?"
- Run the skill for the current state (see Skill Dispatch below)
- After skill completes, check the exit gate condition (see `references/phase-transitions.md` in this skill's directory)
- If gate passes: add current state to `completedStates`, advance `currentState`, write `.state.json`
- If gate fails: tell user what's missing, ask what to do
```

Replace with:
```
### If state is RESEARCH (implemented)
- Check for partial output from a previous interrupted session:
  - Check if `docs/specs/{feature.slug}/research.md` exists
- If partial output found: present it to user, ask "Reuse existing research.md or regenerate?"
- Run the research skill (see Skill Dispatch below)
- After skill completes, check the exit gate condition (see `references/phase-transitions.md` in this skill's directory)
- If gate passes: add RESEARCH to `completedStates`, advance `currentState` to SPEC, write `.state.json`
- If gate fails: tell user what's missing, ask what to do

### If state is SPEC (implemented)
- Check for partial output from a previous interrupted session:
  - Check which of `proposal.md`, `tech-stack.md`, `spec.md`, `design.md` exist in `docs/specs/{feature.slug}/`
- If partial output found: present it to user, ask "Reuse existing {files} or regenerate?"
- Run the spec skill (see Skill Dispatch below)
- After skill completes, check the exit gate condition (see `references/phase-transitions.md` in this skill's directory)
- If gate passes: add SPEC to `completedStates`, advance `currentState` to **DESIGN**, write `.state.json`
- If gate fails: tell user what's missing, ask what to do
```

- [ ] **Step 3: Add DESIGN dispatch block**

Add the following section BEFORE the catch-all block (the `### If state is any other` section at line ~115), so reading order is: BEADS → DESIGN → catch-all → CODE.

```markdown
### If state is DESIGN (implemented)
- Check for partial output: does `docs/c4flow/designs/<feature.slug>/` exist?
  - If `MASTER.md` exists but no screen frames in `.pen` → resume from Step 1.3 (components)
  - If screen frames exist → present for user review, ask "Reuse existing designs or regenerate?"
- Run the design skill (see Skill Dispatch below)
- After skill completes, check gate conditions (see `references/phase-transitions.md`)
- If gate passes: add `DESIGN` to `completedStates`, advance `currentState` to `BEADS`, write `.state.json`
- If gate fails: tell user what's missing, ask what to do
```

- [ ] **Step 4: Fix the unimplemented catch-all**

Find:
```
### If state is any other (unimplemented skills: DESIGN, REVIEW through DEPLOY)
```
Replace with:
```
### If state is any other (unimplemented skills: E2E, INFRA, DEPLOY, MERGE)
```

- [ ] **Step 5: Add DESIGN to Skill Dispatch section**

Add to the Skill Dispatch section:
```markdown
### DESIGN (Main agent, dispatches sub-agents)
This runs in the main agent (you). Load the c4flow:design skill and follow its instructions.
```

- [ ] **Step 6: Verify all four changes**

Run:
```bash
grep "DESIGN" skills/c4flow/SKILL.md
```
Expected lines include:
- `✅ Implemented` (state table)
- `If state is DESIGN (implemented)` (dispatch block)
- `advance \`currentState\` to \`DESIGN\`` (SPEC transition note)
- `E2E, INFRA, DEPLOY, MERGE` (catch-all fix — no longer includes DESIGN)

- [ ] **Step 7: Commit**

```bash
git add skills/c4flow/SKILL.md
git commit -m "feat(design): wire DESIGN state into c4flow orchestrator"
```

---

## Task 9: Update `skills/beads/SKILL.md`

**Files:**
- Modify: `skills/beads/SKILL.md` (Input section, near top)

Current Input section:
```markdown
## Input
- `docs/specs/<feature>/spec.md` (from spec phase)
- `docs/specs/<feature>/design.md` (from spec phase)
```

- [ ] **Step 1: Add design artifacts to Input section**

Replace:
```markdown
## Input
- `docs/specs/<feature>/spec.md` (from spec phase)
- `docs/specs/<feature>/design.md` (from spec phase)
```

With:
```markdown
## Input
- `docs/specs/<feature>/spec.md` (from SPEC phase)
- `docs/specs/<feature>/design.md` (from SPEC phase)
- `docs/c4flow/designs/<feature>/MASTER.md` (from DESIGN phase — design tokens, component list)
- `docs/c4flow/designs/<feature>/screen-map.md` (from DESIGN phase — screens and component breakdown)

> Note: If `MASTER.md` and `screen-map.md` don't exist (DESIGN phase was skipped), proceed with only `spec.md` and `design.md`. The DESIGN phase is not mandatory for the workflow to function.
```

- [ ] **Step 2: Verify**

Run: `grep "screen-map.md" skills/beads/SKILL.md`
Expected: line found

- [ ] **Step 3: Commit**

```bash
git add skills/beads/SKILL.md
git commit -m "feat(design): add MASTER.md and screen-map.md as BEADS inputs"
```

---

## Task 10: Write `skills/design/SKILL.md`

**Files:**
- Modify: `skills/design/SKILL.md` (currently a stub — replace fully)

- [ ] **Step 1: Write the main skill file**

Replace the entire file with:

```markdown
---
name: c4flow:design
description: Generate design system and UI mockups for a feature using Pencil MCP. Runs after SPEC phase, before BEADS. Produces MASTER.md (design tokens), screen-map.md (screen breakdown), and a .pen file with reusable components and screen frames. Use when the workflow reaches DESIGN state or user asks to design screens/UI.
---

# /c4flow:design — Design System + Mockups

**Phase**: 2: Design
**Agent type**: Main agent (interactive) + sub-agents (sequential screen composition)
**Status**: Implemented

## Prerequisites

Before starting, verify:
1. Pencil MCP is available — call `get_editor_state()`. If it fails, tell user: "Design skill requires Pencil MCP. Install from https://docs.pencil.dev/getting-started/ai-integration"
2. `docs/specs/<feature>/spec.md` exists — if not, tell user to run SPEC phase first
3. `docs/specs/<feature>/design.md` exists — if not, tell user to run SPEC phase first

Read workflow state from `docs/c4flow/.state.json` to get `feature.slug` and `feature.name`.

## Partial Resume

Check `docs/c4flow/designs/<slug>/` before starting:

| Existing State | Resume From |
|---|---|
| Directory doesn't exist | Step 1.1 (analyze & screen map) |
| `screen-map.md` exists, no `MASTER.md` | Step 1.2 (design tokens) |
| `MASTER.md` exists, no components in .pen | Step 1.3 (reusable components) |
| Components exist, no screen frames | Step 1.4 (hero screen) |
| Hero screen exists, remaining screens missing | Phase 2 (sub-agents) |
| All screens exist | Final review |

If resuming, tell user: "Found existing design artifacts. Resuming from [step]. Say 'regenerate' to start over."

---

## Phase 1: Main Agent (Interactive)

### Step 1.1: Analyze & Screen Map

**Goal**: Understand what screens to build and get user approval.

1. Read `skills/design/references/design-principles.md` — load Context Gathering Protocol
2. Read `docs/specs/<feature>/spec.md` — extract all MUST requirements + scenarios
3. Read `docs/specs/<feature>/design.md` — extract components, data model, API endpoints
4. Read `docs/specs/<feature>/proposal.md` if exists — extract target audience, brand tone
5. Group requirements into screens:
   - Each major user flow → 1 screen group
   - Each MUST requirement needing UI → at least 1 screen
   - Shared elements (nav, sidebar) → note for component list
6. Draft screen map and present to user:
   ```
   I've analyzed the spec and propose these screens:

   [Auth Flow] (3 screens): Login, Register, Forgot Password
   [Dashboard] (2 screens): Overview, Analytics
   [Feature X] (3 screens): List, Create, Detail

   Shared components needed: Nav, Sidebar, Button, Input, Card, Badge, Table, Modal

   Does this look right? Want to add, remove, or merge any screens?
   ```
7. Iterate until user approves
8. Create directory: `docs/c4flow/designs/<slug>/`
9. Write `docs/c4flow/designs/<slug>/screen-map.md` in this format:

```markdown
# Screen Map: <feature-name>

## <Flow Name> (N screens)

### <Screen Name> — <frame-name>
- **Components:** Nav, Input×2, Button(primary)
- **Spec refs:** spec.md#<section>
- **Notes:** <layout or interaction notes>
```

### Step 1.2: Design System Tokens

**Goal**: Create project-specific design tokens, save to `.pen` file and `MASTER.md`.

1. Read `skills/design/references/color-and-contrast.md`
2. Read `skills/design/references/typography.md`
3. Read `skills/design/references/spatial-design.md`
4. Call `get_style_guide_tags()` → get available tags
5. Select tags based on feature (webapp/mobile/landing-page + mood tags)
6. Call `get_style_guide(name: <chosen-guide>)` → get style inspiration
7. Call `get_guidelines(topic: "design-system")` → get Pencil schema rules
8. Design tokens following Impeccable principles:
   - Colors: OKLCH, tinted neutrals (chroma 0.01), 60-30-10 rule
   - Typography: avoid Inter/Roboto/Arial, modular scale (1.25 or 1.333), max 5 sizes
   - Spacing: 4pt base (4, 8, 12, 16, 24, 32, 48, 64, 96)
9. Call `open_document("new")` → creates new `.pen` file
10. Call `set_variables()` with all tokens
11. Call `batch_design()` → create "Design System" frame with color swatches + type scale samples
12. Call `get_screenshot()` on the DS frame
13. Run quality check from `skills/design/references/quality-checklist.md`
14. Present to user for review and iterate until approved
15. Write `docs/c4flow/designs/<slug>/MASTER.md` (see format in spec)
16. Save the active `.pen` document — note the file will be at `docs/c4flow/designs/<slug>/<slug>.pen`

### Step 1.3: Reusable Components

**Goal**: Create all shared components in the `.pen` file as reusable frames.

1. Read `skills/design/references/component-patterns.md`
2. Read `skills/design/references/spatial-design.md`
3. Determine platform type from `tech-stack.md` — call `get_guidelines(topic: "web-app")` or `"mobile-app"`
4. From `screen-map.md`, extract the full component list
5. For each component:
   - Call `batch_design()` — insert frame with `reusable: true` inside the Design System frame
   - Use design tokens (variables) for all colors, fonts, spacing
   - Create variants as separate reusable frames (e.g., Button Primary, Button Secondary, Button Ghost, Button Destructive)
   - Max 25 operations per `batch_design` call — split into multiple calls if needed
6. After all components created, call `get_screenshot()` on the Design System frame
7. Run quality checklist on component library
8. Present to user for review and iterate

**Binding names must be unique across calls. Never reuse a binding name.**

### Step 1.4: Hero Screen Mockup

**Goal**: Compose the most complex screen using reusable components, validate style direction.

1. Read all reference files (`references/*.md`) — this is the most complex step
2. Select hero screen (most complex = most components, most layout decisions)
3. Determine dimensions from `tech-stack.md` or use defaults from `spatial-design.md`
4. Call `find_empty_space_on_canvas({direction: "right", width: <w>, height: <h>})` → get position
5. Call `batch_design()` → create screen frame at that position
6. Call `batch_get({patterns: [{reusable: true}], searchDepth: 2})` → get all component ref IDs
7. Call `batch_design()` → compose screen using `{type: "ref", ref: "<id>"}` for components
   - Split into multiple calls by section (nav first, then sidebar, then main content)
8. Call `get_screenshot()` on the screen frame
9. Run full quality checklist from `quality-checklist.md`:
   - AI Slop Detection (CRITICAL — first)
   - Visual hierarchy squint test
   - Color contrast check
   - Typography check
   - Spacing check
   - Call `snapshot_layout({nodeIds: [<screenId>], problemsOnly: true})`
10. Fix any issues found, re-screenshot
11. Present to user for review and iterate until approved
12. Record hero screen frame ID
13. Update `.state.json`:
    ```bash
    jq '.heroScreen = "<hero-frame-id>" | .designSystem = "docs/c4flow/designs/<slug>/<slug>.pen" | .screenCount = <N>' \
      docs/c4flow/.state.json > docs/c4flow/.state.json.tmp \
      && mv docs/c4flow/.state.json.tmp docs/c4flow/.state.json
    ```

---

## Phase 2: Sub-Agents (Sequential)

**Goal**: Compose remaining screens one by one, each via a fresh sub-agent.

1. Read `screen-map.md` — list all screens except the hero
2. If >15 screens: batch into groups of 5 — complete one group, do user review, then next group
3. Call `batch_get({patterns: [{reusable: true}], searchDepth: 2})` — extract ALL component ref IDs
4. For each remaining screen, dispatch a sub-agent with the prompt template below
5. Wait for each sub-agent to complete before dispatching the next (sequential — same .pen file)
6. After all screens done: call `get_screenshot()` for all screen frames, present batch review
7. If user requests fixes for a screen: dispatch fix sub-agent for that screen only

### Sub-Agent Prompt Template

```
# Design Screen: {screen_name}

## Context
Feature: {feature_name}
Pencil MCP file: {pen_file_path}
Design System Frame ID: {ds_frame_id}
Hero Screen Frame ID: {hero_frame_id} — use as style reference (match spacing rhythm, visual weight, layout patterns)
Screen Dimensions: {width}×{height}

## Screen Spec (from screen-map.md)
{full screen entry from screen-map.md}

## Reusable Components Available
{list each component: name: ref="<id>"}

## Design Tokens (from MASTER.md)
Primary: {value}
Background: {value}
Foreground: {value}
Font heading: {value}
Font body: {value}
Spacing scale: 4 · 8 · 12 · 16 · 24 · 32 · 48 · 64

## Instructions
1. Call find_empty_space_on_canvas({direction:"right", width:{w}, height:{h}}) → get position
2. batch_design → create screen frame at that position
3. batch_design → compose screen using component refs (type:"ref") — split into ≤25 ops per call
4. get_screenshot on screen frame
5. snapshot_layout({nodeIds:[<frameId>], problemsOnly:true}) → check issues
6. If issues found → fix via batch_design → re-screenshot (1 retry max)

## Design Rules
- No pure black/gray — tinted neutrals only (chroma ≥ 0.005)
- No card nesting — use spacing for hierarchy within sections
- Squint test: primary element identifiable in 2 seconds
- Every interactive element needs clear affordance
- Tight grouping (8-12px) for related items, generous (48-96px) between sections
- 60-30-10 color weight rule (neutrals 60%, secondary 30%, accent 10%)
- No identical repeated card grids (icon + heading + text repeated)
- Match the hero screen's layout rhythm and visual weight

## Report
Return: DONE | DONE_WITH_CONCERNS | BLOCKED
Include:
- Screen frame ID
- Screenshot verified: yes/no
- Issues found: <list or "none">
```

### Model Selection

| Screen Type | Model |
|---|---|
| Simple form (login, register, settings) | `haiku` |
| Dashboard / data-heavy / multi-section | `sonnet` |
| Complex flow (multi-step wizard) | `sonnet` |

---

## Phase 3: Completion

1. Call `get_screenshot()` of entire canvas (all frames)
2. Optional: Call `export_nodes()` for all screen frame IDs → PNG exports
3. Verify gate conditions:
   - `docs/c4flow/designs/<slug>/MASTER.md` exists
   - `docs/c4flow/designs/<slug>/screen-map.md` exists
   - `.pen` file exists with Design System frame + ≥1 screen frame
   - All screens in `screen-map.md` have corresponding frames
   - Hero screen passed quality check
   - User approved final review
4. Update `.state.json`:
   ```bash
   jq '.screenCount = <N>' docs/c4flow/.state.json > docs/c4flow/.state.json.tmp \
     && mv docs/c4flow/.state.json.tmp docs/c4flow/.state.json
   ```
5. Report to orchestrator: DONE — gate conditions met, ready for BEADS

---

## Error Handling

| Situation | Action |
|---|---|
| Pencil MCP not available | Abort: "Design skill requires Pencil MCP. Install from https://docs.pencil.dev/getting-started/ai-integration" |
| `spec.md` or `design.md` missing | Abort: "Run SPEC phase first (`/c4flow:run`)" |
| `get_style_guide` returns no results | Proceed with Impeccable defaults from reference files |
| Sub-agent can't find component ref | Re-call `batch_get({patterns:[{reusable:true}]})`, provide correct ref IDs, re-dispatch |
| `snapshot_layout` reports issues | Fix via `batch_design`, re-screenshot (1 auto-retry), then DONE_WITH_CONCERNS |
| Canvas space insufficient | Call `find_empty_space_on_canvas` with larger dimensions |
| User rejects design 3+ times | Ask: "Want to try a different style direction? We can pick different style guide tags." |
| `batch_design` fails (rollback) | Check error message, fix operation list, retry. Common: invalid ref ID, missing parent, reused binding |
| `.pen` file corrupted or empty | Delete file, restart from Step 1.2 (tokens in MASTER.md survive) |
| >15 screens | Batch into groups of 5, user review between groups |

---

## Pencil MCP Constraints

- `batch_design` max **25 operations** per call — split by logical section
- Every `I()`, `C()`, `R()` operation **must** have a binding name
- `document` is reserved — only use when creating top-level canvas frames
- Bindings are only valid within the same `batch_design` call
- Do NOT `U()` descendants of a freshly `C()`'d node — copy creates new IDs
- No `"image"` node type — images are fills on frame/rectangle nodes via `G()` operation
- `find_empty_space_on_canvas` before every new screen frame — prevents overlap
```

- [ ] **Step 2: Verify the skill has the required frontmatter and sections**

Run:
```bash
head -10 skills/design/SKILL.md
grep -c "^### Step" skills/design/SKILL.md
```

Expected:
- First 10 lines show frontmatter with `name: c4flow:design` and description NOT containing "NOT IMPLEMENTED"
- Step count ≥ 4

- [ ] **Step 3: Verify description does not say NOT IMPLEMENTED**

Run: `grep "NOT IMPLEMENTED" skills/design/SKILL.md`
Expected: no output (empty)

- [ ] **Step 4: Commit**

```bash
git add skills/design/SKILL.md
git commit -m "feat(design): implement c4flow:design skill with Pencil MCP + Impeccable"
```

---

## Final Verification

- [ ] **Verify all files exist**

```bash
ls skills/design/references/
```

Expected: 6 files — `design-principles.md`, `color-and-contrast.md`, `typography.md`, `spatial-design.md`, `component-patterns.md`, `quality-checklist.md`

- [ ] **Verify orchestrator wiring**

```bash
grep -n "DESIGN" skills/c4flow/SKILL.md | head -20
```

Expected: lines showing `✅ Implemented`, `If state is DESIGN`, state transition wiring, and catch-all fix.

- [ ] **Verify BEADS inputs updated**

```bash
grep "MASTER.md" skills/beads/SKILL.md
```

Expected: line found with path `docs/c4flow/designs/<feature>/MASTER.md`

- [ ] **Verify phase gate updated**

```bash
grep "DESIGN → BEADS" skills/c4flow/references/phase-transitions.md
```

Expected: line contains "MASTER.md exists" (7-point gate)

- [ ] **Final commit if any cleanup needed**

```bash
git status
# If clean: done
# If dirty: git add -p && git commit -m "chore(design): final cleanup"
```
