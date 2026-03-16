#!/usr/bin/env zsh
# install.zsh — Install boot-app as a global command.
# Usage: ./install.zsh
# Run once from the ai-app-bios directory.

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
BIN_DIR="${HOME}/.local/bin"
TARGET="${BIN_DIR}/boot-app"

mkdir -p "$BIN_DIR"

# Symlink — updates to boot-app.zsh take effect immediately
ln -sf "${SCRIPT_DIR}/boot-app.zsh" "$TARGET"
chmod +x "${SCRIPT_DIR}/boot-app.zsh" "$TARGET"

printf "✓ Installed: %s → %s\n" "$TARGET" "${SCRIPT_DIR}/boot-app.zsh"

# Also add a bash alias to ~/.zshrc as a fallback / convenience
ALIAS_LINE="alias boot.app='${SCRIPT_DIR}/boot-app.zsh'"
if grep -qF "alias boot.app=" "${HOME}/.zshrc" 2>/dev/null; then
  printf "✓ Alias already in ~/.zshrc\n"
else
  printf "\n%s\n" "$ALIAS_LINE" >> "${HOME}/.zshrc"
  printf "✓ Added alias to ~/.zshrc\n"
fi

# Check PATH
if ! echo "$PATH" | tr ':' '\n' | grep -qx "${BIN_DIR}"; then
  printf "\n⚠  %s is not in your PATH.\n" "$BIN_DIR"
  printf "   Add this to your ~/.zshrc:\n\n"
  printf "     export PATH=\"\$HOME/.local/bin:\$PATH\"\n\n"
  printf "   Then run: source ~/.zshrc\n\n"
else
  printf "\n✓ Ready. Run: boot-app\n"
  printf "  Or: source ~/.zshrc && boot-app\n\n"
fi
