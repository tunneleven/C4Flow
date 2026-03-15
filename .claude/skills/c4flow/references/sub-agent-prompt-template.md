# Sub-Agent Prompt Template

Use this template when constructing prompts for sub-agents. Total prompt context should be ~2000 tokens max, leaving working space for the sub-agent.

## Template

# Task: {task_title}

## Context
{excerpt from spec relevant to this task — max 500 tokens}

## Task Description
{full description with acceptance criteria}

## Files to Modify
{list of files from task description}

## Design Reference
{excerpt from design.md relevant to this task — max 300 tokens}

## Tech Stack
{from tech-stack.md — framework, language, testing framework}

## Rules
- Follow TDD: write failing test first, then implement
- Commit after each RED-GREEN-REFACTOR cycle
- Commit message format: "feat: <desc> (bd-xxxx)" or "feat: <desc>" if no beads
- Report status: DONE / DONE_WITH_CONCERNS / BLOCKED / NEEDS_CONTEXT

## Current Codebase Context
{auto-detected: existing patterns, imports, file structure near target files}

## Token Budget Guidelines

| Section | Max Tokens |
|---------|-----------|
| Context (spec excerpt) | 500 |
| Task Description | 300 |
| Design Reference | 300 |
| Tech Stack | 100 |
| Rules | 100 |
| Codebase Context | 200 |
| Template overhead | 100 |
| **Total** | **~1600** |

Remaining budget (~2400 tokens) is for the sub-agent's working space.
