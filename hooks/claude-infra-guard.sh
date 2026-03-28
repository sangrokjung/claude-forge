#!/bin/bash
# claude-infra-guard.sh - PreToolUse Hook (Edit|Write)
# Prevents agents from modifying Claude Forge system files.
# This is a self-protection mechanism: agents cannot alter their own rules.
#
# Exit codes:
#   0 = allow
#   2 = block
#
# Outside .claude/: always allow
# Inside .claude/: block security boundary files, allow the rest
#
# Blocked (security boundary):
#   claude-infra-guard.sh (self-protection)
#   settings*.json (permission rules)
#   .claude/hooks/*.sh (security hooks)
#   .claude/commands/*.md (command definitions)
#   .claude/skills/**/* (skill definitions)
#   .claude/agents/*.md (agent definitions)
#   .claude/rules/**/*.md (behavior rules)
#   .claude/reference/**/*.md (reference docs)

INPUT=$(cat)

FILE_PATH=$(echo "$INPUT" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get("tool_input", {}).get("file_path", ""))
except:
    print("")
' 2>/dev/null)

if [[ -z "$FILE_PATH" ]]; then
    exit 0
fi

# Not a .claude/ path → allow
if [[ "$FILE_PATH" != *"/.claude/"* ]] && [[ "$FILE_PATH" != *"\\.claude\\"* ]]; then
    exit 0
fi

# ── Security boundary check ──

NORMALIZED="${FILE_PATH//\\//}"
BASENAME=$(basename "$NORMALIZED")

# Self-protection: block modification of this hook
if [[ "$BASENAME" == "claude-infra-guard.sh" ]]; then
    echo "BLOCKED: infra-guard self-modification is not allowed" >&2
    exit 2
fi

# Permission boundary: block settings files
if [[ "$BASENAME" == settings*.json ]]; then
    echo "BLOCKED: settings file modification ($BASENAME). Use settings.local.json for overrides." >&2
    exit 2
fi

# hooks/ directory protection
if [[ "$NORMALIZED" == *"/.claude/hooks/"* ]]; then
    echo "BLOCKED: hook file ($BASENAME). Hooks are protected system files." >&2
    exit 2
fi

# commands/ directory protection
if [[ "$NORMALIZED" == *"/.claude/commands/"* ]]; then
    echo "BLOCKED: command file ($BASENAME). Commands are protected system files." >&2
    exit 2
fi

# skills/ directory protection
if [[ "$NORMALIZED" == *"/.claude/skills/"* ]]; then
    echo "BLOCKED: skill file ($BASENAME). Skills are protected system files." >&2
    exit 2
fi

# agents/ directory protection
if [[ "$NORMALIZED" == *"/.claude/agents/"* ]]; then
    echo "BLOCKED: agent file ($BASENAME). Agents are protected system files." >&2
    exit 2
fi

# rules/ directory protection
if [[ "$NORMALIZED" == *"/.claude/rules/"* ]]; then
    echo "BLOCKED: rule file ($BASENAME). Rules are protected system files." >&2
    exit 2
fi

# reference/ directory protection
if [[ "$NORMALIZED" == *"/.claude/reference/"* ]]; then
    echo "BLOCKED: reference file ($BASENAME). Reference docs are protected system files." >&2
    exit 2
fi

# Everything else → allow
exit 0
