---
name: c4flow:infra
description: Provision AWS EC2 + nginx + SSL infrastructure and Cloudflare DNS for the current C4Flow feature. Use when the user runs /c4flow:infra or when the orchestrator advances to INFRA state.
---

# /c4flow:infra — Infrastructure Provisioning

**Phase**: 6: Release
**Agent type**: Main agent (interactive)
**Status**: Implemented

Provisions EC2 + nginx + Let's Encrypt SSL on AWS and creates a Cloudflare DNS subdomain via Terraform. Pushes outputs to GitHub Secrets so the DEPLOY phase can run CI/CD without manual configuration.

---

## Step 1: Read State

Read `docs/c4flow/.state.json`. Extract:
- `feature.slug` — used for terraform directory path
- `infraConfig` — existing config (may be partial or absent)
- `infraState` — if present, trigger re-run guard (see below)

If `.state.json` is missing or `feature` is null, halt:
```
No active feature found. Run /c4flow:run to start a feature workflow first.
```

**Re-run guard**: If `infraState.appliedAt` is present:
```
Infrastructure already provisioned.
  Host:    {infraState.ec2Host}
  Domain:  {infraState.fqdn}
  Applied: {infraState.appliedAt}

Re-provision? [y/N]
```
If user answers anything other than `y` or `yes`, exit and suggest running `/c4flow:deploy` to continue.

---

## Step 2: Resolve and Validate Config

Resolve each field using this priority order:
1. Existing value in `.state.json` `infraConfig`
2. Environment variable (detect presence with `[ -n "$VAR" ]` — **never print the value**)
3. Interactive prompt (last resort)

For **sensitive** env vars: display `[configured via env]` only. Never echo the value.
For **non-sensitive** defaults: show the computed default and ask for confirmation.

### Fields to resolve

| Field | Env var | Default | Sensitive? |
|-------|---------|---------|------------|
| `domain` | `C4FLOW_DOMAIN` | — | No (but don't echo if from env) |
| `subdomain` | `C4FLOW_SUBDOMAIN` | `basename $(pwd)` | No |
| `awsRegion` | `C4FLOW_AWS_REGION` or `AWS_DEFAULT_REGION` | `us-east-1` | No |
| `appPort` | — | `3000` | No |
| `certbotEmail` | — | — | No (must be monitored — Let's Encrypt sends expiry notices here) |
| `cloudflareZoneId` | `CLOUDFLARE_ZONE_ID` | — | No |
| `sshCidr` | — | current machine IP + /32 | No (restrict SSH access) |
| Cloudflare API token | `CLOUDFLARE_API_TOKEN` | — | **Yes — never stored/displayed** |
| AWS credentials | `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | — | **Yes — never stored/displayed** |

**Prompt format**:
```bash
# Sensitive env var detected:
Domain: [configured via env]  Use it? [Y/n]

# Non-sensitive default:
Subdomain: [default: my-app]  Use it? [Y/n]

# Nothing available:
Enter domain: _

# certbot email (always prompt — must be real):
Certbot email (for Let's Encrypt expiry notices): _

# SSH CIDR (restrict who can SSH to the instance):
SSH access CIDR [default: <your-current-ip>/32, or 0.0.0.0/0 for any]: _
```

Detect current IP for SSH CIDR default:
```bash
CURRENT_IP=$(curl -s --max-time 5 https://checkip.amazonaws.com 2>/dev/null || echo "")
SSH_CIDR_DEFAULT="${CURRENT_IP:+${CURRENT_IP}/32}"
SSH_CIDR_DEFAULT="${SSH_CIDR_DEFAULT:-0.0.0.0/0}"
```

### Validation — REQUIRED before proceeding

**Run these checks before writing anything or generating Terraform. Halt on any failure.**

```bash
# Validate subdomain: lowercase alphanumeric + hyphens, no leading/trailing hyphen, max 63 chars
if ! echo "$SUBDOMAIN" | grep -qE '^[a-z0-9][a-z0-9-]{0,61}[a-z0-9]$'; then
  echo "ERROR: Invalid subdomain '$SUBDOMAIN'."
  echo "Must be lowercase letters, numbers, and hyphens only. No leading/trailing hyphens. Max 63 chars."
  exit 1
fi

# Validate domain: basic FQDN — labels separated by dots, each label alphanumeric + hyphens
if ! echo "$DOMAIN" | grep -qE '^([a-z0-9][a-z0-9-]{0,61}[a-z0-9]\.)+[a-z]{2,}$'; then
  echo "ERROR: Invalid domain '$DOMAIN'."
  echo "Must be a valid fully-qualified domain name (e.g. example.com)."
  exit 1
fi

# Validate appPort: must be integer 1-65535
if ! echo "$APP_PORT" | grep -qE '^[0-9]+$' || [ "$APP_PORT" -lt 1 ] || [ "$APP_PORT" -gt 65535 ]; then
  echo "ERROR: Invalid app port '$APP_PORT'. Must be a number between 1 and 65535."
  exit 1
fi

# Validate certbotEmail: basic email format
if ! echo "$CERTBOT_EMAIL" | grep -qE '^[^@]+@[^@]+\.[^@]+$'; then
  echo "ERROR: Invalid email '$CERTBOT_EMAIL'."
  exit 1
fi

# Validate sshCidr: basic CIDR format
if ! echo "$SSH_CIDR" | grep -qE '^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$'; then
  echo "ERROR: Invalid CIDR '$SSH_CIDR'. Must be in format x.x.x.x/n"
  exit 1
fi

# Validate cloudflareZoneId: 32 hex chars
if ! echo "$CF_ZONE_ID" | grep -qE '^[a-f0-9]{32}$'; then
  echo "ERROR: Invalid Cloudflare Zone ID. Must be a 32-character hex string."
  exit 1
fi
```

### Write resolved config to .state.json

Only write fields NOT sourced from env vars:

```bash
STATE_FILE="docs/c4flow/.state.json"
EXISTING=$(cat "$STATE_FILE")

# Build infraConfig — only include fields explicitly provided by user (not from env vars)
# DOMAIN_EXPLICIT, CF_ZONE_ID_EXPLICIT are set only when user typed the value (not from env)
NEW_STATE=$(echo "$EXISTING" | jq \
  --arg subdomain "$SUBDOMAIN" \
  --arg awsRegion "$AWS_REGION" \
  --argjson appPort "$APP_PORT" \
  --arg sshCidr "$SSH_CIDR" \
  --arg certbotEmail "$CERTBOT_EMAIL" \
  --arg domain "${DOMAIN_EXPLICIT:-}" \
  --arg cfZoneId "${CF_ZONE_ID_EXPLICIT:-}" \
  '.infraConfig = {
    subdomain: $subdomain,
    awsRegion: $awsRegion,
    appPort: $appPort,
    sshCidr: $sshCidr,
    certbotEmail: $certbotEmail
  }
  | if $domain != "" then .infraConfig.domain = $domain else . end
  | if $cfZoneId != "" then .infraConfig.cloudflareZoneId = $cfZoneId else . end')

echo "$NEW_STATE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
```

---

## Step 3: Generate Terraform Files

Create directory and gitignore **first**:

```bash
TF_DIR="docs/c4flow/terraform/${FEATURE_SLUG}"
mkdir -p "$TF_DIR"

# SECURITY: gitignore the entire terraform directory to prevent committing
# state files (contain SSH private key), plan artifacts, and variable files.
cat > "$TF_DIR/.gitignore" <<'EOF'
# Terraform state — contains SSH private key in plaintext
*.tfstate
*.tfstate.backup

# Terraform plan artifact — contains sensitive state snapshot
tfplan
tfplan.out

# Terraform provider cache
.terraform/
.terraform.lock.hcl

# Variable files — contain infra topology (zone IDs, etc.)
*.tfvars
*.tfvars.json
EOF
```

### `variables.tf`

```hcl
variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "domain" {
  description = "Root domain (e.g. example.com)"
  type        = string
}

variable "subdomain" {
  description = "Subdomain prefix (e.g. my-app)"
  type        = string
}

variable "app_port" {
  description = "Application port on EC2"
  type        = number
  default     = 3000
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for the domain"
  type        = string
}

variable "ssh_cidr" {
  description = "CIDR block allowed to SSH to the EC2 instance"
  type        = string
}

variable "certbot_email" {
  description = "Email for Let's Encrypt certificate notifications"
  type        = string
}
```

### `main.tf`

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "cloudflare" {
  # Reads CLOUDFLARE_API_TOKEN from environment automatically
}

# --- SSH Key ---

resource "tls_private_key" "app" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "app" {
  key_name   = "${var.subdomain}-key"
  public_key = tls_private_key.app.public_key_openssh
}

# --- Networking ---

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = { Name = "${var.subdomain}-vpc" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.subdomain}-igw" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.subdomain}-public" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = { Name = "${var.subdomain}-rt" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "app" {
  name   = "${var.subdomain}-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "SSH from trusted CIDR only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- EC2 ---

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_instance" "app" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.app.id]
  key_name               = aws_key_pair.app.key_name

  # NOTE: Terraform variables interpolated here are validated before reaching
  # this point (Step 2). subdomain and domain are restricted to [a-z0-9-] and
  # valid FQDN characters respectively — no shell metacharacters allowed.
  user_data = <<-USERDATA
    #!/bin/bash
    set -euo pipefail

    # Vars baked in at provision time (validated: alphanumeric + hyphens only)
    SUBDOMAIN="${var.subdomain}"
    DOMAIN="${var.domain}"
    APP_PORT="${var.app_port}"
    FQDN="$${SUBDOMAIN}.$${DOMAIN}"
    CERTBOT_EMAIL="${var.certbot_email}"

    # Update system
    dnf update -y

    # Install nginx
    dnf install -y nginx
    systemctl start nginx
    systemctl enable nginx

    # Install certbot (AL2023 ships certbot in the standard repos)
    dnf install -y certbot python3-certbot-nginx

    # Write initial HTTP-only config for certbot ACME challenge
    # Use printf to avoid heredoc quoting issues
    printf 'server {\n    listen 80;\n    server_name %s;\n    location /.well-known/acme-challenge/ { root /var/www/html; }\n    location / { return 301 https://$host$request_uri; }\n}\n' \
      "$FQDN" > "/etc/nginx/conf.d/$${SUBDOMAIN}.conf"

    nginx -s reload

    # Wait for DNS propagation (Cloudflare proxied records)
    echo "Waiting 60s for DNS propagation..."
    sleep 60

    # Obtain Let's Encrypt certificate with retry
    CERT_SUCCESS=false
    for i in 1 2 3; do
      if certbot --nginx -d "$FQDN" \
          --non-interactive --agree-tos \
          -m "$CERTBOT_EMAIL" \
          --redirect; then
        CERT_SUCCESS=true
        break
      fi
      echo "certbot attempt $i failed, retrying in 30s..."
      sleep 30
    done

    # Write final HTTPS reverse proxy config
    cat > "/etc/nginx/conf.d/$${SUBDOMAIN}.conf" <<NGINXEOF
    server {
        listen 80;
        server_name $FQDN;
        return 301 https://\$host\$request_uri;
    }

    server {
        listen 443 ssl;
        server_name $FQDN;

        ssl_certificate     /etc/letsencrypt/live/$FQDN/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/$FQDN/privkey.pem;
        ssl_protocols       TLSv1.2 TLSv1.3;
        ssl_ciphers         HIGH:!aNULL:!MD5;

        location / {
            proxy_pass         http://127.0.0.1:$APP_PORT;
            proxy_http_version 1.1;
            proxy_set_header   Upgrade \$http_upgrade;
            proxy_set_header   Connection 'upgrade';
            proxy_set_header   Host \$host;
            proxy_set_header   X-Real-IP \$remote_addr;
            proxy_set_header   X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header   X-Forwarded-Proto \$scheme;
            proxy_cache_bypass \$http_upgrade;
        }
    }
    NGINXEOF

    nginx -s reload

    # Set up certbot auto-renewal
    echo "0 12 * * * root /usr/bin/certbot renew --quiet" > /etc/cron.d/certbot-renew
  USERDATA

  tags = { Name = "${var.subdomain}-app" }
}

resource "aws_eip" "app" {
  instance = aws_instance.app.id
  domain   = "vpc"
  tags     = { Name = "${var.subdomain}-eip" }
}

# --- Cloudflare DNS ---

resource "cloudflare_record" "app" {
  zone_id = var.cloudflare_zone_id
  name    = var.subdomain
  value   = aws_eip.app.public_ip
  type    = "A"
  proxied = true
}
```

### `outputs.tf`

```hcl
output "ec2_host" {
  description = "EC2 Elastic IP address"
  value       = aws_eip.app.public_ip
}

output "ssh_private_key" {
  description = "SSH private key for EC2 access"
  value       = tls_private_key.app.private_key_pem
  sensitive   = true
}

output "fqdn" {
  description = "Fully qualified domain name"
  value       = "${var.subdomain}.${var.domain}"
}
```

### `terraform.tfvars`

Write resolved values. This file is gitignored by the `.gitignore` generated above:

```hcl
aws_region         = "{awsRegion}"
domain             = "{domain}"
subdomain          = "{subdomain}"
app_port           = {appPort}
cloudflare_zone_id = "{cloudflareZoneId}"
ssh_cidr           = "{sshCidr}"
certbot_email      = "{certbotEmail}"
```

---

## Step 4: Terraform Apply

```bash
TF_DIR="docs/c4flow/terraform/${FEATURE_SLUG}"
cd "$TF_DIR"

# Init — suppress verbose plugin download output
echo "=== terraform init ==="
terraform init -input=false 2>&1 | grep -E '(Initializing|Installing|provider|Error|Warning)' || true
echo "Init complete."

# Plan — write to artifact, show summary only
echo "=== terraform plan ==="
terraform plan -input=false -out=tfplan

# Extract resource count (never shows secrets)
PLAN_SUMMARY=$(terraform show -no-color tfplan 2>/dev/null | grep "^Plan:" | head -1)
echo ""
echo "$PLAN_SUMMARY"
echo ""

# Confirm
read -p "Apply? [yes/N] " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "Apply cancelled. Run /c4flow:infra again when ready."
  # Clean up plan artifact
  rm -f tfplan
  exit 0
fi

# Apply
echo "=== terraform apply ==="
terraform apply -input=false -auto-approve tfplan

# Clean up plan artifact immediately after apply (contains sensitive state snapshot)
rm -f tfplan

echo "Apply complete."
```

---

## Step 5: Push GitHub Secrets

**SECURITY**: Never capture the SSH private key into a shell variable or let it appear in command output. Pipe directly from `terraform output -raw` to `gh secret set`. The key passes through the pipe but Claude never reads it.

```bash
# Check gh auth first
if ! gh auth status > /dev/null 2>&1; then
  echo "ERROR: gh CLI not authenticated."
  echo "Run: gh auth login"
  echo "Then re-run /c4flow:infra to push GitHub Secrets."
  exit 1
fi

echo "Pushing GitHub Secrets..."

# Non-sensitive — safe to capture for infraState write later
EC2_HOST=$(terraform output -raw ec2_host)
FQDN=$(terraform output -raw fqdn)

# SECURITY: SSH private key piped directly — never assigned to a variable,
# never appears in stdout, never enters Claude's context window.
terraform output -raw ssh_private_key | gh secret set EC2_SSH_PRIVATE_KEY

# Non-sensitive secrets
echo "$EC2_HOST"   | gh secret set AWS_EC2_HOST
echo "$AWS_REGION" | gh secret set AWS_REGION
echo "$FQDN"       | gh secret set DEPLOY_DOMAIN

echo "GitHub Secrets configured: AWS_EC2_HOST, AWS_REGION, EC2_SSH_PRIVATE_KEY, DEPLOY_DOMAIN"
```

---

## Step 6: SSL Verification

```bash
echo "Verifying SSL for https://$FQDN ..."

HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  --max-time 30 \
  --max-filesize 1024 \
  "https://$FQDN" 2>/dev/null || echo "000")

if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "301" ] || [ "$HTTP_STATUS" = "302" ]; then
  SSL_CONFIGURED="true"
  echo "SSL verified (HTTP $HTTP_STATUS)"
else
  SSL_CONFIGURED="false"
  echo "WARNING: SSL not yet responding (HTTP $HTTP_STATUS)."
  echo "This is normal — DNS propagation and certbot can take a few minutes."
  echo "You can proceed to /c4flow:deploy. The cert will be ready by deploy time."
fi
```

---

## Step 7: Write infraState to .state.json

```bash
APPLIED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TF_DIR_PATH="docs/c4flow/terraform/${FEATURE_SLUG}"
STATE_FILE="docs/c4flow/.state.json"

# Quote SSL_CONFIGURED for safe jq injection
SSL_BOOL=$([ "$SSL_CONFIGURED" = "true" ] && echo "true" || echo "false")

jq \
  --arg appliedAt "$APPLIED_AT" \
  --arg ec2Host "$EC2_HOST" \
  --arg fqdn "$FQDN" \
  --argjson appPort "$APP_PORT" \
  --arg tfDir "$TF_DIR_PATH" \
  --argjson sslConfigured "$SSL_BOOL" \
  '.infraState = {
    appliedAt: $appliedAt,
    ec2Host: $ec2Host,
    fqdn: $fqdn,
    appPort: $appPort,
    tfDir: $tfDir,
    nginxConfigured: true,
    sslConfigured: $sslConfigured,
    githubSecretsConfigured: true
  }' "$STATE_FILE" > "${STATE_FILE}.tmp" \
  && mv "${STATE_FILE}.tmp" "$STATE_FILE"

echo ""
echo "=== Infrastructure Provisioned ==="
echo "  EC2 Host:  $EC2_HOST"
echo "  Domain:    https://$FQDN"
echo "  SSH CIDR:  $SSH_CIDR"
echo "  SSL:       $([ "$SSL_BOOL" = "true" ] && echo "Ready" || echo "Provisioning (~5 min)")"
echo ""
echo "NOTE: Terraform state is stored locally at $TF_DIR_PATH/terraform.tfstate"
echo "      It is gitignored. Do not delete this directory — it tracks provisioned resources."
echo ""
echo "Next: Run /c4flow:deploy to set up CI/CD."
```

---

## Key Security Constraints

- **Never print sensitive env var values** — only acknowledge `[configured via env]`
- **Never write** `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `CLOUDFLARE_API_TOKEN` to any file
- **Never capture `terraform output -json`** — always use `terraform output -raw <name>` to target specific outputs
- **SSH private key must only flow through a pipe** directly to `gh secret set` — never assigned to a shell variable
- **Validate subdomain and domain** before any shell interpolation — both restricted to safe character sets
- **Terraform state is local and gitignored** — warn user not to delete `docs/c4flow/terraform/`
- **`tfplan` artifact deleted immediately** after apply — contains sensitive state snapshot
