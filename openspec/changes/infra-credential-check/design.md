## Context

The `c4flow:infra` skill's Step 0 credential check currently tests only environment variables. The AWS provider for Terraform already supports multiple credential sources natively (env vars → `~/.aws/credentials` → `~/.aws/config` → SSO → instance profile). Checking env vars manually misses all other sources and confuses users who have already run `aws configure`.

For Cloudflare, there is no official credential file format, but the convention of a `~/.cloudflare` dotfile sourced from `~/.zshrc` is well-established and avoids token sprawl across shell configs.

## Goals / Non-Goals

**Goals:**
- Detect AWS credentials from any standard source using `aws sts get-caller-identity`
- Detect Cloudflare token from env var or `~/.cloudflare` dotfile
- Halt early with actionable, security-conscious setup guidance when credentials are missing
- Never print sensitive values

**Non-Goals:**
- Supporting non-standard credential backends (Vault, 1Password CLI, etc.)
- Modifying how Terraform itself resolves credentials (it already handles this correctly)
- Validating Cloudflare token permissions (scope validation is out of scope)

## Decisions

### Use `aws sts get-caller-identity` instead of env var checks

**Decision**: Call `aws sts get-caller-identity` to verify AWS credentials.

**Rationale**: This is the canonical AWS liveness check. It exercises the full credential chain (env → file → SSO → instance profile) and returns a clear error if nothing works. Manually checking env vars or file contents duplicates the SDK's logic and misses sources like SSO.

**Alternative considered**: Parse `~/.aws/credentials` directly.
**Rejected**: Brittle, doesn't cover SSO or `~/.aws/config`, and duplicates what the SDK already does.

**Security note**: `get-caller-identity` output (Account ID, ARN, UserId) is not sensitive — it's used in IAM policies and logs routinely.

---

### Source `~/.cloudflare` as fallback for Cloudflare token

**Decision**: If `CLOUDFLARE_API_TOKEN` is not in env, attempt `source ~/.cloudflare` before failing.

**Rationale**: Gives users a dedicated, `chmod 600` dotfile for Cloudflare credentials — analogous to `~/.aws/credentials`. Avoids polluting `~/.zshrc` with secrets.

**Security note**: Guide users to create scoped tokens (Zone > DNS > Edit) rather than Global API Keys. The skill's setup guide should include the specific Cloudflare dashboard URL.

---

### Credential check runs in Step 0, before any file I/O or config resolution

**Decision**: Fail before writing any files if credentials are missing.

**Rationale**: Avoids partial state (half-written `infraConfig` in `.state.json`) when the user can't proceed anyway. Fast failure is friendlier.

## Risks / Trade-offs

- **`aws` CLI may not be installed** → Fall back to checking `~/.aws/credentials` file directly if `aws` command is unavailable. Terraform will still find the creds even without the CLI validation.
- **SSO token expired** → `aws sts get-caller-identity` will fail; guide says to run `aws sso login`. This is correct behavior — the session is genuinely expired.
- **`source ~/.cloudflare` side effects** → The file could contain arbitrary shell code. Acceptable risk for a developer tool where the user owns their own dotfiles; document the expectation that the file should only contain `export` statements.

## Migration Plan

- Replace Step 0 in `skills/infra/SKILL.md` only
- No state schema changes
- No other skills affected
- Existing users with `~/.aws/credentials` already set will see improved behavior immediately (no longer need to export env vars)
