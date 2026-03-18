# AI App BIOS — Project OS Bootstrap

One command to scaffold a new project with pm-os + doe-os + the full planning layer (CLAUDE.md, PRD-PIPELINE.md, sync scripts, Claude memory) — all managed as a **git-backed project management hub**.

## How it works

`boot-app` is a thin launcher. It fires a `cly` (Claude bypass-permissions) session with a comprehensive prompt (`bootstrap.prompt.md`) that tells Claude to:

1. **Interview you** about the project (name, stack, architecture, repos, GitHub org)
2. **Fork** app-hq (project hub), pm-os and doe-os scaffolds under your GitHub org (and optionally your app repo)
3. **Set up** the root directory as a local clone of the app-hq fork with proper `.gitignore`
4. **Generate** root CLAUDE.md, PRD-PIPELINE.md, sync scripts, aliases.sh
5. **Write** Claude auto-memory to `~/.claude/projects/.../memory/`
6. **Push** the generated files to the app-hq fork
7. **Generate** the first PRD (app bootstrap & scaffold) with your chosen architecture and tech stack

The root directory becomes a **project management hub** — a fork of app-hq that tracks only planning files while `engineering/` and `product/` sub-repos are gitignored (they have their own git history from forks).

## What gets created

```
{project-slug}/                         ← fork of app-hq (project management hub)
  .gitignore                            ← excludes engineering/ and product/
  CLAUDE.md                             ← plan-mode rules, workflow, ralph CLI ref
  PRD-PIPELINE.md                       ← PRD → spec → fix_plan tracker (pre-filled with PRD-001)
  aliases.sh                            ← CLI aliases (e.g. ep.sync)
  tools/                                ← shared scripts (if no app repo)
  product/{project-slug}-pm-os/         ← forked from pm-os scaffold (separate git)
    outputs/prds/
      PRD-001-app-bootstrap.md          ← first PRD: scaffold app with chosen arch + stack
    outputs/prds/approved/
      PRD-001-app-bootstrap.md          ← auto-approved, ready for rpc.plan
  engineering/{project-slug}-doe-os/    ← forked from doe-os scaffold (separate git)
  engineering/{project-slug}-app/       ← your app repo (optional, forked if URL given)
    ai/
      sync-all.zsh                      ← one-command sync approved PRDs + specs to ralph
      sync-doe-prd-outputs.zsh          ← underlying sync script
~/.claude/projects/.../memory/
  MEMORY.md                             ← auto-loaded Claude memory for this project
```

## Requirements

- `claude` CLI installed
- `gh` CLI installed and authenticated (for forking repos)
- `git` installed
- `rsync` installed

## Global install (one time)

Clone or copy `ai-app-bios/` to your tools directory, then:

```zsh
cd ${HOME}/Projects/Tools-Utilities/ai-utils/ai-app-bios
./install.zsh
source ~/.zshrc
```

This creates a symlink at `~/.local/bin/boot-app` and adds an alias to `~/.zshrc`.

## Usage

```zsh
# Create an empty directory for the project, then run boot-app from inside it
mkdir ~/Projects/my-project && cd ~/Projects/my-project
boot-app

# Or specify the install directory explicitly
boot-app ${HOME}/Projects/my-project
```

## Interview questions Claude will ask

| Question | Example |
|----------|---------|
| Project name | BabbleAI |
| Product description | Real-time voice translation SaaS |
| Target market | Global remote teams |
| Team size | 3 |
| Frontend framework | Next.js |
| Backend framework | Elysia.js + Bun |
| Database | PostgreSQL |
| Cloud / infra | AWS |
| Stack notes | Drizzle ORM, Redis, pnpm monorepo |
| Architecture pattern | Clean Architecture, Feature-Based, Hexagonal, etc. |
| GitHub org / username | BabbleAIHQ (used for all forks + hub repo) |
| app-hq (project hub) URL | https://github.com/AppIncubatorHQ/app-hq |
| pm-os scaffold URL | https://github.com/AppIncubatorHQ/pm-os |
| doe-os scaffold URL | https://github.com/AppIncubatorHQ/doe-os |
| App repo URL | https://github.com/your-org/your-app (optional) |

## After setup — workflow

```
0. Add aliases to shell          → echo 'source ~/Projects/my-app/aliases.sh' >> ~/.zshrc
1. Fill pm-os context library    → pm-os/context-library/
2. Write PRD                     → /prd-draft skill in pm-os
3. Write engineering spec        → doe-os/outputs/specs/
4. Approve PRD                   → copy to pm-os/outputs/prds/approved/
5. Sync                          → ./ai/sync-all.zsh  (from app dir)
6. Plan                          → rpc.plan
7. Build                         → rpc.int
```

## Scaffolds used

- **app-hq**: https://github.com/AppIncubatorHQ/app-hq
- **pm-os**: https://github.com/AppIncubatorHQ/pm-os
- **doe-os**: https://github.com/AppIncubatorHQ/doe-os
