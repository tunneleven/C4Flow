# Quality Gate Chain Research

**Project:** C4Flow — REVIEW and VERIFY phase implementation
**Researched:** 2026-03-16
**Question:** How can we chain multiple quality checks (Codex review, CodeRabbit) before a task/issue can be marked complete?

---

## 1. Claude Code Hooks System

### Mechanics

Hooks are shell commands, HTTP endpoints, or LLM prompts that fire at lifecycle events inside Claude Code. They receive JSON context via stdin and can influence Claude's behavior through their stdout/exit code.

**Configuration location** (in order of scope):
- `~/.claude/settings.json` — user-global (applies to all projects)
- `.claude/settings.json` — project-shared (checked into git)
- `.claude/settings.local.json` — project-local (not checked in)
- Plugin `hooks/hooks.json` — while plugin is active

**Configuration format** (confirmed from live docs):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash|Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/my-hook.sh",
            "timeout": 30,
            "async": false
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          { "type": "command", "command": ".claude/hooks/post-write.sh" }
        ]
      }
    ]
  }
}
```

### Gating / Blocking

**PreToolUse** hooks CAN block tool execution. Two mechanisms:

1. **Exit code 2** — stderr text is fed back to Claude as a blocking error. For PreToolUse events this prevents the tool call entirely.

2. **Exit 0 with JSON** — return structured output:
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Quality checks have not passed."
  }
}
```

**PostToolUse** hooks CANNOT undo an already-executed tool, but they CAN return `{"decision": "block", "reason": "..."}` to interrupt Claude's forward progress and feed it a message.

**Stop event** — a hook on the `Stop` event (no matcher required) can prevent Claude from finishing a session:
```json
{ "decision": "block", "reason": "Quality gate not satisfied." }
```
This fires when Claude tries to stop, making it a potential "you must not declare done" gate.

### Hook Types

| Type | Description | Best For |
|------|-------------|----------|
| `command` | Shell script, stdin/stdout JSON | Running CLI tools like codex review |
| `http` | POST to local server | Long-running checks with async results |
| `prompt` | Single LLM call returning `{ok: bool}` | Lightweight heuristic checks |
| `agent` | Full subagent with tool access | Complex verification requiring file reading |

### Events Without Matchers (Always Fire)

`Stop`, `TaskCompleted`, `UserPromptSubmit` — no matcher field, hooks run on every occurrence.

`TaskCompleted` is particularly interesting: it fires when a task finishes. A hook here can inspect what was done and block or inject context.

### Can a Hook Prevent Beads Close?

Not directly — hooks intercept Claude Code tool calls, not `bd close` invocations made by the user in a terminal. However:

- If the AGENT calls `Bash` to run `bd close`, a `PreToolUse` hook on `Bash` can inspect the command and deny it if quality gates are not met.
- If Claude tries to declare completion via its `Stop` event, a `Stop` hook can block it.
- The `UserPromptSubmit` event fires before each prompt — a hook here could inject a warning if beads are being closed prematurely.

**Bottom line:** Hooks can gate agent-initiated `bd close` calls but not direct terminal usage. The right place to enforce quality gates is in the workflow logic of the skill itself, with hooks as an additional safety net.

---

## 2. Codex CLI — Code Review

### What It Is

OpenAI Codex CLI (`codex`) is installed at `/usr/local/nodejs/bin/codex` on this machine (version 0.114.0). It is a full agentic code assistant with a dedicated non-interactive `review` subcommand.

### CLI Commands

```bash
codex review [OPTIONS] [PROMPT]
```

**Flags:**
- `--base <BRANCH>` — review changes against a branch (mutually exclusive with `--uncommitted`)
- `--uncommitted` — review staged, unstaged, and untracked changes
- `--commit <SHA>` — review the changes introduced by a specific commit
- `--title <TITLE>` — optional commit title for review summary

**Examples:**
```bash
# Review diff from current branch vs main
codex review --base main

# Review the last commit
codex review --base HEAD~1

# Review uncommitted work with custom instructions
codex review --uncommitted "Focus on security issues only"

# Pipe review instructions from stdin
echo "Check for race conditions" | codex review --uncommitted -
```

### How It Works Internally (Observed)

From live execution against this repo, Codex review:
1. Reads the diff via `git diff <base>`
2. Explores repository context (README, config files) via shell commands
3. Invokes the LLM (model: `gpt-5.4` via local proxy on this machine at `http://127.0.0.1:9158/v1`)
4. Produces a human-readable review summary to stdout

**Output format:** Prose text. No native JSON output flag or structured severity levels in the output itself. The output is whatever the LLM decides to write.

**Exit codes:** Not documented. From testing, it appears to always exit 0 unless there is an error running the command itself. It does NOT return a non-zero exit code based on finding issues — it is an LLM agent, not a linter.

### Integration Approach

Since `codex review` produces prose output with no machine-parseable severity, integration requires one of:

**Option A — Use a structured prompt:**
```bash
codex review --base main "Review this diff. Output ONLY a JSON object with fields:
  {\"pass\": boolean, \"critical_issues\": number, \"findings\": [string]}"
```
Prompt engineering to get JSON output. Fragile but functional for simple gates.

**Option B — Post-process with an LLM:**
Run `codex review --base main > review.txt`, then pipe the prose through a second LLM call that classifies severity. The `prompt` hook type in Claude Code can do this inline.

**Option C — Use a `codex exec` task instead:**
```bash
codex exec --full-auto "Review the git diff vs main. If you find any CRITICAL issues (security vulnerabilities, data corruption risks, broken APIs), exit 1. Otherwise exit 0."
```
`codex exec` runs an agentic task non-interactively. You can instruct it to exit with a specific code based on findings. This gives programmatic pass/fail.

**Option D — Direct API call:**
Since Codex CLI uses a compatible API endpoint, you can call the chat completions API directly with the diff and a structured output schema. More reliable than CLI for integration.

### Configuration

`~/.codex/config.toml`:
```toml
base_url = "http://127.0.0.1:9158/v1"
model = "gpt-5.4"
model_reasoning_effort = "medium"
```

Can override per-call: `codex review -c model="gpt-4o" --base main`

### Gotchas

- `codex review` is "research preview" — API contract may change
- The `--base` and `--uncommitted` flags are mutually exclusive
- Review reads full repo context, which means it can be slow and verbose on large diffs
- No timeout flag — long reviews can stall a pipeline

---

## 3. CodeRabbit

### What It Is

CodeRabbit is an AI-powered code review SaaS platform. Primary use case is automated PR review on GitHub/GitLab/Azure DevOps/Bitbucket. It also offers:
- IDE extensions (VS Code, Cursor, Windsurf)
- A CLI tool for local pre-commit reviews
- An MCP server for integration with AI editors including Claude Code

### Local CLI

CodeRabbit offers a CLI for local reviews. It is NOT the same tool as `codex`. It is not installed on this machine. Installation would be:
```bash
npm install -g @coderabbitai/cli   # (package name unconfirmed — docs blocked)
```

The CLI advertises: "Get AI code reviews directly in your CLI before you commit. Catch race conditions, memory leaks, and security vulnerabilities."

**Limitations of research:** CodeRabbit's docs at `docs.coderabbit.ai` returned 404 for most specific pages (CLI, MCP, configuration reference). The overview page and llms.txt were accessible. Confidence on specifics is LOW.

### Claude Code Plugin / MCP

CodeRabbit advertises "AI-powered code review in Claude Code through the CodeRabbit plugin." This implies an MCP server or Claude Code plugin exists. The integration "enables autonomous code review and fixing capabilities." Specific tool names and MCP server config are NOT confirmed — docs were inaccessible.

### REST API

CodeRabbit has API access described in their docs. A "Metrics Data" API exists for programmatic access. A "Report generate" endpoint exists but is deprecated for new use cases. It does NOT appear to offer a "trigger a review on this diff" REST endpoint — reviews are triggered via PR webhook events on the hosting platform.

**For programmatic triggering:** CodeRabbit review at the API level requires creating a PR (or at minimum a branch) on GitHub/GitLab. There is no "submit a diff, get a review" API analogous to OpenAI's completions API.

### `.coderabbit.yaml` Configuration

Available keys (HIGH confidence from multiple sources):

```yaml
language: "en-US"
early_access: false

reviews:
  profile: "chill"           # chill | assertive
  request_changes_workflow: false
  high_level_summary: true
  poem: true
  review_status: true
  auto_review:
    enabled: true
    drafts: false
    ignore_title_keywords:
      - "WIP"
      - "DO NOT MERGE"
    labels:
      - "ready-for-review"
    base_branches:
      - "main"
      - "develop"

chat:
  auto_reply: true

path_instructions:
  - path: "**/*.test.ts"
    instructions: "Do not review test coverage, only review correctness."
  - path: "src/security/**"
    instructions: "Pay close attention to injection vulnerabilities."

tools:
  github-checks:
    enabled: true
  languagetool:
    enabled: true
```

### Integration Approach for Quality Gates

Since CodeRabbit is primarily PR-level, the practical integration points are:

1. **Pre-PR gate:** Use the CLI (if it works locally) to review staged changes before creating a PR. Run in a `PostToolUse` hook on `Bash` or `Write` events.

2. **PR-level gate (native):** Create the PR, then use `bd gate` type `gh:pr` or `gh:run` (if CodeRabbit posts a GitHub check) to wait for CodeRabbit approval before the c4flow workflow advances.

3. **MCP integration:** If the CodeRabbit MCP server is set up, Claude Code can call it via tool calls during the REVIEW phase. No explicit `PreToolUse` hooking needed — it becomes part of the skill's workflow.

### Gotchas

- CodeRabbit is SaaS — requires authentication and internet access
- Free tier has PR review limits
- Local/CLI functionality appears newer and less documented
- For on-prem or fully local workflows, CodeRabbit is not viable
- The GitHub PR webhook model means there is latency between code push and review completion

---

## 4. Beads CLI — Task Completion Mechanics

### How `bd close` Works

```bash
bd close [id...] [flags]
```

Key flags:
- `--continue` — auto-advance to next step in a molecule workflow
- `--force` — bypass pinned issues or **unsatisfied gates** (this is the key flag)
- `--reason string` — audit trail reason
- `--suggest-next` — show newly unblocked issues after closing

**Critical finding:** `bd close` will refuse to close an issue if it has **unsatisfied gates** unless `--force` is passed. This is the native quality gate mechanism.

### Gates — The Native Quality Gate System

Gates are async wait conditions built into beads. They block workflow steps until a condition is met.

```bash
bd gate list              # Show all open gates
bd gate check             # Evaluate and auto-close resolved gates
bd gate resolve <id>      # Manually close a gate
```

**Gate types:**

| Type | Description | Resolution Trigger |
|------|-------------|-------------------|
| `human` | Requires manual `bd gate resolve` | Human closes it |
| `timer` | Expires after timeout | Time passes |
| `gh:run` | Waits for GitHub Actions run | `gh run view` shows success |
| `gh:pr` | Waits for PR merge | PR merged on GitHub |
| `bead` | Waits for cross-rig bead to close | Another bead is closed |

**Escalation:** `bd gate check --escalate` escalates failed/expired gates (e.g., `gh:run` with failed conclusion, timer expired without resolution). Escalated gates become blockers that require human intervention.

### Creating Gates in Formulas

In a `.formula.json` or YAML formula, a step can declare a gate:

```json
{
  "steps": [
    {
      "id": "code-review",
      "title": "Codex code review",
      "gate": {
        "type": "human",
        "description": "Codex review must pass before closing"
      }
    }
  ]
}
```

When a molecule is poured from this formula, the gate bead is created automatically. The step cannot be closed until the gate is resolved.

### Programmatic Gate Resolution

A quality gate script can resolve a gate programmatically:

```bash
GATE_ID=$(bd gate list --json | jq -r '.[] | select(.title | contains("code-review")) | .id')
bd gate resolve "$GATE_ID" --reason "Codex review passed: 0 critical issues"
```

This is the bridge between an automated tool (Codex, CodeRabbit) and the beads task system.

### Git Hook Integration

```bash
bd hooks install    # Installs pre-commit, post-merge, pre-push, post-checkout, prepare-commit-msg
bd hooks list       # Show installed hooks and their status
bd hooks run        # Execute a git hook (called by thin shims)
```

The `pre-commit` hook can run chained checks before allowing a commit. This is a lower-level gate than beads gates but can be integrated with quality tools.

### Preflight Check

```bash
bd preflight --check --json
```

Returns JSON with common pre-PR checks: tests run, lint, format, version consistency. Can be integrated into a quality gate script.

---

## 5. Quality Gate Patterns

### Pattern 1: PreToolUse Hook on Bash (Intercept `bd close`)

The most direct option: a `PreToolUse` hook fires when the agent tries to execute `bd close`.

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/quality-gate.sh"
          }
        ]
      }
    ]
  }
}
```

```bash
#!/bin/bash
# quality-gate.sh
COMMAND=$(cat | jq -r '.tool_input.command')

if echo "$COMMAND" | grep -q 'bd close\|beads close'; then
  # Run quality checks
  REVIEW=$(codex review --uncommitted 2>&1)
  CRITICAL=$(echo "$REVIEW" | grep -ci "critical")

  if [ "$CRITICAL" -gt 0 ]; then
    jq -n --arg reason "Codex review found $CRITICAL critical issues. Review output: $REVIEW" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: $reason
      }
    }'
  fi
fi
```

**Weakness:** Only intercepts agent-initiated `bd close` calls. If the user runs `bd close` in a terminal, this hook does not fire.

### Pattern 2: Beads Gate + Automated Gate Resolver

The most native and robust approach. Works regardless of how `bd close` is invoked.

**Step 1:** When the CODE phase completes and a task is created, also create a quality-gate bead:
```bash
GATE_ID=$(bd create --type gate --title "quality-gate: codex + coderabbit" \
  --parent "$TASK_ID" --json | jq -r '.id')
```

**Step 2:** The workflow skill requires the gate to be resolved before `bd close` succeeds.

**Step 3:** A quality gate runner script (called from a Claude Code hook or manually) executes checks and resolves the gate:
```bash
# quality-gate-runner.sh <gate-id>
GATE_ID=$1

# Run Codex review
codex review --base main > /tmp/codex-review.txt 2>&1
CODEX_EXIT=$?

# Run CodeRabbit (if CLI available)
# coderabbit review --staged > /tmp/coderabbit-review.txt 2>&1

# Parse results (prompt-engineer Codex to give structured output)
PASS=$(codex exec --full-auto "Read /tmp/codex-review.txt. If it contains 0 critical or high severity issues, output: PASS. Otherwise output: FAIL")

if [ "$PASS" = "PASS" ]; then
  bd gate resolve "$GATE_ID" --reason "Codex review passed"
else
  echo "Quality gate failed. Review: $(cat /tmp/codex-review.txt)"
  exit 1
fi
```

### Pattern 3: Molecule Formula with Explicit Review Steps

Use beads molecules to encode the quality gate as sequential workflow steps. The CODE task cannot close until review tasks are explicitly completed.

```yaml
# mol-feature-with-review.formula.yaml
steps:
  - id: implement
    title: "Implement feature"
    type: task

  - id: codex-review
    title: "Codex code review"
    type: task
    depends_on: [implement]
    gate:
      type: human
      description: "Run codex review and resolve this gate when passing"

  - id: coderabbit-review
    title: "CodeRabbit PR review"
    type: gate
    gate_type: gh:pr
    depends_on: [codex-review]

  - id: complete
    title: "Feature complete"
    depends_on: [codex-review, coderabbit-review]
```

This makes quality gates visible in `bd graph` and blocks `--continue` advancement automatically.

### Pattern 4: Stop Hook as Last-Resort Gate

A `Stop` hook fires when Claude tries to end a session. Can be used as a backstop:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/check-open-quality-gates.sh"
          }
        ]
      }
    ]
  }
}
```

```bash
#!/bin/bash
# check-open-quality-gates.sh
OPEN_GATES=$(bd gate list --json 2>/dev/null | jq '[.[] | select(.labels[] | contains("quality-gate"))] | length')

if [ "${OPEN_GATES:-0}" -gt 0 ]; then
  echo '{"decision": "block", "reason": "'"$OPEN_GATES"' quality gate(s) unresolved. Run quality checks before finishing."}'
fi
```

### Pattern 5: GitHub Actions as the Enforcement Layer

For projects already using GitHub:

1. Push branch to GitHub
2. GitHub Actions runs `codex review --base main` and CodeRabbit webhooks trigger
3. Both post check statuses to the PR
4. A `gh:run` gate in beads watches the Actions run
5. A `gh:pr` gate watches for PR merge approval
6. `bd gate check --type=gh` polls and auto-resolves when CI passes

This is the most production-grade pattern but requires GitHub and adds latency.

---

## 6. Recommended Architecture for C4Flow

### Immediate Problem

C4Flow's REVIEW and VERIFY phases are currently stubs. The `review` and `verify` skills need to be implemented. The question is how to wire quality checks into them.

### Recommended Approach: Two-Layer Gate

**Layer 1 — Beads gate (mandatory, blocks `bd close`):**
- When CODE phase completes, the workflow creates a `quality-gate` bead as a dependency of the task
- The `quality-gate` bead can only be closed by an automated script that runs checks

**Layer 2 — Claude Code hook (advisory, for agent-initiated closes):**
- A `PreToolUse` hook on `Bash` intercepts agent calls to `bd close`
- If the quality gate bead is open, the hook denies the close with an explanation

### Implementation for `c4flow:review` Skill

```
1. Collect diff: git diff main -- [files changed in this task]
2. Run codex review:
   codex review --base main > .claude/tmp/review-output.txt
3. Parse output via LLM:
   codex exec "Read .claude/tmp/review-output.txt. Count CRITICAL and HIGH severity issues.
   Output JSON: {\"critical\": N, \"high\": N, \"pass\": boolean}"
4. If pass == true:
   bd gate resolve <gate-id> --reason "Codex review: 0 critical, 0 high"
5. If pass == false:
   Report findings, allow human to override with bd gate resolve --force, or fix and re-review
```

### Where CodeRabbit Fits

CodeRabbit is best suited for the PR_REVIEW_LOOP phase (already a state in the c4flow state machine). The workflow:

1. `c4flow:pr` creates the PR
2. CodeRabbit automatically reviews it (webhook-triggered, no extra work)
3. `bd gate` type `gh:pr` or `gh:run` watches for CodeRabbit check to pass
4. `c4flow:pr-review-loop` polls `bd gate check --type=gh` until CodeRabbit approves

The `.coderabbit.yaml` file in the project repo controls CodeRabbit behavior. For c4flow workflows, configure:
```yaml
reviews:
  auto_review:
    enabled: true
    base_branches: ["main"]
path_instructions:
  - path: "**"
    instructions: "Flag CRITICAL (security, data loss) and HIGH (broken contracts, memory leaks) severity issues. Approve if none found."
```

---

## Summary of Integration Points

| Check | When to Run | How to Trigger | How to Gate on Result |
|-------|-------------|---------------|----------------------|
| Codex review | Before `bd close` in CODE phase | `codex review --base main` in skill logic | Parse output, resolve beads gate if passing |
| CodeRabbit | After PR created in PR_REVIEW_LOOP | Automatic webhook from GitHub | `bd gate` type `gh:run` watching CodeRabbit check |
| `bd preflight` | Before PR creation | `bd preflight --check --json` | Check JSON output, fail VERIFY phase if issues |
| Claude Code hook | When agent calls `bd close` | `PreToolUse` hook on `Bash` | Return `permissionDecision: deny` if gates open |
| Stop hook | When agent session ends | `Stop` event hook | Return `decision: block` if gates open |

---

## Open Questions / Low Confidence Areas

1. **CodeRabbit CLI exact commands** — docs returned 404. The CLI tool likely exists (`@coderabbitai/cli` npm package) but commands and output format are unconfirmed. Needs hands-on testing after installation.

2. **CodeRabbit MCP server tools** — described in marketing copy ("autonomous code review in Claude Code") but no tool names confirmed. Needs access to working CodeRabbit account to test.

3. **`codex review` exit codes on finding issues** — empirically appears to exit 0 always. Not documented. The structured-prompt approach (Option C above) is more reliable than relying on exit codes.

4. **Beads formula gate syntax** — the `gate` field in formula steps was inferred from the `bd gate --help` output and `bd mol pour --help`. Actual YAML/JSON schema for formula gates needs verification against beads documentation or source code.

5. **`TaskCompleted` hook event** — listed in Claude Code hook events but no matcher field. Unclear what JSON payload it passes. Needs testing to understand if it fires per-bead-close or per-Claude-task.

---

## Confidence Assessment

| Area | Confidence | Source |
|------|------------|--------|
| Claude Code hooks mechanics | HIGH | Live Claude Code docs (claude.com/docs) |
| Hooks blocking PreToolUse | HIGH | Confirmed in docs with JSON schema |
| Codex CLI review command | HIGH | Installed locally, live `--help` output, observed execution |
| Codex review exit code behavior | MEDIUM | Empirical observation, not documented |
| Beads gate system | HIGH | Live `bd gate --help`, `bd close --help` output |
| Beads formula gate syntax | MEDIUM | Inferred from help text, not from docs or source |
| CodeRabbit general capabilities | MEDIUM | Marketing copy + llms.txt overview |
| CodeRabbit CLI commands | LOW | Docs inaccessible, not installed locally |
| CodeRabbit MCP server tools | LOW | Referenced in marketing, no specifics confirmed |
| CodeRabbit REST API | LOW | Mentioned in docs overview, no endpoint details |
