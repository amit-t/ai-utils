#!/usr/bin/env python3
"""Catalog updater for skill-sync sync mode.

Updates README.md, site.js, CHANGELOG.md, and skills-lock.json in the target
skills repo so that an existing or newly-synced skill is reflected everywhere
the catalog rule (CLAUDE.md) requires.

Idempotent: re-running for the same skill on the same day produces no extra
entries.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import re
import sys
from pathlib import Path

VALID_CATEGORIES = [
    "Product Management",
    "Project Management",
    "Engineering",
    "UX Design",
    "Agent Behavior",
    "AI Agent",
]


def parse_frontmatter(skill_md: Path) -> dict:
    text = skill_md.read_text(encoding="utf-8")
    if not text.startswith("---"):
        return {}
    end = text.find("\n---", 3)
    if end == -1:
        return {}
    block = text[3:end].strip()
    out = {}
    for line in block.splitlines():
        if ":" not in line:
            continue
        k, _, v = line.partition(":")
        out[k.strip()] = v.strip().strip('"').strip("'")
    return out


def first_paragraph_after_frontmatter(skill_md: Path) -> str:
    text = skill_md.read_text(encoding="utf-8")
    if text.startswith("---"):
        end = text.find("\n---", 3)
        if end != -1:
            text = text[end + 4 :]
    text = text.strip()
    paras = re.split(r"\n\s*\n", text)
    for p in paras:
        p = p.strip()
        if not p or p.startswith("#") or p.startswith("```"):
            continue
        return " ".join(p.splitlines()).strip()
    return ""


def prompt_category(skill_name: str) -> str:
    print(f"\nNo `category` field in {skill_name}/SKILL.md frontmatter.", file=sys.stderr)
    print("Pick one:", file=sys.stderr)
    for i, c in enumerate(VALID_CATEGORIES, 1):
        print(f"  {i}) {c}", file=sys.stderr)
    while True:
        try:
            ans = input("Category number: ").strip()
        except EOFError:
            print("skill-sync: stdin closed; cannot prompt for category", file=sys.stderr)
            sys.exit(1)
        if ans.isdigit() and 1 <= int(ans) <= len(VALID_CATEGORIES):
            return VALID_CATEGORIES[int(ans) - 1]
        print("Invalid choice.", file=sys.stderr)


def update_readme(repo_root: Path, slug: str, tagline: str, category: str) -> None:
    readme = repo_root / "README.md"
    text = readme.read_text(encoding="utf-8")
    section_pat = re.compile(rf"(### {re.escape(category)}\n\n\| Skill \| Description \|\n\|[^\n]*\|\n)((?:\|[^\n]*\n)*)")
    m = section_pat.search(text)
    if not m:
        # Append a new category section if missing.
        new_section = f"\n### {category}\n\n| Skill | Description |\n|-------|-------------|\n| [`{slug}`](./{slug}) | {tagline} |\n"
        text = text.rstrip() + "\n" + new_section
        readme.write_text(text, encoding="utf-8")
        return

    rows = m.group(2)
    row_pat = re.compile(rf"\| \[`{re.escape(slug)}`\]\(\./{re.escape(slug)}\) \|[^\n]*\n")
    new_row = f"| [`{slug}`](./{slug}) | {tagline} |\n"
    if row_pat.search(rows):
        rows = row_pat.sub(new_row, rows)
    else:
        rows = rows + new_row
    text = text[: m.start(2)] + rows + text[m.end(2) :]
    readme.write_text(text, encoding="utf-8")


def js_string(s: str) -> str:
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def render_skill_entry(slug: str, name: str, category: str, tagline: str, detail: str, usage: str) -> str:
    return (
        "  {\n"
        f"    slug: {js_string(slug)},\n"
        f"    name: {js_string(name)},\n"
        f"    category: {js_string(category)},\n"
        f"    tagline: {js_string(tagline)},\n"
        f"    detail: {js_string(detail)},\n"
        f"    usage: {js_string(usage)},\n"
        "  },"
    )


def update_site_js(repo_root: Path, slug: str, name: str, category: str,
                   tagline: str, detail: str, usage: str, change_text: str) -> None:
    site = repo_root / "site.js"
    text = site.read_text(encoding="utf-8")

    # ── skills array ──────────────────────────────────────────────────────────
    entry_pat = re.compile(
        r"\{\s*slug:\s*\"" + re.escape(slug) + r"\"[\s\S]*?\},\n",
        re.MULTILINE,
    )
    new_entry = render_skill_entry(slug, name, category, tagline, detail, usage) + "\n"
    if entry_pat.search(text):
        text = entry_pat.sub(new_entry, text, count=1)
    else:
        # Insert before the closing `];` of the skills array.
        skills_close = re.search(r"^const skills = \[[\s\S]*?\n\];", text, re.MULTILINE)
        if not skills_close:
            raise SystemExit("skill-sync: cannot find `const skills = [` in site.js")
        block = skills_close.group(0)
        # Insert new entry before final `];`
        new_block = block[:-2] + new_entry + "];"
        text = text[: skills_close.start()] + new_block + text[skills_close.end() :]

    # ── changes array ─────────────────────────────────────────────────────────
    today = dt.date.today().isoformat()
    changes_pat = re.compile(r"^const changes = \[\n", re.MULTILINE)
    m = changes_pat.search(text)
    if not m:
        raise SystemExit("skill-sync: cannot find `const changes = [` in site.js")

    # Look for an existing block for today.
    today_block_pat = re.compile(
        r"(\{\s*\n\s*date:\s*\"" + re.escape(today) + r"\",\s*\n\s*items:\s*\[\n)([\s\S]*?)(\n\s*\],\s*\n\s*\},\n)",
        re.MULTILINE,
    )
    m_today = today_block_pat.search(text)
    if m_today:
        items = m_today.group(2)
        item_line = f"      {js_string(change_text)},"
        if change_text in items:
            return  # already present
        new_items = items + "\n" + item_line
        text = text[: m_today.start(2)] + new_items + text[m_today.end(2) :]
    else:
        new_block = (
            "  {\n"
            f"    date: {js_string(today)},\n"
            "    items: [\n"
            f"      {js_string(change_text)},\n"
            "    ],\n"
            "  },\n"
        )
        insert_at = m.end()
        text = text[:insert_at] + new_block + text[insert_at:]

    site.write_text(text, encoding="utf-8")


def update_changelog(repo_root: Path, change_text: str) -> None:
    cl = repo_root / "CHANGELOG.md"
    text = cl.read_text(encoding="utf-8")
    today = dt.date.today().isoformat()
    today_heading = f"## {today}"
    bullet = f"- {change_text}"

    if today_heading in text:
        # Append bullet under today's heading if not already present.
        section_pat = re.compile(
            rf"({re.escape(today_heading)}\n\n)((?:- [^\n]*\n)*)",
        )
        m = section_pat.search(text)
        if not m:
            return
        bullets = m.group(2)
        if bullet in bullets:
            return
        new_bullets = bullets + bullet + "\n"
        text = text[: m.start(2)] + new_bullets + text[m.end(2) :]
    else:
        # Insert today's heading after the intro paragraph (before the first existing date heading).
        first_date = re.search(r"^## \d{4}-\d{2}-\d{2}", text, re.MULTILINE)
        new_section = f"{today_heading}\n\n{bullet}\n\n"
        if first_date:
            text = text[: first_date.start()] + new_section + text[first_date.start() :]
        else:
            text = text.rstrip() + "\n\n" + new_section

    cl.write_text(text, encoding="utf-8")


def update_skills_lock(repo_root: Path, skill_name: str, skill_dir: Path, source_path: Path) -> None:
    lock = repo_root / "skills-lock.json"
    if not lock.exists():
        data = {"version": 1, "skills": {}}
    else:
        try:
            data = json.loads(lock.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            data = {"version": 1, "skills": {}}
    data.setdefault("skills", {})
    h = hashlib.sha256((skill_dir / "SKILL.md").read_bytes()).hexdigest()
    data["skills"][skill_name] = {
        "source": str(source_path),
        "sourceType": "local",
        "computedHash": h,
    }
    lock.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo-root", required=True)
    ap.add_argument("--skill-name", required=True)
    ap.add_argument("--skill-dir", required=True)
    ap.add_argument("--source-path", required=True)
    args = ap.parse_args()

    repo_root = Path(args.repo_root)
    skill_dir = Path(args.skill_dir)
    source_path = Path(args.source_path)

    fm = parse_frontmatter(skill_dir / "SKILL.md")
    name = fm.get("name") or args.skill_name
    description = fm.get("description") or ""
    category = fm.get("category")
    if not category or category not in VALID_CATEGORIES:
        category = prompt_category(args.skill_name)

    tagline = description or args.skill_name
    detail = first_paragraph_after_frontmatter(skill_dir / "SKILL.md") or tagline
    usage = f"/{args.skill_name}"
    change_text = f"Synced `{args.skill_name}` from {source_path}."

    update_readme(repo_root, args.skill_name, tagline, category)
    update_site_js(repo_root, args.skill_name, name, category, tagline, detail, usage, change_text)
    update_changelog(repo_root, change_text)
    update_skills_lock(repo_root, args.skill_name, skill_dir, source_path)

    print(f"  • README.md row updated under {category}")
    print(f"  • site.js skills + changes entries upserted")
    print(f"  • CHANGELOG.md bullet added under today")
    print(f"  • skills-lock.json entry refreshed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
