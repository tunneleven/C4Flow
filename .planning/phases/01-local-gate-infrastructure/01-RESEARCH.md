# Phase 1: Local Gate Infrastructure - Research

**Researched:** 2026-03-16
**Domain:** Claude Code skills, beads gates, Codex CLI review, quality-gate-status.json, subagent definitions
**Confidence:** HIGH (all primary tools verified locally; beads formula YAML schema MEDIUM — inferred from help text)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Review skill behavior (c4flow:review)**
- Report and stop — Codex reviews, reports findings, skill stops. No auto-fix loop. User fixes manually and re-runs `c4flow:review`
- CRITICAL + HIGH block gate resolution. MEDIUM/LOW are reported as informational but don't prevent gate pass
- Subagent invocation — Codex runs as a Claude Code subagent (`.claude/agents/code-reviewer.md`), not a direct CLI call or API call. Keeps review isolated from main context
- Branch diff vs main — Review scope is `git diff main` by default (all changes on current branch vs main)

**Gate status file (quality-gate-status.json)**
- Single file at project root — one `quality-gate-status.json` containing results from all checks (Codex review, bd preflight)
- Detailed findings — per-finding detail: severity, file, line, message. Enables rich summaries in verify skill and explanatory hook messages
- Time-based expiry — results expire after a configurable duration (e.g., 1 hour). Re-running review required if time elapsed. Prevents stale passes after code changes
- Git-ignored — file is ephemeral, added to `.gitignore`. Regenerated each review run, not committed

**Gate lifecycle**
- Created at review invocation — when `c4flow:review` is first invoked for a task, the skill checks if a quality gate bead exists, creates one if not, then runs the review
- Single combined gate per task — one gate covers all checks (Codex + preflight). Gate resolved when ALL checks pass
- Auto-resolve on pass — `c4flow:review` resolves the beads gate automatically when all checks pass. Failing reviews leave gate open for user to fix and re-run
- Both formula + dynamic — ship a molecule formula template (INFR-05) with explicit review/verify gate steps for repeatable workflows, plus dynamic gate creation at review time for ad-hoc tasks

### Claude's Discretion
- Exact `quality-gate-status.json` JSON schema field names and nesting
- Time-based expiry default duration
- Subagent prompt engineering for structured JSON output from Codex
- Molecule formula YAML structure (verify against beads source)
- Fallback behavior details when codex/bd is missing (GATE-04 — standard graceful degradation)

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| GATE-01 | Subagent runs `codex review --base main` and writes structured pass/fail JSON to `quality-gate-status.json` | Codex CLI flags verified locally (v0.114.0); subagent invocation pattern documented in code-reviewer.md template |
| GATE-02 | Skill runs `bd preflight --check --json` and fails VERIFY phase if issues found | `bd preflight --check --json` confirmed locally; JSON output schema verified from help text |
| GATE-03 | Beads gates created programmatically (formula + dynamic) and resolved by quality runner | `bd gate resolve`, `bd create`, `bd close` all verified from local help output; gate blocking on unsatisfied gates confirmed |
| GATE-04 | Tool availability detection warns if codex or bd not installed; graceful fallback | `command -v` pattern established in existing beads skill; fallback to manual verification is well-understood pattern |
| SKIL-01 | `c4flow:review` skill — orchestrates Codex subagent review, parses output, writes gate status file, resolves beads gate on pass | Skill markdown pattern established from existing beads/c4flow skills; subagent dispatch established in c4flow orchestrator |
| SKIL-02 | `c4flow:verify` skill — runs bd preflight, aggregates all gate results, declares "Ready for PR: YES/NO" | JSON aggregation pattern straightforward; `bd preflight --check --json` verified |
| INFR-01 | `.claude/agents/code-reviewer.md` subagent definition that runs Codex review in isolated context, returns structured JSON | Global `code-reviewer.md` exists at `~/.claude/agents/` as reference; project-level file needed in `.claude/agents/` |
| INFR-04 | Gate resolution audit trail — reason string logged on every `bd gate resolve` and `bd close --reason` | `bd gate resolve --reason` flag confirmed; `bd close --reason` flag confirmed |
| INFR-05 | Beads molecule formula template with explicit review and verify gate steps | Formula search paths known (`.beads/formulas/`); `bd cook` and `bd mol pour` confirmed; exact YAML schema is MEDIUM confidence |
| INFR-06 | `quality-gate-status.json` schema definition — includes per-check pass/fail, timestamps, expiry, and findings summary | Schema design is Claude's discretion; constraints from CONTEXT.md define required fields |
</phase_requirements>

---

## Summary

Phase 1 builds the local quality gate chain end-to-end: `c4flow:review` invokes a Codex subagent, produces `quality-gate-status.json`, and resolves a beads gate on pass. `c4flow:verify` reads `bd preflight --check --json`, aggregates results with the Codex gate status, and declares "Ready for PR: YES/NO". `bd close` natively refuses to close when beads gates are unsatisfied. The entire phase operates without GitHub, network calls, or hooks — those are Phase 2.

The critical implementation risk is getting structured JSON output from Codex. Codex `review` produces free-form prose; the subagent must be prompted with an explicit JSON contract. The recommended approach is a project-scoped `.claude/agents/code-reviewer.md` that wraps Codex in a prompt demanding structured output, then returns the parsed result to the calling skill. The global `~/.claude/agents/code-reviewer.md` serves as a reference but must be overridden with C4Flow-specific behavior.

The beads gate formula YAML schema is the only MEDIUM-confidence area. `bd cook` and `bd mol pour` are confirmed, but the exact YAML structure for declaring gate steps must be validated by creating a minimal formula and running `bd cook --dry-run` before implementation.

**Primary recommendation:** Implement in this order: INFR-06 (schema) → INFR-01 (subagent) → SKIL-01 (review skill) → GATE-01 (Codex integration) → GATE-02 + SKIL-02 (verify skill) → INFR-04 (audit trail) → GATE-03 + INFR-05 (formula template). Schema first because everything else reads or writes it.

---

## Standard Stack

### Core

| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| `bd` (beads CLI) | Installed at `/usr/local/nodejs/bin/bd` | Gate creation, resolution, task lifecycle | Native gate enforcement — `bd close` blocks on unsatisfied gates without any custom code |
| `codex` (Codex CLI) | v0.114.0 at `/usr/local/nodejs/bin/codex` | AI code review via subagent dispatch | Already installed; `codex review --base main` is the confirmed review command |
| Claude Code subagents | `.claude/agents/` directory | Isolated context for Codex review | Prevents review context from polluting main agent; pattern established in codebase |
| `quality-gate-status.json` | Project root | Shared gate state between skills | Single file read by both review and verify skills; git-ignored per decision |

### Supporting

| Tool | Purpose | When to Use |
|------|---------|-------------|
| `git diff main` | Compute review scope | Called implicitly by `codex review --base main` |
| `jq` | Parse JSON output from beads and gate status | Required for scripting gate resolution |
| `timeout` (GNU coreutils) | Limit Codex review duration | Wrap every `codex review` call: `timeout 120 codex review --base main` |
| `.gitignore` | Exclude `quality-gate-status.json` | Must be added to project `.gitignore` |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Subagent for Codex review | Direct `codex review` CLI call from skill | Subagent isolates review context; direct CLI is simpler but pollutes main context |
| Single combined gate | Separate gates for review + preflight | Single gate reduces complexity; combined resolution logic in one place |
| File-based expiry check in skill | No expiry (always re-run) | Expiry prevents stale passes; no-expiry is simpler but allows code changes to slip through |

**Installation:**
```bash
# Both tools are already installed on this machine
# Verify:
command -v bd && bd --version
command -v codex && codex --version
```

---

## Architecture Patterns

### Recommended Project Structure

```
skills/
├── review/
│   └── SKILL.md          # c4flow:review implementation (replace stub)
└── verify/
    └── SKILL.md          # c4flow:verify implementation (replace stub)
.claude/
└── agents/
    └── code-reviewer.md  # Project-scoped Codex subagent (CREATE NEW)
.beads/
└── formulas/
    └── mol-c4flow-task.formula.yaml  # Formula template with gates (CREATE NEW)
quality-gate-status.json  # Ephemeral, git-ignored (generated at runtime)
.gitignore                # Add quality-gate-status.json entry
```

### Pattern 1: Subagent Dispatch for Codex Review

**What:** The `c4flow:review` skill dispatches a subagent (`.claude/agents/code-reviewer.md`) rather than calling `codex` directly. The subagent runs Codex, structures the output as JSON, and returns it to the calling skill.

**When to use:** Always for Codex review. Keeps review LLM context isolated from orchestration context.

**Subagent contract (what the subagent MUST return):**
```json
{
  "pass": true,
  "critical_count": 0,
  "high_count": 0,
  "medium_count": 2,
  "low_count": 1,
  "findings": [
    {
      "severity": "MEDIUM",
      "file": "src/gate.ts",
      "line": 42,
      "message": "Function exceeds 50 line limit"
    }
  ],
  "summary": "No blocking issues found. 2 medium, 1 low advisory findings."
}
```

**Subagent invocation from skill:**
```markdown
# In SKILL.md:
Dispatch the code-reviewer subagent with this prompt:
"Review the current branch diff against main. Return structured JSON only — no prose..."
```

**Reference:** Global `~/.claude/agents/code-reviewer.md` for structure; project file must override with C4Flow-specific JSON output contract.

### Pattern 2: Beads Gate Creation + ID Storage

**What:** When `c4flow:review` first runs for a task, it checks for an existing quality gate bead, creates one if absent, stores the gate ID, then resolves it on pass.

**Critical rule (from PITFALLS.md):** Store the gate ID at creation time. Never look up gates by title at resolution time — title matching is fragile.

**Gate creation (dynamic, ad-hoc):**
```bash
# Check if gate already exists for this task (by label)
EXISTING=$(bd gate list --json | jq -r '.[] | select(.labels[] | contains("c4flow-quality-gate")) | .id' | head -1)

if [ -z "$EXISTING" ]; then
  GATE_ID=$(bd create "Quality gate: c4flow review" \
    --type task \
    --labels "c4flow-quality-gate,gate" \
    --description "Automated gate: Codex review + bd preflight must pass" \
    --json | jq -r '.id')
else
  GATE_ID="$EXISTING"
fi

# Store in quality-gate-status.json for downstream use
```

**Gate resolution (after pass):**
```bash
bd gate resolve "$GATE_ID" --reason "Codex review: 0 critical, 0 high. bd preflight: all checks passed."
```

**Note:** The `bd gate resolve` command requires a valid gate bead ID (not a regular task ID). Gates in beads are created either via formula steps with a `gate` field, or as special gate-type issues. Verify the correct `--type` flag for dynamic gate creation.

### Pattern 3: quality-gate-status.json Schema and Expiry

**What:** A single JSON file at project root that accumulates results from all checks. Skills read and write this file. Expiry is enforced by checking `timestamp` against current time at file read.

**Recommended schema:**
```json
{
  "schema_version": "1",
  "generated_at": "2026-03-16T10:30:00Z",
  "expires_at": "2026-03-16T11:30:00Z",
  "gate_id": "bd-xxxx",
  "overall_pass": false,
  "checks": {
    "codex_review": {
      "pass": true,
      "ran_at": "2026-03-16T10:25:00Z",
      "critical_count": 0,
      "high_count": 0,
      "medium_count": 2,
      "low_count": 1,
      "findings": [
        {
          "severity": "MEDIUM",
          "file": "src/gate.ts",
          "line": 42,
          "message": "Function exceeds 50 line limit"
        }
      ]
    },
    "bd_preflight": {
      "pass": null,
      "ran_at": null,
      "issues": []
    }
  }
}
```

**Expiry check logic (in skill):**
```bash
# Check if status file is valid (not expired)
if [ -f quality-gate-status.json ]; then
  EXPIRES_AT=$(jq -r '.expires_at' quality-gate-status.json)
  NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  if [[ "$EXPIRES_AT" < "$NOW" ]]; then
    echo "Gate status expired. Re-running review."
    # proceed to re-run
  fi
fi
```

**Default expiry:** 60 minutes (configurable via `GATE_EXPIRY_MINUTES` env var or hardcoded constant in skill).

### Pattern 4: Molecule Formula Template

**What:** A `.formula.yaml` file in `.beads/formulas/` that encodes review + verify gate steps for repeatable c4flow workflows.

**Formula search path (verified):** `.beads/formulas/` (project), then `~/.beads/formulas/` (user).

**Usage:**
```bash
# Cook and pour a formula (cook is implicit in pour)
bd mol pour mol-c4flow-task --var task_name="implement auth"
```

**Formula structure (MEDIUM confidence — verify with `bd cook --dry-run` before implementation):**
```yaml
# .beads/formulas/mol-c4flow-task.formula.yaml
id: mol-c4flow-task
title: "C4Flow Task: {{task_name}}"
description: "Standard c4flow task with quality gates"
variables:
  task_name:
    description: "Name of the task being implemented"
    required: true

steps:
  - id: implement
    title: "Implement: {{task_name}}"
    type: task

  - id: review-gate
    title: "Quality gate: Codex review"
    type: gate
    gate:
      type: human
      description: "Run c4flow:review. This gate auto-resolves when all checks pass."
    depends_on: [implement]

  - id: verify-gate
    title: "Quality gate: bd preflight"
    type: gate
    gate:
      type: human
      description: "Run c4flow:verify. This gate auto-resolves when preflight passes."
    depends_on: [review-gate]
```

**IMPORTANT:** The `type: gate` and `gate:` fields in formula steps must be verified against the actual beads schema before implementation. Run `bd cook --dry-run .beads/formulas/mol-c4flow-task.formula.yaml` to validate.

### Pattern 5: Tool Availability Detection

**What:** Every skill that requires `bd` or `codex` must check tool availability at the top and fall back gracefully.

**Pattern (established in existing `c4flow:beads` skill):**
```bash
# Check for bd
if ! command -v bd &>/dev/null; then
  echo "WARNING: beads CLI (bd) not found."
  echo "Install from: https://github.com/steveyegge/beads"
  echo "Falling back to manual verification mode."
  # Create manual checklist output instead
  exit 0
fi

# Check for codex
if ! command -v codex &>/dev/null; then
  echo "WARNING: Codex CLI not found."
  echo "Install from: https://github.com/openai/codex"
  echo "Skipping AI review. Run manual code review before proceeding."
  # Create a human gate instead of automated gate
  bd create "Manual review required (codex not available)" \
    --labels "c4flow-quality-gate,gate,manual" \
    --description "Codex CLI not available. Complete manual review and resolve this gate."
  exit 0
fi
```

### Anti-Patterns to Avoid

- **Parsing prose from Codex with grep/regex:** `grep -ci "critical"` matches "not critical", "non-critical". Use structured prompt wrapper returning JSON instead.
- **Looking up gate by title at resolution time:** `bd gate list | jq 'select(.title | contains("quality-gate"))'` breaks on name collisions. Store gate ID at creation.
- **Running `codex review` without timeout:** Long diffs can run 5-10 minutes. Always wrap: `timeout 120 codex review --base main`.
- **Letting `overall_pass: true` when any check hasn't run:** Only set `overall_pass: true` when BOTH `codex_review.pass == true` AND `bd_preflight.pass == true`. Null/not-yet-run checks must not contribute to pass.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Blocking `bd close` when gates open | Custom pre-close check script | Beads native gate enforcement | `bd close` already refuses when gates exist; native behavior covers terminal + agent calls |
| Audit trail for gate resolutions | Custom log file | `bd gate resolve --reason` flag | Reason string is stored in beads audit trail natively; `bd close --reason` same |
| Task dependency enforcement | Custom dependency graph | `depends_on` in formula steps | Beads handles dependency resolution; `bd ready` shows what's unblocked |
| Gate ID persistence | Parse gate ID from `bd gate list` later | Store `GATE_ID=$(bd create ... --json \| jq -r '.id')` at creation | Single source of truth; avoids fragile name-based lookup |

**Key insight:** Beads is the enforcement layer, not a reporting layer. Don't recreate gate blocking in shell scripts when `bd close` native behavior already does it.

---

## Common Pitfalls

### Pitfall 1: Codex Prose Output Breaking Gate Logic

**What goes wrong:** Structured prompt wrapper returns prose instead of JSON, or returns JSON with different field names than expected. Gate always passes (null check evaluates false) or crashes.

**Why it happens:** LLM output is non-deterministic. Even with explicit JSON instruction, models occasionally add prose context before/after the JSON object.

**How to avoid:**
- Extract JSON from subagent output with a regex: `echo "$OUTPUT" | grep -o '{.*}' | jq .`
- Validate required fields before trusting: `jq 'has("pass") and has("critical_count")'`
- If parse fails, fail safe: gate remains open, report error to user

**Warning signs:** Gate auto-resolving on a run where Codex reported issues. Add a validation log entry every time `quality-gate-status.json` is written.

---

### Pitfall 2: quality-gate-status.json Partial Writes

**What goes wrong:** Skill writes Codex results to `quality-gate-status.json` then crashes before writing preflight results. Next invocation of `c4flow:verify` reads `bd_preflight.pass: null` and either crashes or incorrectly evaluates as passing.

**Why it happens:** Multi-step write with no atomic update guarantee.

**How to avoid:**
- Write to a temp file first, then `mv` to final path (atomic rename on same filesystem)
- `c4flow:verify` must treat `null` in any check as "not yet run" — which is NOT a pass
- Start each skill run by reading existing file and merging, not overwriting whole file

---

### Pitfall 3: Gate ID Lost Between Skill Invocations

**What goes wrong:** `c4flow:review` creates a gate bead and stores `GATE_ID` in a shell variable. When the skill finishes and the user re-invokes `c4flow:review` later, the variable is gone. The skill creates a duplicate gate bead.

**Why it happens:** Shell variables don't persist across invocations.

**How to avoid:** Store `gate_id` in `quality-gate-status.json`. At skill start, read the file for an existing gate ID before creating a new one. Label-based lookup as fallback (`bd gate list --json | jq 'select(.labels[] | contains("c4flow-quality-gate"))'`).

---

### Pitfall 4: Formula Gate Schema Mismatch

**What goes wrong:** The formula YAML uses `type: gate` and `gate:` fields that don't match the actual beads schema. `bd cook` fails with a cryptic parse error or silently ignores the gate declaration.

**Why it happens:** Formula schema was inferred from help text, not from official documentation or working examples.

**How to avoid:** Before implementing the formula, run `bd cook --dry-run <formula-file>` on a minimal test formula. Verify that a gate bead is created in the dry-run output. Adjust schema until dry-run confirms gate creation.

---

### Pitfall 5: .gitignore Not Set Before First Review Run

**What goes wrong:** Developer runs `c4flow:review`, `quality-gate-status.json` is written, developer commits changes, file appears in the commit diff. The file contains review timestamps and possibly file paths.

**Why it happens:** `.gitignore` entry was meant to be added as part of implementation but was deferred.

**How to avoid:** Creating `quality-gate-status.json` entry in `.gitignore` must be the FIRST task in implementation, before any skill creates the file.

---

### Pitfall 6: Subagent Returns Before Codex Finishes

**What goes wrong:** The code-reviewer subagent dispatches `codex review --base main` as a background process, captures only partial output, and returns. The quality gate status reflects an incomplete review.

**Why it happens:** Subagent implementations may not wait for long-running commands.

**How to avoid:** In the subagent definition, ensure Codex is called synchronously (not backgrounded). Include `timeout 120` to prevent indefinite blocking. The subagent should not return until it has the complete Codex output.

---

## Code Examples

### Gate Creation and ID Capture

```bash
# Source: bd create --help (verified locally)
# Create a quality gate bead
GATE_ID=$(bd create "Quality gate: c4flow review+verify" \
  --labels "c4flow-quality-gate" \
  --description "Automated gate: resolves when Codex review AND bd preflight pass" \
  --json | jq -r '.id')

echo "Gate created: $GATE_ID"
```

### Gate Resolution with Audit Trail

```bash
# Source: bd gate resolve --help (verified locally)
# -r/--reason flag is the audit trail mechanism
bd gate resolve "$GATE_ID" \
  --reason "Codex review: 0 critical, 0 high. bd preflight: all checks passed. quality-gate-status.json written 2026-03-16T10:30:00Z"
```

### bd close with Reason (Audit Trail)

```bash
# Source: bd close --help (verified locally)
# --reason flag stores audit context on the close event
bd close "$TASK_ID" --reason "All quality gates resolved. PR ready."
```

### bd preflight JSON Output Handling

```bash
# Source: bd preflight --help (verified locally)
PREFLIGHT=$(bd preflight --check --json 2>&1)
PREFLIGHT_PASS=$(echo "$PREFLIGHT" | jq '.pass // false')

if [ "$PREFLIGHT_PASS" != "true" ]; then
  echo "bd preflight failed:"
  echo "$PREFLIGHT" | jq '.issues[]'
  # Write to quality-gate-status.json bd_preflight section
fi
```

### bd close Blocked by Open Gates (Expected Behavior)

```bash
# Source: bd close --help — "-f, --force: Force close pinned issues or unsatisfied gates"
# Without --force, bd close refuses when gates are unsatisfied.
# This is the NATIVE enforcement — no custom code needed.
bd close "$TASK_ID"
# OUTPUT if gates open: "Error: issue has unsatisfied gates. Use --force to bypass."
```

### Tool Availability Detection Pattern

```bash
# Source: established pattern from skills/beads/SKILL.md
check_tool() {
  local tool=$1
  local install_url=$2
  if ! command -v "$tool" &>/dev/null; then
    echo "WARNING: $tool not found. Install from: $install_url"
    return 1
  fi
  return 0
}

check_tool "bd" "https://github.com/steveyegge/beads" || BEADS_AVAILABLE=false
check_tool "codex" "https://github.com/openai/codex" || CODEX_AVAILABLE=false
```

### Subagent Definition Skeleton

```markdown
# Source: ~/.claude/agents/code-reviewer.md (project override at .claude/agents/code-reviewer.md)
---
name: code-reviewer
description: C4Flow code review subagent — runs Codex review and returns structured JSON
tools: ["Bash", "Read"]
model: sonnet
---

You are a code review subagent for C4Flow. Your ONLY output must be a JSON object.

Run: `timeout 120 codex review --base main`

Parse the output and return:
```json
{
  "pass": <true if zero CRITICAL and zero HIGH findings>,
  "critical_count": <number>,
  "high_count": <number>,
  "medium_count": <number>,
  "low_count": <number>,
  "findings": [
    {"severity": "CRITICAL|HIGH|MEDIUM|LOW", "file": "...", "line": <n>, "message": "..."}
  ],
  "summary": "<one sentence>"
}
```

Do NOT output prose. Return the JSON object only.
```

---

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| Parse Codex prose with grep | Structured prompt wrapper returning JSON | Eliminates false positives/negatives from text matching |
| Single enforcement layer (hooks only) | Beads gates (primary) + hooks (safety net) | Terminal `bd close` also blocked, not just agent-initiated |
| Global hook installation | Project-scoped `.claude/settings.json` | Prevents hooks from firing on non-beads projects |
| Gate lookup by title at resolution | Store gate ID at creation | Eliminates fragile string matching |

**Confirmed in existing research (PITFALLS.md, SUMMARY.md):** These patterns are already documented. Phase 1 implements them.

---

## Open Questions

1. **Beads formula YAML gate field exact schema**
   - What we know: `bd formula`, `bd cook`, `bd mol pour` are confirmed commands. Formula files go in `.beads/formulas/`. `bd cook --dry-run` validates formulas.
   - What's unclear: The exact YAML keys for declaring a gate within a formula step (`type: gate`? `gate_type:`? `gate: { type: human }`?).
   - Recommendation: Wave 0 task — create a minimal test formula, run `bd cook --dry-run`, verify gate step creation before implementing INFR-05.

2. **bd gate vs bd create for dynamic gate creation**
   - What we know: `bd create` accepts `--type task` and `--labels`. `bd gate list` shows gate issues. `bd gate resolve` closes gate issues.
   - What's unclear: Whether dynamic gates (not from formula steps) are created with `bd create --type gate` or with specific gate creation command. `bd gate add-waiter` exists — suggests gates may be a sub-type.
   - Recommendation: Run `bd create "test gate" --type gate --json` on a test beads DB to confirm gate creation syntax before implementing GATE-03.

3. **quality-gate-status.json expiry default duration**
   - What we know: User decided time-based expiry is required. No specific duration decided.
   - What's unclear: Whether 60 minutes is the right default for the development loop (too short? too long?).
   - Recommendation: Default to 60 minutes. Make it configurable via environment variable `C4FLOW_GATE_EXPIRY_MINUTES`. Document in SKILL.md.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Shell script integration tests (no test framework — bash scripts testing bash skills) |
| Config file | None required |
| Quick run command | `bash .claude/tests/test-gate-status.sh` |
| Full suite command | `bash .claude/tests/run-all.sh` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| GATE-01 | Codex review writes valid JSON to quality-gate-status.json | Integration | `bash .claude/tests/test-review-output.sh` | Wave 0 |
| GATE-02 | bd preflight result aggregated into gate status | Integration | `bash .claude/tests/test-preflight-integration.sh` | Wave 0 |
| GATE-03 | bd close blocked when gate is open | Integration | `bash .claude/tests/test-gate-blocking.sh` | Wave 0 |
| GATE-04 | Tool-missing warning shown, fallback path taken | Unit | `bash .claude/tests/test-tool-detection.sh` | Wave 0 |
| INFR-04 | Reason string written on gate resolve | Integration | `bash .claude/tests/test-audit-trail.sh` | Wave 0 |
| INFR-06 | quality-gate-status.json matches schema | Unit | `bash .claude/tests/test-schema-validation.sh` | Wave 0 |

**Note:** Tests requiring a live beads DB can use `bd init` in a temp directory within the test script. Tests that call `codex review` should be marked as slow/manual-only (requires LLM).

### Sampling Rate

- **Per task commit:** `bash .claude/tests/test-schema-validation.sh && bash .claude/tests/test-tool-detection.sh`
- **Per wave merge:** All tests in `.claude/tests/run-all.sh` except codex-live tests
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `.claude/tests/` directory — does not exist yet
- [ ] `.claude/tests/test-gate-status.sh` — covers GATE-01 (JSON schema validation)
- [ ] `.claude/tests/test-preflight-integration.sh` — covers GATE-02
- [ ] `.claude/tests/test-gate-blocking.sh` — covers GATE-03 (needs temp beads DB)
- [ ] `.claude/tests/test-tool-detection.sh` — covers GATE-04 (mock command-v)
- [ ] `.claude/tests/test-audit-trail.sh` — covers INFR-04
- [ ] `.claude/tests/test-schema-validation.sh` — covers INFR-06
- [ ] `.claude/tests/run-all.sh` — test suite entry point
- [ ] Framework install: None required (bash scripts only)

---

## Sources

### Primary (HIGH confidence)

- `bd gate --help`, `bd gate resolve --help`, `bd gate list --help`, `bd gate check --help` — gate mechanics, flags, blocking behavior (verified locally)
- `bd close --help` — confirms `-f/--force` flag bypasses unsatisfied gates; `--reason` flag for audit trail
- `bd create --help` — issue creation flags, labels, JSON output
- `bd preflight --help` — confirms `--check --json` flags and what checks are run
- `bd mol pour --help`, `bd formula --help`, `bd cook --help` — formula lifecycle, search paths, cook modes
- `codex review --help` — confirms `--base`, `--uncommitted`, `--commit` flags; no native JSON output
- `~/.claude/agents/code-reviewer.md` — global agent definition structure (reference for project override)
- `skills/beads/SKILL.md` — established skill pattern, `command -v bd` availability check
- `.planning/research/QUALITY-GATE.md` — Codex integration approaches, beads gate patterns (researched 2026-03-16)
- `.planning/research/ARCHITECTURE.md` — two-layer gate architecture, data flow (researched 2026-03-16)
- `.planning/research/PITFALLS.md` — 12 failure patterns with prevention strategies (researched 2026-03-16)

### Secondary (MEDIUM confidence)

- `.planning/research/QUALITY-GATE.md` — beads formula gate YAML structure (inferred from help text, not official schema docs)
- Codex exit code behavior: always exits 0 unless command error (empirically observed, not documented)

### Tertiary (LOW confidence)

- Exact `bd create --type gate` syntax for dynamic (non-formula) gate creation — not confirmed from help text

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — both tools installed and verified locally
- Architecture: HIGH — beads gate mechanics confirmed; subagent pattern established
- Pitfalls: HIGH — sourced from existing phase research with primary tool verification
- Formula YAML schema: MEDIUM — inferred from help text; needs dry-run validation

**Research date:** 2026-03-16
**Valid until:** 2026-04-16 (stable tools; Codex is "research preview" — verify on model changes)
