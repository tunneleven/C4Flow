## Why

C4Flow's workflow ends at `CODE_LOOP` with no path to production. The `INFRA` and `DEPLOY` states exist in the state machine but are unimplemented stubs, leaving users to provision infrastructure and configure CI/CD manually after every feature cycle.

## What Changes

- Implement `c4flow:infra` skill — provisions EC2 + nginx on AWS and configures Cloudflare DNS subdomain via Terraform, then pushes outputs to GitHub Secrets automatically
- Implement `c4flow:deploy` skill — generates GitHub Actions CI/CD workflow and nginx reverse proxy config for SSH-based deployment to the provisioned EC2 instance
- Add `INFRA` as an explicit state in the orchestrator state machine between `CODE_LOOP` and `DEPLOY`
- Extend `.state.json` schema with `infraConfig` (user-provided project config) and `infraState` (post-apply terraform outputs)
- Infra config is resolved at runtime in the INFRA phase: detect env vars (never display values), fall back to `.state.json`, fall back to interactive prompt

## Capabilities

### New Capabilities

- `infra-provision`: Resolve deployment config, generate and apply Terraform for EC2 + nginx + Cloudflare DNS, push GitHub Secrets, write infraState to `.state.json`
- `deploy-cicd`: Read infraState, generate GitHub Actions SSH deploy workflow and nginx reverse proxy config, push to repo, verify health

### Modified Capabilities

- `state-machine`: Add `INFRA` state between `CODE_LOOP` and `DEPLOY` in the orchestrator; extend `.state.json` schema with `infraConfig` and `infraState` blocks

## Impact

- `skills/infra/SKILL.md` — fully implemented (currently a stub)
- `skills/deploy/SKILL.md` — fully implemented (currently a stub)
- `skills/c4flow/SKILL.md` — add INFRA state handling and updated state transition table
- `docs/c4flow/.state.json` schema — two new top-level fields: `infraConfig`, `infraState`
- Requires: `terraform` CLI, `gh` CLI (already used by PR skill), `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ZONE_ID` in environment
