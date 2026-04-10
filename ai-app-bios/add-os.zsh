#!/usr/bin/env zsh
# add-os.zsh — Provision a new OS repo into an existing project.
#
# Usage:
#   add-os.zsh --cly --os uxd-os [--upstream <url>]   # Claude Code yolo mode
#   add-os.zsh --dev --os uxd-os [--upstream <url>]   # Devin bypass permission mode
#
# Installed aliases (via install.zsh):
#   add.os      → Claude Code  (--dangerously-skip-permissions, non-interactive)
#   add.os.dev  → Devin        (--permission-mode dangerous, interactive)
#
# What it does:
#   Forks the specified upstream OS repo into the project's GitHub org,
#   clones it to the correct local directory, configures the upstream remote,
#   and pre-fills the business info template from existing project context.

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROMPT_FILE="${SCRIPT_DIR}/add-os.prompt.md"

# ─── Parse args ────────────────────────────────────────────────────────────────
MODE=""
OS_NAME=""
UPSTREAM_URL=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cly)      MODE="cly"; shift ;;
    --dev)      MODE="dev"; shift ;;
    --os)       OS_NAME="$2"; shift 2 ;;
    --upstream) UPSTREAM_URL="$2"; shift 2 ;;
    -h|--help)
      printf "Usage: add-os.zsh [--cly|--dev] --os <os-name> [--upstream <url>]\n"
      printf "\n  --cly            Use Claude Code in yolo mode (non-interactive)\n"
      printf "  --dev            Use Devin in bypass permission mode (interactive)\n"
      printf "  --os NAME        OS to add (e.g. uxd-os)\n"
      printf "  --upstream URL   Override the upstream source URL (uses known default if omitted)\n"
      printf "\nKnown OS defaults:\n"
      printf "  uxd-os    git@github.com-at:AppIncubatorHQ/uxd-os.git  (product/)\n"
      printf "  pm-os     https://github.com/AppIncubatorHQ/pm-os       (product/)\n"
      printf "  doe-os    https://github.com/AppIncubatorHQ/doe-os      (engineering/)\n"
      printf "  ai-fs-os  https://github.com/AppIncubatorHQ/ai-fs-os    (root, template+private)\n"
      exit 0
      ;;
    *) printf "Unknown argument: %s\n" "$1" >&2; exit 1 ;;
  esac
done

if [[ -z "$MODE" ]]; then
  printf "Error: specify --cly (Claude) or --dev (Devin)\n" >&2
  printf "Run with --help for usage.\n" >&2
  exit 1
fi

if [[ -z "$OS_NAME" ]]; then
  printf "Error: --os <name> is required (e.g. --os uxd-os)\n" >&2
  exit 1
fi

# ─── Verify required CLIs ──────────────────────────────────────────────────────
if [[ "$MODE" == "cly" ]] && ! command -v claude >/dev/null 2>&1; then
  printf "Error: 'claude' CLI not found. Install Claude Code and ensure it is in PATH.\n" >&2
  exit 1
fi
if [[ "$MODE" == "dev" ]] && ! command -v devin >/dev/null 2>&1; then
  printf "Error: 'devin' CLI not found. Install Devin CLI and ensure it is in PATH.\n" >&2
  exit 1
fi
if ! command -v gh >/dev/null 2>&1; then
  printf "Error: 'gh' (GitHub CLI) is required.\n" >&2
  exit 1
fi
if ! command -v git >/dev/null 2>&1; then
  printf "Error: 'git' not found.\n" >&2
  exit 1
fi

# ─── Locate project root by walking up for CLAUDE.md ──────────────────────────
PROJECT_ROOT="$(pwd)"
SEARCH="$(pwd)"
while [[ "$SEARCH" != "/" ]]; do
  if [[ -f "$SEARCH/CLAUDE.md" ]]; then
    PROJECT_ROOT="$SEARCH"
    break
  fi
  SEARCH="$(dirname "$SEARCH")"
done

ENGINE_LABEL="$([[ $MODE == cly ]] && echo 'Claude Code  (yolo / --dangerously-skip-permissions)' || echo 'Devin  (bypass / --permission-mode dangerous)')"

printf "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
printf "  ADD-OS  —  New OS Provisioning Utility\n"
printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
printf "  Project root : %s\n" "$PROJECT_ROOT"
printf "  OS to add    : %s\n" "$OS_NAME"
[[ -n "$UPSTREAM_URL" ]] && printf "  Upstream URL : %s\n" "$UPSTREAM_URL"
printf "  AI engine    : %s\n" "$ENGINE_LABEL"
printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"

# ─── Verify prompt file ────────────────────────────────────────────────────────
if [[ ! -f "$PROMPT_FILE" ]]; then
  printf "Error: add-os.prompt.md not found at %s\n" "$PROMPT_FILE" >&2
  exit 1
fi

# ─── Output directory ──────────────────────────────────────────────────────────
ADD_OS_DIR="${PROJECT_ROOT}/.add-os"
mkdir -p "$ADD_OS_DIR"
RESULT_FILE="${ADD_OS_DIR}/add-os-result.md"
rm -f "$RESULT_FILE"

# ─── Build prompt ──────────────────────────────────────────────────────────────
RUN_PROMPT="$(cat "$PROMPT_FILE")

---
## Runtime Context

\`\`\`
PROJECT_ROOT  = ${PROJECT_ROOT}
OS_NAME       = ${OS_NAME}
UPSTREAM_URL  = ${UPSTREAM_URL}
RESULT_FILE   = ${RESULT_FILE}
\`\`\`

**Your task:** provision \`${OS_NAME}\` into the project at \`${PROJECT_ROOT}\` following all steps in this prompt.
If UPSTREAM_URL is empty, use the known default for the OS_NAME.
Write the result summary to \`${RESULT_FILE}\` when done.
"

# ─── Run ───────────────────────────────────────────────────────────────────────
printf "Provisioning %s ...\n\n" "$OS_NAME"

if [[ "$MODE" == "cly" ]]; then
  CLAUDECODE="" claude -p --dangerously-skip-permissions "$RUN_PROMPT"
else
  PROMPT_TMP="${ADD_OS_DIR}/add-os-prompt.md"
  printf "%s" "$RUN_PROMPT" > "$PROMPT_TMP"
  devin --permission-mode dangerous --prompt-file "$PROMPT_TMP"
fi

# ─── Print result ──────────────────────────────────────────────────────────────
printf "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
printf "  ADD-OS RESULT\n"
printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
if [[ -f "$RESULT_FILE" ]]; then
  cat "$RESULT_FILE"
else
  printf "(No result file found — check AI output above for details)\n"
fi
printf "\n"
