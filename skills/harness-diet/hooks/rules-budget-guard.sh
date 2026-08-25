#!/bin/bash
# rules-budget-guard.sh — PostToolUse (Edit|Write) always-load rules budget advisory
# Part of Claude Forge — github.com/sangrokjung/claude-forge (skills/harness-diet)
#
# The moment a rule edit pushes an always-loaded file (no `paths:` frontmatter) past
# the per-file budget, inject a context note telling the editing session to migrate
# narrative to a reference file instead of appending. Non-blocking by design: a
# blocking pre-commit gate silently stalls auto-commit pipelines.
#
# Wire in settings.json:
#   "PostToolUse": [{ "matcher": "Edit|Write",
#     "hooks": [{ "type": "command",
#       "command": "bash ~/.claude/skills/harness-diet/hooks/rules-budget-guard.sh",
#       "timeout": 8000 }] }]
#
# Env: FORGE_RULES_FILE_BUDGET (default 8192) / kill: FORGE_RULES_BUDGET_GUARD_DISABLED=1
set -u
[ "${FORGE_RULES_BUDGET_GUARD_DISABLED:-}" = "1" ] && exit 0

INPUT=$(cat 2>/dev/null || true)
FILE=$(printf '%s' "$INPUT" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('tool_input',{}).get('file_path',''))" 2>/dev/null) || exit 0
[ -n "$FILE" ] || exit 0

case "$FILE" in
  */.claude/rules/*.md|*/rules/*.md) : ;;
  *) exit 0 ;;
esac
BASE=$(basename "$FILE")
case "$BASE" in _*) exit 0 ;; esac
[ -f "$FILE" ] || exit 0

# conditional rules (paths: frontmatter) are not always-loaded — no budget concern
head -30 "$FILE" | grep -q '^paths:' && exit 0

BUDGET="${FORGE_RULES_FILE_BUDGET:-8192}"
SIZE=$(wc -c < "$FILE" | tr -d ' ')
[ "$SIZE" -le "$BUDGET" ] && exit 0

MSG="[harness-diet] ${BASE} is ${SIZE}B, over the ${BUDGET}B always-load budget. Migrate narrative/incident detail to a reference file and keep only the verdict skeleton + pointer here (see the harness-diet skill). Keep CRITICAL banners, decision tables, trigger keywords, killswitches and canonical commands in the body."
printf '%s' "$MSG" | python3 -c "import sys,json;print(json.dumps({'hookSpecificOutput':{'hookEventName':'PostToolUse','additionalContext':sys.stdin.read()}}))"
exit 0
