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

### Section 2b — Architecture & Folder Structure
Ask this after the tech stack. Present numbered options with descriptions so the user can make an informed choice. Explain briefly why each matters and give a recommendation based on their chosen stack.

**Architecture pattern — pick one (or type your own):**

| # | Pattern | Description | Best For | Example Folder Layout |
|---|---------|-------------|----------|----------------------|
| 1 | **Clean Architecture** | Uncle Bob's layered approach. Strict dependency rule: inner layers never import outer. Layers: entities → use cases → interface adapters → frameworks. | Medium–large apps, teams > 2, long-lived products needing testability | `src/{domain,application,infrastructure,presentation}/` |
| 2 | **Hexagonal (Ports & Adapters)** | Business logic in the centre, external systems plug in via ports (interfaces) and adapters (implementations). Easy to swap DB, API, or UI. | API-heavy backends, microservices, projects needing high swappability | `src/{core/ports,core/services,adapters/in,adapters/out}/` |
| 3 | **Feature-Based (Vertical Slices)** | Each feature is a self-contained folder with its own routes, components, services, and tests. Minimal cross-feature imports. | Fast-moving startups, small teams, monorepos with many independent features | `src/features/{auth,dashboard,billing}/` each with `{api,ui,model,test}/` |
| 4 | **Modular Monolith** | Domain-driven modules with clear public APIs between them. Monolith in deployment, microservice-ready in code boundaries. | Teams planning future service extraction, complex domains | `src/modules/{users,payments,notifications}/` each with `{domain,infra,api}/` |
| 5 | **MVC / MVVM** | Classic separation: Model (data), View (UI), Controller/ViewModel (logic). Straightforward and widely understood. | Simple CRUD apps, MVPs, solo developers, rapid prototyping | `src/{models,views,controllers}/` or `src/{models,views,viewmodels}/` |
| 6 | **Layered (N-Tier)** | Horizontal layers: presentation → business logic → data access. Each layer only calls the one below. Simple but can lead to "god service" classes at scale. | Traditional REST APIs, smaller projects, teams familiar with enterprise Java/.NET patterns | `src/{api,services,repositories,models}/` |

**Recommendation guidance** (say this to the user):
- For **React + Vite / Next.js** frontends: Feature-Based or Clean Architecture work best. Feature-Based is faster to start; Clean scales better.
- For **Elysia / Express / FastAPI** backends: Hexagonal or Clean Architecture are strongest for APIs. Feature-Based works well for smaller APIs.
- For **monorepos** (pnpm/Turborepo): Modular Monolith + Feature-Based is a natural fit — each package or app follows Feature-Based internally.
- For **MVPs / solo devs**: MVC or Feature-Based — lowest ceremony, fastest to ship.
- For **teams > 3 / long-lived products**: Clean Architecture or Hexagonal — the upfront structure pays off in maintainability.

After they pick, confirm: "I'll use **{pattern}** for the folder scaffold structure in the first bootstrap PRD."

### Section 3 — Repositories & GitHub Org
Ask these together:
- **GitHub org or username** under which ALL repos will be created — forks (app-hq, pm-os, doe-os, app) and the project hub repo. Default: personal GitHub account — press Enter to accept. Example: For "EverPlan", org `EverPlanHQ` → all repos live under `github.com/EverPlanHQ/`.
- app-hq (project hub) GitHub URL (default: `https://github.com/AppIncubatorHQ/app-hq` — press Enter to accept)
- pm-os scaffold GitHub URL (default: `https://github.com/AppIncubatorHQ/pm-os` — press Enter to accept)
- doe-os scaffold GitHub URL (default: `https://github.com/AppIncubatorHQ/doe-os` — press Enter to accept)
- Main app GitHub URL — optional, leave blank to skip cloning

### Section 4 — Confirm
Show a compact summary of all answers, then ask: **"Ready to set up? [Y/n]"**

If they say no, ask what to change and loop back.

---

## Step 2: Compute Values

Before writing anything, compute these internally:

**project_slug**: lowercase, hyphens only. Examples: "EverPlan" → `everplan`, "My App" → `my-app`, "BabbleAI" → `babbleai`

**Directories** (the install directory passed at the bottom of this prompt is ROOT_DIR — the current working directory where boot-app was run. Do NOT create a subdirectory named after the project; set up everything directly inside this directory):
```
ROOT_DIR   = {install_dir}
PMOS_DIR   = {ROOT_DIR}/product/{project_slug}-pm-os
DOEOS_DIR  = {ROOT_DIR}/engineering/{project_slug}-doe-os
APP_DIR    = {ROOT_DIR}/engineering/{project_slug}-app   (only if app URL given)
```

**GitHub org**:
- `GITHUB_ORG` = the GitHub org or username provided (may be empty → personal account)
- This is used for ALL repos: forks (pm-os, doe-os, app) AND the project hub repo
- If `GITHUB_ORG` is set: hub repo will be `{GITHUB_ORG}/{project_name}`, forks go under `{GITHUB_ORG}/`
- If empty: everything goes under the user's personal GitHub account
- Derive a short **alias prefix** from the project name (2-3 lowercase letters). Examples: "EverPlan" → `ep`, "BabbleAI" → `ba`, "TaskFlow" → `tf`, "My App" → `ma`

**Architecture**:
- `ARCH_PATTERN` = the chosen architecture pattern name (e.g. "Clean Architecture", "Feature-Based")
- `ARCH_FOLDER_LAYOUT` = the example folder layout string from the table (e.g. `src/{domain,application,infrastructure,presentation}/`)
- These are used in the bootstrap PRD (Step 3.15) and threaded into CLAUDE.md / MEMORY.md

**Claude memory path**:
- Take ROOT_DIR as an absolute path
- Replace every `/` with `-` (drop the leading `-`)
- Result: `~/.claude/projects/{that-id}/memory/`
- Example: `/Users/amit/Projects/babble` → `~/.claude/projects/-Users-amit-Projects-babble/memory/`

---

## Step 3: Execute Setup

Run these steps in order. Announce each step as you go ("Setting up pm-os...", etc.).

### 3.1 — Fork app-hq into ROOT_DIR and create subdirectories

ROOT_DIR is the current working directory (the install directory). Fork the app-hq repo to create the project hub. **Do NOT create an `app-hq` subdirectory** — initialize the fork directly inside ROOT_DIR.

**Fork on GitHub (no clone):**
If `GITHUB_ORG` is set:
```bash
gh repo fork {apphq_url} --fork-name {project_name} --org {GITHUB_ORG} --clone=false
```
If no org (personal account):
```bash
gh repo fork {apphq_url} --fork-name {project_name} --clone=false
```

**Then set up ROOT_DIR as the fork's local clone:**
```bash
cd {ROOT_DIR}
git init -b main
git remote add origin https://github.com/{GITHUB_ORG_OR_USER}/{project_name}.git
git remote add upstream {apphq_url}
git fetch origin
git reset --hard origin/main
```
Where `{GITHUB_ORG_OR_USER}` is the GitHub org (if set) or the user's GitHub username (obtain via `gh api user -q .login`).

**Create project subdirectories:**
```bash
mkdir -p {ROOT_DIR}/product
mkdir -p {ROOT_DIR}/engineering
mkdir -p {ROOT_DIR}/tools
```

### 3.2 — Fork pm-os scaffold
If `GITHUB_ORG` is set:
```bash
gh repo fork {pmos_url} --clone --remote --fork-name {project_slug}-pm-os --org {GITHUB_ORG}
```
If no org (personal account):
```bash
gh repo fork {pmos_url} --clone --remote --fork-name {project_slug}-pm-os
```
Then move into place:
```bash
mv {project_slug}-pm-os {PMOS_DIR}
```

### 3.3 — Fork doe-os scaffold
If `GITHUB_ORG` is set:
```bash
gh repo fork {doeos_url} --clone --remote --fork-name {project_slug}-doe-os --org {GITHUB_ORG}
```
If no org (personal account):
```bash
gh repo fork {doeos_url} --clone --remote --fork-name {project_slug}-doe-os
```
Then move into place:
```bash
mv {project_slug}-doe-os {DOEOS_DIR}
```

### 3.4 — Fork app repo (only if URL was provided)
`{app_repo_name}` = the last path segment of `{app_url}` (e.g. `https://github.com/org/my-app` → `my-app`)
If `GITHUB_ORG` is set:
```bash
gh repo fork {app_url} --clone --remote --org {GITHUB_ORG}
```
If no org (personal account):
```bash
gh repo fork {app_url} --clone --remote
```
Then move into place:
```bash
mv {app_repo_name} {APP_DIR}
```

### 3.5 — (Handled by Step 3.1)

ROOT_DIR was already initialized as a git repo and connected to the app-hq fork in Step 3.1. No additional git initialization is needed.

### 3.6 — Create .gitignore

Write `{ROOT_DIR}/.gitignore`:

```
.DS_Store

# Managed as separate git repos (forked independently)
engineering/
product/
```

This ensures the hub repo only tracks root-level management files (CLAUDE.md, PRD-PIPELINE.md, aliases, tools/, etc.) and does NOT track the sub-repos which have their own git history from the forks.

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

## Architecture

- Pattern: {ARCH_PATTERN}
- Folder layout: `{ARCH_FOLDER_LAYOUT}`

All new code and scaffold PRDs must follow this architecture. When creating new features, modules, or services, use the folder structure prescribed by this pattern.
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
| 1 | App Bootstrap & Scaffold | ✓ PRD-001 (approved) | — | — | — | Auto-generated by boot-app. {ARCH_PATTERN} architecture. |

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

## Architecture

- Pattern: {ARCH_PATTERN}
- Folder layout: `{ARCH_FOLDER_LAYOUT}`
- All new code must follow this pattern. When scaffolding features, use the prescribed folder structure.

## Active PRDs
(none yet — add as PRDs are written)

## Active Specs
(none yet — add as specs are written)

## fix_plan.md Status
Not yet initialised — run `rpc.plan` after first PRD + spec are written and synced.
```

### 3.13 — Create aliases.sh

Write `{ROOT_DIR}/aliases.sh`, using the alias prefix computed in Step 2:

```bash
#!/usr/bin/env bash
# {project_name} CLI aliases
# Source this file in your .bashrc / .zshrc / .bash_profile:
#   source {ROOT_DIR}/aliases.sh

{ALIAS_PREFIX}_APP="{APP_DIR}"

# Sync approved PRDs + doe-os specs into ralph's inbox
#   Runs sync-doe-prd-outputs.zsh from {project_slug}-app/
{alias_prefix}.sync() { (cd "${{{ALIAS_PREFIX}_APP}}" && ./ai/sync-doe-prd-outputs.zsh "$@"); }
```

Where `{ALIAS_PREFIX}` is the uppercase version of the alias prefix (e.g. `EP` for EverPlan), and `{alias_prefix}` is lowercase (e.g. `ep`).

If no app URL was provided, comment out the alias with a note: `# Uncomment and set {ALIAS_PREFIX}_APP when you add your app repo`

### 3.14 — Commit and push to app-hq fork

The GitHub repo already exists as a fork of app-hq (created in Step 3.1). Commit the generated files and push:

```bash
cd {ROOT_DIR}
git add .
git commit -m "feat: initialize {project_name} project management hub with PM OS and DOE OS planning layer"
git push origin main
```

This pushes all hub files (.gitignore, CLAUDE.md, PRD-PIPELINE.md, aliases.sh, tools/) to the forked repo.

### 3.15 — Generate first PRD: App Bootstrap & Scaffold

Write a complete PRD to `{PMOS_DIR}/outputs/prds/PRD-001-app-bootstrap.md` that describes scaffolding the app with the chosen tech stack and architecture pattern. This is the **first PRD** so the team can immediately run `rpc.plan` after setup.

The PRD must be written in the pm-os PRD format (check if `{PMOS_DIR}` has a PRD template — if so, follow it; otherwise use the structure below).

Write the following to `{PMOS_DIR}/outputs/prds/PRD-001-app-bootstrap.md`, substituting all `{placeholders}`:

```markdown
# PRD-001: {project_name} App Bootstrap & Scaffold

**Status:** Draft
**Author:** AI App BIOS (auto-generated)
**Created:** {today_date}
**Priority:** P0 — Must be done first

---

## 1. Problem Statement

The {project_name} project has been initialised with PM OS and DOE OS, but the application codebase (`engineering/{project_slug}-app/`) needs to be scaffolded with the correct tech stack, architecture pattern, and folder structure before any feature work can begin.

## 2. Goal

Set up a production-ready project scaffold for **{project_name}** that:
- Implements the **{ARCH_PATTERN}** architecture pattern
- Uses the agreed tech stack end-to-end
- Includes working dev server, build pipeline, linting, and test runner
- Follows the prescribed folder layout from day one
- Is ready for the first feature PRD to build on

## 3. Tech Stack

| Layer | Choice |
|-------|--------|
| Frontend | {frontend} |
| Backend | {backend} |
| Database | {database} |
| Cloud / Infra | {cloud} |
| Architecture | {ARCH_PATTERN} |
{stack_notes_table_row}

## 4. Architecture & Folder Structure

**Pattern:** {ARCH_PATTERN}

**Target folder layout:**
```
{ARCH_FOLDER_LAYOUT}
```

### What each layer/folder is for:

(Generate 3–5 bullet points explaining the purpose of each top-level folder in the chosen architecture pattern. Tailor these to the specific tech stack chosen.)

## 5. Acceptance Criteria

- [ ] Project initialised with package manager (e.g. `pnpm init`, `bun init`, `npm init`)
- [ ] Folder structure matches the {ARCH_PATTERN} layout above
- [ ] Frontend scaffolded with {frontend} — dev server starts and renders a hello-world page
- [ ] Backend scaffolded with {backend} — server starts and responds to a health-check endpoint (`GET /health`)
- [ ] Database connection configured for {database} (connection tested, migrations folder created)
- [ ] Linting & formatting configured (ESLint / Prettier or language equivalent)
- [ ] Test runner configured and one example test passes per layer (frontend + backend)
- [ ] Build pipeline works (`build` script produces production output)
- [ ] Environment variables managed via `.env` / `.env.example` (no secrets committed)
- [ ] README.md written with: project overview, tech stack, dev setup instructions, and folder structure explanation
- [ ] `.gitignore` appropriate for the stack (node_modules, dist, .env, etc.)

## 6. Out of Scope

- User authentication / authorization (separate PRD)
- CI/CD pipeline setup (separate PRD)
- Production deployment (separate PRD)
- Feature-specific business logic

## 7. Dependencies

- This PRD has no dependencies — it is the first PRD.
- All subsequent PRDs depend on this scaffold being complete.

## 8. Notes

This PRD was auto-generated by AI App BIOS during project setup. Review and adjust acceptance criteria before approving.
```

Where `{stack_notes_table_row}` is either `| Additional | {stack_notes} |` if stack notes were provided, or omitted if blank.

After writing the PRD, also copy it to the approved folder so it's immediately ready for `rpc.plan`:
```bash
cp {PMOS_DIR}/outputs/prds/PRD-001-app-bootstrap.md {PMOS_DIR}/outputs/prds/approved/PRD-001-app-bootstrap.md
```

---

## Step 4: Print Summary

Print a clean summary of what was created:

```
── Setup Complete ─────────────────────────────────────

  ✓ Root (hub):     {ROOT_DIR}
  ✓ GitHub repo:    {hub_repo_url}  (fork of app-hq)
  ✓ pm-os:         {PMOS_DIR}
  ✓ doe-os:        {DOEOS_DIR}
  ✓ App:           {APP_DIR}  (or "not forked — add later")
  ✓ Sync scripts:  {sync_target}
  ✓ Claude memory: {memory_dir}
  ✓ .gitignore:    engineering/ and product/ excluded (separate repos)
  ✓ aliases.sh:    source {ROOT_DIR}/aliases.sh
  ✓ Architecture:  {ARCH_PATTERN}
  ✓ First PRD:     PRD-001-app-bootstrap.md (approved, ready for rpc.plan)

── Next Steps ──────────────────────────────────────────

  1. Add aliases to your shell:
       echo 'source {ROOT_DIR}/aliases.sh' >> ~/.zshrc && source ~/.zshrc
  2. Open Claude Code in {ROOT_DIR}
  3. Review the bootstrap PRD:
       {PMOS_DIR}/outputs/prds/PRD-001-app-bootstrap.md
  4. Write the engineering spec for PRD-001:
       {DOEOS_DIR}/outputs/specs/
  5. Sync + plan:
       ./ai/sync-all.zsh && rpc.plan
  6. Build:
       rpc.int

  Your first PRD is ready — write the engineering spec and you can start building.
```

If the app was not forked, add a note: "Sync scripts are in {ROOT_DIR}/tools/ — move them to your app's ai/ folder when you create it."
