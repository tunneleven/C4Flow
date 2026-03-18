# Init Flow: GitHub, Terraform, and CodeRabbit Bootstrap

**Date:** 2026-03-18
**Status:** Approved

## Goal

Extend `/c4flow:init` so it can optionally create and manage a GitHub repository via Terraform, push the local project to that repository, and optionally set up CodeRabbit for the repository with explicit user consent at each remote-affecting step.

## Context

The current init flow is implemented in [`skills/init/SKILL.md`](/home/tunn/Documents/Research/C4Flow/skills/init/SKILL.md) and [`skills/init/init.sh`](/home/tunn/Documents/Research/C4Flow/skills/init/init.sh). Today it installs Dolt and Beads, runs `bd init`, starts Dolt if needed, and can optionally configure a DoltHub remote.

It does not currently:

- create GitHub repositories
- manage GitHub repository settings declaratively
- push the current local repository to a newly created GitHub remote
- configure CodeRabbit or create `.coderabbit.yaml`

The requested change adds those capabilities while preserving the current shell-driven init experience.

## Requirements

### Functional

- Keep the current Dolt and Beads initialization behavior.
- Ask the user whether they want to create or manage a GitHub repository for the current project.
- If the user agrees, use Terraform with the GitHub provider to create or manage the GitHub repository.
- After the repository exists, configure `origin` and push the local repository to GitHub.
- Ask the user whether they want to set up CodeRabbit for the repository.
- If the user agrees, create a starter `.coderabbit.yaml` in the repository root.
- Support automatic CodeRabbit repository attach when the required GitHub App installation metadata is available.
- If automatic CodeRabbit attach is not possible, stop with precise manual instructions instead of claiming setup is complete.

### Behavioral

- Never create a GitHub repository without an explicit yes from the user.
- Never set up CodeRabbit without an explicit yes from the user.
- If required environment variables are missing, ask the user to set them and stop before making remote changes.
- If a repository already has an `origin` remote, ask before replacing it.
- Fail closed: do not continue to later remote steps after a failed Terraform or push step.

## Research Summary

### GitHub Terraform Provider

The GitHub provider supports:

- repository creation via `github_repository`
- default-branch management via `github_branch_default`
- repository file creation via `github_repository_file`
- Actions secret management via `github_actions_secret`
- GitHub App installation-to-repository associations via `github_app_installation_repository`

Supported authentication models:

- personal access token via `GITHUB_TOKEN`
- GitHub App credentials via `GITHUB_APP_ID`, `GITHUB_APP_INSTALLATION_ID`, and `GITHUB_APP_PEM_FILE`

For GitHub App authentication, `owner` is required.

### CodeRabbit

CodeRabbit repository configuration is rooted in `.coderabbit.yaml` at the repository root. Repository-level configuration can override central configuration. Initial CodeRabbit authorization is still a GitHub App installation flow unless the app is already installed and accessible through installation metadata that Terraform can use.

### GitHub App Install Behavior

GitHub supports installing apps to all repositories or only selected repositories. When an app is installed with selected repositories, repositories created by that app can be granted access automatically, but third-party app setup still depends on the app already being installed and authorized for the owner account or organization.

## Options Considered

### Option 1: Imperative GitHub CLI Setup

Use `gh repo create`, set the remote, push, and create `.coderabbit.yaml` directly from the shell script.

**Pros**
- small implementation surface
- easy to prototype

**Cons**
- does not satisfy the Terraform requirement
- splits repository configuration between shell side effects and future IaC
- harder to extend consistently

### Option 2: Shell Orchestrator + Terraform Bootstrap Module

Keep `init.sh` as the top-level flow, but add a small Terraform module to create and manage the GitHub repository and related GitHub-side resources.

**Pros**
- satisfies the Terraform requirement
- preserves the current init entrypoint and UX
- keeps GitHub bootstrap declarative
- allows project files to remain Git-managed rather than Terraform-managed

**Cons**
- introduces Terraform as a new local dependency
- requires clear auth and state handling

### Option 3: Terraform Owns Repo and Bootstrap Files

Use Terraform for both repository creation and initial repo files such as `.coderabbit.yaml`.

**Pros**
- highly declarative bootstrap
- can provision repo and file content in one apply

**Cons**
- awkward interaction with first local push
- encourages Terraform ownership of normal repo content
- creates unnecessary coupling between bootstrap infrastructure and source content

## Decision

Choose **Option 2**.

`/c4flow:init` remains a shell-driven command. It gains an internal Terraform bootstrap phase for GitHub resources, then returns to normal Git operations for the actual project content. CodeRabbit configuration is committed in Git as `.coderabbit.yaml`, while Terraform is limited to GitHub-side infrastructure concerns.

## High-Level Flow

### Phase 1: Existing Local Init

Retain the current behavior:

- verify git repo
- install Dolt if needed
- install Beads if needed
- run `bd init`
- ensure Dolt server is reachable
- optionally configure DoltHub sync

### Phase 2: Optional GitHub Bootstrap

Ask:

`Do you want to create/manage a GitHub repository for this project?`

If no:

- skip GitHub bootstrap
- continue to optional CodeRabbit question only if a GitHub remote already exists or if the user explicitly wants config-only setup

If yes:

- derive or prompt for repository name
- derive or prompt for owner
- prompt for visibility if not provided
- verify required auth environment variables
- write runtime Terraform inputs
- run Terraform init and apply for the GitHub bootstrap module
- read Terraform outputs for repository URLs and metadata
- inspect existing `origin`
- if `origin` exists and differs, ask:
  `This repo already has an origin remote. Do you want to replace it?`
- set or update `origin`
- push the current branch with upstream tracking

### Phase 3: Optional CodeRabbit Bootstrap

Ask:

`Do you want to set up CodeRabbit for this repository?`

If no:

- stop after GitHub verification

If yes:

- create a starter `.coderabbit.yaml` at the repository root if it does not already exist
- if automatic app attach metadata is available, use Terraform to associate the CodeRabbit installation with the repository
- if automatic app attach metadata is not available, print exact manual setup instructions and mark the step as pending manual completion
- ensure `.coderabbit.yaml` is included in the pushed branch, or tell the user to rerun push if they chose not to auto-commit during init

## Architecture

### Script Ownership

[`skills/init/init.sh`](/home/tunn/Documents/Research/C4Flow/skills/init/init.sh) remains the orchestrator. It should gain small, focused functions for:

- prompt handling
- environment validation
- Terraform bootstrap execution
- remote configuration
- push verification
- CodeRabbit configuration generation

### Terraform Ownership

Add a focused Terraform module under a path like:

- `skills/init/terraform/github-bootstrap/providers.tf`
- `skills/init/terraform/github-bootstrap/variables.tf`
- `skills/init/terraform/github-bootstrap/main.tf`
- `skills/init/terraform/github-bootstrap/outputs.tf`

Runtime input should be passed through a generated `terraform.tfvars.json` or `-var` arguments written by the shell script at runtime.

Terraform should own:

- `github_repository`
- optional branch or repo settings that belong to GitHub infrastructure
- optional `github_app_installation_repository` for CodeRabbit app association when metadata is available

Terraform should not become the long-term owner of normal project source files unless there is a strong reason. `.coderabbit.yaml` should be treated as repository content, not infrastructure state.

## Authentication Model

### GitHub Repository Bootstrap

Support both owner types from day one:

- personal account
- organization

The init flow should accept `GITHUB_OWNER` or an explicit CLI flag such as `--github-owner`. If neither is provided, ask the user.

Supported auth choices:

- `GITHUB_TOKEN`
- GitHub App env vars: `GITHUB_APP_ID`, `GITHUB_APP_INSTALLATION_ID`, `GITHUB_APP_PEM_FILE`

Required behavior:

- if the user opted into GitHub bootstrap and auth vars are missing, stop and tell them exactly what to set
- do not attempt anonymous fallback

### CodeRabbit Automatic Attach

Automatic CodeRabbit app attach should require installation metadata that Terraform can use. If the app is not already installed for the selected owner, the flow should stop with manual instructions.

This means the design supports two CodeRabbit modes:

- **automatic attach mode**: installation metadata available
- **config-only mode**: write `.coderabbit.yaml`, then hand the user a manual install checklist

## File and State Strategy

### Repository Content

Create `.coderabbit.yaml` in the root of the target repository with a minimal starter configuration and schema header.

If the file already exists:

- do not silently overwrite it
- ask whether to keep, merge, or replace

### Terraform Working State

The Terraform bootstrap should be treated as an ephemeral init mechanism unless C4Flow later formalizes ongoing GitHub IaC ownership. For the first version:

- keep the Terraform scope narrow
- prefer local state under the bootstrap folder
- clean up generated runtime variable files after successful completion where possible

## Verification

### Before GitHub Bootstrap

Verify:

- current directory is a git repository
- repository name is known or derivable
- owner is known
- required auth environment variables are set
- Terraform binary is available

### After Terraform Apply

Verify:

- repository exists according to Terraform outputs
- clone URL or HTML URL is returned
- requested visibility matches the created repository

### After Remote Setup

Verify:

- `git remote get-url origin` matches the created repository
- `git push -u origin <branch>` succeeds

### After CodeRabbit Setup

Verify:

- `.coderabbit.yaml` exists in the repository root
- automatic attach succeeded if automatic mode was selected
- otherwise report CodeRabbit as pending manual installation, not complete

## Failure Handling

### Missing Environment Variables

If required env vars are missing, stop and tell the user exactly which variables to export.

Examples:

- `GITHUB_TOKEN` for token auth
- `GITHUB_OWNER` for owner targeting
- `GITHUB_APP_ID`, `GITHUB_APP_INSTALLATION_ID`, `GITHUB_APP_PEM_FILE` for GitHub App auth

### Repository Already Exists

If the target GitHub repository already exists:

- ask whether to adopt and manage it
- if the user declines, abort the GitHub bootstrap phase

### Existing Origin Remote

If `origin` already exists and differs from the target:

- ask before replacing it
- do not overwrite automatically

### Terraform Failure

If Terraform init, plan, or apply fails:

- print the failure
- stop the GitHub bootstrap phase
- do not continue to push or CodeRabbit setup

### Push Failure

If the first push fails:

- keep the remote information visible
- stop before CodeRabbit setup that depends on the pushed repository state

### CodeRabbit Metadata Missing

If CodeRabbit automatic attach was requested but required installation metadata is missing:

- still create `.coderabbit.yaml` if the user approved CodeRabbit setup
- stop with manual install instructions
- report the status as partial completion

## Open Implementation Decisions

- Whether `init.sh` should install Terraform automatically or fail with instructions if Terraform is missing.
- Whether `.coderabbit.yaml` should be committed automatically by init or only created in the working tree for the user to review.
- Whether the Terraform bootstrap folder is purely internal to the skill or intended for ongoing reuse by projects after init.

## Recommended Defaults

- Support both personal and organization owners.
- Default repository name to the current directory name.
- Require explicit user confirmation before remote creation and before CodeRabbit setup.
- Prefer Git-managed `.coderabbit.yaml` over Terraform-managed repository files.
- Treat missing CodeRabbit installation metadata as a manual handoff, not as a hard failure for the rest of init.

## Success Criteria

The feature is successful when:

- `/c4flow:init` still completes local Dolt and Beads setup as before
- users can opt into GitHub repo creation through an explicit prompt
- GitHub repository creation is executed via Terraform
- the local repository can be pushed to the created remote in the same flow
- users can opt into CodeRabbit through a separate explicit prompt
- the flow clearly distinguishes between fully automated CodeRabbit setup and config-only plus manual install
- missing credentials or app metadata produce precise, actionable stop messages instead of partial silent behavior
