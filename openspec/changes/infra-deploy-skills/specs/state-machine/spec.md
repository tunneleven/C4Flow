## ADDED Requirements

### Requirement: INFRA state in orchestrator
The c4flow orchestrator SHALL include `INFRA` as an explicit state between `CODE_LOOP` and `DEPLOY` in the state transition table and status display.

#### Scenario: INFRA appears in status output
- **WHEN** user runs `/c4flow:status` while `currentState` is `INFRA`
- **THEN** status shows `INFRA` as the active state with phase label `6: Release`

#### Scenario: CODE_LOOP advances to INFRA
- **WHEN** `bd ready` returns empty and all epic tasks are closed
- **THEN** the code skill writes `currentState: "INFRA"` to `.state.json` (previously wrote `"DEPLOY"`)

#### Scenario: INFRA advances to DEPLOY on success
- **WHEN** the INFRA skill completes with `infraState.githubSecretsConfigured: true`
- **THEN** orchestrator adds `INFRA` to `completedStates` and sets `currentState` to `DEPLOY`

### Requirement: .state.json infraConfig schema
The `.state.json` file SHALL support a top-level `infraConfig` object with fields: `domain` (string), `subdomain` (string), `awsRegion` (string), `appPort` (number), written by the INFRA skill during config resolution. Fields populated from env vars SHALL NOT be written to `infraConfig`.

#### Scenario: infraConfig persisted after resolution
- **WHEN** INFRA resolves config and user confirms values
- **THEN** `.state.json` contains `infraConfig` with all non-sensitive resolved fields

#### Scenario: Env-var-sourced values absent from infraConfig
- **WHEN** domain is sourced from `C4FLOW_DOMAIN` env var
- **THEN** `infraConfig.domain` is absent from `.state.json`

### Requirement: .state.json infraState schema
The `.state.json` file SHALL support a top-level `infraState` object with fields: `appliedAt` (ISO string), `ec2Host` (string), `fqdn` (string), `appPort` (number), `tfDir` (string), `nginxConfigured` (boolean), `sslConfigured` (boolean), `githubSecretsConfigured` (boolean), written by the INFRA skill after successful apply.

#### Scenario: infraState present after successful INFRA run
- **WHEN** INFRA completes without error
- **THEN** `.state.json`.infraState contains all eight fields with non-null values
