## 1. Rewrite Step 0 in skills/infra/SKILL.md

- [x] 1.1 Replace existing Step 0 credential check block with AWS check using `aws sts get-caller-identity`; fall back to `~/.aws/credentials` file check when `aws` CLI is not installed
- [x] 1.2 Add Cloudflare token check: env var first, then `source ~/.cloudflare` fallback
- [x] 1.3 Collect all missing-credential errors before halting (show all missing at once, not one at a time)
- [x] 1.4 Write AWS setup guide block: recommend `aws configure` first, `aws sso login` as alternative
- [x] 1.5 Write Cloudflare setup guide block: include scoped token URL (`https://dash.cloudflare.com/profile/api-tokens`), recommend `Zone > DNS > Edit` scope, show `~/.cloudflare` dotfile setup with `chmod 600`
- [x] 1.6 Ensure no credential values are printed anywhere in the check — only status indicators (`[set]`, `[loaded from ~/.cloudflare]`, `[not found]`)

## 2. Use /skill-create to generate the updated skill bash

- [x] 2.1 Invoke `/skill-create` with the spec and design as input to generate the final Step 0 bash block
- [x] 2.2 Verify generated block against all 8 spec scenarios before writing to SKILL.md

## 3. Cleanup

- [x] 3.1 Remove the now-redundant Step 4 and Step 5 `IMPORTANT: Use the Bash tool` notes added earlier (credential check is now in Step 0; those notes remain valid but the credential-specific language is superseded)
- [x] 3.2 Update the global agent execution note at the top of SKILL.md to reflect that AWS env vars are no longer required
