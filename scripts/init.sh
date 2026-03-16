#!/usr/bin/env bash
# c4flow init — install and configure dependencies for C4Flow workflow
# Usage: scripts/init.sh [--skip-beads] [--prefix PREFIX] [--remote URL]
#
# Installs Dolt + Beads, runs bd init, configures DoltHub sync.
# Target: complete in under 30 seconds.

set -euo pipefail

# Colors (disable if not a terminal)
if [ -t 1 ]; then
  RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[0;33m' BLUE='\033[0;34m' NC='\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

info()  { echo -e "${BLUE}[c4flow]${NC} $*"; }
ok()    { echo -e "${GREEN}[c4flow]${NC} $*"; }
warn()  { echo -e "${YELLOW}[c4flow]${NC} $*"; }
err()   { echo -e "${RED}[c4flow]${NC} $*" >&2; }

# Run a command with a timeout (default 15s)
run_with_timeout() {
  local secs="${1:-15}"
  shift
  if command -v timeout &>/dev/null; then
    timeout "$secs" "$@" 2>&1
  else
    perl -e "alarm $ARGV[0]; exec @ARGV[1..$#ARGV]" "$secs" "$@" 2>&1
  fi
}

# Parse args
SKIP_BEADS=false
PREFIX=""
REMOTE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-beads) SKIP_BEADS=true; shift ;;
    --prefix)     PREFIX="$2"; shift 2 ;;
    --prefix=*)   PREFIX="${1#*=}"; shift ;;
    --remote)     REMOTE="$2"; shift 2 ;;
    --remote=*)   REMOTE="${1#*=}"; shift ;;
    -h|--help)
      echo "Usage: scripts/init.sh [--skip-beads] [--prefix PREFIX] [--remote URL]"
      echo ""
      echo "Options:"
      echo "  --skip-beads    Skip Beads (bd) installation"
      echo "  --prefix NAME   Set beads issue prefix (default: directory name)"
      echo "  --remote URL    DoltHub repo URL for auto-sync"
      echo "                  Accepts: https://www.dolthub.com/repositories/org/repo"
      echo "                       or: https://doltremoteapi.dolthub.com/org/repo"
      echo "  -h, --help      Show this help"
      exit 0
      ;;
    *) err "Unknown option: $1"; exit 1 ;;
  esac
done

has() { command -v "$1" &>/dev/null; }

# ─── Git ──────────────────────────────────────────────────────────────────────

check_git() {
  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    err "Not inside a git repository. Run from a git project root."
    exit 1
  fi
  ok "git: $(git --version)"
}

# ─── Dolt ─────────────────────────────────────────────────────────────────────

install_dolt() {
  if has dolt; then
    ok "dolt: $(dolt version 2>&1 | head -1)"
    return 0
  fi

  info "Installing Dolt..."
  if has brew; then
    brew install dolt
  elif has curl; then
    sudo bash -c 'curl -L https://github.com/dolthub/dolt/releases/latest/download/install.sh | bash'
  else
    err "Cannot install Dolt: no brew or curl. See https://docs.dolthub.com/introduction/installation"
    exit 1
  fi

  has dolt && ok "dolt: $(dolt version 2>&1 | head -1)" || { err "Dolt installation failed"; exit 1; }
}

# ─── Beads (bd) ───────────────────────────────────────────────────────────────

install_beads() {
  if has bd; then
    ok "bd: $(bd --version 2>&1)"
    return 0
  fi

  info "Installing Beads (bd)..."
  if has curl; then
    curl -sSL https://raw.githubusercontent.com/steveyegge/beads/main/scripts/install.sh | bash
  elif has npm; then
    npm install -g @beads/bd
  else
    err "Cannot install Beads: no curl or npm. See https://github.com/steveyegge/beads"
    exit 1
  fi

  export PATH="$HOME/.local/bin:$HOME/.beads/bin:$PATH"
  has bd && ok "bd: $(bd --version 2>&1)" || { err "Beads installation failed"; exit 1; }
}

# ─── bd init + Dolt server ────────────────────────────────────────────────────

init_beads() {
  # Already initialized?
  if [ -d ".beads" ] && [ -f ".beads/metadata.json" ]; then
    ok ".beads/ already initialized"
    ensure_dolt_server
    return 0
  fi

  info "Running bd init..."

  local init_args=()
  [ -n "$PREFIX" ] && init_args+=(--prefix "$PREFIX")

  # bd init with timeout (30s) — can hang if Dolt server has issues
  if run_with_timeout 30 bd init "${init_args[@]}"; then
    ok "bd init completed"
  else
    local exit_code=$?
    if [ $exit_code -eq 124 ]; then
      warn "bd init timed out (30s). Continuing with manual setup..."
    else
      warn "bd init exited with code $exit_code. Continuing..."
    fi
  fi

  if [ ! -d ".beads" ]; then
    err ".beads/ was not created. bd init failed."
    exit 1
  fi

  ensure_dolt_server
}

ensure_dolt_server() {
  # Use bd's own server management (bd dolt start/status)
  # This is the official way per Beads docs — NOT manual dolt sql-server

  # First check: can bd reach Dolt? (5s timeout)
  if run_with_timeout 5 bd list --json &>/dev/null; then
    ok "Dolt: connected (bd list OK)"
    return 0
  fi

  info "Dolt not responding. Starting via bd dolt start..."

  # Use bd dolt start (official command, handles port/pid/config)
  if run_with_timeout 10 bd dolt start &>/dev/null; then
    sleep 1
    if run_with_timeout 5 bd list --json &>/dev/null; then
      ok "Dolt: started via bd dolt start"
      return 0
    fi
  fi

  # Fallback: try triggering auto-start by just calling bd list
  # Per docs: "Server auto-starts when needed"
  info "Trying auto-start via bd list..."
  if run_with_timeout 10 bd list &>/dev/null; then
    ok "Dolt: auto-started"
    return 0
  fi

  warn "Dolt server could not start. Beads will work in degraded mode."
  warn "Manual fix: bd dolt start (or see bd dolt status)"
}

# ─── Verify ───────────────────────────────────────────────────────────────────

# ─── DoltHub Remote ───────────────────────────────────────────────────────────

# Convert DoltHub web URL to API URL
# https://www.dolthub.com/repositories/org/repo → https://doltremoteapi.dolthub.com/org/repo
normalize_dolthub_url() {
  local url="$1"

  # Already an API URL
  if [[ "$url" == *"doltremoteapi.dolthub.com"* ]]; then
    echo "$url"
    return
  fi

  # Web URL: https://www.dolthub.com/repositories/org/repo
  if [[ "$url" == *"dolthub.com/repositories/"* ]]; then
    local path="${url#*dolthub.com/repositories/}"
    # Strip trailing slash
    path="${path%/}"
    echo "https://doltremoteapi.dolthub.com/${path}"
    return
  fi

  # Short form: org/repo (no URL)
  if [[ "$url" != *"://"* ]] && [[ "$url" == *"/"* ]]; then
    echo "https://doltremoteapi.dolthub.com/${url}"
    return
  fi

  # Unknown format, pass through
  echo "$url"
}

setup_remote() {
  if [ -z "$REMOTE" ]; then
    return 0
  fi

  local api_url
  api_url=$(normalize_dolthub_url "$REMOTE")

  info "Configuring DoltHub remote: $api_url"

  # Add remote via bd (ensures both SQL server and CLI see it)
  if run_with_timeout 10 bd dolt remote add origin "$api_url"; then
    ok "Remote 'origin' added: $api_url"
  else
    # Remote may already exist, try removing first
    if run_with_timeout 5 bd dolt remote remove origin &>/dev/null; then
      if run_with_timeout 10 bd dolt remote add origin "$api_url"; then
        ok "Remote 'origin' updated: $api_url"
      else
        warn "Failed to add remote. Add manually: bd dolt remote add origin $api_url"
        return 1
      fi
    else
      warn "Failed to configure remote. Add manually: bd dolt remote add origin $api_url"
      return 1
    fi
  fi

  # Initial push to create the remote database
  info "Pushing to DoltHub..."
  if run_with_timeout 30 bd dolt push; then
    ok "Pushed to DoltHub successfully"
  else
    warn "Push failed. You may need to authenticate first:"
    warn "  dolt login"
    warn "Then retry: bd dolt push"
  fi
}

# ─── Verify ───────────────────────────────────────────────────────────────────

verify() {
  echo ""
  info "Verification:"

  local all_ok=true

  has git  && echo -e "  ${GREEN}✓${NC} git"  || { echo -e "  ${RED}✗${NC} git"; all_ok=false; }
  has dolt && echo -e "  ${GREEN}✓${NC} dolt" || { echo -e "  ${RED}✗${NC} dolt"; all_ok=false; }

  if [ "$SKIP_BEADS" = true ]; then
    echo -e "  ${YELLOW}⊘${NC} bd (skipped)"
    echo -e "  ${YELLOW}⊘${NC} .beads/ (skipped)"
  else
    has bd && echo -e "  ${GREEN}✓${NC} bd" || { echo -e "  ${RED}✗${NC} bd"; all_ok=false; }
    [ -d ".beads" ] && echo -e "  ${GREEN}✓${NC} .beads/" || { echo -e "  ${RED}✗${NC} .beads/"; all_ok=false; }

    # Quick connectivity check (5s timeout, uses bd list not bd doctor)
    if has bd && [ -d ".beads" ]; then
      if run_with_timeout 5 bd list --json &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} bd ↔ Dolt connected"
      else
        echo -e "  ${YELLOW}⚠${NC} bd ↔ Dolt not connected (run: bd dolt start)"
      fi

      # Show remote if configured
      if [ -n "$REMOTE" ]; then
        local api_url
        api_url=$(normalize_dolthub_url "$REMOTE")
        echo -e "  ${GREEN}✓${NC} remote: $api_url"
      fi
    fi
  fi

  echo ""
  if [ "$all_ok" = true ]; then
    ok "Ready! Run /c4flow to start a workflow."
  else
    warn "Some checks failed. See above."
    return 1
  fi
}

# ─── Main ─────────────────────────────────────────────────────────────────────

main() {
  echo ""
  echo -e "${BLUE}━━━ C4Flow Init ━━━${NC}"
  echo ""

  check_git

  if [ "$SKIP_BEADS" = false ]; then
    install_dolt
    install_beads
    init_beads
    setup_remote
  else
    info "Skipping Beads (--skip-beads)"
  fi

  verify
}

main "$@"
