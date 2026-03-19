#!/usr/bin/env bash
# C4Flow installer for Antigravity IDE
# Usage:
#   bash install.sh          # workspace install (current directory)
#   bash install.sh --global # global install (all workspaces)

set -e

REPO_URL="https://github.com/tunneleven/C4Flow.git"
CLONE_DIR="$HOME/.antigravity/c4flow"

GLOBAL=false
for arg in "$@"; do
  [[ "$arg" == "--global" ]] && GLOBAL=true
done

# Clone or update
if [ -d "$CLONE_DIR/.git" ]; then
  echo "→ Updating existing C4Flow clone..."
  git -C "$CLONE_DIR" pull --ff-only
else
  echo "→ Cloning C4Flow..."
  git clone "$REPO_URL" "$CLONE_DIR"
fi

if $GLOBAL; then
  SKILLS_DIR="$HOME/.gemini/antigravity/skills"
  LINK="$SKILLS_DIR/c4flow"
  mkdir -p "$SKILLS_DIR"
  echo "→ Installing globally to $LINK"
else
  SKILLS_DIR="$(pwd)/.agents/skills"
  LINK="$SKILLS_DIR/c4flow"
  mkdir -p "$SKILLS_DIR"
  echo "→ Installing to workspace $LINK"
fi

# Remove existing link/dir if present
[ -e "$LINK" ] || [ -L "$LINK" ] && rm -rf "$LINK"

ln -s "$CLONE_DIR/skills" "$LINK"
echo "✓ C4Flow skills linked at $LINK"
echo ""
echo "Restart Antigravity to pick up the new skills."
