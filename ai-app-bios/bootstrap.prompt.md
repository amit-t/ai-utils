# new-os Bootstrap — Claude Setup Instructions

You are being invoked to bootstrap a new software project with a complete product + engineering operating system. You will interview the user, then use your tools (Bash, Write, Edit, Read) to execute the full setup autonomously.

**You have bypass permissions. Do the work — don't ask the user to run commands manually.**

---

## Step 1: Interview

Introduce yourself in one line: "I'll set up your project's PM OS, Engineering OS, and root planning layer. Let me ask a few questions."

Then ask the following questions **one section at a time**:

### Section 1 — Project Identity
Ask these together:
- Project name (e.g. "EverPlan", "TaskFlow", "BabbleAI")
- One-line product description — what it does and for whom
- Target market / users (e.g. "Indian families aged 30–60", "indie hackers", "B2B SaaS teams")
- Team size

### Section 2 — Tech Stack
Ask these together. For each, offer numbered options and let them pick or type their own:

**Frontend:** React + Vite | Next.js | Vue + Vite | React Native | Other
**Backend:** Elysia.js + Bun | Express + Node.js (TypeScript) | FastAPI + Python | Rails | Other
**Database:** PostgreSQL | MySQL | MongoDB | SQLite | Other
**Cloud / Infra:** AWS | GCP | Azure | Self-hosted / VPS | Other
**Additional stack notes** (ORM, cache, monorepo tool, etc.) — optional, can be blank

### Section 3 — Repositories
Ask these together:
- pm-os scaffold GitHub URL (default: `https://github.com/amit-t/pm-os` — press Enter to accept)
- doe-os scaffold GitHub URL (default: `https://github.com/amit-t/doe-os` — press Enter to accept)
- Main app GitHub URL — optional, leave blank to skip cloning

### Section 4 — Confirm
Show a compact summary of all answers, then ask: **"Ready to set up? [Y/n]"**

If they say no, ask what to change and loop back.

---

## Step 2: Compute Values

Before writing anything, compute these internally:

**project_slug**: lowercase, hyphens only. Examples: "EverPlan" → `everplan`, "My App" → `my-app`, "BabbleAI" → `babbleai`

**Directories** (using the install directory passed at the bottom of this prompt, or the user's answer if they want somewhere else):
```
ROOT_DIR   = {install_dir}/{project_slug}
PMOS_DIR   = {ROOT_DIR}/product/{project_slug}-pm-os
DOEOS_DIR  = {ROOT_DIR}/engineering/{project_slug}-doe-os
APP_DIR    = {ROOT_DIR}/engineering/{project_slug}-app   (only if app URL given)
```

**Claude memory path**:
- Take ROOT_DIR as an absolute path
- Replace every `/` with `-` (drop the leading `-`)
- Result: `~/.claude/projects/{that-id}/memory/`
- Example: `/Users/amit/Projects/babble` → `~/.claude/projects/-Users-amit-Projects-babble/memory/`

---

## Step 3: Execute Setup

Run these steps in order. Announce each step as you go ("Setting up pm-os...", etc.).

### 3.1 — Create root directories
```bash
mkdir -p {ROOT_DIR}/product
mkdir -p {ROOT_DIR}/engineering
mkdir -p {ROOT_DIR}/tools
```

### 3.2 — Fork pm-os scaffold
```bash
gh repo fork {pmos_url} --clone --remote --fork-name {project_slug}-pm-os
mv {project_slug}-pm-os {PMOS_DIR}
```

### 3.3 — Fork doe-os scaffold
```bash
gh repo fork {doeos_url} --clone --remote --fork-name {project_slug}-doe-os
mv {project_slug}-doe-os {DOEOS_DIR}
```

### 3.4 — Fork app repo (only if URL was provided)
`{app_repo_name}` = the last path segment of `{app_url}` (e.g. `https://github.com/org/my-app` → `my-app`)
```bash
gh repo fork {app_url} --clone --remote
mv {app_repo_name} {APP_DIR}
```

### 3.7 — Create approved PRDs gate folder
```bash
mkdir -p {PMOS_DIR}/outputs/prds/approved
```

### 3.8 — Generate root CLAUDE.md
Write the following to `{ROOT_DIR}/CLAUDE.md`, substituting all `{placeholders}`:

```markdown
# {project_name} — Root Project Instructions

## CRITICAL: Plan Mode Only

**When working from this directory or any subdirectory:**

- **ALWAYS enter plan mode before writing any code or making code changes.**
- **NEVER write, edit, or create code files directly from this root project without an approved plan.**

## Why

{product_desc}. Every code change has trust implications. Plans must be reviewed and approved before execution.

## Session Start: Read the PRD Pipeline

**At the start of every session, read `PRD-PIPELINE.md` (this directory) before doing anything.**
It tracks every PRD → spec → fix_plan → execution status.
Update it at the end of every session.

---

## Three-Project Planning Workflow

| Step | What | Where |
|------|------|-------|
| 1 | Write PRD (using pm-os skills) | `product/{project_slug}-pm-os/outputs/prds/` |
| 2 | Write engineering spec + ADRs | `engineering/{project_slug}-doe-os/outputs/specs/` |
| 3 | Move approved PRD to approved folder | `product/{project_slug}-pm-os/outputs/prds/approved/` |
| 4 | Run `./ai/sync-all.zsh` — publishes approved PRDs + specs into `ai/outputs/` | `engineering/{project_slug}-app/ai/outputs/` |
| 5 | Run `rpc.plan` (or `rpd.plan` / `rpx.plan`) | generates `fix_plan.md` |
| 6 | Run `rpc.int` (or `rpd.int` / `rpx.int`) | executes the fix_plan |

**PRDs always go in pm-os. Engineering specs/ADRs always go in doe-os. Code always goes via ralph.**

## Ralph CLI Reference

| Command | Mode | Agent | What it does |
|---------|------|-------|-------------|
| `ralph.enable` | Setup | — | Enables a directory with the ralph engine |
| `rpc.plan` | Planning | Claude | Reads `ai/outputs/` → generates `fix_plan.md` |
| `rpd.plan` | Planning | Devin | Same, via Devin |
| `rpx.plan` | Planning | Codex | Same, via Codex |
| `rpc.int` | Development | Claude | Executes tasks from `fix_plan.md` |
| `rpd.int` | Development | Devin | Same, via Devin |
| `rpx.int` | Development | Codex | Same, via Codex |

## Planning Workflow

1. Explore and understand the codebase
2. Present a plan (file changes, approach, tradeoffs)
3. Get explicit user approval
4. Only then implement

## Project Structure

```
{project_slug}/
  product/{project_slug}-pm-os/      # PM OS — PRDs, strategy, context library
  engineering/{project_slug}-doe-os/ # DOE OS — specs, ADRs, architecture
  engineering/{project_slug}-app/    # Main app — source code, ralph agent loops
  PRD-PIPELINE.md                    # Cross-project pipeline tracker
```

## Engineering Stack

- Frontend: {frontend}
- Backend: {backend}
- Database: {database}
- Cloud: {cloud}
{stack_notes_line}
```

### 3.9 — Generate PRD-PIPELINE.md
Write the following to `{ROOT_DIR}/PRD-PIPELINE.md`:

```markdown
# {project_name} PRD Pipeline

Tracks every PRD from writing → engineering spec → fix_plan → execution → done.

**Update this file at the end of every planning session.**

---

## Pipeline Status Key

| Symbol | Meaning |
|--------|---------|
| ✓ | Complete |
| ~ | In Progress / In Review |
| — | Not started |
| ✗ | Blocked |

---

## Active Pipeline

| # | Feature | PRD | Spec (DOE OS) | fix_plan | Execution | Notes |
|---|---------|-----|---------------|----------|-----------|-------|

---

## Queued PRDs (written next, in priority order)

| Priority | Feature | Rationale | Depends On |
|----------|---------|-----------|------------|

---

## Completed

| Feature | PRD | Spec | fix_plan | Shipped |
|---------|-----|------|----------|---------|

---

## How to Use This File

**Start of session:** Read this file first. Check Active Pipeline for status. Check Queued PRDs for what to write next.

**End of session:** Update relevant rows. Move completed rows to the Completed section.

**When publishing a PRD to ralph:**
1. Copy approved PRD to `product/{project_slug}-pm-os/outputs/prds/approved/`
2. Run `./ai/sync-all.zsh` from `engineering/{project_slug}-app/`
3. Run `rpc.plan`
4. Update the fix_plan column in Active Pipeline.

---

## File Locations

| Artifact | Location |
|----------|----------|
| PRDs | `product/{project_slug}-pm-os/outputs/prds/` |
| Approved PRDs (ralph inbox) | `product/{project_slug}-pm-os/outputs/prds/approved/` |
| Engineering specs + ADRs | `engineering/{project_slug}-doe-os/outputs/specs/` |
| fix_plan | `engineering/{project_slug}-app/.ralph/fix_plan.md` |
| This tracker | `PRD-PIPELINE.md` (root) |

---

_Last updated: {today_date} — project initialised_
```

### 3.10 — Generate sync scripts

**Determine sync target:**
- If app URL was provided: `{APP_DIR}/ai/`
- Otherwise: `{ROOT_DIR}/tools/` (note this in the summary — user will need to move it to app/ai/ later)

Create the sync target directory: `mkdir -p {sync_target}`

Write `{sync_target}/sync-doe-prd-outputs.zsh`:

```zsh
#!/usr/bin/env zsh
# sync-doe-prd-outputs.zsh — Sync doe-os outputs + approved pm-os PRDs into ai/outputs/
# Usage:
#   ./ai/sync-doe-prd-outputs.zsh [--pm-os [pm_os_dir]] [doe_source_dir] [--dry-run]
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_ROOT="${SCRIPT_DIR:h}"
DEFAULT_DOE_DIR="${PROJECT_ROOT:h}/engineering/{project_slug}-doe-os"
DEFAULT_PM_DIR="${PROJECT_ROOT:h}/product/{project_slug}-pm-os"

DOE_DIR="${DEFAULT_DOE_DIR}"
PM_DIR=""
DRY_RUN=false

print_usage() {
  cat <<'USAGE'
Usage: ./ai/sync-doe-prd-outputs.zsh [--pm-os [pm_os_dir]] [doe_source_dir] [--dry-run]

Behavior:
  - Syncs specs and engineering outputs from doe-os into ai/outputs/
  - With --pm-os: also syncs APPROVED PRDs from pm-os/outputs/prds/approved/
  - Never deletes destination files
USAGE
}

i=1
while [[ $i -le $# ]]; do
  arg="${@[$i]}"
  case "$arg" in
    -h|--help) print_usage; exit 0 ;;
    --dry-run) DRY_RUN=true ;;
    --pm-os)
      next_i=$((i + 1))
      if [[ $next_i -le $# && "${@[$next_i]}" != --* ]]; then
        PM_DIR="${@[$next_i]}"; i=$next_i
      else
        PM_DIR="${DEFAULT_PM_DIR}"
      fi
      ;;
    -*) echo "Unknown flag: $arg" >&2; print_usage; exit 1 ;;
    *) DOE_DIR="$arg" ;;
  esac
  i=$((i + 1))
done

command -v rsync >/dev/null 2>&1 || { echo "rsync required but not installed." >&2; exit 1; }

RSYNC_OPTS=(-a --human-readable --update --exclude '.DS_Store')
[[ "${DRY_RUN}" == true ]] && RSYNC_OPTS+=(--dry-run --itemize-changes) && echo "[DRY RUN]"

[[ -d "${DOE_DIR}" ]] || { echo "doe-os not found: ${DOE_DIR}" >&2; exit 1; }
[[ -d "${DOE_DIR}/outputs" ]] || { echo "doe-os outputs/ not found" >&2; exit 1; }

echo "DOE-OS: ${DOE_DIR}"
mkdir -p "${SCRIPT_DIR}/outputs/specs"

echo; echo "1) Syncing engineering specs..."
rsync "${RSYNC_OPTS[@]}" "${DOE_DIR}/outputs/specs/" "${SCRIPT_DIR}/outputs/specs/"

echo; echo "2) Syncing other doe-os outputs..."
rsync "${RSYNC_OPTS[@]}" --exclude '/specs/' --exclude '/prds/' "${DOE_DIR}/outputs/" "${SCRIPT_DIR}/outputs/"

if [[ -d "${DOE_DIR}/context-library/prds" ]]; then
  mkdir -p "${SCRIPT_DIR}/context-library/prds"
  echo; echo "3) Syncing doe-os context-library PRDs..."
  rsync "${RSYNC_OPTS[@]}" "${DOE_DIR}/context-library/prds/" "${SCRIPT_DIR}/context-library/prds/"
fi

if [[ -n "${PM_DIR}" ]]; then
  echo; echo "────────────────────────"
  APPROVED_DIR="${PM_DIR}/outputs/prds/approved"
  [[ -d "${PM_DIR}" ]] || { echo "pm-os not found: ${PM_DIR}" >&2; exit 1; }
  [[ -d "${APPROVED_DIR}" ]] || { echo "No approved/ folder at ${APPROVED_DIR}" >&2; exit 1; }

  COUNT=$(find "${APPROVED_DIR}" -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')
  if [[ "${COUNT}" -eq 0 ]]; then
    echo "No approved PRDs found — nothing to sync from pm-os."
  else
    mkdir -p "${SCRIPT_DIR}/outputs/prds"
    echo; echo "4) Syncing ${COUNT} approved PRD(s) from pm-os..."
    rsync "${RSYNC_OPTS[@]}" "${APPROVED_DIR}/" "${SCRIPT_DIR}/outputs/prds/"
  fi
fi

echo; echo "Sync complete."
```

Write `{sync_target}/sync-all.zsh`:

```zsh
#!/usr/bin/env zsh
# sync-all.zsh — Publish all approved artifacts to ralph's ai/outputs/ inbox.
# Run this before rpc.plan.
#
# Usage:
#   ./ai/sync-all.zsh            # sync everything
#   ./ai/sync-all.zsh --dry-run  # preview without writing
set -euo pipefail
SCRIPT_DIR="${0:A:h}"
"${SCRIPT_DIR}/sync-doe-prd-outputs.zsh" --pm-os "$@"
```

Make both files executable:
```bash
chmod +x {sync_target}/sync-doe-prd-outputs.zsh {sync_target}/sync-all.zsh
```

If app URL was provided, also create the output directories:
```bash
mkdir -p {APP_DIR}/ai/outputs/prds {APP_DIR}/ai/outputs/specs
```

### 3.11 — Pre-fill pm-os business info template (if file exists)

Check if `{PMOS_DIR}/context-library/business-info-template.md` exists.
If it does, read it and replace these common placeholder patterns with actual values:
- `[Your Company]` → project_name
- `[Your Product]` → project_name
- `[Product description]` → product_desc
- `[Target users]` → target_market
- `[Team size]` → team_size

### 3.12 — Generate Claude auto-memory

Compute the absolute path of ROOT_DIR (resolve it). Then:
- Replace every `/` with `-`
- Strip the leading `-`
- This is the Claude project ID

Memory dir = `~/.claude/projects/{project_id}/memory/`

```bash
mkdir -p {memory_dir}
```

Write `{memory_dir}/MEMORY.md`:

```markdown
# {project_name} Project Memory

## SESSION START: Always Read PRD Pipeline

**At the start of every planning session, read `{ROOT_DIR}/PRD-PIPELINE.md` first.**
It is the source of truth for PRD → spec → fix_plan → execution status.
Update it at the end of every session.

---

## CRITICAL RULE: Plan Mode Only

**Always enter plan mode before writing any code.** Never write, edit, or create code files directly.

Workflow: Explore → Plan → User approves → Implement

---

## Three-Project Workflow (Ground Rules)

| Artifact | Lives In |
|----------|----------|
| PRDs | `product/{project_slug}-pm-os/outputs/prds/` |
| Approved PRDs (ralph inbox) | `product/{project_slug}-pm-os/outputs/prds/approved/` |
| Engineering specs + ADRs | `engineering/{project_slug}-doe-os/outputs/specs/` |
| Task list (fix_plan.md) | `engineering/{project_slug}-app/.ralph/fix_plan.md` |

**Publish gate (before rpc.plan):**
1. Copy approved PRD → `pm-os/outputs/prds/approved/`
2. Run `./ai/sync-all.zsh` from app dir
3. Run `rpc.plan`

**Ralph CLI:** `rpc.plan` / `rpd.plan` / `rpx.plan` = planning mode (Claude / Devin / Codex).
`rpc.int` / `rpd.int` / `rpx.int` = development mode.

---

## Project Overview

{project_name}: {product_desc}
Target: {target_market}. Team: {team_size} people.

## Engineering Stack

- Frontend: {frontend}
- Backend: {backend}
- Database: {database}
- Cloud: {cloud}
{stack_notes_line}

## Active PRDs
(none yet — add as PRDs are written)

## Active Specs
(none yet — add as specs are written)

## fix_plan.md Status
Not yet initialised — run `rpc.plan` after first PRD + spec are written and synced.
```

---

## Step 4: Print Summary

Print a clean summary of what was created:

```
── Setup Complete ─────────────────────────────────────

  ✓ Root:          {ROOT_DIR}
  ✓ pm-os:         {PMOS_DIR}
  ✓ doe-os:        {DOEOS_DIR}
  ✓ App:           {APP_DIR}  (or "not forked — add later")
  ✓ Sync scripts:  {sync_target}
  ✓ Claude memory: {memory_dir}

── Next Steps ──────────────────────────────────────────

  1. Open Claude Code in {ROOT_DIR}
  2. Fill in pm-os context library:
       {PMOS_DIR}/context-library/
  3. Write your first PRD:
       cd {PMOS_DIR} && /prd-draft
  4. Write the engineering spec in doe-os:
       {DOEOS_DIR}/outputs/specs/
  5. When PRD is approved → copy to pm-os/outputs/prds/approved/
  6. Run ./ai/sync-all.zsh then rpc.plan

  Happy building.
```

If the app was not forked, add a note: "Sync scripts are in {ROOT_DIR}/tools/ — move them to your app's ai/ folder when you create it."
