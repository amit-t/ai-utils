# add-os — New OS Provisioning Prompt

You are a project setup agent. Your job is to provision a new OS repo into an existing
project that was bootstrapped with `boot-app`. You fork the upstream OS on GitHub, clone
it to the correct local directory, configure the upstream remote, and pre-fill the
business info template from existing project context.

The Runtime Context block at the end of this prompt provides the specific OS to add.

---

## Known OS Defaults

If `UPSTREAM_URL` is empty in the Runtime Context, look up the default here:

| OS name     | Default upstream URL                                    | Local placement       | Method          |
|-------------|---------------------------------------------------------|-----------------------|-----------------|
| `uxd-os`    | `git@github.com-at:AppIncubatorHQ/uxd-os.git`          | `product/`            | fork            |
| `pm-os`     | `https://github.com/AppIncubatorHQ/pm-os`               | `product/`            | fork            |
| `doe-os`    | `https://github.com/AppIncubatorHQ/doe-os`              | `engineering/`        | fork            |
| `ai-fs-os`  | `https://github.com/AppIncubatorHQ/ai-fs-os`            | `.` (root level)      | template+private|

For any OS not in this table, default to `product/` for placement and require an explicit
`UPSTREAM_URL` — if none was provided and the OS is unknown, stop and report an error
in `${RESULT_FILE}`.

**Method column:**
- `fork` — standard `gh repo fork` (maintains fork relationship to upstream)
- `template+private` — use `gh repo create --template --private` (fresh private repo, no fork link)

---

## Step 1 — Load project context

Read `${PROJECT_ROOT}/CLAUDE.md` and extract:
- **project_name** — the project name (e.g. "EverPlan")
- **project_slug** — the lowercase hyphenated slug (e.g. "everplan")
- **github_org** — the GitHub org or username (look for it in the repo remote URLs)

Get the GitHub org/user from the existing fork remotes:
```bash
cd ${PROJECT_ROOT}
git remote get-url origin 2>/dev/null || true
```
Parse `{org_or_user}` from the origin URL (e.g. `git@github.com-at:EverPlanHQ/everplan.git` → `EverPlanHQ`).

If CLAUDE.md doesn't exist or doesn't contain a clear slug, derive the slug from the
directory name of `${PROJECT_ROOT}`.

---

## Step 2 — Detect GitHub auth mode

```bash
gh auth status
grep -A5 "Host github" ~/.ssh/config 2>/dev/null || echo "No custom SSH host config found"
```

Set `GIT_URL_PREFIX`:
- HTTPS: `https://github.com`
- SSH standard: `git@github.com`
- SSH custom alias (e.g. `github.com-at`): `git@github.com-at`

Use `${GIT_URL_PREFIX}/{org_or_user}/{fork_name}.git` for all clone URLs.

---

## Step 3 — Determine OS placement and fork name

Using the `OS_NAME` from the Runtime Context:

1. Look up the placement directory and method from the Known OS Defaults table above.
2. Set `FORK_NAME` = `{project_slug}-{OS_NAME}` (e.g. `everplan-uxd-os`)
3. Set `OS_DIR`:
   - If placement is `.` (root level): `OS_DIR` = `${PROJECT_ROOT}/{FORK_NAME}`
   - Otherwise: `OS_DIR` = `${PROJECT_ROOT}/{placement}/{FORK_NAME}`
4. Set `UPSTREAM_URL` = the value from Runtime Context if non-empty, otherwise the known default.
5. Set `METHOD` = the method from the Known OS Defaults table (`fork` or `template+private`). Default: `fork`.

Check whether `OS_DIR` already exists:
```bash
[[ -d "${OS_DIR}" ]] && echo "Already exists" || echo "Not found"
```
If it already exists and has a `.git` directory, stop and write to `${RESULT_FILE}`:
```
Error: ${OS_DIR} already exists as a git repo. Nothing to do.
If you want to re-provision it, remove the directory first.
```
Then exit.

---

## Step 4 — Create repo on GitHub

**If `METHOD` is `template+private`** (e.g. `ai-fs-os`):

Use the upstream as a template to create a private repo (no fork relationship):

If `GITHUB_ORG` is set:
```bash
cd "${PROJECT_ROOT}"
gh repo create {GITHUB_ORG}/{FORK_NAME} \
  --template {UPSTREAM_URL_WITHOUT_DOT_GIT} \
  --private \
  --clone
```
If personal account:
```bash
cd "${PROJECT_ROOT}"
gh repo create {FORK_NAME} \
  --template {UPSTREAM_URL_WITHOUT_DOT_GIT} \
  --private \
  --clone
```

Where `{UPSTREAM_URL_WITHOUT_DOT_GIT}` is the upstream URL with `.git` stripped (e.g. `AppIncubatorHQ/ai-fs-os`). You can also use the `OWNER/REPO` shorthand.

After `gh repo create --clone`, verify the repo landed at `OS_DIR`:
```bash
[[ -d "${OS_DIR}/.git" ]] && echo "✓ Created from template" || echo "✗ Not found at expected path"
```

If it cloned to a different directory name, move it to `OS_DIR`.

**Skip Step 5** (clone step) — `gh repo create --clone` already cloned the repo.
**Skip adding upstream remote** — template repos have no fork relationship to track.
**Proceed directly to Step 6** (business context).

---

**If `METHOD` is `fork`** (standard, for pm-os, doe-os, uxd-os, etc.):

Fork the upstream OS repo under the project's org:

If `GITHUB_ORG` is set (org, not personal):
```bash
gh repo fork {UPSTREAM_URL} --fork-name {FORK_NAME} --org {GITHUB_ORG} --clone=false
```
If personal account:
```bash
gh repo fork {UPSTREAM_URL} --fork-name {FORK_NAME} --clone=false
```

If the fork already exists on GitHub (gh reports it), that is fine — proceed to the
clone step. Do not treat an already-existing fork as an error.

---

## Step 5 — Clone into the correct local directory (fork method only)

**Skip this step if `METHOD` is `template+private`** — the repo was already cloned in Step 4.

```bash
mkdir -p "$(dirname ${OS_DIR})"
git clone "${GIT_URL_PREFIX}/{org_or_user}/{FORK_NAME}.git" "${OS_DIR}"
cd "${OS_DIR}"
git remote add upstream {UPSTREAM_URL}
git fetch upstream --quiet
```

Verify:
```bash
git remote -v   # should show origin = fork URL, upstream = UPSTREAM_URL
git log --oneline -3
```

---

## Step 6 — Read existing project business context

The project already has pm-os set up. Read its business info to use for pre-filling:

```bash
# Find pm-os directory
ls "${PROJECT_ROOT}/product/" | grep '\-pm-os$'
```

Set `PMOS_DIR` = `${PROJECT_ROOT}/product/{project_slug}-pm-os`

Read `${PMOS_DIR}/context-library/business-info.md` if it exists. Extract:
- Company name, industry, stage, founded year, website, team size
- Product name, one-liner, detailed description, key features
- Problem statement, solution statement, mission, vision
- Primary and secondary categories
- Target market, buyer personas
- Technology stack (frontend, backend, database, cloud)

If `${PMOS_DIR}/context-library/business-info.md` does not exist, try
`${PMOS_DIR}/context-library/business-info-template.md`. If neither exists, note
"pm-os business info not found — business info template will be left as-is" and
continue.

Also read `${PROJECT_ROOT}/CLAUDE.md` for the tech stack (frontend, backend, database,
cloud, architecture pattern) in case pm-os info is incomplete.

---

## Step 7 — Pre-fill business info template

Check if `${OS_DIR}/context-library/business-info-template.md` exists:
```bash
[[ -f "${OS_DIR}/context-library/business-info-template.md" ]] && echo "Found" || echo "Not found"
```

**If found:**

Create `${OS_DIR}/context-library/business-info.md` by copying the template and replacing
all matching placeholders with the values read in Step 6.

Apply the standard replacement map:

| Template placeholder | Replace with |
|---|---|
| `[Your Company Name]` | project_name |
| `[Your Industry - e.g., SaaS, Fintech, Healthcare]` | industry |
| `[Company Stage - e.g., Seed, Series A, Series B, Growth, Public]` | company_stage |
| `[Year]` (in Founded line only) | founded_year |
| `[Number]` (in Employees line only) | team_size |
| `[ARR/Revenue figure]` | `$0 (pre-revenue)` if stage is Idea/Pre-seed/Seed, else leave as placeholder |
| `[Funding stage and total raised]` | `$0 (pre-funding)` if stage is Idea/Pre-seed, else leave as placeholder |
| `[URL]` (in Website line only) | website_url (or `TBD` if blank) |
| `[Your Product Name]` | project_name |
| `[One sentence describing what your product does and for whom]` | product one-liner |
| `[2-3 paragraphs describing your product...]` | detailed description |
| `[e.g., Project Management, Analytics, CRM]` (Primary Category) | primary_category |
| `[Related categories]` | secondary_categories (or leave as placeholder if blank) |
| `[Feature 1]` through `[Feature 5]` | key features list; leave remaining as placeholder if fewer than 5 |
| `[Technologies]` lines in Technology Stack | Frontend → frontend, Backend → backend, Database → database, Infrastructure → cloud |
| `[Describe the core problem your product solves...]` | problem_statement |
| `[Describe how your product solves the problem...]` | solution_statement |
| `[Your company's mission - what you exist to do]` | mission_statement |
| `[Where you want to be in 3-5 years]` | vision_statement |

Leave all other placeholders as-is.

After writing `business-info.md`:
```bash
rm "${OS_DIR}/context-library/business-info-template.md"
```

**If not found:**
Note "No business-info-template.md in ${OS_DIR}/context-library/ — skipping pre-fill"
and continue. The user can fill it manually later.

---

## Step 8 — Commit and push

```bash
cd "${OS_DIR}"
git add .
git diff --quiet && git diff --cached --quiet || \
  git commit -m "feat: initialize {FORK_NAME} with project context"
git push origin main
```

---

## Step 9 — Write result summary

Write `${RESULT_FILE}`:

```markdown
# Add-OS Result

**OS added:** {OS_NAME}
**Fork name:** {FORK_NAME}
**Local path:** {OS_DIR}
**Upstream:** {UPSTREAM_URL}
**Method:** {METHOD}  (fork / template+private)
**Repo URL:** {repo_url_on_github}

## Actions taken

- [x] Created {FORK_NAME} on GitHub  (forked from / created from template: {UPSTREAM_URL})
- [x] Cloned to {OS_DIR}
- [x] Upstream remote configured  (or: "N/A — template method, no upstream remote")
- [x] Business info pre-filled  (or: "Skipped — no template found" / "Skipped — no pm-os business info")
- [x] Committed and pushed to origin

## Next steps

1. Run `update.os --repos {OS_NAME}` to pull any upstream improvements
2. Review and complete the business info:
   {OS_DIR}/context-library/business-info.md
3. Run `source ~/Profiles/.zprofile` if you added new aliases
```

---

## Important rules

- **Never overwrite an existing fork directory** that already has a `.git` folder.
- **Never force-push.** Use regular `git push origin main`.
- **If the fork already exists on GitHub**, proceed — do not treat it as an error.
- **If pm-os business info is not found**, pre-fill what you can from CLAUDE.md and
  leave the rest as template placeholders.
- **If any step fails**, write the error clearly to `${RESULT_FILE}` and stop rather
  than continuing with a broken state.
