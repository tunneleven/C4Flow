# Architecture Patterns: Quality Gate Orchestration

**Domain:** Multi-check quality gate chains for agent-driven workflows
**Researched:** 2026-03-16
**Note:** This file covers orchestration patterns. Tool-specific mechanics
(hooks JSON format, beads gate syntax, Codex CLI flags) are in QUALITY-GATE.md.

---

## Recommended Architecture for C4Flow

### Two-Layer Gate with Skill Orchestration

```
┌─────────────────────────────────────────────────────────────┐
│  c4flow:review skill                                        │
│  ┌──────────────┐   ┌──────────────┐   ┌─────────────────┐ │
│  │ codex review │──▶│ parse output │──▶│ bd gate resolve │ │
│  │ --base main  │   │ (structured  │   │ or fail         │ │
│  └──────────────┘   │  prompt)     │   └─────────────────┘ │
│                     └──────────────┘                        │
└─────────────────────────────────────────────────────────────┘
         │ on pass
         ▼
┌─────────────────────────────────────────────────────────────┐
│  c4flow:verify skill                                        │
│  ┌──────────────┐   ┌──────────────┐                       │
│  │ bd preflight │──▶│ check JSON   │                       │
│  │ --check      │   │ result       │                       │
│  └──────────────┘   └──────────────┘                       │
└─────────────────────────────────────────────────────────────┘
         │ on pass
         ▼
┌─────────────────────────────────────────────────────────────┐
│  c4flow:pr skill                                            │
│  Creates PR ──▶ CodeRabbit auto-triggers via webhook        │
│  Creates gh:run gate watching CodeRabbit check status       │
└─────────────────────────────────────────────────────────────┘
         │ waiting (async)
         ▼
┌─────────────────────────────────────────────────────────────┐
│  c4flow:pr-review skill (polls)                             │
│  bd gate check --type=gh ──▶ auto-resolves on CR approval   │
│  Surfaces CR comments for human resolution                  │
└─────────────────────────────────────────────────────────────┘
         │ on all gates resolved
         ▼
┌─────────────────────────────────────────────────────────────┐
│  c4flow:merge skill                                         │
│  Merge PR ──▶ bd close task --reason "all gates resolved"   │
└─────────────────────────────────────────────────────────────┘

SAFETY NET (fires at any point):
  PreToolUse hook on Bash ──▶ intercept agent-initiated `bd close`
  Stop hook ──▶ block session end when quality gates are open
  TaskCompleted hook ──▶ block task completion events with open gates
```

---

## Component Boundaries

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| `c4flow:review` skill | Run Codex review, parse output, resolve/fail review gate | Codex CLI, beads gate |
| `c4flow:verify` skill | Run bd preflight, validate build/test/lint, resolve/fail verify gate | beads preflight, beads gate |
| `c4flow:pr` skill | Create PR, configure CodeRabbit, create gh:run gate | GitHub CLI, beads gate |
| `c4flow:pr-review` skill | Poll gh:run gate, surface CR comments, handle human responses | beads gate, GitHub CLI |
| `c4flow:merge` skill | Merge PR after all gates resolved, close task | GitHub CLI, beads close |
| `PreToolUse hook` | Intercept agent `bd close` when gates are open | beads gate list (read-only) |
| `Stop hook` | Prevent session end when quality gates are unresolved | beads gate list (read-only) |
| `TaskCompleted hook` | Intercept task completion events with open gates | beads gate list (read-only) |
| quality-gate-runner.sh | Orchestrate checks, parse results, call gate resolve | Codex, beads, preflight |

---

## Orchestration Patterns

### Pattern: Sequential All-Must-Pass Chain

The default production pattern. Used by GitHub Actions `needs:` and Tekton `runAfter:`.

```
check-1 ──▶ check-2 ──▶ check-3 ──▶ gate-resolved
```

If any check fails, the chain stops and downstream checks do not run. This is the correct default for quality gates — no point running CodeRabbit if the build is broken.

**C4Flow implementation:** Beads dependency graph between gate beads. The REVIEW gate must resolve before VERIFY gate is created. The VERIFY gate must resolve before PR gate is created.

**Key rule from GitHub Actions research:** "If a job fails or is skipped, all jobs that need it are skipped." Apply the same rule — do not attempt downstream gates if upstream fails.

### Pattern: Parallel Independent Checks + Join

Run independent checks in parallel, then join at a single gate.

```
check-A ─┐
check-B ─┼─▶ all-checks-passed gate ──▶ proceed
check-C ─┘
```

**When to use:** When checks are independent (lint, type-check, unit tests can all run simultaneously) and you want to surface all failures at once rather than serially.

**C4Flow relevance:** The `c4flow:verify` skill could run `bd preflight` checks in parallel (tests, lint, format) with a single aggregated result gate. More developer-friendly than sequential because all errors surface at once.

**Implementation note from GitHub Actions matrix research:** Use `fail-fast: false` for the parallel jobs if you want all results, not just the first failure. Map to Bash parallel execution with collected exit codes.

### Pattern: Tiered Checks (Fast First)

Order checks fastest-to-slowest so developers get early feedback.

```
fast-deterministic (lint, format) ──▶ medium (tests, build) ──▶ slow-AI (Codex review) ──▶ async (CodeRabbit)
```

**Rationale:** A lint failure should surface in seconds, not after waiting 3 minutes for Codex. Developer fixes fast issues first; slow AI review only runs when deterministic checks pass.

**C4Flow application:**
1. `bd preflight` (< 30s) — runs first in `c4flow:verify`
2. `codex review` (30s-3min) — runs in `c4flow:review` after preflight passes
3. `CodeRabbit` (async, minutes) — runs after PR is created; non-blocking for Claude

### Pattern: Hard Gate vs Advisory Annotation

Production systems (SonarQube, GitHub required checks) distinguish:

- **Hard gate:** Blocks the next action entirely. No merge, no close, no advance. Error is shown in UI.
- **Advisory annotation:** Check runs and results are visible, but do not block progress. Shows as a warning or comment.

**Implementation for C4Flow:**
- CRITICAL and HIGH severity Codex findings → hard gate (resolve required)
- MEDIUM and LOW severity findings → surfaced as Claude context message, not a gate
- CodeRabbit "approve" required for merge → hard gate via `gh:run` on CodeRabbit check
- CodeRabbit informational comments → advisory; Claude reads them but no gate created

### Pattern: Async Gate with Polling

For checks that take minutes (CodeRabbit, GitHub Actions), do not block the agent session.

```
skill creates gh:run gate ──▶ skill exits normally
[time passes]
pr-review skill calls bd gate check --type=gh ──▶ auto-resolves if check passed
```

**Tekton pattern:** `retries` field with `timeout` per task. Tekton retries failed tasks up to N times before marking the pipeline failed.

**C4Flow pattern:**
```bash
# In c4flow:pr-review skill
MAX_POLLS=10
POLL_INTERVAL=60  # seconds

for i in $(seq 1 $MAX_POLLS); do
  bd gate check --type=gh
  OPEN=$(bd gate list --json | jq '[.[] | select(.type == "gh:run")] | length')
  if [ "$OPEN" -eq 0 ]; then break; fi
  sleep $POLL_INTERVAL
done
```

Do not poll indefinitely. Set a max poll count and escalate to human gate on timeout.

### Pattern: Retry with Backoff for Flaky Checks

For checks that are sometimes flaky (network-dependent AI reviewers), retry before failing.

```
check runs ──▶ fails ──▶ retry 1 (after 5s) ──▶ fails ──▶ retry 2 (after 15s) ──▶ fails ──▶ ESCALATE TO HUMAN
```

**Tekton confirms:** Retries execute even when other tasks fail. Set retries at the task level, not the pipeline level.

**Key constraint:** Never retry more than 2-3 times on an AI reviewer. If it fails 3 times, the issue is real or the service is down — either way, human review is correct.

```bash
# Retry pattern for quality-gate-runner.sh
run_check_with_retry() {
  local cmd=$1
  local max_retries=2
  local attempt=0
  local backoff=5

  while [ $attempt -le $max_retries ]; do
    if $cmd; then return 0; fi
    attempt=$((attempt + 1))
    [ $attempt -le $max_retries ] && sleep $((backoff * attempt))
  done
  return 1
}
```

### Pattern: Escalate-to-Human on Gate Exhaustion

When automated checks fail repeatedly, do not spin indefinitely. Convert to a `human` gate.

```
automated-check fails > N times ──▶ create human gate with failure context ──▶ notify developer
```

**Beads implementation:**
```bash
# If automated gate cannot be resolved, escalate
bd gate resolve "$AUTO_GATE_ID" --reason "Escalating to human: check failed $MAX_RETRIES times"
HUMAN_GATE=$(bd gate create --type human \
  --title "Manual review required: automated check exhausted" \
  --description "$FAILURE_CONTEXT")
```

This converts the non-blocking automated failure into a blocking human gate that appears in `bd gate list`.

---

## Data Flow: Check Result to Gate Resolution

```
Codex review output (prose)
        │
        ▼
structured prompt wrapper: "Output JSON {pass: bool, critical: N, high: N, findings: [str]}"
        │
        ▼
parse JSON from codex output
        │
        ├── critical > 0 OR high > THRESHOLD ──▶ gate FAILS → report findings to Claude → fix required
        │
        └── critical == 0 AND high <= THRESHOLD ──▶ bd gate resolve $GATE_ID --reason "Codex: 0 critical, N high"
                                                            │
                                                            ▼
                                                    bd close succeeds (gates satisfied)
```

---

## Hook Architecture: Defense in Depth

Three hook events complement the beads gate enforcement:

| Hook Event | Trigger | Action |
|------------|---------|--------|
| `PreToolUse` on `Bash` | Agent calls `bd close` or `beads close` | Read gate list; deny if open gates exist |
| `TaskCompleted` | Agent marks any task complete | Read gate list; block if quality gates open |
| `Stop` | Agent session ends | Read gate list; block if quality gates open |

These are safety nets, not primary enforcement. Primary enforcement is beads gates (works for human terminal use too).

**New finding from current docs:** `TaskCompleted` hook fires when a task is being marked complete via the `TaskUpdate` tool. This is distinct from `bd close` — it fires for Claude's internal task tracking. Both need to be gated for complete coverage.

**Also from current docs:** `TeammateIdle` fires when an agent team teammate finishes. For multi-agent workflows (spawned subagents), `TeammateIdle` can enforce that a subagent doesn't go idle with unresolved quality gates.

---

## Scalability Considerations

| Concern | At 1 developer | At 5 developers | At 20+ developers |
|---------|---------------|-----------------|-------------------|
| Gate list noise | Trivial — only your gates | Moderate — need per-task gate scoping | High — use molecule-scoped gates with team filters |
| Codex review latency | 30s-3min; acceptable | Same; each dev runs independently | Same; parallel |
| CodeRabbit PR limits | Free tier: limited PRs/month | Same; budget check needed | Paid tier required |
| False positive rate | Single dev learns patterns quickly | Team alignment on severity threshold needed | Enforce via `.coderabbit.yaml` path_instructions |
| Hook execution overhead | Negligible | Negligible | Negligible (hooks are local shell scripts) |

---

## Sources

- Tekton pipeline docs (tekton.dev/docs/pipelines/pipelines/) — HIGH confidence, live docs
- GitHub Actions job dependency docs — HIGH confidence, live docs
- Claude Code hooks docs (code.claude.com/docs/en/hooks) — HIGH confidence, live docs
- GitHub branch protection docs — HIGH confidence, live docs
- QUALITY-GATE.md (beads, hooks mechanics, Codex integration) — see that file for tool specifics
