# Research Summary: C4Flow Quality Gate Chain

**Domain:** Quality gate chain for a Claude Code plugin (Phase 5: Review & QA and Phase 6: Release)
**Researched:** 2026-03-16
**Overall confidence:** MEDIUM-HIGH (tool mechanics HIGH; production pattern synthesis MEDIUM)

---

## Executive Summary

C4Flow Phase 5 and Phase 6 require implementing a hard quality gate chain that prevents any
task from closing without passing Codex review, bd preflight, and CodeRabbit PR review. The
research covers four areas: (1) the mechanics of Claude Code hooks, Codex CLI, beads gates,
and CodeRabbit (detailed in QUALITY-GATE.md); (2) the feature landscape of what quality gate
systems must do vs what differentiates them (FEATURES.md); (3) concrete orchestration patterns
from GitHub Actions, Tekton, and production CI/CD practice (ARCHITECTURE.md); and (4) the
failure modes that destroy quality gate systems in practice (PITFALLS.md).

The core finding is that two-layer enforcement is mandatory. Beads gates block `bd close` from
any caller (terminal or agent). Claude Code hooks (PreToolUse, Stop, TaskCompleted) catch
agent-specific lifecycle events that don't route through `bd close`. Neither layer alone is
sufficient. Production quality gate systems (GitHub required status checks, SonarQube) confirm
that hard blocking is the correct model — there is no "merge anyway with warning" UI in mature
systems.

The most critical implementation risk is Codex review output parsing. Codex produces prose, not
structured data. Regex-based parsing of "critical" from free-form LLM output is fragile and will
silently break when the model changes phrasing. The fix is a structured prompt wrapper that
demands JSON output, with a fallback to `codex exec --full-auto` with explicit exit code
instructions.

A newly confirmed capability in current Claude Code docs: `TaskCompleted` is a real hook event
that fires when a task is marked complete via the `TaskUpdate` tool, distinct from `bd close`.
`TeammateIdle` fires for agent team teammates. Both are relevant to the gate architecture and
were not fully covered in the initial QUALITY-GATE.md research.

---

## Key Findings

**Stack:** Beads gates (primary enforcement) + Claude Code hooks (agent safety net) + Codex CLI (AI review) + CodeRabbit (PR-level review via webhook)

**Architecture:** Sequential all-must-pass chain with async CodeRabbit gate; fast deterministic checks first (preflight), slow AI checks second (Codex), async PR review third (CodeRabbit)

**Critical pitfall:** Parsing Codex prose output with grep is fragile; use structured prompt wrapper that forces JSON output

---

## Complete Research Index

| File | Contents |
|------|----------|
| QUALITY-GATE.md | Claude Code hook mechanics, Codex CLI flags and integration approaches, beads gate types and formulas, CodeRabbit capabilities and config, 5 implementation patterns, recommended architecture |
| FEATURES.md | Table stakes vs differentiator features for quality gate systems, anti-features to avoid, MVP recommendation, production check reference |
| ARCHITECTURE.md | Two-layer gate diagram, component boundaries, 6 orchestration patterns (sequential, parallel, tiered, hard vs advisory, async, retry+escalate), data flow diagram, complete hook architecture |
| PITFALLS.md | 12 pitfalls with prevention strategies, AI code review specific warnings, phase-specific warning table |

---

## Implications for Roadmap

Based on research, suggested phase structure for Phase 5 (Review & QA) and Phase 6 (Release):

### Phase 5a: Local Quality Gates (c4flow:review + c4flow:verify)

- Addresses: Codex review with structured output, bd preflight integration, beads gate creation/resolution
- Avoids: Prose parsing brittleness (use structured prompt from day one)
- Implements: Two skills + quality-gate-runner.sh script + tool availability detection
- Rationale: Local gates are entirely within the developer's control — no external dependencies, no latency. Prove the gate mechanism works here before adding async external checks.

### Phase 5b: Safety Net Hooks (PreToolUse + Stop + TaskCompleted)

- Addresses: Agent-initiated bd close interception, session completion gating, task completion gating
- Avoids: Global hook installation (project-scope only to prevent non-beads project breakage)
- Implements: `.claude/hooks/quality-gate.sh`, `.claude/hooks/check-open-gates.sh`, hooks.json config
- Rationale: Hook layer is complementary to beads gates, not primary. Implement after gates prove out so hooks are tuning an existing system, not the only enforcement.

### Phase 5c: PR Creation and CodeRabbit Gate (c4flow:pr + c4flow:pr-review)

- Addresses: PR creation, CodeRabbit webhook triggering, gh:run gate creation, async polling with cap
- Avoids: Synchronous blocking on CodeRabbit (async gate + max-poll pattern)
- Implements: PR skill + pr-review skill + .coderabbit.yaml + CodeRabbit gh:run gate
- Rationale: CodeRabbit gate has external SaaS dependency and async latency — add last so it doesn't block proving the local gate chain.

### Phase 6: Release Gates (c4flow:merge)

- Addresses: Merge after all gates resolved, force-bypass audit, close task with audit trail
- Avoids: Gate bypass normalization (audit log check before merge)
- Implements: Merge skill + audit log verification + `bd close --reason`
- Rationale: Merge is the final gate — only possible after Phase 5 proves all preceding gates work.

**Phase ordering rationale:**
- Local before remote: Beads gates + Codex work without GitHub; prove mechanism locally first
- Deterministic before AI: bd preflight is deterministic and fast; AI review is variable; fast checks earn early failure signal
- Synchronous before async: Stop/PreToolUse hooks are synchronous; CodeRabbit is async; avoid async complexity until synchronous path is solid
- Hooks after gates: Gates are the primary mechanism; hooks are refinement

**Research flags for phases:**
- Phase 5a: Codex structured output prompt needs empirical tuning — model may need iteration before JSON output is reliable
- Phase 5b: `TaskCompleted` hook payload is confirmed in docs but untested against actual beads task closures — may need hands-on verification
- Phase 5c: CodeRabbit gh:run gate resolution requires CodeRabbit to post a GitHub check status — verify this actually happens with the account's plan/configuration
- Phase 6: Force-bypass audit via PreToolUse hook + log file pattern is new; test that the hook correctly detects `--force` flag in the command string

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Claude Code hooks mechanics | HIGH | Live docs confirmed; PreToolUse, Stop, TaskCompleted, TeammateIdle all documented with payloads |
| Beads gate system | HIGH | Local tool; bd gate --help, bd close --help outputs verified |
| Codex CLI integration | HIGH | Installed locally (v0.114.0); flags confirmed; exit code behavior empirically observed |
| CodeRabbit PR integration | MEDIUM | Marketing + llms.txt overview; CLI docs inaccessible; webhook pattern is the reliable path |
| Orchestration patterns (GHA, Tekton) | HIGH | Live official docs fetched; runAfter, needs, retries all confirmed |
| Gate UX (blocking vs advisory) | HIGH | GitHub required checks confirmed as hard blocks; SonarQube pattern well-established |
| Production quality gate features | MEDIUM | Inferred from GitHub/SonarQube patterns; not primary source for every claim |
| AI review false positive handling | MEDIUM | Industry pattern; no primary source; consistent across multiple sources |
| Force-bypass audit pattern | LOW | Proposed pattern; no prior art found in ecosystem; needs hands-on testing |
| CodeRabbit gh:run gate auto-resolution | LOW | Mechanism is correct in theory; whether CodeRabbit actually posts a check that bd can watch is unconfirmed |

---

## Gaps to Address

1. **CodeRabbit check status format** — Does CodeRabbit post a GitHub Actions check or a commit status? The type determines whether `gh:run` or `gh:pr` is the correct beads gate type. Needs hands-on testing with a configured CodeRabbit account.

2. **`TaskCompleted` hook with beads tasks** — The hook fires when Claude marks a task complete via `TaskUpdate`. Does this fire when `bd close` is called, or only for Claude's internal task tracking? The interaction between Claude's task model and beads tasks needs empirical testing.

3. **Codex structured JSON output reliability** — Prompt engineering to get consistent JSON from `codex review` needs testing. If the structured prompt approach is too fragile, `codex exec --full-auto` with explicit exit code instructions is the fallback.

4. **Beads formula gate exact YAML/JSON schema** — The formula gate syntax was inferred from `bd gate --help`. The exact schema for declaring gates in molecule formulas needs verification against beads source or docs.

5. **`bd gate check --type=gh` polling behavior** — Does `bd gate check` actually poll GitHub for check status, or does it require a GitHub webhook? The polling vs webhook distinction affects how the `c4flow:pr-review` skill should be implemented.
