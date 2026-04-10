#!/usr/bin/env zsh
# boot-app — Bootstrap a new project by starting a Claude session with the setup prompt.
# Usage: boot-app [--trim] [install_dir]
# Install globally: run install.zsh once, then `boot-app` from anywhere.
#
# Flags:
#   --trim    Lightweight bootstrap — sets up HQ directory and ai-fs-os only
#             (no pm-os, uxd-os, doe-os). Uses current directory as HQ;
#             does not force git init if the directory is not already a repo.

set -euo pipefail

BOOTSTRAP_DIR="${0:A:h}"
PROMPT_FILE="${BOOTSTRAP_DIR}/bootstrap.prompt.md"

# ─── Parse args ────────────────────────────────────────────────────────────────
TRIM_MODE=false
WORKING_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --trim)    TRIM_MODE=true; shift ;;
    -h|--help)
      printf "Usage: boot-app [--trim] [install_dir]\n"
      printf "\n  --trim         Lightweight bootstrap — HQ + ai-fs-os only (no pm/uxd/doe-os)\n"
      printf "                 Uses current directory as HQ; does not force git init.\n"
      printf "                 Creates ai-fs-os from private template.\n"
      printf "  install_dir    Working directory for bootstrap (default: pwd)\n"
      exit 0
      ;;
    *)         WORKING_DIR="$1"; shift ;;
  esac
done

[[ -z "$WORKING_DIR" ]] && WORKING_DIR="$(pwd)"

if [[ ! -f "$PROMPT_FILE" ]]; then
  printf "Error: bootstrap.prompt.md not found at %s\n" "$PROMPT_FILE" >&2
  exit 1
fi

if ! command -v claude >/dev/null 2>&1; then
  printf "Error: 'claude' command not found. Ensure the Claude CLI is installed and in your PATH.\n" >&2
  exit 1
fi

# ─── Build prompt ──────────────────────────────────────────────────────────────
FULL_PROMPT="$(cat "$PROMPT_FILE")

---
Bootstrap context: Set up the project directly in this directory (ROOT_DIR): ${WORKING_DIR}
TRIM_MODE: ${TRIM_MODE}
"

claude --dangerously-skip-permissions "$FULL_PROMPT"
