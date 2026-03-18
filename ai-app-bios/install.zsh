#!/usr/bin/env zsh
# install.zsh — Install ai-app-bios tools as global commands.
# Installs: boot-app, sync-os
# Usage: ./install.zsh
# Run once from the ai-app-bios directory.

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
BIN_DIR="${HOME}/.local/bin"

mkdir -p "$BIN_DIR"

# ─── boot-app ──────────────────────────────────────────────────────────────────
BOOT_TARGET="${BIN_DIR}/boot-app"
ln -sf "${SCRIPT_DIR}/boot-app.zsh" "$BOOT_TARGET"
chmod +x "${SCRIPT_DIR}/boot-app.zsh" "$BOOT_TARGET"
printf "✓ Installed: %s → %s\n" "$BOOT_TARGET" "${SCRIPT_DIR}/boot-app.zsh"

BOOT_ALIAS="alias boot.app='${SCRIPT_DIR}/boot-app.zsh'"
if grep -qF "alias boot.app=" "${HOME}/.zshrc" 2>/dev/null; then
  printf "✓ Alias already in ~/.zshrc: boot.app\n"
else
  printf "\n%s\n" "$BOOT_ALIAS" >> "${HOME}/.zshrc"
  printf "✓ Added alias to ~/.zshrc: boot.app\n"
fi

# ─── sync-os ───────────────────────────────────────────────────────────────────
SYNC_TARGET="${BIN_DIR}/sync-os"
ln -sf "${SCRIPT_DIR}/sync-os.zsh" "$SYNC_TARGET"
chmod +x "${SCRIPT_DIR}/sync-os.zsh" "$SYNC_TARGET"
printf "✓ Installed: %s → %s\n" "$SYNC_TARGET" "${SCRIPT_DIR}/sync-os.zsh"

# sync.os     → Claude Code yolo mode  (non-interactive, dangerously-skip-permissions)
# sync.os.dev → Devin bypass mode      (interactive, --permission-mode dangerous)
SYNC_ALIAS_CLY="alias sync.os='${SCRIPT_DIR}/sync-os.zsh --cly'"
SYNC_ALIAS_DEV="alias sync.os.dev='${SCRIPT_DIR}/sync-os.zsh --dev'"

if grep -qF "alias sync.os=" "${HOME}/.zshrc" 2>/dev/null; then
  printf "✓ Alias already in ~/.zshrc: sync.os\n"
else
  printf "\n%s\n" "$SYNC_ALIAS_CLY" >> "${HOME}/.zshrc"
  printf "✓ Added alias to ~/.zshrc: sync.os\n"
fi

if grep -qF "alias sync.os.dev=" "${HOME}/.zshrc" 2>/dev/null; then
  printf "✓ Alias already in ~/.zshrc: sync.os.dev\n"
else
  printf "%s\n" "$SYNC_ALIAS_DEV" >> "${HOME}/.zshrc"
  printf "✓ Added alias to ~/.zshrc: sync.os.dev\n"
fi

# ─── PATH check ────────────────────────────────────────────────────────────────
if ! echo "$PATH" | tr ':' '\n' | grep -qx "${BIN_DIR}"; then
  printf "\n⚠  %s is not in your PATH.\n" "$BIN_DIR"
  printf "   Add this to your ~/.zshrc:\n\n"
  printf "     export PATH=\"\$HOME/.local/bin:\$PATH\"\n\n"
  printf "   Then run: source ~/.zshrc\n\n"
else
  printf "\n✓ Ready. Available commands:\n"
  printf "  boot-app          — bootstrap a new project\n"
  printf "  boot.app          — alias for boot-app\n"
  printf "  sync-os --cly     — sync fork improvements to upstream (Claude yolo)\n"
  printf "  sync-os --dev     — sync fork improvements to upstream (Devin interactive)\n"
  printf "  sync.os           — alias for sync-os --cly\n"
  printf "  sync.os.dev       — alias for sync-os --dev\n\n"
  printf "  Run: source ~/.zshrc\n\n"
fi
