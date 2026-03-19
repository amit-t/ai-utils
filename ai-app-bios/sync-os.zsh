#!/usr/bin/env zsh
# sync-os.zsh — Sync new skills and improvements from project forks back to upstream parent repos.
#
# Usage:
#   sync-os.zsh --cly [--repos pm-os,doe-os,uxd-os,app-hq]   # Claude Code yolo mode
#   sync-os.zsh --dev [--repos pm-os,doe-os,uxd-os,app-hq]   # Devin bypass permission mode
#
# Installed aliases (via install.zsh):
#   sync.os       → Claude Code  (--dangerously-skip-permissions, non-interactive)
#   sync.os.dev   → Devin        (--permission-mode dangerous, interactive)
#
# How it works:
#   Phase 1 — AI analyses each fork vs its upstream parent and writes a sync-summary.md
#   Gate    — You review the summary and approve (or cancel)
#   Phase 2 — AI creates PRs to the upstream repos (only for approved repos)

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROMPT_FILE="${SCRIPT_DIR}/sync-os.prompt.md"

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
      printf "Usage: sync-os.zsh [--cly|--dev] [--repos pm-os,doe-os,uxd-os,app-hq]\n"
      printf "\n  --cly          Use Claude Code in yolo mode (non-interactive)\n"
      printf "  --dev          Use Devin in bypass permission mode (interactive)\n"
      printf "  --repos LIST   Comma-separated repos to sync (default: pm-os,doe-os,uxd-os,app-hq)\n"
      printf "  --all          Sync all four repos (same as default)\n"
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
if ! command -v gh >/dev/null 2>&1; then
  printf "Error: 'gh' (GitHub CLI) is required for PR creation.\n" >&2
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
printf "  SYNC-OS  —  Fork → Upstream PR Utility\n"
printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
printf "  Project root : %s\n" "$PROJECT_ROOT"
printf "  Target repos : %s\n" "$TARGET_REPOS_RAW"
printf "  AI engine    : %s\n" "$ENGINE_LABEL"
printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"

# ─── Verify prompt file ────────────────────────────────────────────────────────
if [[ ! -f "$PROMPT_FILE" ]]; then
  printf "Error: sync-os.prompt.md not found at %s\n" "$PROMPT_FILE" >&2
  exit 1
fi

# ─── Output directory ──────────────────────────────────────────────────────────
SYNC_DIR="${PROJECT_ROOT}/.sync-os"
mkdir -p "$SYNC_DIR"
SUMMARY_FILE="${SYNC_DIR}/sync-summary.md"
PR_RESULTS_FILE="${SYNC_DIR}/pr-results.md"

# Remove artifacts from any previous run so stale files don't fool the check
rm -f "$SUMMARY_FILE" "$PR_RESULTS_FILE"

# ─── Phase 1 prompt ────────────────────────────────────────────────────────────
PHASE1_PROMPT="$(cat "$PROMPT_FILE")

---
## Runtime Context

\`\`\`
PROJECT_ROOT    = ${PROJECT_ROOT}
TARGET_REPOS    = ${TARGET_REPOS_RAW}
SYNC_OUTPUT_DIR = ${SYNC_DIR}
SUMMARY_FILE    = ${SUMMARY_FILE}
PHASE           = ANALYSIS
\`\`\`

**Your task for this run is PHASE 1: ANALYSIS ONLY.**

Analyse the fork(s) vs their upstream parent repos and write a complete summary
to \`${SUMMARY_FILE}\` following the format specified in the prompt.

Do NOT open any PRs, push any branches, or make any commits yet.
Stop as soon as the summary file is written.
"

# ─── Run Phase 1 ───────────────────────────────────────────────────────────────
printf "Phase 1 — Analysing forks vs upstream parents ...\n\n"

if [[ "$MODE" == "cly" ]]; then
  CLAUDECODE="" claude -p --dangerously-skip-permissions "$PHASE1_PROMPT"
else
  P1_FILE="${SYNC_DIR}/phase1-prompt.md"
  printf "%s" "$PHASE1_PROMPT" > "$P1_FILE"
  devin --permission-mode dangerous --prompt-file "$P1_FILE"
fi

# ─── Verify summary written ────────────────────────────────────────────────────
if [[ ! -f "$SUMMARY_FILE" ]]; then
  printf "\n✗  Analysis did not produce %s\n" "$SUMMARY_FILE" >&2
  printf "   Check AI output above for errors.\n" >&2
  exit 1
fi

# ─── Display summary ───────────────────────────────────────────────────────────
printf "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
printf "  SYNC ANALYSIS SUMMARY\n"
printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
cat "$SUMMARY_FILE"
printf "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
printf "Summary saved at: %s\n\n" "$SUMMARY_FILE"

# ─── User approval gate ────────────────────────────────────────────────────────
printf "Review the summary above carefully.\n"
printf "Proceed and create upstream PRs for the changes listed? [y/N] "
read -r APPROVAL

if [[ "$APPROVAL" != "y" && "$APPROVAL" != "Y" ]]; then
  printf "\nSync cancelled. No PRs were created.\n"
  printf "Re-run at any time — the summary is saved at:\n  %s\n\n" "$SUMMARY_FILE"
  exit 0
fi

# ─── Phase 2 prompt ────────────────────────────────────────────────────────────
PHASE2_PROMPT="$(cat "$PROMPT_FILE")

---
## Runtime Context

\`\`\`
PROJECT_ROOT    = ${PROJECT_ROOT}
TARGET_REPOS    = ${TARGET_REPOS_RAW}
SYNC_OUTPUT_DIR = ${SYNC_DIR}
SUMMARY_FILE    = ${SUMMARY_FILE}
PR_RESULTS_FILE = ${PR_RESULTS_FILE}
PHASE           = PR_CREATION
\`\`\`

**Your task for this run is PHASE 2: PR CREATION.**

The user has reviewed and approved the summary at \`${SUMMARY_FILE}\`.

Read the summary to understand which repos have changes to contribute, then follow
the PR creation instructions in the prompt to raise one PR per repo.

After creating all PRs, write \`${PR_RESULTS_FILE}\` listing each PR URL and its status.
"

# ─── Run Phase 2 ───────────────────────────────────────────────────────────────
printf "\nPhase 2 — Creating upstream PRs ...\n\n"

if [[ "$MODE" == "cly" ]]; then
  CLAUDECODE="" claude -p --dangerously-skip-permissions "$PHASE2_PROMPT"
else
  P2_FILE="${SYNC_DIR}/phase2-prompt.md"
  printf "%s" "$PHASE2_PROMPT" > "$P2_FILE"
  devin --permission-mode dangerous --prompt-file "$P2_FILE"
fi

# ─── Print results ─────────────────────────────────────────────────────────────
printf "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
printf "  PR CREATION RESULTS\n"
printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
if [[ -f "$PR_RESULTS_FILE" ]]; then
  cat "$PR_RESULTS_FILE"
else
  printf "(No pr-results.md found — check AI output above for PR links)\n"
fi
printf "\n"
