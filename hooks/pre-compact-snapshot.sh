#!/bin/bash
# PreCompact Hook - snapshot key files before context compaction
#
# Hook trigger: PreCompact
# Behavior: backs up plan.md, auto-loop-todo.md, decisions.md
# Always exits 0 (fails silently on error)

set -o pipefail

# read JSON input from stdin
INPUT=$(cat)

# extract cwd (grep+sed, no jq dependency)
CWD=$(echo "$INPUT" | grep -o '"cwd"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/"cwd"[[:space:]]*:[[:space:]]*"//;s/"$//')
if [ -z "$CWD" ]; then
  exit 0
fi

SNAPSHOT_DIR="$HOME/.claude/compact-snapshots"
mkdir -p "$SNAPSHOT_DIR" 2>/dev/null || exit 0

TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
SAVED_FILES=""

# copy target files
for FILE in plan.md auto-loop-todo.md decisions.md; do
  SRC="$CWD/.claude/$FILE"
  if [ -f "$SRC" ]; then
    BASE="${FILE%.md}"
    cp "$SRC" "$SNAPSHOT_DIR/${BASE}-${TIMESTAMP}.md" 2>/dev/null
    if [ $? -eq 0 ]; then
      SAVED_FILES="${SAVED_FILES:+$SAVED_FILES, }$FILE"
    fi
  fi
done

# clean up snapshots older than 7 days
find "$SNAPSHOT_DIR" -name "*.md" -mtime +7 -delete 2>/dev/null

# print a status message to stderr
if [ -n "$SAVED_FILES" ]; then
  echo "[pre-compact] Snapshot saved: $SAVED_FILES" >&2
else
  echo "[pre-compact] No files to back up" >&2
fi

exit 0
