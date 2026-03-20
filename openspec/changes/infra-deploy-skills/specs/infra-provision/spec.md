## ADDED Requirements

### Requirement: Config resolution at INFRA phase start
The INFRA skill SHALL resolve deployment configuration before generating any Terraform. Resolution order per field: (1) existing `infraConfig` in `.state.json`, (2) environment variable, (3) interactive prompt. Sensitive env var values (domain tokens, credentials) SHALL be acknowledged with `[configured via env]` and never displayed. Non-sensitive defaults (subdomain derived from `basename $(pwd)`) SHALL be shown to the user for confirmation.

#### Scenario: Env var detected for domain
- **WHEN** `C4FLOW_DOMAIN` is set in the environment
- **THEN** INFRA displays `Domain: [configured via env]  Use it? [Y/n]` without printing the value

#### Scenario: No env var, no prior config
- **WHEN** `C4FLOW_DOMAIN` is not set and `infraConfig.domain` is absent from `.state.json`
- **THEN** INFRA prompts `Enter domain:` and writes the provided value to `infraConfig.domain` in `.state.json`

#### Scenario: Subdomain defaults to folder name
- **WHEN** `infraConfig.subdomain` is absent and `C4FLOW_SUBDOMAIN` is not set
- **THEN** INFRA sets subdomain to `basename $(pwd)` and shows `Subdomain: [default: <name>]  Use it? [Y/n]`

#### Scenario: Prior infraConfig exists on re-run
- **WHEN** `.state.json` already contains a complete `infraConfig` block
- **THEN** INFRA skips all prompts for already-configured fields and proceeds directly

### Requirement: Terraform HCL generation for EC2 + nginx + SSL
The INFRA skill SHALL generate Terraform HCL files into `docs/c4flow/terraform/<feature-slug>/` that provision: a VPC with public subnet, an EC2 t3.micro instance with Amazon Linux 2, a security group allowing ports 22/80/443, an Elastic IP, an SSH key pair via `tls_private_key`, and a `user_data` script that: installs nginx, installs certbot, obtains a Let's Encrypt SSL certificate for `<subdomain>.<domain>`, configures nginx as a reverse proxy to the app port (default 3000) with SSL termination, and sets up certbot auto-renewal via cron.

#### Scenario: Terraform directory created on first run
- **WHEN** INFRA generates Terraform for a feature slug for the first time
- **THEN** the directory `docs/c4flow/terraform/<feature-slug>/` is created containing `main.tf`, `variables.tf`, and `outputs.tf`

#### Scenario: nginx configured as reverse proxy with SSL
- **WHEN** EC2 instance starts via user_data
- **THEN** nginx is configured with an HTTP→HTTPS redirect on port 80 and an HTTPS server block on port 443 proxying to `localhost:<app-port>`, with a valid Let's Encrypt certificate for `<fqdn>`

#### Scenario: App port asked during config resolution
- **WHEN** INFRA resolves config and `infraConfig.appPort` is absent
- **THEN** INFRA prompts `App port (default: 3000):` and stores the value in `infraConfig.appPort`

#### Scenario: Existing terraform directory skipped
- **WHEN** `infraState.appliedAt` is present in `.state.json` and the terraform directory exists
- **THEN** INFRA informs the user infra is already provisioned and asks `Re-provision? [y/N]` before proceeding

### Requirement: Cloudflare DNS subdomain via Terraform
The INFRA skill SHALL generate Terraform resources using the Cloudflare provider to create an A record pointing `<subdomain>.<domain>` to the EC2 Elastic IP, with `proxied = true` (Cloudflare proxy enabled for TLS termination).

#### Scenario: DNS record created
- **WHEN** terraform apply completes successfully
- **THEN** a Cloudflare A record exists for `<subdomain>.<domain>` pointing to the EC2 EIP

#### Scenario: Missing Cloudflare credentials
- **WHEN** `CLOUDFLARE_API_TOKEN` or `CLOUDFLARE_ZONE_ID` are not set and not in `.state.json`
- **THEN** INFRA prompts for `CLOUDFLARE_ZONE_ID` (non-sensitive, may be stored) and acknowledges `CLOUDFLARE_API_TOKEN` must be set as env var

### Requirement: Terraform apply with confirmation gate
The INFRA skill SHALL run `terraform plan` first, display a summary of resources to be created, and require explicit user confirmation before running `terraform apply -auto-approve`.

#### Scenario: User confirms apply
- **WHEN** user enters `yes` at the confirmation prompt
- **THEN** INFRA runs `terraform apply -auto-approve` and streams output

#### Scenario: User declines apply
- **WHEN** user enters anything other than `yes` at the confirmation prompt
- **THEN** INFRA exits without applying and instructs the user to re-run `/c4flow:infra` when ready

### Requirement: GitHub Secrets push after apply
After a successful `terraform apply`, the INFRA skill SHALL push exactly four secrets to the GitHub repository using `gh secret set`: `AWS_EC2_HOST` (EC2 public IP), `AWS_REGION` (from infraConfig), `EC2_SSH_PRIVATE_KEY` (from terraform output), and `DEPLOY_DOMAIN` (computed FQDN).

#### Scenario: All four secrets set successfully
- **WHEN** terraform apply succeeds and `gh` CLI is authenticated
- **THEN** all four secrets are visible in the repository's GitHub Actions secrets

#### Scenario: gh CLI not authenticated
- **WHEN** `gh auth status` fails
- **THEN** INFRA halts after apply, instructs user to run `gh auth login`, and exits with a message that secrets were not pushed

### Requirement: infraState written to .state.json
After apply and secrets push, the INFRA skill SHALL write an `infraState` block to `.state.json` containing: `appliedAt` (ISO timestamp), `ec2Host` (public IP), `fqdn` (full subdomain.domain), `appPort` (from infraConfig), `tfDir` (path to terraform directory), `nginxConfigured` (boolean), `sslConfigured` (boolean), `githubSecretsConfigured` (boolean).

#### Scenario: infraState persisted
- **WHEN** INFRA completes successfully
- **THEN** `.state.json` contains `infraState.appliedAt`, `infraState.ec2Host`, `infraState.fqdn`, `infraState.appPort`, `infraState.nginxConfigured: true`, `infraState.sslConfigured: true`, `infraState.githubSecretsConfigured: true`
