---
name: c4flow:infra-destroy
description: Tear down all AWS infrastructure provisioned by c4flow:infra — destroys EC2, VPC, Elastic IP, Cloudflare DNS record, and removes associated GitHub Secrets. Clears infraState from .state.json. Requires explicit double-confirmation before any destructive action. Use when the user runs /c4flow:infra-destroy or asks to "destroy infra", "tear down", or "clean up AWS resources".
---

# /c4flow:infra-destroy — Infrastructure Teardown

**Phase**: Release (cleanup)
**Agent type**: Main agent (interactive)

Destroys all AWS and Cloudflare resources created by `/c4flow:infra`, removes GitHub Secrets, and resets the infra state so you can provision fresh infrastructure later.

> **This is irreversible.** EC2 instances, VPCs, Elastic IPs, and DNS records will be permanently deleted. The Terraform state file is also removed. You cannot undo this without re-running `/c4flow:infra`.

---

## Step 1: Read and Validate State

Read `docs/c4flow/.state.json`:

```bash
STATE_FILE="docs/c4flow/.state.json"

if [ ! -f "$STATE_FILE" ]; then
  echo "No .state.json found. Nothing to destroy."
  exit 0
fi

FEATURE_SLUG=$(jq -r '.feature.slug // empty' "$STATE_FILE")
APPLIED_AT=$(jq -r '.infraState.appliedAt // empty' "$STATE_FILE")
EC2_HOST=$(jq -r '.infraState.ec2Host // empty' "$STATE_FILE")
FQDN=$(jq -r '.infraState.fqdn // empty' "$STATE_FILE")
TF_DIR=$(jq -r '.infraState.tfDir // empty' "$STATE_FILE")
```

**If `infraState.appliedAt` is absent**: there is no provisioned infrastructure to destroy.

```
No infrastructure has been provisioned for this feature.
infraState is absent in .state.json — nothing to destroy.
```

Exit cleanly.

**If `TF_DIR` is absent but `infraState` exists**: Terraform state directory is missing but infra may have been provisioned. Show warning and offer to clean up state only (Step 6 — skip Terraform steps).

---

## Step 2: Show Destruction Summary

Display exactly what will be destroyed before asking for confirmation:

```
=== INFRASTRUCTURE DESTROY SUMMARY ===

Feature:    {feature.slug}
Provisioned: {infraState.appliedAt}

AWS resources to be destroyed (via terraform destroy):
  - EC2 instance       ({infraState.ec2Host})
  - Elastic IP         ({infraState.ec2Host})
  - VPC + subnets + route tables + internet gateway
  - Security group
  - SSH key pair

Cloudflare DNS record to be destroyed:
  - A record: {infraState.fqdn} → {infraState.ec2Host}

GitHub Secrets to be removed:
  - AWS_EC2_HOST
  - AWS_REGION
  - EC2_SSH_PRIVATE_KEY
  - DEPLOY_DOMAIN

Terraform state files to be deleted:
  - {infraState.tfDir}/terraform.tfstate
  - {infraState.tfDir}/terraform.tfstate.backup
  - {infraState.tfDir}/.terraform/

After destroy:
  - infraState will be cleared from .state.json
  - You can re-provision by running /c4flow:infra again

=====================================
```

---

## Step 3: Double Confirmation

**This is a destructive, irreversible action. Require two explicit confirmations.**

```bash
# First confirmation
echo ""
echo "WARNING: This will permanently delete all infrastructure listed above."
echo "Running applications will go offline immediately."
echo ""
read -p "Type 'destroy' to confirm: " CONFIRM1

if [ "$CONFIRM1" != "destroy" ]; then
  echo "Cancelled — you must type 'destroy' exactly."
  exit 0
fi

# Second confirmation — name the feature slug
echo ""
read -p "Confirm feature name (type '$FEATURE_SLUG' to proceed): " CONFIRM2

if [ "$CONFIRM2" != "$FEATURE_SLUG" ]; then
  echo "Cancelled — feature name did not match."
  exit 0
fi

echo ""
echo "Confirmed. Proceeding with destroy..."
```

---

## Step 4: Terraform Destroy

```bash
TF_DIR=$(jq -r '.infraState.tfDir' "$STATE_FILE")

if [ ! -d "$TF_DIR" ]; then
  echo "WARNING: Terraform directory not found at $TF_DIR"
  echo "Cannot run terraform destroy — directory is missing."
  echo "Skipping to GitHub Secrets cleanup..."
else
  cd "$TF_DIR"

  # Verify state file exists
  if [ ! -f "terraform.tfstate" ]; then
    echo "WARNING: terraform.tfstate not found in $TF_DIR"
    echo "Resources may have already been destroyed, or state was lost."
    read -p "Continue with cleanup (GitHub Secrets + state reset)? [y/N] " SKIP_TF
    if [ "$SKIP_TF" != "y" ] && [ "$SKIP_TF" != "Y" ]; then
      echo "Cancelled."
      exit 0
    fi
  else
    echo "=== terraform destroy ==="
    terraform destroy -input=false -auto-approve

    DESTROY_EXIT=$?
    if [ $DESTROY_EXIT -ne 0 ]; then
      echo ""
      echo "ERROR: terraform destroy exited with code $DESTROY_EXIT"
      echo "Some resources may not have been destroyed."
      echo "Check the AWS console and Cloudflare dashboard to verify."
      echo ""
      read -p "Continue with GitHub Secrets cleanup and state reset anyway? [y/N] " CONTINUE
      if [ "$CONTINUE" != "y" ] && [ "$CONTINUE" != "Y" ]; then
        echo "Stopped. Fix terraform issues and re-run /c4flow:infra-destroy."
        exit 1
      fi
    else
      echo "Terraform destroy complete."
    fi
  fi
fi
```

---

## Step 5: Remove GitHub Secrets

```bash
if ! gh auth status > /dev/null 2>&1; then
  echo "WARNING: gh CLI not authenticated — skipping GitHub Secrets removal."
  echo "Remove these secrets manually in GitHub → Settings → Secrets and variables → Actions:"
  echo "  - AWS_EC2_HOST"
  echo "  - AWS_REGION"
  echo "  - EC2_SSH_PRIVATE_KEY"
  echo "  - DEPLOY_DOMAIN"
else
  echo "Removing GitHub Secrets..."
  for SECRET in AWS_EC2_HOST AWS_REGION EC2_SSH_PRIVATE_KEY DEPLOY_DOMAIN; do
    if gh secret delete "$SECRET" 2>/dev/null; then
      echo "  ✓ Removed $SECRET"
    else
      echo "  - $SECRET not found (already removed or never set)"
    fi
  done
fi
```

---

## Step 6: Delete Terraform State Files

```bash
TF_DIR=$(jq -r '.infraState.tfDir' "$STATE_FILE")

if [ -d "$TF_DIR" ]; then
  echo "Removing Terraform state files..."

  # State files contain SSH private key in plaintext — must be deleted
  rm -f "$TF_DIR/terraform.tfstate"
  rm -f "$TF_DIR/terraform.tfstate.backup"
  rm -f "$TF_DIR/tfplan"
  rm -f "$TF_DIR/tfplan.out"
  rm -rf "$TF_DIR/.terraform"

  # Keep the .tf source files — useful for debugging what was provisioned
  # (they contain no secrets; all sensitive values were in .tfvars which is gitignored)
  echo "  ✓ State files deleted (Terraform source files preserved in $TF_DIR)"
fi
```

---

## Step 7: Clear infraState from .state.json

```bash
CLEARED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

jq \
  --arg clearedAt "$CLEARED_AT" \
  'del(.infraState) | .infraConfig.destroyedAt = $clearedAt' \
  "$STATE_FILE" > "${STATE_FILE}.tmp" \
  && mv "${STATE_FILE}.tmp" "$STATE_FILE"

echo ""
echo "=== Infrastructure Destroyed ==="
echo "  Feature:   $FEATURE_SLUG"
echo "  Host:      $EC2_HOST (no longer accessible)"
echo "  Domain:    https://$FQDN (DNS record removed)"
echo "  Destroyed: $CLEARED_AT"
echo ""
echo "infraState cleared from .state.json."
echo ""
echo "To provision fresh infrastructure, run /c4flow:infra"
```

---

## Key Safety Constraints

- **Double confirmation required**: user must type `destroy` AND the feature slug before anything is deleted
- **`terraform destroy` is run first** — if it fails, the user is asked whether to continue cleanup; partial state is never silently discarded
- **Terraform source `.tf` files are preserved** after destroy — only state files and the provider cache are deleted. This lets you inspect what was provisioned and re-apply if needed.
- **GitHub Secrets removal is best-effort** — if `gh` is not authenticated, instructions are printed for manual removal instead of failing the entire operation
- **`infraState` is cleared from `.state.json`** only after all prior steps complete (or the user explicitly chooses to continue past errors)
- **`infraConfig.destroyedAt` is written** so there is a permanent record of when infra was torn down, even after `infraState` is gone
