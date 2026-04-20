# skill-sync

Sync an existing at-skills skill from a source path, or scaffold a new one via `claude` / `codex` / `devin`.

Designed to run from the root of any at-skills-style repo (e.g. `at-skills`, `qr-skills`). Cwd is treated as the target.

## Install

```bash
cd ai-utils/skill-sync
./install.zsh
```

This symlinks `skill-sync.zsh` to `~/.local/bin/skill-sync`. Make sure `~/.local/bin` is on `$PATH`.

## Usage

```text
skill-sync <source-path> [skill-name] [--agent claude|codex|devin] [--yolo]
```

| Arg / Flag | Description |
|------------|-------------|
| `<source-path>` | Direct path to a skill directory containing `SKILL.md`. |
| `[skill-name]`  | Optional. With it → **sync mode**. Without it → **build mode**. |
| `--agent`       | Build-mode only. `claude` (default), `codex`, or `devin`. |
| `--yolo`        | Pass dangerous-permission flag to the agent. |

### Sync mode

Mirrors `<source-path>/` into `<cwd>/<skill-name>/` and updates the four catalog files:

- `README.md` — upsert row under the right category table
- `site.js` — upsert entry in the `skills` array, prepend a `changes` entry under today's date
- `CHANGELOG.md` — bullet under today's date heading (creates the heading if needed)
- `skills-lock.json` — refresh the entry with a new SHA-256 of `SKILL.md`

The category is read from the source `SKILL.md` frontmatter (`category:`). If missing, you'll be prompted interactively.

### Build mode

Invokes the chosen agent CLI with a prompt that instructs it to scaffold a new skill from `<source-path>` into the current repo, following the at-skills `write-a-skill` conventions and the catalog rule in `CLAUDE.md`.

The agent does the file writes — this utility only sets up the prompt and the runtime context (`SKILL_SOURCE_PATH`, `SKILLS_REPO_DIR`).

## Examples

Sync an upstream e2e-audit refresh:

```bash
cd ~/Projects/Tools-Utilities/at-skills
skill-sync ~/Projects/Refinery/engineering/refinery-app/.agents/skills/e2e-audit e2e-audit
```

Build a brand-new skill from a directory of source notes, using Codex:

```bash
cd ~/Projects/Tools-Utilities/at-skills
skill-sync ~/Projects/Refinery/engineering/refinery-app/.agents/skills/new-thing --agent codex
```

Same, but yolo with Devin:

```bash
skill-sync ~/path/to/source --agent devin --yolo
```

## Requirements

- `zsh`, `python3`, `rsync` (all on macOS by default)
- One of: `claude`, `codex`, `devin` on `$PATH` (only the one you select with `--agent`)

## After running

`skill-sync` never commits or pushes. After it finishes:

```bash
git status
git diff
git checkout -b feat/<skill-name>-<change>
git add ...
git commit -m "feat(<skill-name>): ..."
git push -u origin <branch>
gh pr create --base main
```
