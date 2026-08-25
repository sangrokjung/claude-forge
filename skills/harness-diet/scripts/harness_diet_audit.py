#!/usr/bin/env python3
"""harness_diet_audit.py — measure the always-loaded context of a Claude Code harness.

Part of Claude Forge — github.com/sangrokjung/claude-forge (skills/harness-diet)

Scans rules directories and CLAUDE.md files, classifies rules as always-loaded
(no `paths:` key in YAML frontmatter) vs conditional, and reports byte totals
against budgets.

Usage:
  harness_diet_audit.py [--rules-dir DIR ...] [--claude-md FILE ...]
                        [--file-budget 8192] [--total-budget 102400]
                        [--claude-md-lines 200] [--json] [--strict]

Defaults auto-discover: ./.claude/rules, ~/.claude/rules,
./CLAUDE.md, ./.claude/CLAUDE.md, ~/.claude/CLAUDE.md.
--strict exits 2 when any budget is exceeded (for CI / ratchet use).
"""
import argparse
import json
import os
import re
import sys

FRONTMATTER_RE = re.compile(r"\A---\s*\n(.*?)\n---\s*\n", re.S)


def parse_frontmatter(text):
    m = FRONTMATTER_RE.match(text)
    if not m:
        return None
    fm = {}
    for line in m.group(1).splitlines():
        km = re.match(r"^([A-Za-z_][A-Za-z0-9_-]*):", line)
        if km:
            fm[km.group(1)] = line.split(":", 1)[1].strip()
    return fm


def scan_rules_dir(path):
    entries = []
    for name in sorted(os.listdir(path)):
        if not name.endswith(".md") or name.startswith("_"):
            continue
        fp = os.path.join(path, name)
        if not os.path.isfile(fp):
            continue
        try:
            text = open(fp, encoding="utf-8", errors="replace").read()
        except OSError:
            continue
        fm = parse_frontmatter(text)
        always = fm is None or "paths" not in fm
        entries.append({
            "file": name,
            "bytes": len(text.encode("utf-8")),
            "always_load": always,
            "has_frontmatter": fm is not None,
        })
    return entries


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rules-dir", action="append", default=[])
    ap.add_argument("--claude-md", action="append", default=[])
    ap.add_argument("--file-budget", type=int, default=8192)
    ap.add_argument("--total-budget", type=int, default=102400)
    ap.add_argument("--claude-md-lines", type=int, default=200)
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--strict", action="store_true")
    args = ap.parse_args()

    home = os.path.expanduser("~")
    rules_dirs = [os.path.realpath(d) for d in args.rules_dir] or [
        os.path.realpath(d) for d in (
            os.path.join(os.getcwd(), ".claude", "rules"),
            os.path.join(home, ".claude", "rules"),
        ) if os.path.isdir(d)
    ]
    # realpath + dedup: ~/.claude/rules is often a symlink into the project itself
    rules_dirs = list(dict.fromkeys(d for d in rules_dirs if os.path.isdir(d)))

    claude_mds = args.claude_md or [
        p for p in (
            os.path.join(os.getcwd(), "CLAUDE.md"),
            os.path.join(os.getcwd(), ".claude", "CLAUDE.md"),
            os.path.join(home, ".claude", "CLAUDE.md"),
        ) if os.path.isfile(p)
    ]

    report = {
        "budgets": {
            "per_file_bytes": args.file_budget,
            "total_bytes": args.total_budget,
            "claude_md_lines": args.claude_md_lines,
        },
        "rules_dirs": [],
        "claude_md": [],
        "always_load_bytes_total": 0,
        "over_budget": False,
    }

    for d in rules_dirs:
        entries = scan_rules_dir(d)
        always = [e for e in entries if e["always_load"]]
        over = [e for e in always if e["bytes"] > args.file_budget]
        subtotal = sum(e["bytes"] for e in always)
        report["always_load_bytes_total"] += subtotal
        report["rules_dirs"].append({
            "dir": d,
            "files": len(entries),
            "always_load_count": len(always),
            "always_load_bytes": subtotal,
            "over_file_budget": sorted(over, key=lambda e: -e["bytes"]),
        })

    for p in claude_mds:
        try:
            lines = open(p, encoding="utf-8", errors="replace").read().count("\n") + 1
        except OSError:
            continue
        report["claude_md"].append({
            "file": p, "lines": lines,
            "over": lines > args.claude_md_lines,
        })

    file_over = any(d["over_file_budget"] for d in report["rules_dirs"])
    total_over = report["always_load_bytes_total"] > args.total_budget
    md_over = any(c["over"] for c in report["claude_md"])
    report["over_budget"] = file_over or total_over or md_over

    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=1))
    else:
        t, b = report["always_load_bytes_total"], args.total_budget
        pct = (t * 100 // b) if b else 0
        print(f"always-loaded rules total: {t:,}B / budget {b:,}B ({pct}%)"
              f" -> {'OVER' if total_over else 'within budget'}")
        for d in report["rules_dirs"]:
            print(f"  {d['dir']}: {d['always_load_count']} always-load"
                  f" / {d['files']} files, {d['always_load_bytes']:,}B")
            for e in d["over_file_budget"]:
                print(f"    OVER-FILE {e['file']} {e['bytes']:,}B"
                      f" (budget {args.file_budget:,}B)")
        for c in report["claude_md"]:
            mark = "OVER" if c["over"] else "ok"
            print(f"  CLAUDE.md {c['file']}: {c['lines']} lines"
                  f" (budget {args.claude_md_lines}) [{mark}]")

    if args.strict and report["over_budget"]:
        sys.exit(2)


if __name__ == "__main__":
    main()
