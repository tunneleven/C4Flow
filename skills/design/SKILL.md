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
15. Write `docs/c4flow/designs/<slug>/MASTER.md` with this format:

```markdown
# MASTER: <feature-name> Design System

## Design Tokens

| Token | Value | Purpose |
|-------|-------|---------|
| `--primary` | `oklch(...)` | CTAs, links |
| `--bg` | `oklch(...)` | Page background |
| `--fg` | `oklch(...)` | Body text |
| `--muted` | `oklch(...)` | Secondary text |
| `--border` | `oklch(...)` | Borders |
| `--card` | `oklch(...)` | Card surfaces |
| `--destructive` | `oklch(...)` | Errors |
| `--success` | `oklch(...)` | Confirmations |
| `--warning` | `oklch(...)` | Warnings |
| `--secondary` | `oklch(...)` | Secondary actions |
| `font-heading` | `'...'` | Heading font |
| `font-body` | `'...'` | Body font |
| `space-xs` | `4` | Tight spacing |
| `space-sm` | `8` | Small spacing |
| `space-md` | `16` | Medium spacing |
| `space-lg` | `32` | Large spacing |
| `space-xl` | `64` | XL spacing |

## Reusable Components

| Component | Variants | Frame ID |
|-----------|----------|----------|
| Button | Primary, Secondary, Ghost, Destructive | `<id>` |
| Input | Default, Error, Disabled | `<id>` |
| ... | ... | ... |

## File

- Pencil file: `docs/c4flow/designs/<slug>/<slug>.pen`
- Design System Frame ID: `<id>`
```

16. Save the `.pen` file: call `get_editor_state()` to get the current document path, then use the filesystem to confirm the file exists at `docs/c4flow/designs/<slug>/<slug>.pen`. Note: Pencil MCP auto-saves to the path used when `open_document("new")` was called — if the file path is not yet set, call `open_document("save", path: "docs/c4flow/designs/<slug>/<slug>.pen")` to save explicitly.

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
   - If sub-agent returns **BLOCKED**: pause dispatch, present the blocker to user, ask for guidance before continuing
   - If sub-agent returns **DONE_WITH_CONCERNS**: present concerns to user, ask "Proceed to next screen or fix this one first?"
   - If sub-agent returns **DONE**: continue to next screen
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
