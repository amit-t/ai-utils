# AI App BIOS — Project OS Bootstrap

One command to scaffold a new project with pm-os + doe-os + the full planning layer (CLAUDE.md, PRD-PIPELINE.md, sync scripts, Claude memory).

## How it works

`boot-app` is a thin launcher. It fires a `cly` (Claude bypass-permissions) session with a comprehensive prompt (`bootstrap.prompt.md`) that tells Claude to:

1. **Interview you** about the project (name, stack, repos)
2. **Clone** pm-os and doe-os scaffolds and detach from scaffold git history
3. **Generate** root CLAUDE.md, PRD-PIPELINE.md, sync scripts
4. **Write** Claude auto-memory to `~/.claude/projects/.../memory/`

All setup is done by Claude using its own tools. The shell script is just the launcher.

## What gets created

```
{project-slug}/
  product/{project-slug}-pm-os/       ← cloned from pm-os scaffold, fresh git
  engineering/{project-slug}-doe-os/  ← cloned from doe-os scaffold, fresh git
  engineering/{project-slug}-app/     ← your app repo (optional, cloned if URL given)
  CLAUDE.md                           ← plan-mode rules, workflow, ralph CLI ref
  PRD-PIPELINE.md                     ← PRD → spec → fix_plan tracker
  engineering/{project-slug}-app/ai/
    sync-all.zsh                      ← one-command sync approved PRDs + specs to ralph
    sync-doe-prd-outputs.zsh          ← underlying sync script
~/.claude/projects/.../memory/
  MEMORY.md                           ← auto-loaded Claude memory for this project
```

## Requirements

- `cly` alias configured: `alias cly='claude --dangerously-skip-permissions'`
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
# From any directory — Claude will install the project here
boot-app

# Specify the install directory explicitly
boot-app ${HOME}/Projects/Tools-Utilities/ai-utils
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
| pm-os scaffold URL | https://github.com/amit-t/pm-os |
| doe-os scaffold URL | https://github.com/amit-t/doe-os |
| App repo URL | https://github.com/your-org/your-app (optional) |

## After setup — workflow

```
1. Fill pm-os context library    → pm-os/context-library/
2. Write PRD                     → /prd-draft skill in pm-os
3. Write engineering spec        → doe-os/outputs/specs/
4. Approve PRD                   → copy to pm-os/outputs/prds/approved/
5. Sync                          → ./ai/sync-all.zsh  (from app dir)
6. Plan                          → rpc.plan
7. Build                         → rpc.int
```

## Scaffolds used

- **pm-os**: https://github.com/amit-t/pm-os
- **doe-os**: https://github.com/amit-t/doe-os
