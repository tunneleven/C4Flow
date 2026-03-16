# Feature Landscape: Quality Gate Systems

**Domain:** CI/CD quality gate chains for agent-driven development workflows
**Researched:** 2026-03-16
**Note:** This file covers features of quality gate systems in general. Technical
implementation specifics (hooks, beads CLI, Codex integration) are in QUALITY-GATE.md.

---

## Table Stakes

Features that any quality gate system must have. Missing = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Hard blocking on critical issues | Gates that can be bypassed are not gates — developers will bypass | Low | `bd close` refusal is already native to beads |
| Clear failure feedback | Developer must know exactly what failed, not just "gate failed" | Low | stderr message + structured output to Claude |
| Pass/fail result per check | Each check must give a binary result, not just prose output | Medium | Codex outputs prose; requires structured prompt or post-processing |
| Audit trail | Every gate resolution must record who resolved it and why | Low | `--reason` flag on `bd gate resolve` covers this |
| Bypass mechanism (explicit only) | Emergency overrides must be possible but costly and visible | Low | `bd close --force` is the escape hatch; hooks should log it |
| Graceful degradation when tools absent | Gate chain should not crash if Codex or CodeRabbit is unavailable | Low | Detect tool presence at skill start; warn + skip optional checks |
| Sequential dependency enforcement | Check B must not run if Check A fails | Low | Beads dependency graph + GitHub Actions `needs` chain |
| Status visibility | Developer can see which gates are open, which are resolved | Low | `bd gate list` covers this |

---

## Differentiators

Features that set this quality gate system apart. Not universally expected, but high value.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Gate resolution is auditable by bead type | `gh:run` gates auto-resolve from CI; `human` gates require explicit reason | Low | Native beads feature; must configure gate types correctly |
| Stop hook as backstop | Even if all else fails, Claude cannot declare "done" with open gates | Low | `Stop` event hook + `bd gate list` check |
| TaskCompleted hook enforcement | Fires when Claude marks any task complete, not just `bd close` | Medium | New event type (confirmed in latest docs); connects to beads task lifecycle |
| Two-layer architecture | Beads gates enforce against all callers; hooks enforce against agent specifically | Medium | Defense in depth; neither layer alone is sufficient |
| Weighted scoring for AI review | Instead of binary pass/fail on AI review, score by severity count (0 critical = pass, N high <= threshold = warning) | High | Requires structured Codex output + scoring logic |
| Per-path review instructions | Different review strictness for security code vs test code vs docs | Medium | `.coderabbit.yaml` `path_instructions` already supports this |
| PR-level gate separate from local gate | Local Codex review gates the task close; CodeRabbit PR review gates the merge | Low | Already the intended architecture; just needs correct gate types |
| Molecule formula encodes entire review workflow | Review steps are visible in `bd graph` as part of the workflow, not hidden in scripts | Medium | Beads formula gates; gives developer workflow visibility |

---

## Anti-Features

Features to explicitly NOT build.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Gate bypass without --force | Silent bypass is undetectable and erodes the entire system | Require explicit `--force` on `bd close`; have hooks log bypass events |
| AI review as the only gate | AI reviewers have false positives; a single AI vote blocks all work | Chain AI review with `bd preflight` (deterministic); require both to pass |
| Blocking on warnings | Warning-level issues blocking a gate causes fatigue and bypass pressure | Only block on CRITICAL and HIGH severity; surface warnings as informational |
| Fully synchronous CodeRabbit gate | PR review takes minutes to hours; blocking Claude's session for that duration breaks flow | Use async `gh:pr` gate type; let Claude move to other work while waiting |
| Global hooks with no per-project opt-out | Global hook that fires on every project causes friction for non-gated projects | Scope hooks to project-level `.claude/settings.json`, not global settings |
| Retrying the same failing check in a loop | Infinite retry on a flaky check hangs the pipeline | Set max_retries=2 with exponential backoff; escalate to human gate on exhaustion |
| Codex review gating on prose output | Parsing "critical" from free-form prose is fragile; any wording change breaks the gate | Use structured prompt for Codex output or use `codex exec` with explicit exit code |

---

## Feature Dependencies

```
bd preflight → (bd close blockable)       # preflight must run before close is attempted
codex review → gate resolution            # review output drives gate resolve/fail
gate resolution → bd close success        # all gates must resolve before close
PR creation → CodeRabbit trigger          # CodeRabbit only activates on PR webhook
CodeRabbit review → gh:run gate           # gate watches the CodeRabbit check status
gh:run gate resolve → merge allowed       # merge blocked until CodeRabbit approves
Stop hook → open gate check               # backstop: checks gates at session end
TaskCompleted hook → open gate check      # fires when task marked complete
```

---

## MVP Recommendation

Prioritize these in Phase 5:

1. **Beads gate on CODE task** (table stakes) — gate created when task enters REVIEW state; blocks `bd close`
2. **Codex review with structured output** (table stakes) — resolves the gate if passing, surfaces findings if failing
3. **bd preflight before PR** (table stakes) — deterministic checks catch what AI misses
4. **Stop hook with open gate check** (differentiator) — backstop prevents Claude declaring done prematurely
5. **TaskCompleted hook** (differentiator) — fires on task completion events, not just `bd close` calls

Defer:
- **CodeRabbit path instructions** — configure `.coderabbit.yaml` basics, leave tuning for later
- **Weighted severity scoring** — start with binary pass/fail on critical issues; add scoring in Phase 6
- **Molecule formula gates** — valuable for repeatable workflows; add after single-task gate chain is proven

---

## Production Quality Gate Checks — Reference

Based on what production teams actually check (GitHub required status checks, SonarQube patterns):

| Check Type | Category | Blocking? | Tool Pattern |
|------------|----------|-----------|-------------|
| Build success | Deterministic | Always | CI job, exit code |
| Unit tests passing | Deterministic | Always | CI job, exit code |
| No new critical security issues | Deterministic + AI | Always | Static analysis or AI review |
| Code coverage >= threshold (new code) | Deterministic | Optional | SonarQube "new code" gate |
| No critical/high severity AI review findings | AI | Blocking | Codex/CodeRabbit with severity parse |
| Lint / format compliance | Deterministic | Always | eslint/prettier exit code |
| No unresolved PR comments | Human | Blocking at merge | GitHub PR protection |
| AI review warnings | AI | Advisory only | Show but do not block |

Key insight from GitHub required status checks: production teams treat blocking gates as hard requirements with no soft option — the UI prevents merge entirely. There is no "merge anyway with warning" UI. Advisory checks appear as annotations but do not block.

---

## Sources

- Claude Code hooks documentation (code.claude.com/docs/en/hooks) — HIGH confidence, live docs
- GitHub protected branches documentation — HIGH confidence, live docs
- GitHub Actions job dependency docs — HIGH confidence, live docs
- Tekton pipeline docs — HIGH confidence, live docs
- QUALITY-GATE.md (beads, Codex, CodeRabbit specifics) — see that file for tool-level detail
