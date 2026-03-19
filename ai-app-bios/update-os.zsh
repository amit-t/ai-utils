#!/usr/bin/env zsh
# update-os.zsh — Pull new skills and improvements from upstream parent repos into a project fork.
#
# Usage:
#   update-os.zsh --cly [--repos pm-os,doe-os,uxd-os,app-hq]   # Claude Code yolo mode
#   update-os.zsh --dev [--repos pm-os,doe-os,uxd-os,app-hq]   # Devin bypass permission mode
#
# Installed aliases (via install.zsh):
#   update.os       → Claude Code  (--dangerously-skip-permissions, non-interactive)
#   update.os.dev   → Devin        (--permission-mode dangerous, interactive)
#
# What it does:
#   Fetches the latest from each upstream parent repo and intelligently merges only
#   the new generic improvements (new skills, updated templates, new utilities) into
#   the fork — WITHOUT overwriting any project-specific content.
#
# How it works:
#   Phase 1 — AI analyses what is new in upstream vs the fork and writes an update plan
#   Gate    — You review the plan and approve (or cancel)
#   Phase 2 — AI applies the updates, resolving conflicts to preserve fork-specific values

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROMPT_FILE="${SCRIPT_DIR}/update-os.prompt.md"

# ─── Parse args ────────────────────────────────────────────────────────────────
MODE=""
TARGET_REPOS_RAW=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cly)   MODE="cly";  shift ;;
    --dev)   MODE="dev";  shift ;;
    --repos) TARGET_REPOS_RAW="$2"; shift 2 ;;
    --all)   TARGET_REPOS_RAW="pm-os,doe-os,uxd-os,app-hq"; shift ;;
    -h|--help)
      printf "Usage: update-os.zsh [--cly|--dev] [--repos pm-os,doe-os,uxd-os,app-hq]\n"
      printf "\n  --cly          Use Claude Code in yolo mode (non-interactive)\n"
      printf "  --dev          Use Devin in bypass permission mode (interactive)\n"
      printf "  --repos LIST   Comma-separated repos to update (default: pm-os,doe-os,uxd-os,app-hq)\n"
      printf "  --all          Update all four repos (same as default)\n"
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

[[ -z "$TARGET_REPOS_RAW" ]] && TARGET_REPOS_RAW="pm-os,doe-os,uxd-os,app-hq"

# ─── Verify required CLIs ──────────────────────────────────────────────────────
if [[ "$MODE" == "cly" ]] && ! command -v claude >/dev/null 2>&1; then
  printf "Error: 'claude' CLI not found. Install Claude Code and ensure it is in PATH.\n" >&2
  exit 1
fi
if [[ "$MODE" == "dev" ]] && ! command -v devin >/dev/null 2>&1; then
  printf "Error: 'devin' CLI not found. Install Devin CLI and ensure it is in PATH.\n" >&2
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
printf "  UPDATE-OS  —  Upstream → Fork Refresh Utility\n"
printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
printf "  Project root : %s\n" "$PROJECT_ROOT"
printf "  Target repos : %s\n" "$TARGET_REPOS_RAW"
printf "  AI engine    : %s\n" "$ENGINE_LABEL"
printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"

# ─── Verify prompt file ────────────────────────────────────────────────────────
if [[ ! -f "$PROMPT_FILE" ]]; then
  printf "Error: update-os.prompt.md not found at %s\n" "$PROMPT_FILE" >&2
  exit 1
fi

# ─── Output directory ──────────────────────────────────────────────────────────
UPDATE_DIR="${PROJECT_ROOT}/.update-os"
mkdir -p "$UPDATE_DIR"
PLAN_FILE="${UPDATE_DIR}/update-plan.md"
RESULT_FILE="${UPDATE_DIR}/update-result.md"

# Remove artifacts from any previous run
rm -f "$PLAN_FILE" "$RESULT_FILE"

# ─── Phase 1 prompt ────────────────────────────────────────────────────────────
PHASE1_PROMPT="$(cat "$PROMPT_FILE")

---
## Runtime Context

\`\`\`
PROJECT_ROOT    = ${PROJECT_ROOT}
TARGET_REPOS    = ${TARGET_REPOS_RAW}
UPDATE_DIR      = ${UPDATE_DIR}
PLAN_FILE       = ${PLAN_FILE}
PHASE           = ANALYSIS
\`\`\`

**Your task for this run is PHASE 1: ANALYSIS ONLY.**

Analyse what is new in upstream vs the current fork for each target repo.
Write the complete update plan to \`${PLAN_FILE}\` following the format in the prompt.

Do NOT modify any files in the fork, do NOT commit, do NOT push.
Stop as soon as the plan file is written.
"

# ─── Run Phase 1 ───────────────────────────────────────────────────────────────
printf "Phase 1 — Analysing upstream for new skills and improvements ...\n\n"

if [[ "$MODE" == "cly" ]]; then
  CLAUDECODE="" claude -p --dangerously-skip-permissions "$PHASE1_PROMPT"
else
  P1_FILE="${UPDATE_DIR}/phase1-prompt.md"
  printf "%s" "$PHASE1_PROMPT" > "$P1_FILE"
  devin --permission-mode dangerous --prompt-file "$P1_FILE"
fi

# ─── Verify plan was written ───────────────────────────────────────────────────
if [[ ! -f "$PLAN_FILE" ]]; then
  printf "\n✗  Analysis did not produce %s\n" "$PLAN_FILE" >&2
  printf "   Check AI output above for errors.\n" >&2
  exit 1
fi

# ─── Display plan ──────────────────────────────────────────────────────────────
printf "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
printf "  UPDATE PLAN\n"
printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
cat "$PLAN_FILE"
printf "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
printf "Plan saved at: %s\n\n" "$PLAN_FILE"

# ─── User approval gate ────────────────────────────────────────────────────────
printf "Review the update plan above carefully.\n"
printf "Apply these updates to the fork? [y/N] "
read -r APPROVAL

if [[ "$APPROVAL" != "y" && "$APPROVAL" != "Y" ]]; then
  printf "\nUpdate cancelled. No changes were made to the fork.\n"
  printf "Re-run at any time — the plan is saved at:\n  %s\n\n" "$PLAN_FILE"
  exit 0
fi

# ─── Phase 2 prompt ────────────────────────────────────────────────────────────
PHASE2_PROMPT="$(cat "$PROMPT_FILE")

---
## Runtime Context

\`\`\`
PROJECT_ROOT    = ${PROJECT_ROOT}
TARGET_REPOS    = ${TARGET_REPOS_RAW}
UPDATE_DIR      = ${UPDATE_DIR}
PLAN_FILE       = ${PLAN_FILE}
RESULT_FILE     = ${RESULT_FILE}
PHASE           = APPLY
\`\`\`

**Your task for this run is PHASE 2: APPLY UPDATES.**

The user has reviewed and approved the plan at \`${PLAN_FILE}\`.

Read the plan and apply every update listed, following the merge and conflict-resolution
rules in the prompt. Preserve all project-specific content in the fork.

After applying all updates, write \`${RESULT_FILE}\` summarising what was changed.
"

# ─── Run Phase 2 ───────────────────────────────────────────────────────────────
printf "\nPhase 2 — Applying upstream updates to fork ...\n\n"

if [[ "$MODE" == "cly" ]]; then
  CLAUDECODE="" claude -p --dangerously-skip-permissions "$PHASE2_PROMPT"
else
  P2_FILE="${UPDATE_DIR}/phase2-prompt.md"
  printf "%s" "$PHASE2_PROMPT" > "$P2_FILE"
  devin --permission-mode dangerous --prompt-file "$P2_FILE"
fi

# ─── Print results ─────────────────────────────────────────────────────────────
printf "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
printf "  UPDATE RESULTS\n"
printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
if [[ -f "$RESULT_FILE" ]]; then
  cat "$RESULT_FILE"
else
  printf "(No update-result.md found — check AI output above for details)\n"
fi
printf "\n"
