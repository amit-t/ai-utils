#!/usr/bin/env zsh
# skill-sync — sync or scaffold an at-skills skill from a source path.
#
# Usage:
#   skill-sync <source-path> [skill-name] [--agent claude|codex|devin] [--yolo]
#
# Sync mode (skill-name passed): mirrors <source-path>/ into <cwd>/<skill-name>/
# and updates catalog files (README.md, site.js, CHANGELOG.md, skills-lock.json).
#
# Build mode (skill-name omitted): invokes the chosen agent CLI with a prompt
# that instructs it to scaffold a new at-skills skill from <source-path>.
#
# Run from the root of an at-skills-style repo (must have site.js + AGENTS.md).

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROMPT_FILE="${SCRIPT_DIR}/skill-sync.prompt.md"
HELPER_PY="${SCRIPT_DIR}/skill_sync_catalog.py"

print_usage() {
  cat <<EOF
Usage: skill-sync <source-path> [skill-name] [--agent claude|codex|devin] [--yolo]

  source-path   Direct path to a skill directory containing SKILL.md
  skill-name    (optional) When passed, sync source into <cwd>/<skill-name>/
                When omitted, scaffold a new skill via agent CLI

Flags:
  --agent       claude (default) | codex | devin   (build mode only)
  --yolo        Use dangerous-permission flag for the agent
  -h, --help    Show this message
EOF
}

# ── parse args ────────────────────────────────────────────────────────────────
agent="claude"
yolo=false
positional=()

while (( $# > 0 )); do
  case "$1" in
    -h|--help) print_usage; exit 0 ;;
    --agent)
      [[ -z "${2:-}" ]] && { print -u2 "skill-sync: --agent requires a value"; exit 2; }
      agent="$2"; shift 2 ;;
    --agent=*) agent="${1#--agent=}"; shift ;;
    --yolo)    yolo=true; shift ;;
    --) shift; positional+=("$@"); break ;;
    -*) print -u2 "skill-sync: unknown flag: $1"; print_usage; exit 2 ;;
    *)  positional+=("$1"); shift ;;
  esac
done

if (( ${#positional[@]} < 1 )); then
  print -u2 "skill-sync: source-path is required"
  print_usage
  exit 2
fi

source_path="${positional[1]:A}"
skill_name="${positional[2]:-}"

case "$agent" in
  claude|codex|devin) ;;
  *) print -u2 "skill-sync: --agent must be claude|codex|devin (got: $agent)"; exit 2 ;;
esac

# ── validate cwd is a skills repo ─────────────────────────────────────────────
repo_root="$(pwd)"
if [[ ! -f "${repo_root}/site.js" || ! -f "${repo_root}/AGENTS.md" ]]; then
  print -u2 "skill-sync: cwd does not look like a skills repo (need site.js + AGENTS.md at ${repo_root})"
  exit 1
fi

# ── validate source ───────────────────────────────────────────────────────────
if [[ ! -d "$source_path" ]]; then
  print -u2 "skill-sync: source path is not a directory: $source_path"
  exit 1
fi
if [[ ! -f "${source_path}/SKILL.md" ]]; then
  print -u2 "skill-sync: no SKILL.md found at ${source_path}/SKILL.md"
  exit 1
fi

# ── sync mode ─────────────────────────────────────────────────────────────────
if [[ -n "$skill_name" ]]; then
  dest="${repo_root}/${skill_name}"
  print "→ Syncing ${source_path} → ${dest}"
  rsync -a --delete "${source_path}/" "${dest}/"

  print "→ Updating catalog (README.md, site.js, CHANGELOG.md, skills-lock.json)"
  python3 "$HELPER_PY" \
    --repo-root "$repo_root" \
    --skill-name "$skill_name" \
    --skill-dir  "$dest" \
    --source-path "$source_path"

  print "✓ Sync complete. Review with: git -C \"$repo_root\" status && git -C \"$repo_root\" diff"
  exit 0
fi

# ── build mode ────────────────────────────────────────────────────────────────
if [[ ! -f "$PROMPT_FILE" ]]; then
  print -u2 "skill-sync: prompt file missing: $PROMPT_FILE"
  exit 1
fi

if ! command -v "$agent" >/dev/null 2>&1; then
  print -u2 "skill-sync: agent CLI not on PATH: $agent"
  exit 127
fi

export SKILL_SOURCE_PATH="$source_path"
export SKILLS_REPO_DIR="$repo_root"

print "→ Build mode: invoking $agent against ${source_path} (target repo: ${repo_root})"

# Build a prompt that includes both the static prompt file and the runtime context.
runtime_prompt="$(mktemp -t skill-sync-prompt.XXXXXX).md"
trap "rm -f '$runtime_prompt'" EXIT

{
  print "# Runtime context"
  print "- SKILL_SOURCE_PATH: ${source_path}"
  print "- SKILLS_REPO_DIR:   ${repo_root}"
  print ""
  cat "$PROMPT_FILE"
} > "$runtime_prompt"

case "$agent" in
  claude)
    if $yolo; then
      claude --dangerously-skip-permissions "$(cat "$runtime_prompt")"
    else
      claude "$(cat "$runtime_prompt")"
    fi
    ;;
  codex)
    if $yolo; then
      codex exec --full-auto - < "$runtime_prompt"
    else
      codex exec - < "$runtime_prompt"
    fi
    ;;
  devin)
    if $yolo; then
      devin --permission-mode dangerous --prompt-file "$runtime_prompt"
    else
      devin --prompt-file "$runtime_prompt"
    fi
    ;;
esac
