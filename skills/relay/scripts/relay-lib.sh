#!/bin/bash
# relay-lib.sh — shared function library for the relay skill.
# Think of it as a toolbox that keeps several workers (collect, write, hook) using the same ruler
# and the same drawer location.
#
# Usage: `source` this from other scripts. (No top-level side effects — function definitions only.)
# Env var overrides (for tests):
#   RELAY_DIR           : state storage directory (default $HOME/.claude/relay)
#   RELAY_CLIPBOARD_CMD : clipboard command mock (e.g. cat >"$tmp/clip.txt")
#
# Note: this file does not set `set -e/-u` (so it doesn't touch the shell options of the sourcing caller).

# State directory path
relay_dir() {
  echo "${RELAY_DIR:-$HOME/.claude/relay}"
}

# Current project name (cwd basename)
relay_proj_name() {
  basename "$PWD"
}

# cwd hash — first 12 chars of the md5 of the absolute path string. (writer <-> hook matching key)
# arg1: directory (default $PWD)
relay_cwd_hash() {
  local dir="${1:-$PWD}"
  local h=""
  if command -v md5 >/dev/null 2>&1; then
    # macOS: md5 -q -s hashes the string itself
    h="$(md5 -q -s "$dir" 2>/dev/null)"
  elif command -v md5sum >/dev/null 2>&1; then
    h="$(printf '%s' "$dir" | md5sum 2>/dev/null | cut -c1-32)"
  fi
  # first 12 chars only
  printf '%s' "${h:0:12}"
}

# Pointer file path (for PostCompact auto-restore)
# arg1: cwd hash
relay_pointer_path() {
  echo "$(relay_dir)/.pointer-$1"
}

# Consume-once marker file path
# arg1: cwd hash
relay_consumed_path() {
  echo "$(relay_dir)/.pointer-$1.consumed"
}

# File holding the path of the most recently written baton
relay_last_path() {
  echo "$(relay_dir)/.last-baton"
}

# Escape a string for use inside a JSON string (does not add the surrounding quotes).
# arg1: source string. Escapes " \ newline tab CR precisely.
relay_json_escape() {
  printf '%s' "$1" | python3 -c 'import json,sys; s=sys.stdin.read(); sys.stdout.write(json.dumps(s)[1:-1])'
}

# Copy a file's contents to the clipboard. Returns 0 on success, 1 if no tool is available.
# Never kills the caller.
# arg1: path of the file to copy
relay_clipboard_copy() {
  local file="$1"
  [ -f "$file" ] || return 1
  if [ -n "${RELAY_CLIPBOARD_CMD:-}" ]; then
    cat "$file" | eval "$RELAY_CLIPBOARD_CMD"
    return $?
  fi
  if command -v pbcopy >/dev/null 2>&1; then
    cat "$file" | pbcopy && return 0
  fi
  if command -v xclip >/dev/null 2>&1; then
    cat "$file" | xclip -selection clipboard && return 0
  fi
  if command -v xsel >/dev/null 2>&1; then
    cat "$file" | xsel --clipboard --input && return 0
  fi
  if command -v wl-copy >/dev/null 2>&1; then
    cat "$file" | wl-copy && return 0
  fi
  return 1
}
