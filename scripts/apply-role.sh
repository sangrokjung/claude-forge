#!/usr/bin/env bash
# apply-role.sh — Apply RBAC role permissions to a Claude Forge project
# Reads a role definition from roles/{role_name}.json and generates
# merged permissions by combining role permissions with existing team settings.
#
# Usage:
#   source scripts/apply-role.sh
#   apply_role "developer" "/path/to/project"
#
# Or run directly:
#   bash scripts/apply-role.sh developer /path/to/project

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORGE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROLES_DIR="$FORGE_DIR/roles"

# Source the merge-settings library
# shellcheck source=merge-settings.sh
source "$SCRIPT_DIR/merge-settings.sh"

# ── Helpers ──────────────────────────────────────────────────────────

# List all available role names (without .json extension)
list_roles() {
  local role_file
  for role_file in "$ROLES_DIR"/*.json; do
    [[ -f "$role_file" ]] || continue
    basename "$role_file" .json
  done
}

# Validate that a role exists
validate_role() {
  local role_name="$1"
  local role_file="$ROLES_DIR/${role_name}.json"

  if [[ ! -f "$role_file" ]]; then
    echo "Error: Role '$role_name' not found." >&2
    echo "Available roles:" >&2
    list_roles | sed 's/^/  - /' >&2
    return 1
  fi
}

# Read role definition JSON
read_role() {
  local role_name="$1"
  local role_file="$ROLES_DIR/${role_name}.json"
  read_json_file "$role_file"
}

# Get current role from project's settings.team.json
get_current_role() {
  local project_dir="${1:-.}"
  local team_file="$project_dir/settings.team.json"

  if [[ -f "$team_file" ]]; then
    jq -r '.current_role // "none"' "$team_file"
  else
    echo "none"
  fi
}

# ── Core: Apply Role ────────────────────────────────────────────────

# Apply a role to a project directory
# Merges role permissions with existing team settings (if any)
# Writes the result to settings.team.json in the project directory
apply_role() {
  local role_name="$1"
  local project_dir="${2:-.}"

  # Validate inputs
  validate_role "$role_name"

  if [[ ! -d "$project_dir" ]]; then
    echo "Error: Directory '$project_dir' does not exist" >&2
    return 1
  fi

  local role_json
  role_json=$(read_role "$role_name")

  local team_file="$project_dir/settings.team.json"
  local existing_team_json
  existing_team_json=$(read_json_file "$team_file")

  # Extract role permissions
  local role_allow role_deny
  role_allow=$(echo "$role_json" | jq '.permissions.allow // []')
  role_deny=$(echo "$role_json" | jq '.permissions.deny // []')

  # Extract existing team permissions (preserve team-level overrides)
  local existing_allow existing_deny
  existing_allow=$(echo "$existing_team_json" | jq '.permissions.allow // []')
  existing_deny=$(echo "$existing_team_json" | jq '.permissions.deny // []')

  # Merge: role permissions as base, intersect with existing allow if present
  local merged_allow
  merged_allow=$(jq -n \
    --argjson role "$role_allow" \
    --argjson existing "$existing_allow" \
    'if ($existing | length) == 0 then $role
     else $role | map(select(IN($existing[])))
     end')

  # Merge deny: union of role deny + existing deny
  local merged_deny
  merged_deny=$(jq -n \
    --argjson role "$role_deny" \
    --argjson existing "$existing_deny" \
    '$role + $existing | unique')

  # Extract role metadata
  local role_commands role_agents role_mcp role_description
  role_commands=$(echo "$role_json" | jq '.commands // []')
  role_agents=$(echo "$role_json" | jq '.agents // []')
  role_mcp=$(echo "$role_json" | jq '.mcp // []')
  role_description=$(echo "$role_json" | jq -r '.description // ""')

  # Preserve existing non-permission fields from team settings
  local existing_other
  existing_other=$(echo "$existing_team_json" | jq \
    'del(.permissions, .current_role, .role_applied_at, .role_commands, .role_agents, .role_mcp)')

  # Build final settings.team.json
  local result
  result=$(jq -n \
    --argjson other "$existing_other" \
    --argjson allow "$merged_allow" \
    --argjson deny "$merged_deny" \
    --arg role "$role_name" \
    --arg applied_at "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
    --argjson commands "$role_commands" \
    --argjson agents "$role_agents" \
    --argjson mcp "$role_mcp" \
    '$other + {
      permissions: { allow: $allow, deny: $deny },
      current_role: $role,
      role_applied_at: $applied_at,
      role_commands: $commands,
      role_agents: $agents,
      role_mcp: $mcp
    }')

  # Write atomically (write to temp, then move)
  local tmp_file
  tmp_file=$(mktemp "$project_dir/.settings.team.XXXXXX.json")
  echo "$result" > "$tmp_file"
  mv "$tmp_file" "$team_file"

  echo "Role '$role_name' applied to $project_dir"
  echo "  Description: $role_description"
  echo "  Commands:    $(echo "$role_commands" | jq -r 'if . == ["*"] then "all" else join(", ") end')"
  echo "  Agents:      $(echo "$role_agents" | jq -r 'if . == ["*"] then "all" elif length == 0 then "none" else join(", ") end')"
  echo "  MCP:         $(echo "$role_mcp" | jq -r 'if . == ["*"] then "all" elif length == 0 then "none" else join(", ") end')"
}

# ── Direct Execution ────────────────────────────────────────────────

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ $# -lt 1 ]]; then
    echo "Usage: bash scripts/apply-role.sh <role_name> [project_dir]" >&2
    echo "" >&2
    echo "Available roles:" >&2
    list_roles | sed 's/^/  - /' >&2
    exit 1
  fi

  role_name="$1"
  project_dir="${2:-.}"

  apply_role "$role_name" "$project_dir"
fi
