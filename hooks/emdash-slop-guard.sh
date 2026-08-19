#!/bin/bash
# emdash-slop-guard.sh - PostToolUse hook (Write|Edit)
# Flags em-dash (—/–) interjection AI-tells in Korean-dominant .md output.
# Detection logic lives in scripts/emdash_slop_check.py (single source of
# truth — do not duplicate the regex/heuristic here, edit that file instead).
# Rule: rules/korean-writing-quality.md §4/§6
# Non-blocking: always exits 0, emits additionalContext only.
# Kill switch: CLAUDE_FORGE_EMDASH_GUARD_DISABLED=1

[ "${CLAUDE_FORGE_EMDASH_GUARD_DISABLED:-0}" = "1" ] && exit 0

INPUT=$(cat)
CHECKER="$HOME/.claude/scripts/emdash_slop_check.py"
[ -f "$CHECKER" ] || exit 0

echo "$INPUT" | CHECKER="$CHECKER" python3 -c "
import sys, json, os, subprocess

try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)

tool = d.get('tool_name', '')
checker = os.environ['CHECKER']

if tool not in ('Write', 'Edit'):
    sys.exit(0)

fp = d.get('tool_input', {}).get('file_path', '')
if not fp.endswith('.md') or not os.path.isfile(fp):
    sys.exit(0)

try:
    r = subprocess.run([sys.executable, checker, fp],
                       capture_output=True, text=True, timeout=8)
    out = r.stdout.strip()
except Exception:
    sys.exit(0)

if out:
    payload = {'hookSpecificOutput': {'hookEventName': 'PostToolUse',
               'additionalContext': out + chr(10) + '[Emdash Slop] Fix the interjections above before treating this doc as final (advisory, not a hard block — rules/korean-writing-quality.md §4).'}}
    print(json.dumps(payload, ensure_ascii=False))
" 2>/dev/null

exit 0
