#!/usr/bin/env python3
"""preservation_check.py — deterministic loss check for harness diets.

Part of Claude Forge — github.com/sangrokjung/claude-forge (skills/harness-diet)

Extract a manifest of load-bearing literals from a rule BEFORE dieting it, then
verify the slimmed body still contains every entry. Catches the failure mode a
maker cannot see: a plausible slim body missing one qualifier.

Usage:
  preservation_check.py extract <file>            # manifest JSON on stdout
  preservation_check.py verify  <file> <manifest> # exit 0 = all kept, 2 = loss

Manifest entries are plain literals grouped by kind. Review the manifest by hand
after extract and DELETE entries you intend to migrate — everything left is a
contract the slimmed file must honor.

Extraction heuristics (conservative, literal-based):
  headings      - every markdown heading line's text
  banners       - headings/lines carrying CRITICAL or IMPORTANT markers
  env_vars      - KILLSWITCH-style assignments (UPPER_SNAKE=value)
  code_spans    - inline `code` spans of length >= 4 (commands, flags, paths, IDs)
  long_tokens   - bare identifiers >= 18 chars (calendar/drive IDs, hashes)
"""
import json
import re
import sys


def extract(text):
    man = {"headings": [], "banners": [], "env_vars": [],
           "code_spans": [], "long_tokens": []}
    seen = set()

    def add(kind, val):
        val = val.strip()
        if len(val) < 2 or val in seen:
            return
        seen.add(val)
        man[kind].append(val)

    for line in text.splitlines():
        h = re.match(r"^#{1,6}\s+(.*)$", line)
        if h:
            add("headings", h.group(1))
        if re.search(r"\b(CRITICAL|IMPORTANT)\b", line):
            # store a VERBATIM slice only — transformed text can never be re-found
            frag = re.sub(r"^[>#\s|*-]+", "", line).strip()[:80]
            if frag:
                add("banners", frag)
        for m in re.finditer(r"\b([A-Z][A-Z0-9_]{3,}=[A-Za-z0-9_./:-]+)", line):
            add("env_vars", m.group(1))
    for m in re.finditer(r"`([^`\n]{4,120})`", text):
        add("code_spans", m.group(1))
    for m in re.finditer(r"\b([A-Za-z0-9_-]{18,})\b", text):
        if not m.group(1).startswith("http"):
            add("long_tokens", m.group(1))
    return man


def verify(text, man):
    losses = []
    for kind, vals in man.items():
        for v in vals:
            if v not in text:
                losses.append({"kind": kind, "value": v})
    return losses


def main():
    if len(sys.argv) < 3:
        print(__doc__, file=sys.stderr)
        sys.exit(1)
    cmd, path = sys.argv[1], sys.argv[2]
    text = open(path, encoding="utf-8", errors="replace").read()
    if cmd == "extract":
        print(json.dumps(extract(text), ensure_ascii=False, indent=1))
    elif cmd == "verify":
        man = json.load(open(sys.argv[3], encoding="utf-8"))
        losses = verify(text, man)
        total = sum(len(v) for v in man.values())
        kept = total - len(losses)
        print(f"preserved {kept}/{total}")
        for l in losses:
            print(f"  LOST [{l['kind']}] {l['value']}")
        if losses:
            sys.exit(2)
    else:
        print(f"unknown command: {cmd}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
