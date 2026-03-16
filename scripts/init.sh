#!/usr/bin/env bash
# c4flow init — install and configure dependencies for C4Flow workflow
# Usage: scripts/init.sh [--skip-beads] [--prefix PREFIX]
#
# This script:
#   1. Detects OS and architecture
#   2. Checks/installs Dolt (required by Beads)
#   3. Checks/installs Beads (bd)
#   4. Runs bd init in the current project
#   5. Verifies with bd doctor

set -euo pipefail

# Colors (disable if not a terminal)
if [ -t 1 ]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  BLUE='\033[0;34m'
  NC='\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

info()  { echo -e "${BLUE}[c4flow]${NC} $*"; }
ok()    { echo -e "${GREEN}[c4flow]${NC} $*"; }
warn()  { echo -e "${YELLOW}[c4flow]${NC} $*"; }
err()   { echo -e "${RED}[c4flow]${NC} $*" >&2; }

# Parse args
SKIP_BEADS=false
PREFIX=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-beads) SKIP_BEADS=true; shift ;;
    --prefix)     PREFIX="$2"; shift 2 ;;
    --prefix=*)   PREFIX="${1#*=}"; shift ;;
    -h|--help)
      echo "Usage: scripts/init.sh [--skip-beads] [--prefix PREFIX]"
      echo ""
      echo "Options:"
      echo "  --skip-beads    Skip Beads (bd) installation"
      echo "  --prefix NAME   Set beads issue prefix (default: directory name)"
      echo "  -h, --help      Show this help"
      exit 0
      ;;
    *) err "Unknown option: $1"; exit 1 ;;
  esac
done

# Detect OS and architecture
detect_platform() {
  OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
  ARCH="$(uname -m)"

  case "$OS" in
    linux*)  OS="linux" ;;
    darwin*) OS="darwin" ;;
    *)       err "Unsupported OS: $OS"; exit 1 ;;
  esac

  case "$ARCH" in
    x86_64|amd64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    *)             err "Unsupported architecture: $ARCH"; exit 1 ;;
  esac

  info "Platform: $OS/$ARCH"
}

# Check if a command exists
has() { command -v "$1" &>/dev/null; }

# Check if we're in a git repo
check_git() {
  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    err "Not inside a git repository. Please run from a git project root."
    exit 1
  fi
  ok "Git repository detected"
}

# ─── Dolt ────────────────────────────────────────────────────────────────────

install_dolt() {
  if has dolt; then
    ok "Dolt already installed: $(dolt version 2>&1 | head -1)"
    return 0
  fi

  info "Installing Dolt..."

  if has brew; then
    info "Installing via Homebrew..."
    brew install dolt
  elif has curl; then
    info "Installing via install script..."
    sudo bash -c 'curl -L https://github.com/dolthub/dolt/releases/latest/download/install.sh | bash'
  else
    err "Cannot install Dolt: no brew or curl found."
    err "Install manually: https://docs.dolthub.com/introduction/installation"
    exit 1
  fi

  if has dolt; then
    ok "Dolt installed: $(dolt version 2>&1 | head -1)"
  else
    err "Dolt installation failed"
    exit 1
  fi
}

# ─── Beads (bd) ──────────────────────────────────────────────────────────────

install_beads() {
  if has bd; then
    ok "Beads already installed: $(bd --version 2>&1)"
    return 0
  fi

  info "Installing Beads (bd)..."

  if has curl; then
    curl -sSL https://raw.githubusercontent.com/steveyegge/beads/main/scripts/install.sh | bash
  elif has npm; then
    info "Installing via npm..."
    npm install -g @beads/bd
  else
    err "Cannot install Beads: no curl or npm found."
    err "Install manually: https://github.com/steveyegge/beads"
    exit 1
  fi

  # Reload PATH in case install put it somewhere new
  export PATH="$HOME/.local/bin:$HOME/.beads/bin:$PATH"

  if has bd; then
    ok "Beads installed: $(bd --version 2>&1)"
  else
    err "Beads installation failed. Check https://github.com/steveyegge/beads"
    exit 1
  fi
}

# ─── bd init ─────────────────────────────────────────────────────────────────

init_beads() {
  # Check if already initialized
  if [ -d ".beads" ] && [ -f ".beads/metadata.json" ]; then
    ok "Beads already initialized in this project"
    return 0
  fi

  info "Initializing Beads in project..."

  local init_args=()
  if [ -n "$PREFIX" ]; then
    init_args+=(--prefix "$PREFIX")
  fi

  if bd init "${init_args[@]}" 2>&1; then
    ok "Beads initialized successfully"
  else
    warn "bd init had issues. Running bd doctor..."
    bd doctor --fix --yes 2>&1 || true
  fi
}

# ─── Verify ──────────────────────────────────────────────────────────────────

verify() {
  info "Verifying installation..."
  echo ""

  local all_ok=true

  if has git; then
    echo -e "  ${GREEN}✓${NC} git: $(git --version)"
  else
    echo -e "  ${RED}✗${NC} git: not found"
    all_ok=false
  fi

  if has dolt; then
    echo -e "  ${GREEN}✓${NC} dolt: $(dolt version 2>&1 | head -1)"
  else
    echo -e "  ${RED}✗${NC} dolt: not found"
    all_ok=false
  fi

  if has bd; then
    echo -e "  ${GREEN}✓${NC} bd: $(bd --version 2>&1)"
  else
    if [ "$SKIP_BEADS" = true ]; then
      echo -e "  ${YELLOW}⊘${NC} bd: skipped"
    else
      echo -e "  ${RED}✗${NC} bd: not found"
      all_ok=false
    fi
  fi

  if [ -d ".beads" ]; then
    echo -e "  ${GREEN}✓${NC} .beads/ initialized"
  else
    if [ "$SKIP_BEADS" = true ]; then
      echo -e "  ${YELLOW}⊘${NC} .beads/ skipped"
    else
      echo -e "  ${RED}✗${NC} .beads/ not found"
      all_ok=false
    fi
  fi

  echo ""

  if [ "$all_ok" = true ]; then
    ok "All checks passed! Project is ready for C4Flow."
  else
    warn "Some checks failed. See above for details."
    return 1
  fi
}

# ─── Main ────────────────────────────────────────────────────────────────────

main() {
  echo ""
  echo -e "${BLUE}━━━ C4Flow Init ━━━${NC}"
  echo ""

  detect_platform
  check_git

  # Always need Dolt (beads dependency)
  if [ "$SKIP_BEADS" = false ]; then
    install_dolt
    install_beads
    init_beads
  else
    info "Skipping Beads installation (--skip-beads)"
  fi

  echo ""
  verify
  echo ""
}

main "$@"
