#!/usr/bin/env zsh
# install.zsh — Install ai-app-bios tools as global commands.
# Installs: boot-app, sync-os, update-os, add-os
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
# sync.os.sup → Claude Code superpowers plugin mode (non-interactive, dangerously-skip-permissions + superpowers)
# sync.os.dev → Devin bypass mode      (interactive, --permission-mode dangerous)
SYNC_ALIAS_CLY="alias sync.os='${SCRIPT_DIR}/sync-os.zsh --cly'"
SYNC_ALIAS_SUP="alias sync.os.sup='${SCRIPT_DIR}/sync-os.zsh --sup'"
SYNC_ALIAS_DEV="alias sync.os.dev='${SCRIPT_DIR}/sync-os.zsh --dev'"

if grep -qF "alias sync.os=" "${HOME}/.zshrc" 2>/dev/null; then
  printf "✓ Alias already in ~/.zshrc: sync.os\n"
else
  printf "\n%s\n" "$SYNC_ALIAS_CLY" >> "${HOME}/.zshrc"
  printf "✓ Added alias to ~/.zshrc: sync.os\n"
fi

if grep -qF "alias sync.os.sup=" "${HOME}/.zshrc" 2>/dev/null; then
  printf "✓ Alias already in ~/.zshrc: sync.os.sup\n"
else
  printf "%s\n" "$SYNC_ALIAS_SUP" >> "${HOME}/.zshrc"
  printf "✓ Added alias to ~/.zshrc: sync.os.sup\n"
fi

if grep -qF "alias sync.os.dev=" "${HOME}/.zshrc" 2>/dev/null; then
  printf "✓ Alias already in ~/.zshrc: sync.os.dev\n"
else
  printf "%s\n" "$SYNC_ALIAS_DEV" >> "${HOME}/.zshrc"
  printf "✓ Added alias to ~/.zshrc: sync.os.dev\n"
fi

# ─── update-os ─────────────────────────────────────────────────────────────────
UPDATE_TARGET="${BIN_DIR}/update-os"
ln -sf "${SCRIPT_DIR}/update-os.zsh" "$UPDATE_TARGET"
chmod +x "${SCRIPT_DIR}/update-os.zsh" "$UPDATE_TARGET"
printf "✓ Installed: %s → %s\n" "$UPDATE_TARGET" "${SCRIPT_DIR}/update-os.zsh"

# update.os     → Claude Code yolo mode  (non-interactive, dangerously-skip-permissions)
# update.os.dev → Devin bypass mode      (interactive, --permission-mode dangerous)
UPDATE_ALIAS_CLY="alias update.os='${SCRIPT_DIR}/update-os.zsh --cly'"
UPDATE_ALIAS_DEV="alias update.os.dev='${SCRIPT_DIR}/update-os.zsh --dev'"

if grep -qF "alias update.os=" "${HOME}/.zshrc" 2>/dev/null; then
  printf "✓ Alias already in ~/.zshrc: update.os\n"
else
  printf "\n%s\n" "$UPDATE_ALIAS_CLY" >> "${HOME}/.zshrc"
  printf "✓ Added alias to ~/.zshrc: update.os\n"
fi

if grep -qF "alias update.os.dev=" "${HOME}/.zshrc" 2>/dev/null; then
  printf "✓ Alias already in ~/.zshrc: update.os.dev\n"
else
  printf "%s\n" "$UPDATE_ALIAS_DEV" >> "${HOME}/.zshrc"
  printf "✓ Added alias to ~/.zshrc: update.os.dev\n"
fi

# ─── add-os ────────────────────────────────────────────────────────────────────
ADD_OS_TARGET="${BIN_DIR}/add-os"
ln -sf "${SCRIPT_DIR}/add-os.zsh" "$ADD_OS_TARGET"
chmod +x "${SCRIPT_DIR}/add-os.zsh" "$ADD_OS_TARGET"
printf "✓ Installed: %s → %s\n" "$ADD_OS_TARGET" "${SCRIPT_DIR}/add-os.zsh"

# add.os     → Claude Code yolo mode  (non-interactive, dangerously-skip-permissions)
# add.os.dev → Devin bypass mode      (interactive, --permission-mode dangerous)
ADD_ALIAS_CLY="alias add.os='${SCRIPT_DIR}/add-os.zsh --cly'"
ADD_ALIAS_DEV="alias add.os.dev='${SCRIPT_DIR}/add-os.zsh --dev'"

if grep -qF "alias add.os=" "${HOME}/.zshrc" 2>/dev/null; then
  printf "✓ Alias already in ~/.zshrc: add.os\n"
else
  printf "\n%s\n" "$ADD_ALIAS_CLY" >> "${HOME}/.zshrc"
  printf "✓ Added alias to ~/.zshrc: add.os\n"
fi

if grep -qF "alias add.os.dev=" "${HOME}/.zshrc" 2>/dev/null; then
  printf "✓ Alias already in ~/.zshrc: add.os.dev\n"
else
  printf "%s\n" "$ADD_ALIAS_DEV" >> "${HOME}/.zshrc"
  printf "✓ Added alias to ~/.zshrc: add.os.dev\n"
fi

# ─── PATH check ────────────────────────────────────────────────────────────────
if ! echo "$PATH" | tr ':' '\n' | grep -qx "${BIN_DIR}"; then
  printf "\n⚠  %s is not in your PATH.\n" "$BIN_DIR"
  printf "   Add this to your ~/.zshrc:\n\n"
  printf "     export PATH=\"\$HOME/.local/bin:\$PATH\"\n\n"
  printf "   Then run: source ~/.zshrc\n\n"
else
  printf "\n✓ Ready. Available commands:\n"
  printf "  boot-app            — bootstrap a new project\n"
  printf "  boot.app            — alias for boot-app\n"
  printf "  sync-os --cly       — sync fork improvements → upstream (Claude yolo)\n"
  printf "  sync-os --sup       — sync fork improvements → upstream (Claude superpowers)\n"
  printf "  sync-os --dev       — sync fork improvements → upstream (Devin interactive)\n"
  printf "  sync.os             — alias for sync-os --cly\n"
  printf "  sync.os.sup         — alias for sync-os --sup\n"
  printf "  sync.os.dev         — alias for sync-os --dev\n"
  printf "  update-os --cly     — pull upstream improvements → fork (Claude yolo)\n"
  printf "  update-os --dev     — pull upstream improvements → fork (Devin interactive)\n"
  printf "  update.os           — alias for update-os --cly\n"
  printf "  update.os.dev       — alias for update-os --dev\n"
  printf "  add-os --cly        — provision a new OS repo into a project (Claude yolo)\n"
  printf "  add-os --dev        — provision a new OS repo into a project (Devin interactive)\n"
  printf "  add.os              — alias for add-os --cly\n"
  printf "  add.os.dev          — alias for add-os --dev\n\n"
  printf "  Run: source ~/.zshrc\n\n"
fi
