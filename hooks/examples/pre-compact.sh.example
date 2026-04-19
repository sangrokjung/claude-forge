#!/usr/bin/env bash
# PreCompact hook example — claude-forge v3.0
# Event: PreCompact
# Trigger: Fires just before context compaction begins (last chance to snapshot state)
#
# Usage:
#   1. mkdir -p ~/.claude/hooks && cp this_file ~/.claude/hooks/pre-compact.sh
#   2. chmod +x ~/.claude/hooks/pre-compact.sh
#   3. Add to ~/.claude/settings.json hooks.PreCompact section
#
# Input (stdin JSON): { "session_id": "...", "cwd": "...", "tokens": N }
# Output: exit 0 success, exit 2 blocking error (blocks compaction)
set -euo pipefail

DIR="${HOME}/.claude/compact-backup"
mkdir -p "$DIR"

INPUT=$(cat)
TS=$(date -u +%Y%m%dT%H%M%SZ)

# Backup TODAY.md + plan.md (if present) before compaction wipes working context
for f in "${HOME}/QJC/tasks/TODAY.md" ".claude/plan.md" ".claude/auto-loop-todo.md"; do
  [ -f "$f" ] && cp "$f" "${DIR}/${TS}-$(basename "$f")" 2>/dev/null || true
done

printf '%s\n' "$INPUT" > "${DIR}/${TS}-payload.json"
printf '[pre-compact] snapshot saved under %s (%s)\n' "$DIR" "$TS" >&2

exit 0
