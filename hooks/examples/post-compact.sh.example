#!/usr/bin/env bash
# PostCompact hook example — claude-forge v3.0
# Event: PostCompact
# Trigger: Fires immediately after context compaction completes
#
# Usage:
#   1. mkdir -p ~/.claude/hooks && cp this_file ~/.claude/hooks/post-compact.sh
#   2. chmod +x ~/.claude/hooks/post-compact.sh
#   3. Add to ~/.claude/settings.json hooks.PostCompact section
#
# Input (stdin JSON): { "session_id": "...", "summary": "...", "tokens_before": N, "tokens_after": N }
# Output: exit 0 success, exit 2 blocking error
set -euo pipefail

DIR="${HOME}/.claude/compact-history"
mkdir -p "$DIR"

INPUT=$(cat)
TS=$(date -u +%Y%m%dT%H%M%SZ)
OUT="${DIR}/${TS}.json"

# Persist the full compaction payload for later auditing / relay prompts
printf '%s\n' "$INPUT" > "$OUT"
printf '[post-compact] summary saved: %s\n' "$OUT" >&2

exit 0
