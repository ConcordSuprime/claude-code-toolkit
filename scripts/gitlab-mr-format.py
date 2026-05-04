#!/usr/bin/env python3
"""Formats GitLab MR or commit data into structured markdown for Claude code review."""

import sys
import json

url = sys.argv[1]
info_file = sys.argv[2]
changes_file = sys.argv[3]
gomod_file = sys.argv[4]
mode = sys.argv[5] if len(sys.argv) > 5 else "mr"
commit_sha = sys.argv[6] if len(sys.argv) > 6 else ""

with open(info_file) as f:
    info = json.load(f)

with open(changes_file) as f:
    raw = json.load(f)

with open(gomod_file) as f:
    gomod = f.read().strip()

# Normalize changes list
if isinstance(raw, list):
    changes = raw  # commit diff — array of diffs
else:
    changes = raw.get("changes", [])  # MR changes — object with changes key

print("# Code Review Context\n")

if mode == "commit":
    print("## Commit")
    print(f"- **SHA:** `{commit_sha[:12]}`")
    print(f"- **Title:** {info.get('title', '')}")
    print(f"- **Author:** {info.get('author_name', '')}")
    print(f"- **Date:** {info.get('authored_date', '')}")
    msg = (info.get("message") or "").strip()
    if msg and msg != info.get("title", "").strip():
        print(f"- **Message:** {msg}")
    stats = info.get("stats", {})
    print(f"- **Changes:** +{stats.get('additions', '?')} / -{stats.get('deletions', '?')} in {len(changes)} files")
    print(f"- **URL:** {url}\n")
else:
    print("## Merge Request")
    print(f"- **Title:** {info.get('title', '')}")
    print(f"- **Author:** {info.get('author', {}).get('name', '')}")
    print(f"- **Branch:** `{info.get('source_branch', '')}` → `{info.get('target_branch', '')}`")
    print(f"- **Changed files:** {len(changes)}")
    print(f"- **URL:** {url}\n")
    desc = (info.get("description") or "").strip() or "(no description)"
    print(f"## Description\n{desc}\n")

print("## go.mod (project dependencies)")
print("```")
print(gomod)
print("```\n")

print("## Code Changes\n")
for c in changes:
    path = c.get("new_path") or c.get("old_path", "unknown")
    diff = c.get("diff", "")
    if not diff.strip():
        continue
    lines = diff.splitlines()
    if len(lines) > 150:
        diff = "\n".join(lines[:150]) + f"\n... ({len(lines) - 150} more lines truncated)"
    print(f"### {path}")
    print("```diff")
    print(diff)
    print("```\n")
