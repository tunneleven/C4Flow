## Why

The `c4flow:infra` skill currently checks only env vars (`AWS_ACCESS_KEY_ID`, etc.) for credentials, failing even when AWS credentials are already configured in `~/.aws/credentials`. This causes unnecessary friction — users must re-export credentials every terminal session despite having them stored securely.

## What Changes

- Replace brittle env-var-only credential check with `aws sts get-caller-identity` to detect AWS creds from all standard sources (env vars, `~/.aws/credentials`, SSO, instance profile)
- Add Cloudflare token detection from both env var and `~/.cloudflare` dotfile
- Drop manual `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` checks (Terraform reads `~/.aws/credentials` natively)
- When credentials are missing, halt early with actionable setup guidance (including security recommendations for scoped tokens)
- Never print credential values — only acknowledge `[set]` or `[not found]`

## Capabilities

### New Capabilities

- `infra-credential-check`: Multi-source credential resolution for AWS and Cloudflare before Terraform provisioning, with secure setup guidance on failure

### Modified Capabilities

*(none — no existing specs)*

## Impact

- `skills/infra/SKILL.md` — Step 0 rewritten
- No breaking changes to other skills or state schema
- Removes need for users to export AWS env vars if `~/.aws/credentials` exists
