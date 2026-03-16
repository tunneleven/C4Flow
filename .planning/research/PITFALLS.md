# Domain Pitfalls: Quality Gate Systems

**Domain:** Quality gate chains for agent-driven development workflows
**Researched:** 2026-03-16
**Note:** This file focuses on failure patterns and prevention strategies.
Implementation mechanics are in QUALITY-GATE.md. Architectural patterns are in ARCHITECTURE.md.

---

## Critical Pitfalls

Mistakes that cause rewrites or break the entire quality gate system.

### Pitfall 1: Parsing Prose Output for Pass/Fail

**What goes wrong:** Codex review produces free-form prose. Code like `grep -ci "critical"` matches "not critical", "non-critical", "critically important (see above)" — all false positives. A wording change in the LLM output silently breaks the gate.

**Why it happens:** Integrators reach for the obvious `codex review | grep` pattern because it's simple. The brittleness only surfaces in production when the model changes its phrasing.

**Consequences:** Gate always passes (false negatives) or always fails (false positives). Either outcome destroys developer trust in the gate system.

**Prevention:**
- Use a structured prompt wrapper: `codex review --base main "...Output ONLY JSON: {\"pass\": bool, \"critical\": N, \"high\": N}"`
- Alternatively use `codex exec --full-auto "...exit 1 if critical issues found, else exit 0"` — relies on exit code, not output parsing
- Validate JSON output before acting on it; if parse fails, fail safe (gate remains open)

**Detection:** Add a test: run `codex review` on a known-bad diff and verify the gate blocks. Run periodically to detect model drift.

---

### Pitfall 2: Gate Bypass Normalization

**What goes wrong:** `bd close --force` exists for emergencies. Once one developer uses it to bypass a failing gate "just this once," it becomes the default when any gate inconveniently fails. The gate system becomes security theater.

**Why it happens:** `--force` is undocumented in daily workflow but visible in help text. Under deadline pressure, developers rationalize single bypasses. No audit trail = no accountability.

**Consequences:** Quality gates are bypassed on every PR that has any friction. The review/verify phase collapses into a formality.

**Prevention:**
- Log every `--force` usage: `PreToolUse` hook detects `bd close --force` and writes to `.claude/audit.log`
- Make bypass visible: hook sends the force-close context message to Claude, which surfaces it in the conversation
- Require a reason: `bd close --force --reason "hotfix: prod down"` — the hook blocks force-close without `--reason`
- Review audit log in `c4flow:merge` skill before merging

**Detection:** Check `.claude/audit.log` at merge time; if force-closes exist without reasons, block merge.

---

### Pitfall 3: Synchronous Blocking on Async External Services

**What goes wrong:** `c4flow:pr-review` polls for CodeRabbit review in a tight loop with `sleep 10`. CodeRabbit takes 3-8 minutes. The Claude session blocks for the entire duration, consuming context window and leaving the developer staring at a spinning terminal.

**Why it happens:** The simplest implementation of "wait for CodeRabbit" is a polling loop. It works but is wrong for the UX.

**Consequences:** Developer context switches away. Long-running Claude sessions exhaust context window. On timeout, the entire session fails with a cryptic error.

**Prevention:**
- Use async `gh:run` gate type: skill creates the gate and exits; developer returns later to run `pr-review` skill
- Cap poll duration: `pr-review` polls for max 10 minutes (configurable), then outputs instructions for manual check
- Make the wait state explicit: "CodeRabbit review gate created. Run `/c4flow:pr-review` when you want to check status."

**Detection:** Any `sleep` call > 30 seconds in a skill is a red flag. Skills should be short-running orchestrators, not long-running pollers.

---

### Pitfall 4: Single-Layer Enforcement (Hooks Only or Gates Only)

**What goes wrong:** Using only Claude Code hooks for gate enforcement means `bd close` called directly in a terminal bypasses all gates. Using only beads gates means Claude can declare task "done" via `Stop` without triggering a close — the state machine advances without enforcement.

**Why it happens:** Hooks feel complete because they intercept agent calls. Gates feel complete because they block `bd close`. Neither alone is sufficient.

**Consequences:** Gaps exist. A developer running `bd close` in a terminal bypasses hook enforcement. Claude ending its session without calling `bd close` bypasses gate enforcement.

**Prevention:** Implement both layers as described in ARCHITECTURE.md. Beads gates are primary (all callers). Hooks are safety net (agent-specific + session lifecycle). The `Stop` and `TaskCompleted` hooks are the bridge — they catch session completion without `bd close`.

**Detection:** Write a test: run `bd close <task_id>` directly in terminal with an open quality gate. Verify it fails without `--force`. Also have Claude attempt to stop with open gates and verify the Stop hook blocks it.

---

## Moderate Pitfalls

### Pitfall 5: Blocking on Advisory-Level Issues (Gate Fatigue)

**What goes wrong:** The quality gate blocks `bd close` when Codex finds any issue, including LOW and MEDIUM severity findings like "variable name could be more descriptive" or "consider adding a comment here." Developers face a gate that almost always has some finding. They learn to force-bypass.

**Why it happens:** "Zero issues = pass" feels rigorous. In practice, AI reviewers surface style issues in addition to real problems.

**Prevention:**
- Only gate on CRITICAL and HIGH severity findings
- MEDIUM and LOW findings are injected as context ("FYI: Codex found 3 medium issues — see .claude/tmp/review-output.txt") but do not block
- Configure `.coderabbit.yaml` `profile: "chill"` for informational-only by default; use `assertive` only for security-focused paths

**Detection:** Track how often developers use `--force` to bypass. High bypass rate = threshold is too strict.

---

### Pitfall 6: No Timeout on Codex Review

**What goes wrong:** `codex review --base main` launches an agentic LLM process. On a large diff, it can run for 5-10 minutes, exploring the codebase extensively. The hook or skill hangs with no feedback to the developer.

**Why it happens:** `codex review` has no native `--timeout` flag. The default behavior is unbounded.

**Prevention:**
- Wrap `codex review` in a timeout: `timeout 120 codex review --base main`
- On timeout, fail the gate with message: "Codex review timed out after 2 minutes. Review the diff manually or re-run on a smaller change."
- For large diffs, run Codex on only the changed files: `git diff --name-only main | head -20` then review file-by-file

**Detection:** Monitor review duration; if consistently > 3 minutes, the diff is too large or the prompt is too open-ended.

---

### Pitfall 7: Missing Tool Detection at Skill Start

**What goes wrong:** `c4flow:review` skill runs `codex review --base main` without checking if Codex is installed. On a machine without Codex, the skill silently fails or produces a confusing error: `command not found: codex`.

**Why it happens:** Skills are written for the happy path (machine with all tools installed).

**Prevention:** Each skill must begin with a tool availability check:
```bash
if ! command -v codex &>/dev/null; then
  echo "WARNING: codex CLI not found. Skipping AI review. Install from https://github.com/openai/codex"
  # Create a human gate instead of an automated gate
  bd gate create --type human --title "Manual code review required (codex not available)"
  exit 0
fi
```

Same pattern for `bd` (beads CLI): if not available, fall back to tasks.md manual verification.

---

### Pitfall 8: Flaky Checks Triggering Human Escalation Too Quickly

**What goes wrong:** A CodeRabbit webhook occasionally takes 15 minutes instead of 3. The `pr-review` skill polls for 10 minutes, hits the limit, and creates a human gate: "Manual review required: automated check exhausted." The developer resolves the human gate, but CodeRabbit finishes 2 minutes later. Now the merge gate waits for a human approval that is already implicitly granted.

**Why it happens:** Timeout and retry logic is hard to get right, especially for external SaaS with variable latency.

**Prevention:**
- Distinguish "timed out" from "failed": timeout creates a "please re-run pr-review" advisory, not a blocking human gate
- Human gate should only be created when the check definitively fails (non-zero exit or explicit "request changes" on PR), not on timeout
- On timeout, message: "CodeRabbit check still pending. Re-run `/c4flow:pr-review` in a few minutes."

---

## Minor Pitfalls

### Pitfall 9: Gate IDs Are Fragile String Lookups

**What goes wrong:** Gate resolution uses `jq 'select(.title | contains("quality-gate"))'` to find the gate by name. A title wording change, or two tasks with similar names, breaks the lookup.

**Prevention:** Store gate IDs at creation time: `GATE_ID=$(bd gate create ... | jq -r '.id')`. Pass the ID explicitly to the resolver rather than searching by name at resolution time.

### Pitfall 10: CodeRabbit Reviewing Its Own Config

**What goes wrong:** Adding or modifying `.coderabbit.yaml` triggers a CodeRabbit review of the config change itself. If CodeRabbit interprets its own config update as "suspicious", it may request changes on the PR that configures it.

**Prevention:** Add `.coderabbit.yaml` to CodeRabbit's ignore patterns, or use `ignore_title_keywords: ["chore: update coderabbit config"]` for those PRs.

### Pitfall 11: Global Hook Fires on Every Project

**What goes wrong:** Installing the quality gate hooks in `~/.claude/settings.json` (global) means they fire on every Claude project on the machine, including projects that don't use beads or have no quality gates. The `bd gate list` command fails with "not a beads project" errors.

**Prevention:** Install hooks in `.claude/settings.json` (project-scoped) or add a guard at the top of each hook: `[ -f "$(pwd)/.bd" ] || exit 0`.

### Pitfall 12: Stop Hook Causing Infinite Loop

**What goes wrong:** The `Stop` hook blocks Claude from finishing. Claude tries again. The Stop hook fires again. Claude cannot finish unless it resolves the gate, but it has no more context to do so.

**Prevention:** The Stop hook should never block without giving Claude actionable instructions. Always include the gate IDs and suggested remediation in the block message:
```json
{
  "decision": "block",
  "reason": "Quality gate open: [gate-id]. Run 'bd gate list' for details. Fix issues and re-run '/c4flow:review' or use 'bd gate resolve <id> --reason \"manual override\"' to unblock."
}
```

---

## Phase-Specific Warnings

| Phase / Topic | Likely Pitfall | Mitigation |
|---------------|---------------|------------|
| c4flow:review | Prose parsing brittleness (Pitfall 1) | Structured prompt; validate JSON before acting |
| c4flow:review | Codex timeout on large diffs (Pitfall 6) | `timeout 120` wrapper; limit to changed files |
| c4flow:verify | Missing bd preflight tool (Pitfall 7) | Check `bd` availability; fallback to manual |
| c4flow:pr | CodeRabbit not installed on repo (Pitfall 7) | Detect `.coderabbit.yaml` existence; skip gh:run gate if absent |
| c4flow:pr-review | Synchronous polling blocks session (Pitfall 3) | Async gate pattern; cap poll at 10min with exit message |
| c4flow:pr-review | Timeout misclassified as failure (Pitfall 8) | Distinguish timeout (retry advisory) from failure (human gate) |
| c4flow:merge | Force-close bypasses not audited (Pitfall 2) | Check audit log before merge; hook logs all --force usage |
| hooks install | Global hooks fire on non-beads projects (Pitfall 11) | Project-scope hooks; guard with beads detection |
| Stop hook | Infinite loop when no remediation path given (Pitfall 12) | Always include gate ID and remediation steps in block message |
| Gate resolution | Gate lookup by name fragility (Pitfall 9) | Store and pass gate ID at creation time |

---

## AI Code Review Specific Warnings

These pitfalls are specific to using AI (Codex, CodeRabbit) as quality gate gatekeepers:

1. **Model drift changes output format:** If the underlying model changes (e.g., gpt-5.4 → gpt-6), the structured JSON output may change. Pin the model version in `.codex/config.toml` and test on model upgrades.

2. **AI reviewers are not deterministic:** Running `codex review` twice on the same diff may produce different findings. Do not use "number of findings" as a gate threshold without acknowledging this variance. Binary "any CRITICAL?" is more stable than "fewer than 3 HIGH?"

3. **False positives from AI reviewers block real work:** AI reviewers sometimes flag correct code as problematic. Build an escape hatch: `bd gate resolve <id> --reason "false positive: [explanation]"` should always be available to developers. Log these for model/prompt improvement.

4. **Context window limits affect review quality:** On very large diffs, Codex truncates its context and misses issues. For large changes, run `codex review` per-file rather than on the full diff.

---

## Sources

- Claude Code hooks docs (code.claude.com/docs/en/hooks) — HIGH confidence, live docs
- Beads CLI `bd close --help`, `bd gate --help` output — HIGH confidence, local tool
- GitHub Actions workflow docs — HIGH confidence, live docs
- Tekton retry/timeout docs — HIGH confidence, live docs
- Production quality gate patterns inferred from multiple sources — MEDIUM confidence
