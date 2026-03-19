# Personal Identity in Code Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `code` skill ask "who are you?" before dispatching tasks, then only run tasks assigned to that person — stored in a gitignored `.personal.json` file.

**Architecture:** Two changes to `skills/code/SKILL.md`: (1) a new Step 0 that resolves identity from `.personal.json` or prompts the user, and (2) updated dispatch logic that filters `bd ready` output to the current person's tasks in the current epic. One `.gitignore` entry prevents the identity file from being committed.

**Tech Stack:** Bash, jq, beads CLI (`bd`), markdown

**Spec:** `docs/superpowers/specs/2026-03-19-personal-identity-code-skill-design.md`

---

### Task 1: Add `.gitignore` entry (first commit)

**Files:**
- Modify: `.gitignore`

This must be committed before any developer creates `.personal.json`.

- [ ] **Step 1: Add the entry**

Open `.gitignore` and append at the end of the file:

```
# Personal identity — local only, never commit
docs/c4flow/.personal.json
```

- [ ] **Step 2: Ensure `docs/c4flow/` directory exists**

```bash
mkdir -p docs/c4flow
```

This directory is created at runtime by the code skill, but git check-ignore needs it to exist.

- [ ] **Step 3: Verify git treats the path as ignored**

```bash
git check-ignore -v docs/c4flow/.personal.json
```

Expected: `.gitignore:NN:docs/c4flow/.personal.json  docs/c4flow/.personal.json`

If it shows nothing, the entry isn't matching — check for typos.

- [ ] **Step 4: Commit**

```bash
git add .gitignore
git commit -m "chore: gitignore personal identity file"
```

---

### Task 2: Verify `bd` JSON field names

**Files:**
- Read: `skills/code/SKILL.md` (no edits yet — this is a research task)

The spec uses placeholder names like `<epic-field>` and `<child-field>` because the exact beads JSON schema wasn't verified at design time. This task pins the real field names before we touch SKILL.md.

- [ ] **Step 1: Check if `bd` is installed**

```bash
command -v bd && echo "INSTALLED" || echo "NOT_INSTALLED"
```

If NOT_INSTALLED: skip to Step 5 (use field names from beads source/docs).

- [ ] **Step 2: Check if a beads repo exists**

```bash
[ -d ".beads" ] && echo "EXISTS" || echo "MISSING"
```

If MISSING: `bd init` or look at beads CLI help to infer the schema.

- [ ] **Step 3: Inspect `bd ready --json` output shape**

```bash
bd ready --json | jq '.[0] | keys'
```

Look for: which key links to the parent epic (likely `epicId`, `parentId`, or `parent`). Note the exact key name.

- [ ] **Step 4: Inspect `bd show <epic-id> --json` output shape**

```bash
# Get any epic ID to test with
EPIC_ID=$(jq -r '.beadsEpic // empty' docs/c4flow/.state.json 2>/dev/null)
[ -n "$EPIC_ID" ] && bd show "$EPIC_ID" --json | jq 'keys'
bd show "$EPIC_ID" --json | jq '.[0] // . | keys'
```

Look for: the key that holds child tasks (likely `children`, `tasks`, or the root is already an array).

- [ ] **Step 5: Document findings**

Write the verified field names as a comment at the top of your next edit. For reference, the placeholders to replace are:
- `<epic-field>` — the key on a ready task that references its parent epic
- `<child-field>` — the key under a `bd show` response that lists child tasks

If `bd` is unavailable, use `epicId` for `<epic-field>` and `children` for `<child-field>` as best-guess defaults — these match the beads README examples.

---

### Task 3: Add Step 0 (Identity Check) to `skills/code/SKILL.md`

**Files:**
- Modify: `skills/code/SKILL.md`

**Prerequisite: Task 2 must be complete.** Replace every `<child-field>` and `<epic-field>` placeholder with the verified field names before inserting this block — leaving them as literals will cause jq parse errors.

Insert a new section before the `## Prerequisites` heading (currently the first heading after the frontmatter/description block).

- [ ] **Step 1: Read the current top of the file to find the insertion point**

```bash
head -50 skills/code/SKILL.md
```

Confirm `## Prerequisites` is the heading to insert before.

- [ ] **Step 2: Insert Step 0 before `## Prerequisites`**

Add the following block immediately before the `## Prerequisites` heading:

```markdown
## Step 0: Identity Check

Applies to Beads path only. Skip entirely if operating in `tasks.md` fallback mode (i.e., `taskSource` in `.state.json` is not `beads`).

1. Check `docs/c4flow/.personal.json`:
   - If it exists: `MY_NAME=$(jq -r '.name' docs/c4flow/.personal.json)` — proceed to Prerequisites
   - If missing: run the identity prompt below

2. **Identity prompt** (runs once per machine):

   ```bash
   EPIC_ID=$(jq -r '.beadsEpic' docs/c4flow/.state.json)

   # List unique assignees from epic children
   # Replace <child-field> with verified field name (e.g. children)
   ASSIGNEES=$(bd show "$EPIC_ID" --json \
     | jq -r '[.<child-field>[]?.assignee // empty] | unique[]')
   ```

   - If `$ASSIGNEES` is empty: print "No assignees found in epic — assign tasks in beads first: `bd update <task-id> --assignee <name>`, then re-run." and exit.
   - Present the list: "Who are you on this project? Pick one:" and list each name.
   - Save the choice:
     ```bash
     printf '{"name":"%s"}\n' "<chosen-name>" > docs/c4flow/.personal.json
     ```
   - Set `MY_NAME` and continue to Prerequisites.

> **To switch identity:** `rm docs/c4flow/.personal.json` then re-run `/c4flow:run`
```

- [ ] **Step 3: Verify the file still renders correctly**

```bash
grep -n "## Step 0\|## Prerequisites\|## Execution Flow" skills/code/SKILL.md | head -10
```

Expected: Step 0 appears before Prerequisites.

- [ ] **Step 4: Commit**

```bash
git add skills/code/SKILL.md
git commit -m "feat(code): add Step 0 identity check before Prerequisites"
```

---

### Task 4: Update dispatch sites in Steps 2 & 3

**Files:**
- Modify: `skills/code/SKILL.md`

Replace the `bd ready --json` calls that feed task **dispatch** with a single captured, filtered call. Two sections need updating:
- `### Step 2: Get Ready Tasks` (standalone section)
- `### Step 3: Claim and Dispatch — The Agent Loop` (the loop body)

Use the verified field names from Task 2.

- [ ] **Step 1: Locate the two dispatch sections**

```bash
grep -n "bd ready --json\|### Step 2\|### Step 3" skills/code/SKILL.md
```

Identify the line numbers for the `bd ready --json` calls under Step 2 and Step 3 only.

- [ ] **Step 2: Replace Step 2's `bd ready --json` block**

Find the existing `bd ready --json` call under `### Step 2: Get Ready Tasks`. Replace the entire block (the bash snippet and surrounding explanation) with:

```markdown
Query beads for ready tasks scoped to the current epic and the current user:

```bash
# Capture once — reuse for warnings and dispatch
# Replace <epic-field> with verified field (e.g. epicId)
READY_JSON=$(bd ready --json | jq --arg epic "$EPIC_ID" '[.[] | select(.<epic-field> == $epic)]')

# Warn about tasks with no assignee
echo "$READY_JSON" | jq -r '.[] | select(.assignee == null) | "WARNING: Task \(.id) has no assignee — skipping. Assign it in beads first."'

# Filter to current user
MY_TASKS=$(echo "$READY_JSON" | jq --arg name "$MY_NAME" '[.[] | select(.assignee == $name)]')

# Guard: halt if no tasks for this user
if [ "$(echo "$MY_TASKS" | jq 'length')" -eq 0 ]; then
  echo "No tasks assigned to $MY_NAME in this epic."
  echo "Check beads or switch identity: rm docs/c4flow/.personal.json"
  exit 1
fi
```
```

- [ ] **Step 3: Update Step 3's dispatch loop to split open vs in-flight**

Insert the following block immediately before the line containing `"For each task, dispatch a fresh subagent"` (or equivalent dispatch loop start text) in `### Step 3: Claim and Dispatch`:

```markdown
Before dispatching, split tasks into new work and already-claimed in-flight work:

```bash
# Open tasks ready to dispatch (MY_TASKS already filtered to current user)
TO_DISPATCH=$MY_TASKS

# In-flight: claimed on a previous run — bd ready only returns open tasks,
# so fetch in-progress from the full epic view.
# Filter by status only (not assignee — --claim may overwrite assignee field).
# Replace <child-field> with verified field (e.g. children)
IN_FLIGHT=$(bd show "$EPIC_ID" --json \
  | jq '[.<child-field>[]? | select(.status == "in_progress")]')

# For each task in IN_FLIGHT: skip dispatch — already claimed
# For each task in TO_DISPATCH: claim and dispatch as normal
```
```

- [ ] **Step 4: Verify no dispatch-path `bd ready` calls remain unfiltered**

```bash
grep -n "bd ready --json" skills/code/SKILL.md
```

Confirm the only remaining bare `bd ready --json` calls are in:
- `### Step 4: Monitor Progress`
- `## Completion Gate` description
- `## Implementation Notes`

Any in Step 2 or Step 3 should now use `READY_JSON` or `MY_TASKS`.

- [ ] **Step 5: Commit**

```bash
git add skills/code/SKILL.md
git commit -m "feat(code): filter bd ready by assignee and epic at dispatch sites"
```

---

### Task 5: Update Step 6 Completion Check (epic-scoped gate)

**Files:**
- Modify: `skills/code/SKILL.md`

The current `bd list --json` in Step 6 counts open tasks across ALL epics (the `$epic` arg is passed but never used in the jq filter — a pre-existing bug). Fix it to scope to the current epic while keeping it unfiltered by assignee (so the last team member to finish triggers CODE→TEST).

- [ ] **Step 1: Find the Step 6 completion check**

```bash
grep -n "OPEN_COUNT\|bd list --json\|### Step 6" skills/code/SKILL.md
```

- [ ] **Step 2: Replace the `OPEN_COUNT` command**

Find the existing block (it looks like):
```bash
OPEN_COUNT=$(bd list --json 2>/dev/null | \
  jq --arg epic "$EPIC_ID" '[.[] | select(.status != "closed")] | length')
```

Replace with (note: `$epic` is now actually used in the filter):
```bash
# Count all open tasks in THIS epic (not filtered by assignee — last person done triggers gate)
# Replace <epic-field> with verified field (e.g. epicId)
OPEN_COUNT=$(bd list --json 2>/dev/null | \
  jq --arg epic "$EPIC_ID" \
    '[.[] | select(.<epic-field> == $epic and .status != "closed")] | length')
```

- [ ] **Step 3: Verify the change looks correct in context**

```bash
grep -A5 "OPEN_COUNT" skills/code/SKILL.md
```

Confirm the epic filter is now active.

- [ ] **Step 3b (optional): Note the second `bd list` call**

Step 6 also has a second `bd list --json` call that queries discovered issues (unrelated to OPEN_COUNT). It is also unscoped, but fixing it is out of scope for this feature. Add a `# TODO: scope to $EPIC_ID` comment next to it so a future implementer knows.

- [ ] **Step 4: Commit**

```bash
git add skills/code/SKILL.md
git commit -m "fix(code): scope completion gate to current epic only"
```

---

### Task 6: Smoke test the full flow

No automated tests possible for skill markdown — verify by reading through the updated file end-to-end.

- [ ] **Step 1: Read Step 0 through Step 3 in sequence**

```bash
sed -n '/## Step 0/,/### Step 4/p' skills/code/SKILL.md
```

Verify:
- Step 0 appears and references `MY_NAME`
- Step 2 uses `READY_JSON` / `MY_TASKS`, not bare `bd ready --json`
- Step 3 references `TO_DISPATCH` and `IN_FLIGHT`

- [ ] **Step 2: Verify Step 4 and Step 6 are untouched / correctly updated**

```bash
grep -n "bd ready\|OPEN_COUNT\|MY_NAME\|MY_TASKS\|READY_JSON\|IN_FLIGHT\|TO_DISPATCH" skills/code/SKILL.md
```

Expected layout:
- `MY_NAME` — Step 0 and Step 2
- `READY_JSON`, `MY_TASKS` — Step 2 and Step 3
- `IN_FLIGHT`, `TO_DISPATCH` — Step 3 only
- `bd ready --json` (bare) — Step 4, Completion Gate, Implementation Notes only
- `OPEN_COUNT` — Step 6 only, with epic filter active

- [ ] **Step 3: Check `.gitignore` entry is still present**

```bash
grep "personal.json" .gitignore
```

Expected: `docs/c4flow/.personal.json`

- [ ] **Step 4: Final commit if anything needs cleanup**

```bash
git status
# If clean: nothing to do
# If dirty: git add + git commit -m "chore(code): cleanup personal identity implementation"
```
