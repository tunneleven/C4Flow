## ADDED Requirements

### Requirement: infraState gate check
The DEPLOY skill SHALL read `infraState` from `.state.json` before proceeding. If `infraState` is absent, or `infraState.githubSecretsConfigured` is not `true`, or `infraState.nginxConfigured` is not `true`, DEPLOY SHALL halt and instruct the user to run `/c4flow:infra` first.

#### Scenario: infraState present and valid
- **WHEN** `.state.json` contains `infraState.githubSecretsConfigured: true` and `infraState.nginxConfigured: true`
- **THEN** DEPLOY proceeds to workflow generation

#### Scenario: infraState absent
- **WHEN** `.state.json` has no `infraState` block
- **THEN** DEPLOY halts with message: `Infrastructure not provisioned. Run /c4flow:infra first.`

#### Scenario: nginx not yet configured
- **WHEN** `infraState.nginxConfigured` is `false` or absent
- **THEN** DEPLOY halts with message: `nginx not configured. Run /c4flow:infra first.`

### Requirement: GitHub Actions deploy workflow generation
The DEPLOY skill SHALL generate `.github/workflows/deploy.yml` that: triggers on push to `main`, SSHs into the EC2 host using the `EC2_SSH_PRIVATE_KEY` secret, pulls the latest code on the server, installs dependencies, and restarts the application process. The workflow uses `AWS_EC2_HOST`, `EC2_SSH_PRIVATE_KEY`, `AWS_REGION`, and `DEPLOY_DOMAIN` secrets (all provisioned by INFRA).

#### Scenario: Workflow file created
- **WHEN** DEPLOY generates the workflow
- **THEN** `.github/workflows/deploy.yml` exists with `on: push: branches: [main]` trigger and SSH deploy steps referencing `${{ secrets.EC2_SSH_PRIVATE_KEY }}` and `${{ secrets.AWS_EC2_HOST }}`

#### Scenario: Start command detection — Node
- **WHEN** repo contains `package.json`
- **THEN** workflow SSH step runs `npm install --production && pm2 restart app || pm2 start npm --name app -- start`

#### Scenario: Start command detection — Python
- **WHEN** repo contains `requirements.txt` or `pyproject.toml`
- **THEN** workflow SSH step runs `pip install -r requirements.txt && sudo systemctl restart app`

#### Scenario: Health check step included
- **WHEN** workflow is generated
- **THEN** a final step curls `https://<DEPLOY_DOMAIN>/` and asserts HTTP 200 with a 30s timeout

### Requirement: Workflow committed and pushed
The DEPLOY skill SHALL stage `.github/workflows/deploy.yml`, commit with message `ci: add GitHub Actions deploy workflow`, and push to the `main` branch.

#### Scenario: Workflow committed and pushed
- **WHEN** DEPLOY completes generation
- **THEN** `.github/workflows/deploy.yml` is committed and pushed; `git log --oneline -1` shows the ci commit

### Requirement: First deploy triggered and monitored
After pushing, the DEPLOY skill SHALL trigger the GitHub Actions workflow run and monitor its status via `gh run watch` until completion, then report the result.

#### Scenario: Deploy succeeds
- **WHEN** GitHub Actions workflow run completes with status `success`
- **THEN** DEPLOY reports `Deploy succeeded. Live at: https://<fqdn>` and advances state to DONE

#### Scenario: Deploy fails
- **WHEN** GitHub Actions workflow run completes with status `failure`
- **THEN** DEPLOY shows the last 20 lines of logs via `gh run view --log`, reports failure, and asks the user how to proceed without advancing state
