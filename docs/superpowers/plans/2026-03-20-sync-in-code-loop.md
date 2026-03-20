# Auto-sync on CODE_LOOP Entry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a pre-flight sync step to `c4flow:code` so that when a team member starts the CODE_LOOP, their local Dolt beads DB and git branch are automatically synced from remote before task discovery.

**Architecture:** Insert Step 0.5 into `skills/code/SKILL.md` between Step 0 (Read State) and Step 1 (PICKUP). Step 0.5 invokes `c4flow:sync` and asks the user whether to continue or stop if sync fails. Also update the Resume Logic table to document that CLOSING subState skips Step 0.5.

**Tech Stack:** Markdown (skill file), no code dependencies — `c4flow:sync` is called as-is.

---

### Task 1: Add Step 0.5 between Step 0 and Step 1

**Files:**
- Modify: `skills/code/SKILL.md:97-99` (the `---` separator before `## Step 1`)

The current file at line 97-99 looks like:
```
---

## Step 1: PICKUP — Find and Claim Task
```

We insert the new step between the `---` (end of Step 0) and `## Step 1`.

- [ ] **Step 1: Open the file and verify the insertion point**

  Confirm that line 97 is `---`, line 98 is blank, and line 99 is `## Step 1: PICKUP — Find and Claim Task`.

  Run:
  ```bash
  sed -n '95,101p' skills/code/SKILL.md
  ```
  Expected output:
  ```
  ```
  (blank line after the closing ```)
  ---

  ## Step 1: PICKUP — Find and Claim Task
  ```

- [ ] **Step 2: Insert Step 0.5**

  Replace the separator line between Step 0 and Step 1 with the new step content. Edit `skills/code/SKILL.md`: find the exact string:

  ```
  ---

  ## Step 1: PICKUP — Find and Claim Task
  ```

  Replace with:

  ```
  ---

  ## Step 0.5: Pre-flight Sync

  > **Skip this step** if resuming from `taskLoop.subState == "CLOSING"` — go directly to Step 7.

  Invoke `c4flow:sync`. This syncs both Dolt beads from DoltHub and git from GitHub origin.

  **On success:**
  → Proceed to Step 1: PICKUP

  **On failure (any sync error):**
  → Show the error output verbatim
  → Ask the user:
    ```
    Sync failed. How do you want to proceed?
    [continue] Use local data (may be stale — tasks you see may not reflect latest team activity)
    [stop]     Exit now to fix the sync issue
    ```
  → If user chooses **[continue]**: note the sync failure in the session, proceed to Step 1
  → If user chooses **[stop]**: exit the skill immediately, leave `.state.json` unchanged

  ---

  ## Step 1: PICKUP — Find and Claim Task
  ```

- [ ] **Step 3: Verify the edit looks correct**

  Run:
  ```bash
  grep -n "Step 0.5\|Pre-flight\|Step 1: PICKUP" skills/code/SKILL.md
  ```
  Expected: Step 0.5 appears before Step 1: PICKUP, both present.

- [ ] **Step 4: Commit**

  ```bash
  git add skills/code/SKILL.md
  git commit -m "feat(code): add Step 0.5 pre-flight sync before task pickup"
  ```

---

### Task 2: Update Resume Logic table

**Files:**
- Modify: `skills/code/SKILL.md` — Resume Logic section (around line 497-512)

The Resume Logic table currently has no mention of Step 0.5 or the CLOSING exception. Add a note to the table header and a row annotation.

- [ ] **Step 1: Find the Resume Logic section**

  Run:
  ```bash
  grep -n "Resume Logic\|CLOSING\|subState" skills/code/SKILL.md | head -20
  ```
  Confirm the table exists with `CLOSING` row.

- [ ] **Step 2: Add Step 0.5 note to the Resume Logic section**

  Find the text:
  ```
  On entry to CODE_LOOP skill, if `taskLoop.subState` is non-null:

  | subState | Resume action |
  |----------|--------------|
  | `CODING` | Ask user: "Re-run TDD from RED, or continue from where you left off?" |
  | `VERIFYING` | Re-run test suite + bd preflight (skip TDD) |
  | `REVIEWING` | Re-dispatch `c4flow:review` (skip TDD + verify) |
  | `CLOSING` | Re-run `bd close` + `bd dolt push` (skip everything else) |
  | `BLOCKED` | Show block reason, wait for user to resolve |
  ```

  Replace with:
  ```
  On entry to CODE_LOOP skill, if `taskLoop.subState` is non-null:

  > **Step 0.5 (Pre-flight Sync)** runs for all resume states **except `CLOSING`**.

  | subState | Run Step 0.5? | Resume action |
  |----------|--------------|---------------|
  | `CODING` | ✅ Yes | Ask user: "Re-run TDD from RED, or continue from where you left off?" |
  | `VERIFYING` | ✅ Yes | Re-run test suite + bd preflight (skip TDD) |
  | `REVIEWING` | ✅ Yes | Re-dispatch `c4flow:review` (skip TDD + verify) |
  | `CLOSING` | ❌ Skip | Re-run `bd close` + `bd dolt push` (skip everything else) |
  | `BLOCKED` | ✅ Yes | Show block reason, wait for user to resolve |
  ```

- [ ] **Step 3: Verify the table renders correctly**

  Run:
  ```bash
  grep -A 10 "Resume Logic" skills/code/SKILL.md
  ```
  Confirm the table now has 3 columns and the note about Step 0.5 appears above it.

- [ ] **Step 4: Commit**

  ```bash
  git add skills/code/SKILL.md
  git commit -m "docs(code): update Resume Logic table with Step 0.5 sync exception"
  ```

---

### Task 3: Smoke test — read the full modified skill

**Files:**
- Read: `skills/code/SKILL.md`

- [ ] **Step 1: Verify overall structure**

  Run:
  ```bash
  grep -n "^## Step" skills/code/SKILL.md
  ```
  Expected output (in order):
  ```
  ## Step 0: Read State and Resolve Actor
  ## Step 0.5: Pre-flight Sync
  ## Step 1: PICKUP — Find and Claim Task
  ## Step 2: BRANCH — Create Task Branch
  ## Step 3: TDD — Red Gate Sub-agent
  ## Step 4: VERIFY — Tests + Preflight
  ## Step 5: REVIEW — Per-task Code Review
  ## Step 6: PR + MERGE
  ## Step 7: CLOSE + SYNC
  ```

- [ ] **Step 2: Verify CLOSING skip instruction is present in Step 0.5**

  Run:
  ```bash
  grep -A 3 "Step 0.5" skills/code/SKILL.md | head -6
  ```
  Expected: Contains `"CLOSING"` and `"Skip"` or `"skip"`.

- [ ] **Step 3: No broken markdown — check for unclosed code blocks**

  Run:
  ```bash
  grep -c '```' skills/code/SKILL.md
  ```
  Expected: even number (all code blocks are closed).
