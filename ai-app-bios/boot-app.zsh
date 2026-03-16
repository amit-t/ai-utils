#!/usr/bin/env zsh
# new-os — Bootstrap a new project by starting a Claude session with the setup prompt.
# Usage: new-os [install_dir]
# Install globally: run install.zsh once, then `new-os` from anywhere.

set -euo pipefail

BOOTSTRAP_DIR="${0:A:h}"
PROMPT_FILE="${BOOTSTRAP_DIR}/bootstrap.prompt.md"

if [[ ! -f "$PROMPT_FILE" ]]; then
  printf "Error: bootstrap.prompt.md not found at %s\n" "$PROMPT_FILE" >&2
  exit 1
fi

if ! command -v cly >/dev/null 2>&1; then
  printf "Error: 'cly' command not found.\n" >&2
  printf "Ensure your cly alias (claude --dangerously-skip-permissions) is set up.\n" >&2
  exit 1
fi

# Optional: pass working directory as context appended to prompt
WORKING_DIR="${1:-$(pwd)}"

FULL_PROMPT="$(cat "$PROMPT_FILE")

---
Bootstrap context: Install the new project in this directory: ${WORKING_DIR}
"

cly "$FULL_PROMPT"
