# Phase 1: Local Gate Infrastructure - Context

**Gathered:** 2026-03-16
**Status:** Ready for planning

<domain>
## Phase Boundary

The local quality gate chain runs end-to-end: `c4flow:review` invokes Codex via subagent, `c4flow:verify` aggregates all gate results, beads gates block `bd close` until checks pass, and `quality-gate-status.json` tracks per-check status with detailed findings. Tool availability is detected with graceful fallback. CodeRabbit and hooks are out of scope (Phase 2/3/v2).

</domain>

<decisions>
## Implementation Decisions

### Review skill behavior (c4flow:review)
- **Report and stop** — Codex reviews, reports findings, skill stops. No auto-fix loop. User fixes manually and re-runs `c4flow:review`
- **CRITICAL + HIGH block** gate resolution. MEDIUM/LOW are reported as informational but don't prevent gate pass
- **Subagent invocation** — Codex runs as a Claude Code subagent (`.claude/agents/code-reviewer.md`), not a direct CLI call or API call. Keeps review isolated from main context
- **Branch diff vs main** — Review scope is `git diff main` by default (all changes on current branch vs main)

### Gate status file (quality-gate-status.json)
- **Single file** at project root — one `quality-gate-status.json` containing results from all checks (Codex review, bd preflight)
- **Detailed findings** — per-finding detail: severity, file, line, message. Enables rich summaries in verify skill and explanatory hook messages
- **Time-based expiry** — results expire after a configurable duration (e.g., 1 hour). Re-running review required if time elapsed. Prevents stale passes after code changes
- **Git-ignored** — file is ephemeral, added to `.gitignore`. Regenerated each review run, not committed

### Gate lifecycle
- **Created at review invocation** — when `c4flow:review` is first invoked for a task, the skill checks if a quality gate bead exists, creates one if not, then runs the review
- **Single combined gate** per task — one gate covers all checks (Codex + preflight). Gate resolved when ALL checks pass
- **Auto-resolve on pass** — `c4flow:review` resolves the beads gate automatically when all checks pass. Failing reviews leave gate open for user to fix and re-run
- **Both formula + dynamic** — ship a molecule formula template (INFR-05) with explicit review/verify gate steps for repeatable workflows, plus dynamic gate creation at review time for ad-hoc tasks

### Claude's Discretion
- Exact `quality-gate-status.json` JSON schema field names and nesting
- Time-based expiry default duration
- Subagent prompt engineering for structured JSON output from Codex
- Molecule formula YAML structure (verify against beads source)
- Fallback behavior details when codex/bd is missing (GATE-04 — not discussed, standard graceful degradation)

</decisions>

<specifics>
## Specific Ideas

- User explicitly chose report-and-stop over auto-fix to avoid hallucination spirals — this is a firm decision, not a "maybe later" deferral
- Codex review produces prose, so the subagent must be prompted to return structured JSON. Research should investigate the most reliable prompt pattern for this
- The two-layer architecture (beads primary, hooks safety net) means Phase 1 focuses purely on the beads gate layer — hooks come in Phase 2

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `skills/review/SKILL.md`: Stub skill file — needs full implementation, but frontmatter structure exists
- `skills/verify/SKILL.md`: Stub skill file — needs full implementation
- `skills/beads/SKILL.md`: Implemented beads skill with `bd create`, `bd close`, formula patterns — reference for gate creation commands
- `.claude/settings.json`: Currently only has plugin config — hooks config will go here in Phase 2

### Established Patterns
- Skills are markdown files in `skills/<name>/SKILL.md` with YAML frontmatter (`name`, `description`)
- Beads CLI integration pattern: check `command -v bd`, branch on availability, use `--json` flag for structured output
- State tracking via `.state.json` in feature docs directory
- Subagent definitions go in `.claude/agents/` directory

### Integration Points
- `c4flow:review` skill connects to beads gate system via `bd gate resolve`
- `quality-gate-status.json` is read by `c4flow:verify` skill and (in Phase 2) by hooks
- Molecule formula template needs to work with existing `bd mol pour` command
- The c4flow orchestrator state machine transitions through REVIEW and VERIFY phases

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-local-gate-infrastructure*
*Context gathered: 2026-03-16*
