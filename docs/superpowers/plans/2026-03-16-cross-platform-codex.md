# Cross-Platform Codex CLI Support Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make C4Flow work on both Claude Code CLI and OpenAI Codex CLI with full parity.

**Architecture:** Convert all tool-specific references in SKILL.md files to natural language. Add Codex CLI install guide (`.codex/INSTALL.md`) following the superpowers pattern. Update README with Codex instructions.

**Tech Stack:** Markdown only — no code changes needed.

**Spec:** `docs/superpowers/specs/2026-03-16-cross-platform-codex-design.md`

---

## Chunk 1: Natural Language Conversion

### Task 1: Convert research skill to natural language

**Files:**
- Modify: `skills/research/SKILL.md`

- [ ] **Step 1: Replace tool references**

Change these lines:

Line 34: `Use \`WebSearch\` to find:` → `Search the web to find:`

Line 42: `Use \`WebFetch\` on the 3-5 most relevant results to gather detailed information:` → `Fetch and read the 3-5 most relevant URLs to gather detailed information:`

- [ ] **Step 2: Verify no other tool references remain**

Search the file for backtick-wrapped tool names: `WebSearch`, `WebFetch`, `Bash`, `Read`, `Write`, `Edit`, `Grep`, `Glob`, `Agent`, `Skill`

- [ ] **Step 3: Commit**

```bash
git add skills/research/SKILL.md
git commit -m "refactor: convert research skill to natural language tool refs"
```

### Task 2: Convert orchestrator skill to natural language

**Files:**
- Modify: `skills/c4flow/SKILL.md`

- [ ] **Step 1: Replace tool references in RESEARCH dispatch section**

Line 91: `1. Use WebSearch to research:` → `1. Search the web to research:`

Line 92: `2. Use WebFetch on the 3-5 most relevant results` → `2. Fetch and read the 3-5 most relevant URLs`

- [ ] **Step 2: Replace skill file path references**

Line 116: `Follow the spec skill at \`skills/spec/SKILL.md\`.` → `Load the c4flow:spec skill and follow its instructions.`

Line 119: `Follow the beads skill at \`skills/beads/SKILL.md\`.` → `Load the c4flow:beads skill and follow its instructions.`

- [ ] **Step 3: Replace "Dispatch a sub-agent" wording**

Line 76-78: Replace `Dispatch a sub-agent with this prompt:` — keep the instruction but ensure it says "Dispatch a sub-agent" without referencing the `Agent` tool specifically. (Current wording is already close — just verify no `Agent` tool reference.)

- [ ] **Step 4: Verify no other tool references remain**

Search the file for backtick-wrapped tool names.

- [ ] **Step 5: Commit**

```bash
git add skills/c4flow/SKILL.md
git commit -m "refactor: convert orchestrator skill to natural language tool refs"
```

### Task 3: Convert spec skill to natural language

**Files:**
- Modify: `skills/spec/SKILL.md`

- [ ] **Step 1: Check and replace tool references**

The spec skill currently uses generic language like "Read", "Write", "Present the draft". Scan for any explicit tool name references (e.g., `Use Read`, `Use Write`) and replace with natural language equivalents.

- [ ] **Step 2: Commit**

```bash
git add skills/spec/SKILL.md
git commit -m "refactor: convert spec skill to natural language tool refs"
```

### Task 4: Convert beads skill to natural language

**Files:**
- Modify: `skills/beads/SKILL.md`

- [ ] **Step 1: Check and replace tool references**

The beads skill uses `command -v bd` (shell command, not a tool ref) and `bd create` commands. These are fine — they describe shell commands to run, which both platforms support.

Scan for any explicit tool name references and replace if found.

- [ ] **Step 2: Commit**

```bash
git add skills/beads/SKILL.md
git commit -m "refactor: convert beads skill to natural language tool refs"
```

### Task 5: Verify stub skills have no tool references

**Files:**
- Check: `skills/design/SKILL.md`, `skills/code/SKILL.md`, `skills/tdd/SKILL.md`, `skills/test/SKILL.md`, `skills/e2e/SKILL.md`, `skills/review/SKILL.md`, `skills/verify/SKILL.md`, `skills/pr/SKILL.md`, `skills/pr-review/SKILL.md`, `skills/infra/SKILL.md`, `skills/merge/SKILL.md`, `skills/deploy/SKILL.md`

- [ ] **Step 1: Grep all stubs for tool names**

Search all 12 stub files for: `WebSearch`, `WebFetch`, `Bash`, `Read`, `Write`, `Edit`, `Grep`, `Glob`, `Agent`, `Skill`

Expected: no matches (already confirmed stubs are clean).

- [ ] **Step 2: No commit needed if clean**

---

## Chunk 2: Codex CLI Install Support

### Task 6: Create .codex/INSTALL.md

**Files:**
- Create: `.codex/INSTALL.md`

- [ ] **Step 1: Create the directory and file**

```bash
mkdir -p .codex
```

Write `.codex/INSTALL.md` with:

```markdown
# C4Flow for Codex — Installation

## Prerequisites
- Git installed

## Install

1. Clone the repository:
   ```bash
   git clone https://github.com/tunneleven/C4Flow.git ~/.codex/c4flow
   ```

2. Create the skills symlink:
   ```bash
   mkdir -p ~/.agents/skills
   ln -s ~/.codex/c4flow/skills ~/.agents/skills/c4flow
   ```

3. Restart Codex (quit and relaunch).

## Verify
```bash
ls -la ~/.agents/skills/c4flow
```
Should show a symlink pointing to `~/.codex/c4flow/skills/`.

## Usage
Once installed, invoke in Codex:
- `$c4flow` — Start or resume the development workflow
- `$c4flow-status` — Check workflow progress

## Update
```bash
cd ~/.codex/c4flow && git pull
```
Skills update instantly through the symlink.

## Uninstall
```bash
rm ~/.agents/skills/c4flow
rm -rf ~/.codex/c4flow
```
```

- [ ] **Step 2: Commit**

```bash
git add .codex/INSTALL.md
git commit -m "feat: add Codex CLI installation guide"
```

### Task 7: Create docs/README.codex.md

**Files:**
- Create: `docs/README.codex.md`

- [ ] **Step 1: Write the Codex documentation**

```markdown
# C4Flow for Codex CLI

## Quick Install

Tell Codex:

> "Fetch and follow instructions from https://raw.githubusercontent.com/tunneleven/C4Flow/main/.codex/INSTALL.md"

## Manual Installation

1. Clone: `git clone https://github.com/tunneleven/C4Flow.git ~/.codex/c4flow`
2. Symlink: `ln -s ~/.codex/c4flow/skills ~/.agents/skills/c4flow`
3. Restart Codex

## How It Works

Codex scans `~/.agents/skills/` at startup, parsing SKILL.md frontmatter to discover skills. The symlink makes all C4Flow skills available as `$c4flow`, `$c4flow-research`, `$c4flow-spec`, etc.

## Usage

- `$c4flow` — Start the full workflow (equivalent to `/c4flow:run` in Claude Code)
- Type your feature idea when prompted

## Skills Available

| Skill | Description | Status |
|---|---|---|
| c4flow | Orchestrator — drives the 14-state workflow | Implemented |
| c4flow:research | Web research on feature idea | Implemented |
| c4flow:spec | Interactive spec generation (4 artifacts) | Implemented |
| c4flow:beads | Task breakdown with epic/tasks | Implemented |
| c4flow:design | Design system + mockups | Stub |
| c4flow:code | Code implementation via sub-agents | Stub |
| c4flow:test | Unit + integration tests | Stub |
| c4flow:review | AI code review loop | Stub |
| c4flow:verify | Quality gate | Stub |
| c4flow:pr | Create pull request | Stub |
| c4flow:merge | Merge to main | Stub |
| c4flow:deploy | Deploy to production | Stub |

## Update

```bash
cd ~/.codex/c4flow && git pull
```

## Uninstall

```bash
rm ~/.agents/skills/c4flow
rm -rf ~/.codex/c4flow
```
```

- [ ] **Step 2: Commit**

```bash
git add docs/README.codex.md
git commit -m "docs: add Codex CLI documentation"
```

### Task 8: Update README.md with Codex section

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add Codex CLI section after Claude Code installation**

After the existing "Option 2: Install from within Claude Code REPL" section, add:

```markdown
### Option 3: Install for OpenAI Codex CLI

Tell Codex:

> "Fetch and follow instructions from https://raw.githubusercontent.com/tunneleven/C4Flow/main/.codex/INSTALL.md"

Or manually:

```bash
git clone https://github.com/tunneleven/C4Flow.git ~/.codex/c4flow
mkdir -p ~/.agents/skills
ln -s ~/.codex/c4flow/skills ~/.agents/skills/c4flow
```

Restart Codex, then use `$c4flow` to start the workflow.

See [Codex CLI docs](docs/README.codex.md) for details.
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add Codex CLI installation option to README"
```

---

## Chunk 3: Final Verification

### Task 9: Verify all changes and push

- [ ] **Step 1: Run final grep to verify no tool-specific references remain**

Search all `skills/*/SKILL.md` files for: `WebSearch`, `WebFetch`, and any backtick-quoted tool name patterns like `` `Read` ``, `` `Write` ``, `` `Bash` ``, `` `Agent` ``, `` `Skill` `` used as tool invocations (not general English words).

- [ ] **Step 2: Verify .codex/INSTALL.md exists and is valid**

Read the file, confirm all commands are correct.

- [ ] **Step 3: Verify docs/README.codex.md exists**

Read the file, confirm content is complete.

- [ ] **Step 4: Push all commits**

```bash
git push
```

- [ ] **Step 5: Bump version to 0.3.0**

Update `version` in both `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` from `0.2.0` to `0.3.0`.

```bash
git add .claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "chore: bump version to 0.3.0"
git push
```
