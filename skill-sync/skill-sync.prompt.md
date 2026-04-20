# Build a new at-skills skill from a source path

You are being invoked by the `skill-sync` utility in **build mode**. Your job is to scaffold a new agent skill in the current at-skills-style repo using the source directory provided in the runtime context.

## Inputs (from environment)

- `SKILL_SOURCE_PATH` — directory containing the source material (must contain `SKILL.md` and may include other files such as `README.md`, scripts, examples).
- `SKILLS_REPO_DIR` — root of the target skills repo. Treat this as your working directory for all writes.

## Hard requirements

1. **Read the source first.** Read every file under `$SKILL_SOURCE_PATH` to understand the skill's purpose, triggers, inputs/outputs, and any examples.

2. **Choose a slug.** Use the `name:` field from the source frontmatter if present, otherwise propose one based on the source content and confirm with the user before writing files.

3. **Pick a category.** Must be exactly one of:
   - `Product Management`
   - `Project Management`
   - `Engineering`
   - `UX Design`
   - `Agent Behavior`
   - `AI Agent`

   If the source frontmatter has a `category:` field, use it. Otherwise, propose one based on what the skill does and confirm.

4. **Write the skill files** at `$SKILLS_REPO_DIR/<slug>/`:
   - `SKILL.md` — required. Frontmatter: `name`, `description`, `category`, plus any agent-specific flags (e.g., `disable-model-invocation`, `user-invocable`). Body: clear instructions an agent can follow without further context. Use the existing skills in the repo as a style reference.
   - `README.md` — required. Human-facing overview: what the skill does, when to use it, install instructions per agent (Claude Code, Cursor, Codex, Devin, Gemini CLI), usage example, license.

5. **Update the catalog** per the rule in `$SKILLS_REPO_DIR/CLAUDE.md`. All four files must change:
   - `README.md` — add a row under the correct category table.
   - `site.js` — add an entry to the `skills` array (`slug`, `name`, `category`, `tagline`, `detail`, `usage`) and prepend an entry to the `changes` array under today's date.
   - `CHANGELOG.md` — add a bullet under today's date heading (create the heading if it does not exist).
   - `skills-lock.json` — add an entry for the new skill if appropriate.

6. **Follow conventional commits.** When you stage and commit, use a message like `feat(<slug>): add <slug> skill`.

7. **Do not push or open a PR.** The user drives git operations after reviewing your changes.

## Quality bar

- Match the voice and depth of the existing skills in `$SKILLS_REPO_DIR` (e.g., `eng-spec`, `prd-draft`, `e2e-audit`).
- Keep the SKILL.md focused on what an agent needs to act. Move long-form explanation to README.md.
- Verify your edits are syntactically valid (`site.js` should still be valid JavaScript; `skills-lock.json` should still be valid JSON).
- After writing, run `git status` and `git diff` so the user can review.

## What you can rely on

- `$SKILLS_REPO_DIR` is verified to be a skills repo (it has `site.js` and `AGENTS.md`).
- `$SKILL_SOURCE_PATH` is verified to exist and contain `SKILL.md`.

Begin by reading the source skill and the target repo's existing structure, then propose the slug and category before writing any files.
