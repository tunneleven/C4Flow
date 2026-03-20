## 1. Orchestrator — Add INFRA State

- [x] 1.1 Update `skills/c4flow/SKILL.md` state table: add `INFRA` row between `CODE_LOOP` and `DEPLOY`, mark status as Implemented
- [x] 1.2 Update CODE_LOOP transition in orchestrator: change `currentState: "DEPLOY"` write to `currentState: "INFRA"` when all tasks closed
- [x] 1.3 Add INFRA state handler in orchestrator: check for existing `infraState`, dispatch `c4flow:infra` skill, advance to DEPLOY on success
- [x] 1.4 Update DEPLOY state handler in orchestrator: dispatch `c4flow:deploy` skill, advance to DONE on success

## 2. c4flow:infra Skill — Config Resolution

- [x] 2.1 Implement Step 1 config resolution: read `.state.json infraConfig`, detect env vars (show `[configured via env]` without value), fall back to interactive prompt for `domain`, `subdomain` (default `basename pwd`), `awsRegion`, `appPort` (default 3000)
- [x] 2.2 Write resolved non-sensitive values to `infraConfig` in `.state.json` (skip fields sourced from env vars)
- [x] 2.3 Implement re-run guard: if `infraState.appliedAt` exists, show summary and ask `Re-provision? [y/N]` before proceeding

## 3. c4flow:infra Skill — Terraform Generation

- [x] 3.1 Generate `docs/c4flow/terraform/<feature-slug>/variables.tf` with vars: `aws_region`, `domain`, `subdomain`, `app_port`, `cloudflare_zone_id`
- [x] 3.2 Generate `docs/c4flow/terraform/<feature-slug>/main.tf`: AWS provider, VPC + public subnet, EC2 t3.micro (Amazon Linux 2), security group (22/80/443), Elastic IP, `tls_private_key` + `aws_key_pair`
- [x] 3.3 Add `user_data` script to `main.tf`: install nginx + certbot, configure nginx reverse proxy (`proxy_pass localhost:<app_port>`) with HTTP→HTTPS redirect, run certbot for Let's Encrypt cert on `<subdomain>.<domain>` with 60s DNS wait + retry, set up certbot cron renewal
- [x] 3.4 Add Cloudflare provider + `cloudflare_record` A record to `main.tf`: `<subdomain>.<domain>` → EC2 EIP, `proxied = true`
- [x] 3.5 Generate `docs/c4flow/terraform/<feature-slug>/outputs.tf`: `ec2_host` (EIP), `ssh_private_key` (sensitive), `fqdn`

## 4. c4flow:infra Skill — Apply + Secrets

- [x] 4.1 Run `terraform init` in the terraform directory, stream output
- [x] 4.2 Run `terraform plan`, display resource count summary, then proceed automatically with apply (no confirmation prompt — agent-driven)
- [x] 4.3 Run `terraform apply -auto-approve`, stream output
- [x] 4.4 Read outputs via `terraform output -json`, extract `ec2_host`, `ssh_private_key`, `fqdn`
- [x] 4.5 Push four GitHub Secrets via `gh secret set`: `AWS_EC2_HOST`, `AWS_REGION`, `EC2_SSH_PRIVATE_KEY`, `DEPLOY_DOMAIN` — handle `gh auth` error gracefully
- [x] 4.6 Verify SSL readiness: curl `https://<fqdn>` with 30s timeout, warn user if cert not yet valid (DNS propagation may be in progress)
- [x] 4.7 Write `infraState` to `.state.json`: `appliedAt`, `ec2Host`, `fqdn`, `appPort`, `tfDir`, `nginxConfigured: true`, `sslConfigured` (based on curl result), `githubSecretsConfigured: true`

## 5. c4flow:deploy Skill

- [x] 5.1 Implement infraState gate check: read `.state.json`, halt with clear message if `infraState` absent or `nginxConfigured`/`githubSecretsConfigured` not true
- [x] 5.2 Detect app start command from repo (check `package.json` → Node/pm2, `requirements.txt`/`pyproject.toml` → Python/systemd, fallback to generic)
- [x] 5.3 Generate `.github/workflows/deploy.yml`: trigger on push to main, SSH deploy step (pull + install + restart), health check step curling `https://${{ secrets.DEPLOY_DOMAIN }}/` asserting HTTP 200
- [x] 5.4 Commit `.github/workflows/deploy.yml` with message `ci: add GitHub Actions deploy workflow` and push to main
- [x] 5.5 Trigger workflow run and monitor with `gh run watch` until completion
- [x] 5.6 On success: report `Deploy succeeded. Live at: https://<fqdn>`, advance state to DONE
- [x] 5.7 On failure: show last 20 log lines via `gh run view --log`, report failure, ask user how to proceed without advancing state
