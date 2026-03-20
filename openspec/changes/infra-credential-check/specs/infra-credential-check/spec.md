## ADDED Requirements

### Requirement: AWS credentials detected from all standard sources
The skill SHALL verify AWS credentials using `aws sts get-caller-identity` when the `aws` CLI is available, accepting credentials from any source in the standard chain (env vars, `~/.aws/credentials`, `~/.aws/config`, SSO). When the `aws` CLI is not installed, the skill SHALL fall back to checking for a `~/.aws/credentials` file with `aws_access_key_id` present.

#### Scenario: AWS credentials present via credentials file
- **WHEN** `~/.aws/credentials` contains valid keys and no AWS env vars are set
- **THEN** `aws sts get-caller-identity` succeeds and the skill proceeds without error

#### Scenario: AWS credentials present via environment variables
- **WHEN** `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` are set in the environment
- **THEN** `aws sts get-caller-identity` succeeds and the skill proceeds without error

#### Scenario: AWS credentials absent
- **WHEN** no AWS credentials are found from any source
- **THEN** the skill halts before any file I/O and prints a setup guide recommending `aws configure`

#### Scenario: AWS CLI not installed, credentials file present
- **WHEN** the `aws` command is not available but `~/.aws/credentials` contains `aws_access_key_id`
- **THEN** the skill acknowledges the file and proceeds (Terraform will use it directly)

### Requirement: Cloudflare token detected from env or dotfile
The skill SHALL check `CLOUDFLARE_API_TOKEN` first in the environment, then attempt to source `~/.cloudflare` as a fallback before concluding the token is missing.

#### Scenario: Cloudflare token set in environment
- **WHEN** `CLOUDFLARE_API_TOKEN` is exported in the current shell session
- **THEN** the skill acknowledges `[set via env]` and proceeds

#### Scenario: Cloudflare token in dotfile
- **WHEN** `CLOUDFLARE_API_TOKEN` is not in env but `~/.cloudflare` exists and exports it
- **THEN** the skill sources `~/.cloudflare`, finds the token, and proceeds

#### Scenario: Cloudflare token absent
- **WHEN** `CLOUDFLARE_API_TOKEN` is not in env and `~/.cloudflare` does not export it
- **THEN** the skill halts and prints a setup guide including the scoped token URL and `~/.cloudflare` dotfile instructions

### Requirement: Credential values never printed
The skill SHALL never print the value of any credential. It SHALL only display `[set]`, `[set via env]`, `[loaded from ~/.cloudflare]`, or `[not found]` status indicators.

#### Scenario: All credentials present
- **WHEN** both AWS and Cloudflare credentials are resolved
- **THEN** output shows only status indicators, no credential values

### Requirement: Setup guide is actionable and security-conscious
When a credential is missing, the setup guide SHALL recommend the most secure standard approach first, and SHALL include a note directing users to create scoped Cloudflare tokens rather than Global API Keys.

#### Scenario: AWS missing — guide content
- **WHEN** AWS credentials are not found
- **THEN** guide recommends `aws configure` as first option, mentions SSO as alternative

#### Scenario: Cloudflare missing — guide content
- **WHEN** Cloudflare token is not found
- **THEN** guide includes the Cloudflare API tokens dashboard URL, recommends `Zone > DNS > Edit` scope, and shows the `~/.cloudflare` dotfile setup commands with `chmod 600`
