#!/usr/bin/env bash
# merge-settings.sh — Settings merge library for Claude Forge enterprise
# Merge order: settings.json (base) -> settings.team.json (team) -> settings.local.json (local)
#
# Usage:
#   source scripts/merge-settings.sh
#   merged=$(merge_settings "/path/to/project")
#
# Or run directly:
#   bash scripts/merge-settings.sh /path/to/project

set -euo pipefail

# ── Helpers ──────────────────────────────────────────────────────────

# Read a JSON file, returning '{}' if file does not exist or is empty
read_json_file() {
  local file_path="$1"
  if [[ -f "$file_path" ]] && [[ -s "$file_path" ]]; then
    jq '.' "$file_path" 2>/dev/null || echo '{}'
  else
    echo '{}'
  fi
}

# Extract a nested field from JSON, returning a default if missing
json_field() {
  local json="$1"
  local path="$2"
  local default="${3:-null}"
  local result
  result=$(echo "$json" | jq -r "$path // empty" 2>/dev/null) || true
  if [[ -z "$result" ]]; then
    echo "$default"
  else
    echo "$result"
  fi
}

# ── Permission Merging ───────────────────────────────────────────────

# Merge deny lists: union (team denials cannot be overridden by local)
# Team blocks persist — local can only add more denials, never remove them
merge_deny() {
  local base_deny="$1"
  local team_deny="$2"
  local local_deny="$3"

  jq -n \
    --argjson base "$base_deny" \
    --argjson team "$team_deny" \
    --argjson local "$local_deny" \
    '$base + $team + $local | unique'
}

# Merge allow lists: intersection (only permissions allowed by ALL levels remain)
# Team restrictions cannot be bypassed by local settings
merge_allow() {
  local base_allow="$1"
  local team_allow="$2"
  local local_allow="$3"

  # If team allow is empty/null, use base; then intersect with local
  local team_filtered
  team_filtered=$(jq -n \
    --argjson base "$base_allow" \
    --argjson team "$team_allow" \
    'if ($team | length) == 0 then $base
     else $base | map(select(IN($team[])))
     end')

  jq -n \
    --argjson filtered "$team_filtered" \
    --argjson local "$local_allow" \
    'if ($local | length) == 0 then $filtered
     else $filtered | map(select(IN($local[])))
     end'
}

# Merge permissions (allow + deny)
merge_permissions() {
  local base_json="$1"
  local team_json="$2"
  local local_json="$3"

  local base_allow base_deny team_allow team_deny local_allow local_deny
  base_allow=$(echo "$base_json" | jq '.permissions.allow // []')
  base_deny=$(echo "$base_json" | jq '.permissions.deny // []')
  team_allow=$(echo "$team_json" | jq '.permissions.allow // []')
  team_deny=$(echo "$team_json" | jq '.permissions.deny // []')
  local_allow=$(echo "$local_json" | jq '.permissions.allow // []')
  local_deny=$(echo "$local_json" | jq '.permissions.deny // []')

  local merged_allow merged_deny
  merged_allow=$(merge_allow "$base_allow" "$team_allow" "$local_allow")
  merged_deny=$(merge_deny "$base_deny" "$team_deny" "$local_deny")

  jq -n \
    --argjson allow "$merged_allow" \
    --argjson deny "$merged_deny" \
    '{"allow": $allow, "deny": $deny}'
}

# ── Enforced Rules Merging ───────────────────────────────────────────

# Merge enforced_rules: team rules cannot be removed by local settings
# Local can only add more rules on top of team rules
merge_enforced_rules() {
  local base_json="$1"
  local team_json="$2"
  local local_json="$3"

  local base_rules team_rules local_rules
  base_rules=$(echo "$base_json" | jq '.enforced_rules // []')
  team_rules=$(echo "$team_json" | jq '.enforced_rules // []')
  local_rules=$(echo "$local_json" | jq '.enforced_rules // []')

  # Union all: base + team + local, deduplicated
  # Team rules are always preserved (union guarantees this)
  jq -n \
    --argjson base "$base_rules" \
    --argjson team "$team_rules" \
    --argjson local "$local_rules" \
    '$base + $team + $local | unique'
}

# ── Top-level Merge ─────────────────────────────────────────────────

# Merge all settings following the inheritance chain
# base (settings.json) -> team (settings.team.json) -> local (settings.local.json)
merge_settings() {
  local project_dir="${1:-.}"

  local base_file="$project_dir/settings.json"
  local team_file="$project_dir/settings.team.json"
  local local_file="$project_dir/settings.local.json"

  local base_json team_json local_json
  base_json=$(read_json_file "$base_file")
  team_json=$(read_json_file "$team_file")
  local_json=$(read_json_file "$local_file")

  local merged_permissions merged_enforced_rules team_name

  # Merge permissions
  merged_permissions=$(merge_permissions "$base_json" "$team_json" "$local_json")

  # Merge enforced rules
  merged_enforced_rules=$(merge_enforced_rules "$base_json" "$team_json" "$local_json")

  # Team name comes from team settings (if present)
  team_name=$(echo "$team_json" | jq '.team_name // null')

  # Merge MCP servers: base + team + local (local overrides team overrides base)
  local base_mcp team_mcp local_mcp merged_mcp
  base_mcp=$(echo "$base_json" | jq '.mcp_servers // {}')
  team_mcp=$(echo "$team_json" | jq '.mcp_servers // {}')
  local_mcp=$(echo "$local_json" | jq '.mcp_servers // {}')
  merged_mcp=$(jq -n \
    --argjson base "$base_mcp" \
    --argjson team "$team_mcp" \
    --argjson local "$local_mcp" \
    '$base * $team * $local')

  # Deep merge remaining top-level fields (env, hooks, etc.)
  # base * team * local for non-permission/non-enforced fields
  local merged_other
  merged_other=$(jq -n \
    --argjson base "$base_json" \
    --argjson team "$team_json" \
    --argjson local "$local_json" \
    '($base | del(.permissions, .enforced_rules, .mcp_servers, .team_name))
     * ($team | del(.permissions, .enforced_rules, .mcp_servers, .team_name))
     * ($local | del(.permissions, .enforced_rules, .mcp_servers, .team_name))')

  # Assemble final result
  jq -n \
    --argjson other "$merged_other" \
    --argjson permissions "$merged_permissions" \
    --argjson enforced_rules "$merged_enforced_rules" \
    --argjson team_name "$team_name" \
    --argjson mcp_servers "$merged_mcp" \
    '$other
     + {permissions: $permissions}
     + {enforced_rules: $enforced_rules}
     + {mcp_servers: $mcp_servers}
     + (if $team_name != null then {team_name: $team_name} else {} end)'
}

# ── Utility Functions ────────────────────────────────────────────────

# Check if a team settings file exists in the project
has_team_settings() {
  local project_dir="${1:-.}"
  [[ -f "$project_dir/settings.team.json" ]]
}

# Get the team name from team settings
get_team_name() {
  local project_dir="${1:-.}"
  local team_file="$project_dir/settings.team.json"
  if [[ -f "$team_file" ]]; then
    jq -r '.team_name // "unknown"' "$team_file"
  else
    echo ""
  fi
}

# Get enforced rules from team settings
get_enforced_rules() {
  local project_dir="${1:-.}"
  local team_file="$project_dir/settings.team.json"
  if [[ -f "$team_file" ]]; then
    jq -r '.enforced_rules // [] | .[]' "$team_file"
  fi
}

# ── Direct Execution ────────────────────────────────────────────────

# When run directly (not sourced), merge and output result
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  project_dir="${1:-.}"
  if [[ ! -d "$project_dir" ]]; then
    echo "Error: Directory '$project_dir' does not exist" >&2
    exit 1
  fi
  merge_settings "$project_dir"
fi
