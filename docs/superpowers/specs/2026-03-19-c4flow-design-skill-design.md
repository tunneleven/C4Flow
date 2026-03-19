# C4Flow Design Skill — Design Specification

## Overview

The `/c4flow:design` skill generates a design system and screen mockups for a feature using Pencil MCP, positioned between SPEC and BEADS in the c4flow workflow. It produces design tokens, reusable components, and composable screen mockups in a single `.pen` file, plus human-readable documentation (`MASTER.md`, `screen-map.md`) that downstream phases consume.

**Workflow position:** `SPEC → DESIGN → BEADS → CODE → ...`

**Agent type:** Main agent (interactive) + sub-agents (parallel screen composition)

**Dependencies:** Pencil MCP (required), spec artifacts from SPEC phase

---

## Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Workflow position | After SPEC, before BEADS | Design system + mockups inform task breakdown — BEADS needs to know what screens/components to build |
| Pencil MCP | Required, user installs | Design skill cannot function without Pencil MCP tools |
| Design approach | Hybrid — custom tokens + Pencil built-in components | Flexibility: project-specific tokens ensure brand consistency, Pencil components accelerate composition |
| Impeccable integration | Deep embedding via reference files | Encode full methodology (not just anti-patterns) into skill prompts — no external dependency on Impeccable plugin |
| Screen extraction | Smart analysis of spec + design artifacts | Group related requirements into screens, present for user approval before designing |
| Output for BEADS | `MASTER.md` + `screen-map.md` (not `.pen` files) | BEADS needs "what to build" not "how it looks" — pixel details deferred to CODE phase implementers |
| File organization | All screens in 1 `.pen` file | Figma-like canvas — design system frame + screen frames organized spatially |

---

## Output Structure

```
docs/c4flow/designs/<feature-slug>/
├── MASTER.md                    # Design system tokens (human-readable)
├── screen-map.md                # Screen list + component breakdown per screen
└── <feature-slug>.pen           # Single Pencil file: design system + all screens
```

### .pen File Internal Structure

```
<feature-slug>.pen (canvas)
├── Design System (frame, top-left)
│   ├── Colors (swatches)
│   ├── Typography (samples)
│   └── Components (reusable: true)
│       ├── Button (primary, secondary, ghost, destructive)
│       ├── Input (default, error, disabled)
│       ├── Card (default, interactive)
│       ├── Badge (info, success, warning, error)
│       ├── Nav (top, sidebar)
│       ├── Modal (default, confirm)
│       └── ... (derived from screen-map analysis)
├── Screen Group: Auth Flow (positioned right)
│   ├── Login (screen frame)
│   ├── Register (screen frame)
│   └── Forgot Password (screen frame)
├── Screen Group: Dashboard (positioned below)
│   └── Dashboard (screen frame)
└── ... (more screen groups)
```

### MASTER.md Format

```markdown
# Design System: <feature-name>

## Style Direction
- Style: [e.g. minimal, editorial, brutalist...]
- Mood: [e.g. professional, playful, premium...]
- Differentiation: [what makes this unforgettable]

## Colors (OKLCH)
| Token | Value | Usage |
|-------|-------|-------|
| --primary | oklch(60% 0.15 250) | CTA, links, key actions |
| --secondary | oklch(55% 0.12 300) | Secondary actions |
| --accent | oklch(75% 0.20 150) | Highlights, badges |
| --bg | oklch(98% 0.005 250) | Page background |
| --fg | oklch(20% 0.02 250) | Body text |
| --muted | oklch(65% 0.01 250) | Secondary text |
| --border | oklch(85% 0.01 250) | Borders, dividers |
| --destructive | oklch(55% 0.25 25) | Errors, delete actions |
| --card | oklch(99% 0.003 250) | Card/surface backgrounds |

## Typography
| Token | Value |
|-------|-------|
| --font-heading | [distinctive font], sans-serif |
| --font-body | [readable font], sans-serif |
| --text-h1 | Xpx / 1.2 / -0.02em |
| --text-h2 | Xpx / 1.25 / -0.01em |
| --text-h3 | Xpx / 1.3 |
| --text-body | 16px / 1.5 |
| --text-small | 14px / 1.4 |
| --text-caption | 12px / 1.4 |

## Spacing Scale (4px base)
4 · 8 · 12 · 16 · 24 · 32 · 48 · 64 · 96

## Border Radius
| Token | Value |
|-------|-------|
| --radius-sm | 4px |
| --radius-md | 8px |
| --radius-lg | 12px |
| --radius-full | 9999px |

## Shadows
| Token | Value |
|-------|-------|
| --shadow-sm | 0 1px 2px oklch(0% 0 0 / 0.05) |
| --shadow-md | 0 4px 12px oklch(0% 0 0 / 0.08) |
| --shadow-lg | 0 8px 24px oklch(0% 0 0 / 0.12) |

## Reusable Components
| Component | Variants | Usage |
|-----------|----------|-------|
| Button | primary, secondary, ghost, destructive | Actions |
| Input | default, error, disabled | Form fields |
| Card | default, interactive | Content containers |
| ... | | |

## Impeccable Anti-Patterns (enforced)
- No pure black/gray — always tinted neutrals (chroma 0.01+)
- No gray text on colored backgrounds — use shade of bg color
- No overused default fonts (Inter, Roboto, Arial, Open Sans)
- No excessive card nesting (max 1 level)
- No bounce/elastic animations
- No purple gradients as default accent
- No low-contrast text (min 4.5:1 body, 3:1 large, 3:1 UI)
- No glassmorphism as decoration
- No identical card grids (icon + heading + text repeated)
- No hero metric layout template
```

### screen-map.md Format

```markdown
# Screen Map: <feature-name>

## <Flow Name> (N screens)

### <Screen Name> — <screen-frame-name>
- **Components:** Nav, Input×2, Button(primary), Link
- **Spec refs:** spec.md#<requirement-section>
- **Notes:** <layout/interaction notes>

### <Screen Name> — <screen-frame-name>
- **Components:** ...
- **Spec refs:** ...
...
```

---

## Execution Flow

### Phase 1: Main Agent (Interactive)

#### Step 1.1: Analyze & Screen Map

**Input:** `spec.md` + `design.md` from SPEC phase
**Output:** `screen-map.md` (user approved)

1. Read `docs/specs/<feature>/spec.md` — extract all requirements + scenarios
2. Read `docs/specs/<feature>/design.md` — extract components, data model, API endpoints
3. Load `references/design-principles.md` — Context Gathering Protocol
4. Group related requirements into screens:
   - Each major user flow → 1 screen group
   - Each MUST requirement needing UI → at least 1 screen
   - Shared elements (nav, sidebar) → note for component list
5. Present screen map to user with component summary
6. Iterate until user approves
7. Write `docs/c4flow/designs/<slug>/screen-map.md`

#### Step 1.2: Design System Tokens

**Input:** `screen-map.md` + `tech-stack.md`
**Output:** `MASTER.md` + Pencil variables in `.pen` file

1. Call `get_style_guide_tags()` → get available style tags
2. Select tags based on feature context (webapp/mobile/landing)
3. Call `get_style_guide(tags:[...])` → get style inspiration
4. Call `get_guidelines(topic:"design-system")` → get Pencil rules
5. Load `references/color-and-contrast.md` + `references/typography.md` + `references/spatial-design.md`
6. Generate design tokens following Impeccable principles:
   - Colors: OKLCH, tinted neutrals, reduce chroma at extreme lightness
   - Typography: avoid overused fonts, use modular scale (1.25 or 1.333), max 5 sizes
   - Spacing: 4px base grid
7. Call `open_document("new")` → create `.pen` file
8. Call `set_variables()` → set all tokens as Pencil variables
9. Call `batch_design()` → create "Design System" frame with color swatches + type samples
10. Call `get_screenshot()` → screenshot design system frame
11. Present to user via visual companion for review
12. Iterate tokens until approved
13. Write `docs/c4flow/designs/<slug>/MASTER.md`
14. Save `.pen` file to `docs/c4flow/designs/<slug>/<slug>.pen`

#### Step 1.3: Reusable Components

**Input:** `screen-map.md` (component list) + design tokens
**Output:** Reusable components in `.pen` file

1. From screen-map, extract list of shared components needed
2. Call `get_guidelines(topic:"web-app")` or `get_guidelines(topic:"mobile-app")` (based on project)
3. Load `references/component-patterns.md`
4. For each component:
   - Call `batch_design()` → insert frame with `reusable: true`
   - Apply design tokens (variables) for colors, fonts, spacing
   - Create variants if needed (e.g., Button: primary, secondary, ghost, destructive)
5. Call `get_screenshot()` → screenshot entire component library
6. Present to user via visual companion for review
7. Iterate until approved

#### Step 1.4: Hero Screen Mockup

**Input:** Design system + components + screen-map
**Output:** 1 approved hero screen in `.pen` file

1. Select most complex screen as hero (typically dashboard or main screen)
2. Call `find_empty_space_on_canvas()` → find position for screen frame
3. Call `batch_design()` → create screen frame (e.g. 1440×900)
4. Call `batch_design()` → compose screen by inserting refs to reusable components
5. Call `get_screenshot()` → screenshot hero screen
6. Load `references/quality-checklist.md` → run quality check:
   - AI Slop Test — does it look AI-generated?
   - Squint test — primary element identifiable in 2 seconds?
   - Contrast check — all text meets WCAG?
   - Layout rhythm — tight grouping for related, generous between sections?
7. Call `snapshot_layout({problemsOnly:true})` → check structural issues
8. Present in visual companion → user review
9. Iterate style, layout, spacing until user approves
10. Hero screen becomes **reference style** for Phase 2

### Phase 2: Sub-Agents (Parallel)

**Input:** Approved hero screen + design system + component refs + screen-map
**Output:** Remaining screens in `.pen` file

1. Main agent reads `screen-map.md` → list remaining screens (excluding hero)
2. Main agent calls `batch_get()` → extract all reusable component ref IDs
3. For each remaining screen, dispatch sub-agent with:
   - Screen name, spec refs, component list
   - Component ref IDs (from batch_get)
   - Design tokens (from MASTER.md — key values)
   - Design rules (subset of Impeccable principles)
   - `.pen` file path
4. Each sub-agent:
   - Calls `find_empty_space_on_canvas()` → find position
   - Calls `batch_design()` → create screen frame
   - Calls `batch_design()` → compose using component refs (type:"ref")
   - Calls `get_screenshot()` → verify visual quality
   - Calls `snapshot_layout({problemsOnly:true})` → check layout issues
   - If issues → fix via `batch_design()` → re-screenshot (1 retry max)
   - Reports: DONE | DONE_WITH_CONCERNS | BLOCKED
5. Main agent collects results:
   - Calls `get_screenshot()` for all screens
   - Presents batch review in visual companion
   - User approves or requests fixes for specific screens
   - If fixes needed → dispatch fix sub-agent for that screen

#### Sub-Agent Model Selection

| Screen Type | Model | Reason |
|---|---|---|
| Simple form (login, register, settings) | `haiku` | 1-2 component types, clear layout |
| Dashboard / data-heavy / multi-section | `sonnet` | Multi-component composition, layout judgment |
| Complex flow (multi-step wizard, builder) | default | Design judgment needed |

### Phase 3: Completion

1. Final `get_screenshot()` of entire canvas
2. Optional: `export_nodes()` → export all screens as PNG for reference
3. Verify gate conditions (see Gate Conditions below)
4. Update `.state.json`
5. Report completion to orchestrator

---

## Impeccable Integration

### Reference File Structure

```
skills/design/
├── SKILL.md
└── references/
    ├── design-principles.md      # From Impeccable frontend-design SKILL.md
    ├── color-and-contrast.md     # From Impeccable reference
    ├── typography.md             # From Impeccable reference
    ├── spatial-design.md         # From Impeccable reference
    ├── component-patterns.md     # From Impeccable interaction-design + arrange
    └── quality-checklist.md      # From Impeccable audit + critique + polish
```

### Reference Loading Per Step

| Step | References Loaded |
|------|-------------------|
| 1.1 Analyze & Screen Map | `design-principles.md` (context gathering, design direction) |
| 1.2 Design System Tokens | `color-and-contrast.md` + `typography.md` + `spatial-design.md` |
| 1.3 Reusable Components | `component-patterns.md` + `spatial-design.md` |
| 1.4 Hero Screen | All references |
| Phase 2 Sub-agents | `design-principles.md` + `component-patterns.md` (subset) |
| Quality Check | `quality-checklist.md` (after every `get_screenshot`) |

### Key Principles Embedded

**Design Direction** (from frontend-design SKILL):
- Commit to BOLD aesthetic — no middle-ground genericism
- Every design must pass the AI Slop Test
- Make unexpected choices — no two designs should look the same
- Required context: target audience, use cases, brand personality/tone

**Color** (from color-and-contrast.md):
- OKLCH for all colors — perceptually uniform
- Tinted neutrals (chroma 0.01) — no pure gray/black/white
- Reduce chroma at extreme lightness — high chroma + light = garish
- 60-30-10 rule for visual weight (neutrals 60%, secondary 30%, accent 10%)
- Gray text on colored backgrounds → use shade of bg color instead
- Alpha/transparency is a design smell — define explicit colors

**Typography** (from typography.md):
- Avoid invisible defaults (Inter, Roboto, Arial, Open Sans, Lato, Montserrat)
- Better alternatives: Instrument Sans, Plus Jakarta Sans, Outfit, Figtree, Onest
- Modular scale with 5 sizes max: caption, secondary, body, subheading, heading
- Popular ratios: 1.25 (major third), 1.333 (perfect fourth)
- Vertical rhythm: spacing = multiples of line-height
- One font family often enough — only add second for genuine contrast (serif+sans, geometric+humanist)
- Never pair similar-but-not-identical fonts

**Spatial** (from spatial-design.md):
- 4pt base (not 8pt — too coarse): 4, 8, 12, 16, 24, 32, 48, 64, 96
- `gap` over margins — eliminates margin collapse
- Squint test after every screen — can you identify primary element blurred?
- Cards only when content is truly distinct — never nest cards
- Hierarchy through multiple dimensions: size + weight + color + space

**Components** (from interaction-design + arrange):
- Progressive disclosure — start simple, reveal sophistication
- Empty states teach the interface, not just "nothing here"
- Every interactive surface feels intentional and responsive
- Not every button should be primary — use ghost, text links, secondary
- Consistent interaction states: default, hover, focus, active, disabled, loading, error, success

**Quality** (from audit + critique + polish):
- Anti-patterns verdict first — pass/fail AI detection
- Visual hierarchy: squint test, 2-second primary element recognition
- Contrast ratios: 4.5:1 body text, 3:1 large text, 3:1 UI components
- No glassmorphism as decoration, no sparklines as decoration
- No rounded rectangles with generic drop shadows
- Touch targets: 44px minimum
- Consistent token usage — no hard-coded colors

---

## Pencil MCP Tool Usage

### Tool Call Patterns Per Step

**Step 1.2 — Design System Tokens:**
```
get_style_guide_tags() → get_style_guide(tags) → get_guidelines("design-system")
→ open_document("new") → set_variables({...}) → batch_design([DS frame])
→ get_screenshot(dsFrame)
```

**Step 1.3 — Reusable Components:**
```
get_guidelines("web-app"|"mobile-app")
→ batch_design([component with reusable:true]) × N components
→ get_screenshot(dsFrame)
```

**Step 1.4 & Phase 2 — Screen Composition:**
```
find_empty_space_on_canvas({direction, width, height})
→ batch_design([screen frame]) → batch_design([component refs via I(parent,{type:"ref",ref:id})])
→ get_screenshot(screenFrame) → snapshot_layout({problemsOnly:true})
```

**Quality Check (after every screenshot):**
```
get_screenshot(frameId) → snapshot_layout({nodeIds:[frameId], problemsOnly:true})
→ if issues: batch_design([fixes]) → get_screenshot(frameId)
```

### Constraints

- `batch_design` max **25 operations** per call — split by logical section
- Every `I()`, `C()`, `R()` **must** have a binding name
- `document` is reserved binding — only use for top-level frames
- Bindings only valid within same `batch_design` call
- Do not `U()` descendants of freshly `C()`'d nodes — IDs change on copy
- No "image" node type — images are fills on frame/rectangle via `G()` operation

---

## State Machine Integration

### State Table Update

| State | Phase | Status |
|-------|-------|--------|
| `DESIGN` | 2: Design | ✅ Implemented |

### Transition Order

```
SPEC → DESIGN → BEADS → CODE → TEST → REVIEW → VERIFY → PR → ...
```

### `.state.json` Additions

```json
{
  "designSystem": "docs/c4flow/designs/<slug>/<slug>.pen",
  "screenCount": 8,
  "heroScreen": "<hero-frame-id>"
}
```

### Gate Condition (DESIGN → BEADS)

All must pass:
- `MASTER.md` exists at `docs/c4flow/designs/<slug>/MASTER.md`
- `screen-map.md` exists at `docs/c4flow/designs/<slug>/screen-map.md`
- `.pen` file exists with Design System frame containing reusable components
- `.pen` file has ≥1 screen frame
- All screens listed in `screen-map.md` have corresponding frames in `.pen` file
- Quality check passed (AI Slop Test + squint test on hero screen)
- User approved final review

### BEADS Skill Input Update

BEADS skill adds these inputs:
- `docs/c4flow/designs/<slug>/MASTER.md`
- `docs/c4flow/designs/<slug>/screen-map.md`

### Partial Resume Support

| Existing State | Resume From |
|---|---|
| Nothing in `designs/` dir | Step 1.1 (analyze & screen map) |
| `screen-map.md` exists | Step 1.2 (design tokens) |
| `MASTER.md` exists, no components in .pen | Step 1.3 (reusable components) |
| Components exist, no screen frames | Step 1.4 (hero screen) |
| Hero screen exists, remaining screens missing | Phase 2 (sub-agents) |
| All screens exist | Final review |

### Orchestrator Dispatch

```markdown
### If state is DESIGN (implemented)
- Check for partial output: does `docs/c4flow/designs/<slug>/` exist?
  - If MASTER.md exists but no screens → resume from Step 1.3
  - If screens exist → present for user review, ask "Reuse or regenerate?"
- Run the design skill (see Skill Dispatch below)
- After skill completes, check gate conditions
- If gate passes: add DESIGN to completedStates, advance to BEADS

### DESIGN (Main agent, dispatches sub-agents)
Load the c4flow:design skill and follow its instructions.
```

---

## Error Handling

| Situation | Action |
|---|---|
| Pencil MCP not available | Abort with message: "Design skill requires Pencil MCP. Install from https://docs.pencil.dev/getting-started/ai-integration" |
| `spec.md` or `design.md` missing | Cannot proceed — tell user to run SPEC phase first |
| `get_style_guide` returns no results | Proceed with Impeccable defaults from reference files |
| Sub-agent can't find component ref | Main agent re-reads components via `batch_get`, provides correct ref ID, re-dispatch |
| `snapshot_layout` reports issues | Sub-agent fixes automatically (1 retry), then reports DONE_WITH_CONCERNS |
| Canvas space insufficient | Main agent calls `find_empty_space_on_canvas` with larger area, provides new coordinates |
| User rejects design 3+ times | Ask: "Would you like to adjust the style direction? We can pick different style guide tags or change the aesthetic." |
| `batch_design` operation fails (rollback) | Review error, fix operation list, retry. Common issues: invalid ref ID, missing parent, wrong schema |

---

## Sub-Agent Prompt Template

```markdown
# Design Screen: {screen_name}

## Context
Feature: {feature_name}
File: {pen_file_path}
Design System Frame ID: {ds_frame_id}

## Screen Spec
{full screen spec from screen-map.md}

## Reusable Components Available
{component_name}: ref="{ref_id}"
{component_name}: ref="{ref_id}"
...

## Design Tokens
{key values from MASTER.md: colors, fonts, spacing}

## Instructions
1. find_empty_space_on_canvas → find position
2. batch_design → create screen frame ({width}×{height})
3. batch_design → compose using component refs (type:"ref")
4. get_screenshot → verify visual
5. snapshot_layout(problemsOnly:true) → check issues
6. If issues → fix via batch_design → re-screenshot

## Design Rules
- No pure black/gray — tinted neutrals only
- No card nesting — spacing for hierarchy
- Squint test: primary element in 2 seconds
- Every interactive element needs clear affordance
- Tight grouping (8-12px) related items, generous (48-96px) between sections
- 60-30-10 color weight rule
- No identical repeated card grids

## Report
Return: DONE | DONE_WITH_CONCERNS | BLOCKED
Include: screen frame ID, screenshot status, issues found
```
