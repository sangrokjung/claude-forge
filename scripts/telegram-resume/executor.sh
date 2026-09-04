#!/usr/bin/env bash
#
# executor.sh — launch a Claude Code session in tmux/iTerm.
#
# Usage:
#   ./executor.sh <mode> <session-uuid>
#
# Modes:
#   resume  — `claude --resume <uuid>` in tmux
#   fork    — `claude --resume <uuid> --fork-session` (new session ID)
#   rc      — `claude --resume <uuid> --remote-control`
#
# Reads session metadata from ~/.claude/projects/<slug>/<uuid>.jsonl to find cwd.
# Creates a detached tmux session named `claude-<uuid:0:8>`; reattaches if it
# already exists. tmux is required.
#
# Env overrides:
#   CLAUDE_BIN            — claude binary path (default: claude in PATH)
#   TMUX_SESSION_PREFIX   — tmux session name prefix (default: claude-)
#   DRY_RUN=1             — print the command instead of running it
#

set -euo pipefail

MODE="${1:-}"
UUID="${2:-}"

if [[ -z "$MODE" || -z "$UUID" ]]; then
  echo "usage: $0 <mode: resume|fork|rc> <session-uuid>" >&2
  exit 2
fi

case "$MODE" in
  resume|fork|rc) : ;;
  *)
    echo "ERROR: unknown mode '$MODE' (expected: resume|fork|rc)" >&2
    exit 2
    ;;
esac

PROJECTS_DIR="${CLAUDE_PROJECTS_DIR:-$HOME/.claude/projects}"
JSONL=""
for dir in "$PROJECTS_DIR"/*/; do
  candidate="${dir%/}/${UUID}.jsonl"
  if [[ -f "$candidate" ]]; then
    JSONL="$candidate"
    break
  fi
done

if [[ -z "$JSONL" ]]; then
  echo "ERROR: no jsonl found for UUID $UUID under $PROJECTS_DIR" >&2
  exit 3
fi

CWD="$(
  awk '
    NR > 0 {
      if (match($0, /"cwd":"[^"]+"/)) {
        s = substr($0, RSTART+7, RLENGTH-8)
        print s
        exit
      }
    }
  ' "$JSONL" || true
)"

if [[ -z "$CWD" || ! -d "$CWD" ]]; then
  echo "ERROR: cwd not found or missing dir for $UUID (got: '$CWD')" >&2
  exit 4
fi

CLAUDE_BIN="${CLAUDE_BIN:-claude}"
if ! command -v "$CLAUDE_BIN" >/dev/null 2>&1; then
  echo "ERROR: '$CLAUDE_BIN' not in PATH (set CLAUDE_BIN env)" >&2
  exit 5
fi

case "$MODE" in
  resume) RESUME_ARGS=(--resume "$UUID") ;;
  fork)   RESUME_ARGS=(--resume "$UUID" --fork-session) ;;
  rc)     RESUME_ARGS=(--resume "$UUID" --remote-control) ;;
esac

if ! command -v tmux >/dev/null 2>&1; then
  echo "ERROR: tmux not installed (brew install tmux)" >&2
  exit 6
fi

TMUX_PREFIX="${TMUX_SESSION_PREFIX:-claude-}"
TMUX_NAME="${TMUX_PREFIX}${UUID:0:8}"

CMD_ARGS=("$CLAUDE_BIN" "${RESUME_ARGS[@]}")
QUOTED_CMD="$(printf '%q ' "${CMD_ARGS[@]}")"

if [[ "${DRY_RUN:-0}" == "1" ]]; then
  echo "DRY_RUN — would execute in tmux '${TMUX_NAME}' (cwd: ${CWD}):"
  echo "  ${QUOTED_CMD}"
  exit 0
fi

if tmux has-session -t "$TMUX_NAME" 2>/dev/null; then
  echo "tmux session '${TMUX_NAME}' exists — sending command."
  tmux send-keys -t "$TMUX_NAME" "cd ${CWD@Q} && ${QUOTED_CMD}" C-m
else
  echo "creating tmux session '${TMUX_NAME}' (cwd: ${CWD})"
  tmux new-session -d -s "$TMUX_NAME" -c "$CWD" "${CMD_ARGS[@]}"
fi

echo "✅ ${MODE} dispatched: ${TMUX_NAME}"
echo "   uuid: ${UUID}"
echo "   cwd:  ${CWD}"
echo "   attach with: tmux attach -t ${TMUX_NAME}"
