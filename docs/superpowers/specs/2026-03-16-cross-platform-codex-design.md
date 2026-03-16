# Cross-Platform Compatibility: Claude Code + Codex CLI

**Date:** 2026-03-16
**Status:** Approved

## Goal

Make C4Flow plugin work on both Claude Code CLI and OpenAI Codex CLI with full parity — all workflow states (RESEARCH through DEPLOY) functional on both platforms.

## Context

C4Flow is currently a Claude Code plugin using tool-specific references (`WebSearch`, `WebFetch`, `Bash`, `Read`, `Write`, `Skill`, `Agent`) in skill files. OpenAI Codex CLI uses different tool names (`web_search`, `shell`, `read_file`, `apply_patch`, `spawn_agent`) but shares the same SKILL.md format (Open Agent Skills Standard).

### Key Compatibility Points

| Aspect | Claude Code | Codex CLI |
|---|---|---|
| Skill format | `SKILL.md` with YAML frontmatter | Same |
| Skill location | `skills/` (via plugin) | `.agents/skills/` (scanned at startup) |
| Commands | `commands/*.md` → `/c4flow:run` | No equivalent — `$skill-name` |
| Config | `plugin.json` (JSON) | `config.toml` (TOML) |
| Tool names | `WebSearch`, `WebFetch`, `Bash`, `Read`, `Write`, `Edit`, `Grep`, `Glob`, `Agent` | `web_search`, `shell`, `read_file`, `apply_patch`, `grep_files`, `list_dir`, `spawn_agent` |

## Approach: Natural Language Skills + Platform Install Guide

### Rationale

Both Claude Code and Codex CLI use LLMs that understand natural language instructions. Instead of referencing specific tool names, skills describe *what to do* and let each platform's LLM map to the correct tool.

**Alternatives considered:**
- Platform detection + mapping in each skill — adds complexity, still 1 file but verbose
- Duplicate skills per platform — maintenance burden, drift risk

### Decision

Single set of skills using natural language. Platform-specific entry points and install guides only.

## Changes

### 1. Natural Language Conversion (all SKILL.md files)

Replace tool-specific references with natural language equivalents:

| Before (tool-specific) | After (natural language) |
|---|---|
| `Use WebSearch to find...` | `Search the web to find...` |
| `Use WebFetch on the 3-5 most relevant results` | `Fetch and read the 3-5 most relevant URLs` |
| `Use the Skill tool to load...` | `Load the skill...` |
| `Use the Agent tool to dispatch...` | `Dispatch a sub-agent to...` |
| `Use Read to read the file` | `Read the file at...` |
| `Use Write to create...` | `Create/write the file at...` |
| `Use Bash to run...` | `Run the command...` |
| `Use Grep/Glob to search...` | `Search for files/content matching...` |

**Affected files:**
- `skills/c4flow/SKILL.md` — orchestrator
- `skills/research/SKILL.md` — web research
- `skills/spec/SKILL.md` — spec generation
- `skills/beads/SKILL.md` — task breakdown
- 12 stub skills — minimal/no changes needed

### 2. Codex CLI Install Support

**New file: `.codex/INSTALL.md`**

Installation steps:
1. `git clone https://github.com/tunneleven/C4Flow.git ~/.codex/c4flow`
2. `ln -s ~/.codex/c4flow/skills ~/.agents/skills/c4flow`
3. Restart Codex

User invokes by pasting into Codex:
> "Fetch and follow instructions from https://raw.githubusercontent.com/tunneleven/C4Flow/main/.codex/INSTALL.md"

**New file: `docs/README.codex.md`**

Detailed documentation for Codex users covering:
- Installation (quick + manual)
- How it works (skill discovery via symlink)
- Usage (`$c4flow` to invoke)
- Update (`cd ~/.codex/c4flow && git pull`)
- Uninstall

### 3. README Update

Add Codex CLI installation section to main README alongside existing Claude Code instructions.

### 4. No Changes Required

- `references/` templates — no tool names
- `.claude-plugin/` — Claude Code only
- `commands/run.md` — Claude Code only (Codex uses `$c4flow` directly)
- `commands/status.md` — no tool names

## Entry Points by Platform

| | Claude Code | Codex CLI |
|---|---|---|
| Install | `plugins marketplace add` + `plugins install` | Clone + symlink |
| Invoke workflow | `/c4flow:run <idea>` | `$c4flow <idea>` |
| Check status | `/c4flow:status` | `$c4flow-status` |
| Update | `plugins update c4flow@c4flow-marketplace` | `cd ~/.codex/c4flow && git pull` |

## Risks

- **Natural language ambiguity**: LLM might choose wrong tool in edge cases. Mitigated by clear action verbs ("search the web", "fetch the URL").
- **Codex tool differences**: Codex has no direct `WebFetch` equivalent — its web search tool handles both search and fetch. Skills should describe the *goal* not the mechanism.
- **Symlink maintenance**: Users must manually update via git pull. No auto-update like Claude Code plugins.
