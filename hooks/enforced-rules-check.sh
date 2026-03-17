#!/usr/bin/env bash
# enforced-rules-check.sh — SessionStart hook
# Checks that all enforced_rules from settings.team.json exist in ~/.claude/rules/
# Non-destructive: only warns, never blocks session start
# exit 0 always (must not block session)

set -e

CLAUDE_DIR="$HOME/.claude"
FORGE_META="$CLAUDE_DIR/.forge-meta.json"

# Resolve the repo directory from forge metadata
get_repo_dir() {
    if [[ -f "$FORGE_META" ]] && command -v jq >/dev/null 2>&1; then
        jq -r '.repo_path // ""' "$FORGE_META" 2>/dev/null
    else
        echo ""
    fi
}

# Main check
main() {
    local repo_dir
    repo_dir=$(get_repo_dir)

    if [[ -z "$repo_dir" ]] || [[ ! -d "$repo_dir" ]]; then
        exit 0
    fi

    local team_file="$repo_dir/settings.team.json"
    if [[ ! -f "$team_file" ]]; then
        exit 0
    fi

    if ! command -v jq >/dev/null 2>&1; then
        exit 0
    fi

    # Read enforced_rules array
    local rules
    rules=$(jq -r '.enforced_rules // [] | .[]' "$team_file" 2>/dev/null) || exit 0

    if [[ -z "$rules" ]]; then
        exit 0
    fi

    local missing=()
    while IFS= read -r rule; do
        [[ -z "$rule" ]] && continue
        if [[ ! -f "$CLAUDE_DIR/$rule" ]]; then
            missing+=("$rule")
        fi
    done <<< "$rules"

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "[enforced-rules] WARNING: Missing enforced rule files:" >&2
        for m in "${missing[@]}"; do
            echo "  - $m" >&2
        done
        echo "[enforced-rules] Install these rules or contact your team lead." >&2
    fi

    exit 0
}

main
