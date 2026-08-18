#!/bin/bash
# hook-guard.sh — shared hook guard library (cooldown + token validation)
#
# Install path: ~/.claude/libs/hook-guard.sh (installed by install.sh/install.ps1
# from this repo's libs/). Hooks source it directly from the install path, not
# from the repo checkout.
#
# Analogy: the "cooldown notice" at a meeting room door. If the same person
# tries to walk back in within 30 seconds, the door won't open. This stops
# notification hooks from flooding in multi-session environments.
#
# Usage:
#   source ~/.claude/libs/hook-guard.sh
#   hook_cooldown <name> <seconds>
#   [[ $? -eq 0 ]] || exit 0
#
# Functions provided:
#   hook_cooldown <name> <seconds>  — returns 1 (suppress) if <name> was called
#                                      within <seconds>, else touches state and
#                                      returns 0.
#   hook_token_valid <token>        — returns 1 if <token> is empty or a known
#                                      placeholder ("YOUR_WEBHOOK_TOKEN" etc.),
#                                      else returns 0.
#   $PYTHON3                        — resolved python3 interpreter path, so hooks
#                                      that source this file don't need to
#                                      re-resolve it themselves.
#
# State: <state-dir>/<name>.ts holds the last-run epoch timestamp. State dir
# defaults to ~/.claude/cache/hook-guard, override with HOOK_GUARD_STATE_DIR
# (used by scripts/tests/test_hook_guard.sh for isolated test state).
#
# Multi-session safe: state file mtime comparison — many concurrent sessions
# sourcing this file at once still only let the first call through; the rest
# return 1.
HOOK_GUARD_STATE_DIR="${HOOK_GUARD_STATE_DIR:-$HOME/.claude/cache/hook-guard}"

# python3 interpreter path. Hooks that source this file reference $PYTHON3
# without resolving it themselves, so it's defined once here.
: "${PYTHON3:=$(command -v python3 || echo python3)}"

hook_cooldown() {
  local name="$1" sec="${2:-30}"
  if [[ -z "$name" ]]; then
    return 0  # no name = guard is a no-op (compatibility)
  fi
  local dir="$HOOK_GUARD_STATE_DIR"
  local file="$dir/${name}.ts"
  mkdir -p "$dir" 2>/dev/null
  if [[ -f "$file" ]]; then
    local last now
    last=$(cat "$file" 2>/dev/null || echo 0)
    now=$(date +%s)
    if (( now - last < sec )); then
      return 1
    fi
  fi
  date +%s > "$file"
  return 0
}

# External webhook token validation — rejects placeholder/unconfigured patterns.
# Usage: hook_token_valid "$WEBHOOK_TOKEN" || exit 0
hook_token_valid() {
  local tok="${1:-}"
  case "$tok" in
    ""|"YOUR_WEBHOOK_TOKEN"|"NOT_CONFIGURED"|"REPLACE_ME"|"PLACEHOLDER"|"TODO")
      return 1
      ;;
  esac
  return 0
}
