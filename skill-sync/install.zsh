#!/usr/bin/env zsh
# install.zsh — Install skill-sync as a global command.
# Symlinks skill-sync.zsh → ~/.local/bin/skill-sync and makes it executable.
# Run once from the skill-sync directory.

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
BIN_DIR="${HOME}/.local/bin"

mkdir -p "$BIN_DIR"

TARGET="${BIN_DIR}/skill-sync"
ln -sf "${SCRIPT_DIR}/skill-sync.zsh" "$TARGET"
chmod +x "${SCRIPT_DIR}/skill-sync.zsh" "$TARGET"
chmod +x "${SCRIPT_DIR}/skill_sync_catalog.py"

printf "✓ Installed: %s → %s\n" "$TARGET" "${SCRIPT_DIR}/skill-sync.zsh"

if [[ ":${PATH}:" != *":${BIN_DIR}:"* ]]; then
  printf "\n⚠ %s is not on PATH. Add this to your ~/.zshrc:\n" "$BIN_DIR"
  printf "    export PATH=\"%s:\$PATH\"\n" "$BIN_DIR"
fi

cat <<'EOF'

Quick check:
  command -v skill-sync && skill-sync --help

Usage:
  skill-sync <source-path> [skill-name] [--agent claude|codex|devin] [--yolo]
EOF
