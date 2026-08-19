#!/bin/bash
# relay-build-focus.sh — pure function: next task + files + key decision -> `/compact` one-liner.
# Think of it as a sticky note that tells the next person "keep this, drop that" in one line.
#
# Args: $1=NEXT_TASK (required), $2=files (space/comma separated, optional), $3=key_decision (optional)
# Output: exactly one line on stdout (starts with `/compact `). exit 0.
# NEXT_TASK empty or whitespace-only -> stderr error + exit 2.
#
# WARNING: this script never runs /compact itself — it only produces the "one line" to paste in.
set -euo pipefail

NEXT_TASK="${1:-}"
FILES="${2:-}"
DECISION="${3:-}"

# error if only whitespace
if [ -z "$(printf '%s' "$NEXT_TASK" | tr -d '[:space:]')" ]; then
  echo "[relay-build-focus] Error: NEXT_TASK is empty." >&2
  exit 2
fi

# newlines/tabs -> spaces, collapse runs of whitespace, trim both ends
_clean() {
  printf '%s' "$1" | tr '\n\r\t' '   ' | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//'
}

NEXT_TASK="$(_clean "$NEXT_TASK")"
FILES="$(_clean "$FILES")"
DECISION="$(_clean "$DECISION")"

# replace single quotes ' with ’ (U+2019) inside NEXT_TASK to avoid breaking quoting
NEXT_TASK="${NEXT_TASK//\'/’}"

# files clause: commas -> spaces, tokenize. more than 6 -> first 6 + "and N more"
FILES_CLAUSE=""
FILES_NORM="$(printf '%s' "$FILES" | tr ',' ' ' | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')"
if [ -n "$FILES_NORM" ]; then
  read -r -a _toks <<< "$FILES_NORM" || true
  ntok=${#_toks[@]}
  files_disp=""
  i=0
  for t in "${_toks[@]}"; do
    [ "$i" -ge 6 ] && break
    files_disp="${files_disp:+$files_disp }$t"
    i=$((i + 1))
  done
  if [ "$ntok" -gt 6 ]; then
    extra=$((ntok - 6))
    files_disp="$files_disp and ${extra} more"
  fi
  FILES_CLAUSE="code context around ${files_disp}, "
fi

# decision clause
DEC_CLAUSE=""
if [ -n "$DECISION" ]; then
  DEC_CLAUSE="${DECISION}, "
fi

# assemble the one-liner
LINE="/compact next task='${NEXT_TASK}'. Keep: ${FILES_CLAUSE}${DEC_CLAUSE}uncommitted changes and unfinished tests. Drop: everything else — exploration, build logs, resolved errors, side conversation."

# max 600 chars — truncate the tail with … if longer (still one line, still starts with /compact)
MAX=600
if [ "${#LINE}" -gt "$MAX" ]; then
  keep=$((MAX - 1))
  LINE="${LINE:0:$keep}…"
fi

printf '%s\n' "$LINE"
exit 0
