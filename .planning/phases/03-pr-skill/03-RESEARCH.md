# Phase 3: PR Skill - Research

**Researched:** 2026-03-16
**Domain:** GitHub CLI (gh), Claude Code skill authoring, .state.json mutation, quality-gate-status.json reading
**Confidence:** HIGH (gh CLI verified locally v2.87.3; state.json schema verified from existing skill files; quality-gate-status.json schema verified from implemented schema file)

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| SKIL-03 | `c4flow:pr` skill — creates GitHub PR with quality gate status summary in description, updates `.state.json` with PR number; warns (does not block) when gates have not all passed | `gh pr create` flags verified locally; PR number extraction from URL output confirmed; `.state.json` `prNumber` field already defined in schema; quality-gate-status.json schema fully implemented |
</phase_requirements>

---

## Summary

Phase 3 implements `c4flow:pr` — a Claude Code skill that creates a GitHub PR via the `gh` CLI, embeds a quality gate status summary in the PR body, and writes the PR number to `.state.json`. Phase 1 and 2 are already complete: `quality-gate-status.json` is written by `c4flow:review`/`c4flow:verify`, and the `.state.json` schema already has a `prNumber: null` field waiting to be populated.

The skill has one deliberate design constraint from REQUIREMENTS.md: gates not passing triggers a **warning**, not a hard block. PR creation is informational — the hard gate is `bd close`. This means the skill must check `overall_pass` from `quality-gate-status.json`, surface a warning if false, ask the user to confirm, and proceed either way.

The only technical complexity is (1) extracting the PR number from `gh pr create` output and (2) writing it atomically to `docs/c4flow/.state.json`. Both are straightforward with `grep -o '[0-9]*$'` on the URL output and a `jq` merge + atomic write. The PR body is a markdown heredoc constructed from `quality-gate-status.json` fields.

**Primary recommendation:** Implement as a single-plan skill following the existing `c4flow:verify` pattern: tool detection → gate status read → optional warning with confirmation → PR creation → state write → summary output.

---

## Standard Stack

### Core

| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| `gh` CLI | v2.87.3 | Create GitHub PR with `--title`, `--body`, `--base` flags | Already installed and authenticated; the established project standard for GitHub operations |
| `jq` | system | Read `quality-gate-status.json`; merge PR number into `.state.json` | Used throughout all Phase 1/2 scripts; confirmed available |
| `quality-gate-status.json` | runtime | Source of gate pass/fail data for PR body and warn/proceed logic | Schema fully implemented; already consumed by hooks and verify skill |
| `docs/c4flow/.state.json` | runtime | Persistence target for `prNumber` after PR creation | Schema already includes `prNumber: null`; pattern established by `c4flow:beads` skill |

### Supporting

| Tool | Purpose | When to Use |
|------|---------|-------------|
| `git` | Detect current branch name for `--head` flag; check upstream push status | Before creating PR — must confirm branch is pushed |
| `git push -u origin <branch>` | Push branch to remote before PR creation | When branch has no remote tracking |
| `grep -o '[0-9]*$'` | Extract PR number from `gh pr create` URL output | After PR creation — parse `https://github.com/owner/repo/pull/123` |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `gh pr create --body "..."` with heredoc | `gh pr create --body-file -` reading from stdin | Heredoc is simpler in skill markdown steps; body-file stdin works but adds complexity |
| Parse PR number from `gh pr create` URL output | `gh pr view --json number` after creation | URL parse is one step; `gh pr view` is a second round-trip but more robust |
| Warn and confirm before proceeding when gates fail | Hard block | REQUIREMENTS.md explicitly specifies: "warns the user before proceeding (but does not block)" |

**Installation:**
```bash
# gh is already installed and authenticated:
gh --version          # 2.87.3
gh auth status        # logged in as tunneleven
```

---

## Architecture Patterns

### Recommended Project Structure

```
skills/
└── pr/
    └── SKILL.md      # c4flow:pr implementation (REPLACE stub)
docs/c4flow/
└── .state.json       # prNumber written here after PR creation (schema already has this field)
quality-gate-status.json  # read-only in this skill (written by review/verify)
```

### Pattern 1: Gate Status Warning (Not Block) Before PR

**What:** Read `quality-gate-status.json`. If `overall_pass` is false or the file is missing, print a warning and ask the user to confirm before proceeding. Do NOT exit.

**When to use:** Always — this is the SKIL-03 requirement for "warns but does not block."

**Example:**
```bash
# Read gate status
if [ -f quality-gate-status.json ]; then
  OVERALL_PASS=$(jq -r '.overall_pass' quality-gate-status.json)
else
  OVERALL_PASS="missing"
fi

if [ "$OVERALL_PASS" != "true" ]; then
  echo "WARNING: Quality gates have not all passed."
  echo "  overall_pass: $OVERALL_PASS"
  echo "  Run /c4flow:verify to see current gate status."
  echo ""
  echo "Creating a PR before gates pass is allowed but not recommended."
  # In skill markdown: Ask user: "Proceed anyway? (yes/no)"
  # If no: exit. If yes: continue.
fi
```

### Pattern 2: Construct PR Body from Gate Status

**What:** Build the PR body as markdown by reading fields from `quality-gate-status.json`. Include a summary table showing each check's pass/fail status, counts, and run timestamp.

**When to use:** Always — the PR body MUST include gate status summary per SKIL-03.

**Example (PR body template):**
```markdown
## Quality Gate Status

| Check | Status | Details | Ran At |
|-------|--------|---------|--------|
| Codex Review | ✅ PASS | 0 critical, 0 high, 2 medium, 1 low | 2026-03-16T10:28:00Z |
| bd Preflight | ✅ PASS | 0 issues | 2026-03-16T10:30:00Z |

**Overall: ✅ Ready for PR**

Gate ID: bd-xxxx
Status file generated: 2026-03-16T10:30:00Z (expires: 2026-03-16T11:30:00Z)
```

**When gates have not passed:**
```markdown
## Quality Gate Status

| Check | Status | Details | Ran At |
|-------|--------|---------|--------|
| Codex Review | ⚠️ NOT RUN | — | — |
| bd Preflight | ❌ FAIL | 3 issues | 2026-03-16T10:30:00Z |

**Overall: ⚠️ PR created before all gates passed**
```

**Shell construction:**
```bash
# Source: jq pattern for constructing PR body fields
CODEX_PASS=$(jq -r 'if .checks.codex_review.pass == true then "✅ PASS" elif .checks.codex_review.pass == false then "❌ FAIL" else "⚠️ NOT RUN" end' quality-gate-status.json 2>/dev/null || echo "⚠️ NO STATUS FILE")
CODEX_DETAIL=$(jq -r '"\(.checks.codex_review.critical_count // 0) critical, \(.checks.codex_review.high_count // 0) high, \(.checks.codex_review.medium_count // 0) medium, \(.checks.codex_review.low_count // 0) low"' quality-gate-status.json 2>/dev/null || echo "—")
CODEX_RAN=$(jq -r '.checks.codex_review.ran_at // "—"' quality-gate-status.json 2>/dev/null || echo "—")

BD_PASS=$(jq -r 'if .checks.bd_preflight.pass == true then "✅ PASS" elif .checks.bd_preflight.pass == false then "❌ FAIL" else "⚠️ NOT RUN" end' quality-gate-status.json 2>/dev/null || echo "⚠️ NO STATUS FILE")
BD_ISSUES=$(jq -r '(.checks.bd_preflight.issues | length | tostring) + " issues"' quality-gate-status.json 2>/dev/null || echo "—")
BD_RAN=$(jq -r '.checks.bd_preflight.ran_at // "—"' quality-gate-status.json 2>/dev/null || echo "—")

OVERALL_STATUS=$(jq -r 'if .overall_pass then "✅ Ready for PR" else "⚠️ PR created before all gates passed" end' quality-gate-status.json 2>/dev/null || echo "⚠️ No gate status file")
GATE_ID=$(jq -r '.gate_id // "none"' quality-gate-status.json 2>/dev/null || echo "none")
GENERATED_AT=$(jq -r '.generated_at // "unknown"' quality-gate-status.json 2>/dev/null || echo "unknown")
EXPIRES_AT=$(jq -r '.expires_at // "unknown"' quality-gate-status.json 2>/dev/null || echo "unknown")
```

### Pattern 3: Create PR and Capture Number

**What:** Run `gh pr create`, capture the output URL, extract the PR number, and store it.

**Key behavior:** `gh pr create` prints the PR URL to stdout on success (e.g., `https://github.com/owner/repo/pull/42`). Extract the trailing number with `grep -o '[0-9]*$'`.

**Pre-condition:** The branch must be pushed to the remote before `gh pr create` will work. The skill must detect and handle an unpushed branch.

**Example:**
```bash
# Check if branch is pushed to remote
BRANCH=$(git rev-parse --abbrev-ref HEAD)
REMOTE_EXISTS=$(git ls-remote --heads origin "$BRANCH" 2>/dev/null | wc -l)

if [ "$REMOTE_EXISTS" -eq 0 ]; then
  echo "Branch '$BRANCH' has no remote. Pushing now..."
  git push -u origin "$BRANCH"
fi

# Create PR — output URL to stdout
PR_URL=$(gh pr create \
  --title "$PR_TITLE" \
  --body "$PR_BODY" \
  --base main)

# Extract number from URL: https://github.com/.../pull/123
PR_NUMBER=$(echo "$PR_URL" | grep -o '[0-9]*$')
echo "PR created: $PR_URL (number: $PR_NUMBER)"
```

### Pattern 4: Write PR Number to .state.json (Atomic)

**What:** Merge `prNumber` into the existing `docs/c4flow/.state.json` using `jq` with atomic write (tmp + mv).

**Critical:** Must be a merge, NOT an overwrite. The `.state.json` contains other fields (`currentState`, `completedStates`, etc.) that must be preserved.

**Example:**
```bash
STATE_FILE="docs/c4flow/.state.json"

# Atomic merge write — preserves all existing fields
jq --argjson pr_num "$PR_NUMBER" \
  '.prNumber = $pr_num | .currentState = "PR_REVIEW_LOOP" | (.completedStates) += ["PR"]' \
  "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"

echo "Wrote prNumber=$PR_NUMBER to $STATE_FILE"
```

**Note:** The skill should also advance `currentState` from `PR` to `PR_REVIEW_LOOP` per the workflow state machine in `references/workflow-state.md`.

### Pattern 5: Tool Availability Detection

**What:** Check for `gh` before any GitHub operations. Graceful fallback if not authenticated.

**Example (consistent with existing c4flow skills):**
```bash
# Check for gh CLI
if ! command -v gh &>/dev/null; then
  echo "WARNING: GitHub CLI (gh) not found."
  echo "Install from: https://cli.github.com"
  echo ""
  echo "MANUAL PR CHECKLIST (gh fallback):"
  echo "[ ] Push branch: git push -u origin <branch>"
  echo "[ ] Open: https://github.com/<owner>/<repo>/compare"
  echo "[ ] Include quality gate summary from quality-gate-status.json in PR body"
  echo "[ ] Update docs/c4flow/.state.json prNumber manually after creation"
  exit 0
fi

# Check gh is authenticated
if ! gh auth status &>/dev/null; then
  echo "WARNING: gh CLI is not authenticated."
  echo "Run: gh auth login"
  exit 1
fi
```

### Anti-Patterns to Avoid

- **Overwriting .state.json instead of merging:** Using `echo '{"prNumber": 42}' > .state.json` destroys all other fields. Use `jq ... | mv` merge pattern only.
- **Parsing PR number from prose:** `gh pr create` output is a URL. Use `grep -o '[0-9]*$'` on the URL — do not attempt to parse variable prose output or error messages.
- **Blocking on gate failure:** REQUIREMENTS.md explicitly prohibits hard-blocking. Warn and ask to confirm — never `exit 1` on gate failure alone.
- **Calling `gh pr create` without first pushing:** Will fail with "must first push the current branch to a remote." Always check/push branch before calling.
- **Writing the PR body with unescaped special characters:** Heredoc in shell can break on backticks, `$` in markdown, or multiline jq output. Use `--body-file` with a temp file as an escape hatch if heredoc becomes complex.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| GitHub PR creation | Custom `curl` to GitHub API | `gh pr create` | Auth, repo detection, base branch detection all handled; API approach requires token management |
| State persistence | Custom JSON writer | `jq` merge + `mv` atomic write | Prevents partial writes; already the established pattern in this project |
| PR number extraction | Parse `gh` prose output | `grep -o '[0-9]*$'` on URL | URL format is stable; prose format varies and could include "PR" text |
| Branch push check | Custom git remote inspection | `git ls-remote --heads origin <branch>` | Single command; already established git pattern |

**Key insight:** The `gh` CLI handles all GitHub authentication, repo detection, and API interaction. Using the raw GitHub REST API would require token management and repo slug construction — all solved by `gh`.

---

## Common Pitfalls

### Pitfall 1: .state.json Overwrite Destroys Workflow State

**What goes wrong:** Skill writes `{"prNumber": 42}` to `docs/c4flow/.state.json` directly, wiping `currentState`, `completedStates`, `feature`, and all other fields. Orchestrator (c4flow skill) sees IDLE state on next invocation and starts a new workflow.

**Why it happens:** Simple file write without reading existing content first.

**How to avoid:** Always use `jq` merge pattern: `jq '.prNumber = N' existing.json > tmp && mv tmp existing.json`. The Phase 1 pattern (atomic write via `.tmp` + `mv`) was established for `quality-gate-status.json` — apply the same here.

**Warning signs:** After `c4flow:pr` runs, `docs/c4flow/.state.json` has only one or two fields instead of the full schema fields.

---

### Pitfall 2: PR Created Twice (Idempotency)

**What goes wrong:** User runs `c4flow:pr` twice. Second run creates a duplicate PR. `.state.json` gets the second PR number, the first PR is orphaned.

**Why it happens:** No check for existing PR on current branch before calling `gh pr create`.

**How to avoid:** Check if a PR already exists for the current branch before creating:
```bash
EXISTING_PR=$(gh pr view --json number --jq '.number' 2>/dev/null)
if [ -n "$EXISTING_PR" ]; then
  echo "PR #$EXISTING_PR already exists for this branch."
  echo "URL: $(gh pr view --json url --jq '.url')"
  # Update .state.json with existing PR number if not already set
  exit 0
fi
```

**Warning signs:** Two open PRs with the same branch name in the repository.

---

### Pitfall 3: PR Body Breaks on Special Characters

**What goes wrong:** Quality gate findings contain backticks, `$VARIABLE`, or multiline text that gets evaluated or truncated when passed as a shell argument to `--body`.

**Why it happens:** Shell interpolation in double-quoted strings processes special characters.

**How to avoid:** Write the PR body to a temp file and use `--body-file`:
```bash
BODY_FILE=$(mktemp /tmp/c4flow-pr-body.XXXXX.md)
cat > "$BODY_FILE" << 'BODY_EOF'
[body content with no shell interpolation]
BODY_EOF
# Then use variables in the file with separate heredoc or printf
gh pr create --title "$PR_TITLE" --body-file "$BODY_FILE"
rm -f "$BODY_FILE"
```

**Warning signs:** PR body is truncated, contains literal `$CODEX_PASS` text, or `gh pr create` fails with a parse error.

---

### Pitfall 4: Branch Not Pushed Before PR Creation

**What goes wrong:** `gh pr create` fails with "you must first push the current branch to a remote." The skill exits with an error; PR number is never written.

**Why it happens:** Developer has local commits that haven't been pushed.

**How to avoid:** Check for remote tracking branch before calling `gh pr create`. If missing, push with `-u`:
```bash
BRANCH=$(git rev-parse --abbrev-ref HEAD)
if ! git ls-remote --heads origin "$BRANCH" 2>/dev/null | grep -q "$BRANCH"; then
  git push -u origin "$BRANCH"
fi
```

**Warning signs:** `gh pr create` error message mentions "push" or "remote."

---

### Pitfall 5: quality-gate-status.json Missing at PR Creation Time

**What goes wrong:** User runs `c4flow:pr` on a fresh clone or after deleting the ephemeral file. `jq` calls fail with "file not found," and the PR body contains `null`/empty gate status.

**Why it happens:** `quality-gate-status.json` is git-ignored and ephemeral — it won't exist in a new checkout.

**How to avoid:** Handle missing file as a distinct case (not the same as "file exists but gates failed"):
```bash
if [ ! -f quality-gate-status.json ]; then
  echo "WARNING: No quality-gate-status.json found."
  echo "  Run /c4flow:review and /c4flow:verify first for a complete gate status."
  echo "  Proceeding with PR creation — gate summary will show 'No status available'."
  # Use fallback body without gate table
fi
```

**Warning signs:** PR body shows empty table rows or `null` values in the gate summary.

---

## Code Examples

Verified patterns from official sources and established project conventions:

### Check for Existing PR on Branch

```bash
# Source: gh pr view --help (verified locally)
EXISTING_PR_NUMBER=$(gh pr view --json number --jq '.number' 2>/dev/null)
if [ -n "$EXISTING_PR_NUMBER" ] && [ "$EXISTING_PR_NUMBER" != "null" ]; then
  echo "PR #$EXISTING_PR_NUMBER already exists for this branch."
  EXISTING_PR_URL=$(gh pr view --json url --jq '.url' 2>/dev/null)
  echo "URL: $EXISTING_PR_URL"
fi
```

### Create PR and Capture Number

```bash
# Source: gh pr create --help (verified locally v2.87.3)
# --body-file "-" reads from stdin; --body "string" for inline
PR_URL=$(gh pr create \
  --title "$PR_TITLE" \
  --body-file "$BODY_FILE" \
  --base main)

# Extract PR number from URL: https://github.com/owner/repo/pull/42
PR_NUMBER=$(echo "$PR_URL" | grep -o '[0-9]*$')
```

### Atomic Merge Write to .state.json

```bash
# Source: established project pattern (see skills/beads/SKILL.md for beadsEpic write)
STATE_FILE="docs/c4flow/.state.json"

if [ -f "$STATE_FILE" ]; then
  jq --argjson num "$PR_NUMBER" \
    '.prNumber = $num | .currentState = "PR_REVIEW_LOOP" | .completedStates += ["PR"] | .failedAttempts = 0 | .lastError = null' \
    "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
else
  # State file missing — warn and create minimal update only
  echo '{}' | jq --argjson num "$PR_NUMBER" '.prNumber = $num' > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
  echo "WARNING: docs/c4flow/.state.json was missing. Created with prNumber only."
fi
```

### Skill Step Structure (from existing c4flow skills)

```markdown
# /c4flow:pr — Create Pull Request

## Instructions

### Step 1: Tool Availability Detection
  [Check gh, gh auth status — exit gracefully if missing]

### Step 2: Read Gate Status and Warn if Not Passed
  [Read quality-gate-status.json, check overall_pass, warn if false/missing, ask confirm]

### Step 3: Build PR Body
  [Construct markdown table from gate status fields; handle missing file case]

### Step 4: Check for Existing PR
  [gh pr view --json number; if exists, update state.json and exit]

### Step 5: Push Branch if Not Pushed
  [git ls-remote check; git push -u origin if missing]

### Step 6: Create PR
  [gh pr create --title ... --body-file ...; capture URL; extract PR_NUMBER]

### Step 7: Write PR Number to .state.json
  [jq merge pattern; atomic write; advance currentState to PR_REVIEW_LOOP]

### Step 8: Summary Output
  [Print PR URL, number, gate status, next step hint]
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual PR creation with copy-pasted gate summary | `c4flow:pr` skill automates body construction from JSON | Phase 3 | Consistent gate status format in every PR |
| Hard-blocking PR creation when gates fail | Warn-and-confirm (soft gate) | Phase 3 design | Allows informational PRs for WIP; hard enforcement remains at `bd close` |
| prNumber tracked manually | Written to `.state.json` by skill | Phase 3 | Enables future `c4flow:merge` to reference PR without user input |

**Already established by prior phases:**
- `quality-gate-status.json` schema is implemented and stable (Phase 1)
- `.state.json` `prNumber` field is in the schema but null (defined in `references/workflow-state.md`)
- `c4flow:verify` established the pattern of reading `quality-gate-status.json` and printing a gate summary — PR body follows the same data

---

## Open Questions

1. **PR title source**
   - What we know: `gh pr create --title` is required (no `--fill` default). The skill needs a title.
   - What's unclear: Should the skill derive the title from `feature.name` in `.state.json`, ask the user interactively, or use the current branch name?
   - Recommendation: Read `.state.json` `feature.name` as the default title (e.g., "feat: {feature.name}"). Offer to customize. If `.state.json` is missing, ask the user.

2. **State advancement: should the skill advance currentState?**
   - What we know: The state machine in `references/workflow-state.md` shows `PR → PR_REVIEW_LOOP` after PR creation. The `prNumber` field is in `completedStates` advance pattern.
   - What's unclear: Whether advancing state is in scope for this skill or belongs to the c4flow orchestrator only.
   - Recommendation: The skill writes `prNumber` (confirmed in SKIL-03). Advancing `currentState` to `PR_REVIEW_LOOP` is a logical atomic operation with the same write — do it in the same `jq` merge. The orchestrator will read the updated state on next invocation.

3. **PR base branch**
   - What we know: `gh pr create --base` defaults to the repository's default branch if omitted. That's typically `main`.
   - What's unclear: Whether to hard-code `--base main` or detect it via `gh repo view --json defaultBranchRef`.
   - Recommendation: Default to `--base main` (matches project convention). Document as configurable.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Shell script integration tests (bash, no test framework — consistent with Phase 1/2 test patterns) |
| Config file | None required |
| Quick run command | `bash .claude/tests/test-pr-skill.sh` |
| Full suite command | `bash .claude/tests/run-all-tests.sh` (extends existing `.claude/tests/run-hooks-tests.sh` pattern) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SKIL-03 | Skill file exists and has non-stub content | Unit | `bash .claude/tests/test-pr-skill-file.sh` | Wave 0 |
| SKIL-03 | PR body construction includes gate summary from quality-gate-status.json | Unit | `bash .claude/tests/test-pr-body-construction.sh` | Wave 0 |
| SKIL-03 | Warn (not block) when overall_pass is false | Unit | `bash .claude/tests/test-pr-gate-warn.sh` | Wave 0 |
| SKIL-03 | PR number extracted from URL correctly | Unit | `bash .claude/tests/test-pr-number-extraction.sh` | Wave 0 |
| SKIL-03 | .state.json prNumber written correctly after PR creation | Unit | `bash .claude/tests/test-state-json-write.sh` | Wave 0 |
| SKIL-03 | gh not installed → graceful warning, no crash | Unit | `bash .claude/tests/test-pr-no-gh.sh` | Wave 0 |

**Note:** Tests requiring a live `gh pr create` call are marked manual-only (requires GitHub remote and auth). All automated tests use mock inputs and do not call the live GitHub API.

### Sampling Rate

- **Per task commit:** `bash .claude/tests/test-pr-body-construction.sh && bash .claude/tests/test-pr-number-extraction.sh`
- **Per wave merge:** `bash .claude/tests/test-pr-skill-file.sh && bash .claude/tests/test-pr-gate-warn.sh && bash .claude/tests/test-state-json-write.sh && bash .claude/tests/test-pr-no-gh.sh`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `.claude/tests/test-pr-skill-file.sh` — covers SKIL-03 file existence check
- [ ] `.claude/tests/test-pr-body-construction.sh` — covers PR body markdown from mock `quality-gate-status.json`
- [ ] `.claude/tests/test-pr-gate-warn.sh` — covers warn-not-block behavior (mock overall_pass=false)
- [ ] `.claude/tests/test-pr-number-extraction.sh` — covers URL → number parse (`echo "...pull/42" | grep -o '[0-9]*$'`)
- [ ] `.claude/tests/test-state-json-write.sh` — covers `.state.json` atomic merge write with `jq`
- [ ] `.claude/tests/test-pr-no-gh.sh` — covers graceful degradation when `gh` is not installed

*(No framework install needed — bash scripts only, consistent with Phase 1/2 test infrastructure)*

---

## Sources

### Primary (HIGH confidence)

- `gh pr create --help` (verified locally v2.87.3) — all flags, URL output format, dry-run behavior
- `gh pr view --help` (verified locally) — `--json number` field for idempotency check
- `gh auth status` (verified locally) — authentication state check pattern
- `/home/tunn/Documents/Research/C4Flow/quality-gate-status.schema.json` — complete field schema for PR body construction
- `/home/tunn/Documents/Research/C4Flow/references/workflow-state.md` — `.state.json` schema with `prNumber` field definition and state machine transitions
- `/home/tunn/Documents/Research/C4Flow/skills/verify/SKILL.md` — established pattern for skill structure, gate status reading, jq field extraction
- `/home/tunn/Documents/Research/C4Flow/skills/c4flow/SKILL.md` — `.state.json` read/write patterns, `prNumber` field usage
- `/home/tunn/Documents/Research/C4Flow/skills/beads/SKILL.md` — established `beadsEpic` write-to-state pattern (direct model for `prNumber` write)

### Secondary (MEDIUM confidence)

- `gh` CLI documentation: URL output format for `gh pr create` is stable and documented in `EXAMPLES` section of help output

### Tertiary (LOW confidence)

- None — all findings verified against local tool output or existing implemented files

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — gh CLI installed and authenticated; jq available; all patterns verified
- Architecture: HIGH — established patterns from Phase 1/2 directly applicable; .state.json schema already defines prNumber
- Pitfalls: HIGH — sourced from verified tool behavior (gh output format, jq merge semantics) and project-established patterns
- Test approach: HIGH — consistent with Phase 2 bash test infrastructure already in place

**Research date:** 2026-03-16
**Valid until:** 2026-04-16 (gh CLI is stable; jq is stable; schema is locked in Phase 1)
