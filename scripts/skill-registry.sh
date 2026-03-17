#!/usr/bin/env bash
# skill-registry.sh — Private skill registry management library for Claude Forge
# Manages installation, updating, rollback, and syncing of skills from private git registries.
#
# Usage:
#   source scripts/skill-registry.sh
#   load_registry "$HOME/.claude/registry.json"
#   install_skill "company-skills" "custom-review" "1.2.0"
#
# Or run directly for quick operations:
#   bash scripts/skill-registry.sh sync company-skills

set -euo pipefail

# ── Constants ──────────────────────────────────────────────────

SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
REGISTRY_CACHE_DIR="${CLAUDE_REGISTRY_CACHE:-$HOME/.claude/.registry-cache}"
REGISTRY_CONFIG=""
MAX_DEPENDENCY_DEPTH=10

# ── Registry Loading ──────────────────────────────────────────

# Load and validate a registry.json config file
# Usage: load_registry "/path/to/registry.json"
load_registry() {
  local config_path="$1"

  if [[ ! -f "$config_path" ]]; then
    echo "Error: Registry config not found: $config_path" >&2
    return 1
  fi

  if ! jq empty "$config_path" 2>/dev/null; then
    echo "Error: Invalid JSON in registry config: $config_path" >&2
    return 1
  fi

  local registries_count
  registries_count=$(jq '.registries | length' "$config_path")
  if [[ "$registries_count" -eq 0 ]]; then
    echo "Error: No registries defined in config" >&2
    return 1
  fi

  # Validate each registry has required fields
  local invalid
  invalid=$(jq -r '.registries[] | select(.name == null or .url == null) | .name // "unnamed"' "$config_path")
  if [[ -n "$invalid" ]]; then
    echo "Error: Registry missing required fields (name, url): $invalid" >&2
    return 1
  fi

  REGISTRY_CONFIG="$config_path"
  echo "Registry loaded: $config_path ($registries_count registries)"
}

# ── Registry Queries ──────────────────────────────────────────

# List all skills in a named registry
# Usage: list_registry_skills "company-skills"
list_registry_skills() {
  local registry_name="$1"
  _require_config

  local registry_json
  registry_json=$(_get_registry "$registry_name") || return 1

  echo "$registry_json" | jq -r '.skills[] | "\(.name)\t\(.version)\t\(.required)\t\(.path)"'
}

# Get the URL for a named registry
# Usage: _get_registry_url "company-skills"
_get_registry_url() {
  local registry_name="$1"
  jq -r --arg name "$registry_name" \
    '.registries[] | select(.name == $name) | .url' \
    "$REGISTRY_CONFIG"
}

# Get a registry object by name
# Usage: _get_registry "company-skills"
_get_registry() {
  local registry_name="$1"
  local result
  result=$(jq --arg name "$registry_name" \
    '.registries[] | select(.name == $name)' \
    "$REGISTRY_CONFIG")

  if [[ -z "$result" ]]; then
    echo "Error: Registry not found: $registry_name" >&2
    return 1
  fi
  echo "$result"
}

# Get a skill entry from a registry
# Usage: _get_skill_entry "company-skills" "custom-review"
_get_skill_entry() {
  local registry_name="$1"
  local skill_name="$2"
  local registry_json
  registry_json=$(_get_registry "$registry_name") || return 1

  local result
  result=$(echo "$registry_json" | jq --arg name "$skill_name" \
    '.skills[] | select(.name == $name)')

  if [[ -z "$result" ]]; then
    echo "Error: Skill '$skill_name' not found in registry '$registry_name'" >&2
    return 1
  fi
  echo "$result"
}

# ── Skill Installation ────────────────────────────────────────

# Install a skill from a registry
# Usage: install_skill "company-skills" "custom-review" "1.2.0"
install_skill() {
  local registry_name="$1"
  local skill_name="$2"
  local version="${3:-}"
  _require_config

  local skill_entry
  skill_entry=$(_get_skill_entry "$registry_name" "$skill_name") || return 1

  local skill_path
  skill_path=$(echo "$skill_entry" | jq -r '.path')

  if [[ -z "$version" ]]; then
    version=$(echo "$skill_entry" | jq -r '.version')
  fi

  local target_dir="$SKILLS_DIR/$skill_name"
  if [[ -d "$target_dir" ]]; then
    echo "Skill '$skill_name' already installed at $target_dir" >&2
    echo "Use update_skill to upgrade, or remove it first." >&2
    return 1
  fi

  # Resolve dependencies before installing
  resolve_dependencies "$skill_name" "$registry_name" || return 1

  echo "Installing $skill_name@$version from $registry_name..."
  _clone_and_extract "$registry_name" "$skill_name" "$skill_path" "$version" "$target_dir"
}

# Clone a registry repo, checkout the tag, and extract the skill directory
# Usage: _clone_and_extract "company-skills" "custom-review" "skills/custom-review" "1.2.0" "/target"
_clone_and_extract() {
  local registry_name="$1"
  local skill_name="$2"
  local skill_path="$3"
  local version="$4"
  local target_dir="$5"

  local repo_url
  repo_url=$(_get_registry_url "$registry_name")

  local cache_dir="$REGISTRY_CACHE_DIR/$registry_name"
  mkdir -p "$REGISTRY_CACHE_DIR"

  # Clone or fetch the registry repo
  if [[ -d "$cache_dir/.git" ]]; then
    git -C "$cache_dir" fetch --tags --quiet 2>/dev/null || {
      echo "Error: Failed to fetch from registry '$registry_name'" >&2
      echo "Check network connection and repository access." >&2
      return 1
    }
  else
    git clone --quiet "$repo_url" "$cache_dir" 2>/dev/null || {
      echo "Error: Failed to clone registry '$registry_name'" >&2
      echo "URL: $repo_url" >&2
      echo "Check network connection and credentials." >&2
      return 1
    }
  fi

  # Checkout the requested version tag
  local tag="v$version"
  if ! git -C "$cache_dir" rev-parse "$tag" >/dev/null 2>&1; then
    echo "Error: Version $version (tag $tag) not found in registry '$registry_name'" >&2
    echo "Available versions:" >&2
    git -C "$cache_dir" tag -l 'v*' --sort=-v:refname | head -10 >&2
    return 1
  fi

  git -C "$cache_dir" checkout --quiet "$tag" 2>/dev/null

  # Verify the skill path exists in the repo
  if [[ ! -d "$cache_dir/$skill_path" ]]; then
    echo "Error: Skill path '$skill_path' not found in registry repo" >&2
    return 1
  fi

  # Copy skill to target
  mkdir -p "$target_dir"
  cp -r "$cache_dir/$skill_path/." "$target_dir/"

  # Write version metadata
  _write_version_meta "$target_dir" "$registry_name" "$skill_name" "$version"

  # Verify the installed skill
  verify_skill "$target_dir" || {
    rm -rf "$target_dir"
    echo "Error: Installed skill failed verification, removed." >&2
    return 1
  }

  echo "Installed: $skill_name@$version -> $target_dir"
}

# ── Skill Update ──────────────────────────────────────────────

# Update a skill to the latest version (or a specific version)
# Usage: update_skill "company-skills" "custom-review" ["2.0.0"]
update_skill() {
  local registry_name="$1"
  local skill_name="$2"
  local version="${3:-}"
  _require_config

  local target_dir="$SKILLS_DIR/$skill_name"
  if [[ ! -d "$target_dir" ]]; then
    echo "Error: Skill '$skill_name' is not installed" >&2
    return 1
  fi

  local skill_entry
  skill_entry=$(_get_skill_entry "$registry_name" "$skill_name") || return 1

  local skill_path
  skill_path=$(echo "$skill_entry" | jq -r '.path')

  # Determine target version
  if [[ -z "$version" ]]; then
    version=$(_get_latest_version "$registry_name" "$skill_name")
    if [[ -z "$version" ]]; then
      echo "Error: Could not determine latest version for '$skill_name'" >&2
      return 1
    fi
  fi

  # Check if already at this version
  local current_version
  current_version=$(_read_version_meta "$target_dir")
  if [[ "$current_version" == "$version" ]]; then
    echo "Skill '$skill_name' is already at version $version"
    return 0
  fi

  echo "Updating $skill_name: $current_version -> $version..."

  # Backup current version for rollback
  local backup_dir="$REGISTRY_CACHE_DIR/.backups/$skill_name/$current_version"
  mkdir -p "$backup_dir"
  cp -r "$target_dir/." "$backup_dir/"

  # Remove current and install new
  rm -rf "$target_dir"
  _clone_and_extract "$registry_name" "$skill_name" "$skill_path" "$version" "$target_dir" || {
    echo "Update failed, restoring previous version..." >&2
    cp -r "$backup_dir/." "$target_dir/"
    return 1
  }

  echo "Updated: $skill_name $current_version -> $version"
}

# Get the latest version tag from a registry for a skill
# Usage: _get_latest_version "company-skills" "custom-review"
_get_latest_version() {
  local registry_name="$1"
  local skill_name="$2"

  local cache_dir="$REGISTRY_CACHE_DIR/$registry_name"
  if [[ ! -d "$cache_dir/.git" ]]; then
    echo "" && return 1
  fi

  git -C "$cache_dir" fetch --tags --quiet 2>/dev/null
  git -C "$cache_dir" tag -l 'v*' --sort=-v:refname | head -1 | sed 's/^v//'
}

# ── Skill Rollback ────────────────────────────────────────────

# Rollback a skill to a previous version
# Usage: rollback_skill "company-skills" "custom-review" "1.0.0"
rollback_skill() {
  local registry_name="$1"
  local skill_name="$2"
  local version="$3"
  _require_config

  local target_dir="$SKILLS_DIR/$skill_name"
  local backup_dir="$REGISTRY_CACHE_DIR/.backups/$skill_name/$version"

  # Try backup first (faster)
  if [[ -d "$backup_dir" ]]; then
    echo "Rolling back $skill_name to $version from backup..."
    rm -rf "$target_dir"
    mkdir -p "$target_dir"
    cp -r "$backup_dir/." "$target_dir/"
    echo "Rolled back: $skill_name -> $version (from backup)"
    return 0
  fi

  # No backup, re-install from registry
  echo "No backup found for $version, re-installing from registry..."
  local skill_entry
  skill_entry=$(_get_skill_entry "$registry_name" "$skill_name") || return 1

  local skill_path
  skill_path=$(echo "$skill_entry" | jq -r '.path')

  rm -rf "$target_dir"
  _clone_and_extract "$registry_name" "$skill_name" "$skill_path" "$version" "$target_dir"
}

# ── Dependency Resolution ─────────────────────────────────────

# Parse and resolve dependencies from a skill.md file
# Usage: resolve_dependencies "custom-review" "company-skills"
resolve_dependencies() {
  local skill_name="$1"
  local registry_name="$2"
  local depth="${3:-0}"

  if [[ "$depth" -ge "$MAX_DEPENDENCY_DEPTH" ]]; then
    echo "Error: Circular dependency detected at depth $MAX_DEPENDENCY_DEPTH for '$skill_name'" >&2
    return 1
  fi

  local cache_dir="$REGISTRY_CACHE_DIR/$registry_name"
  if [[ ! -d "$cache_dir/.git" ]]; then
    return 0
  fi

  local skill_entry
  skill_entry=$(_get_skill_entry "$registry_name" "$skill_name") 2>/dev/null || return 0

  local skill_path
  skill_path=$(echo "$skill_entry" | jq -r '.path')

  local skill_md="$cache_dir/$skill_path/skill.md"
  if [[ ! -f "$skill_md" ]]; then
    return 0
  fi

  # Parse depends: field from skill.md frontmatter
  local deps
  deps=$(_parse_depends "$skill_md")
  if [[ -z "$deps" ]]; then
    return 0
  fi

  echo "Resolving dependencies for $skill_name: $deps"

  local dep
  while IFS= read -r dep; do
    dep=$(echo "$dep" | xargs)
    [[ -z "$dep" ]] && continue

    local dep_dir="$SKILLS_DIR/$dep"
    if [[ -d "$dep_dir" ]]; then
      echo "  Dependency '$dep' already installed"
      continue
    fi

    echo "  Installing dependency: $dep"
    local next_depth=$((depth + 1))
    resolve_dependencies "$dep" "$registry_name" "$next_depth" || return 1
    install_skill "$registry_name" "$dep" "" || {
      echo "Error: Failed to install dependency '$dep' for '$skill_name'" >&2
      return 1
    }
  done <<< "$deps"
}

# Parse depends: from skill.md YAML frontmatter
# Usage: _parse_depends "/path/to/skill.md"
_parse_depends() {
  local skill_md="$1"
  # Extract depends: line from YAML frontmatter (between --- markers)
  sed -n '/^---$/,/^---$/p' "$skill_md" \
    | grep -i '^depends:' \
    | sed 's/^[Dd]epends:\s*//' \
    | tr ',' '\n' \
    | sed 's/^[ \t]*//' \
    | sed '/^$/d'
}

# ── Skill Verification ────────────────────────────────────────

# Verify a skill has required structure and files
# Usage: verify_skill "/path/to/skill"
verify_skill() {
  local skill_path="$1"
  local errors=0

  if [[ ! -d "$skill_path" ]]; then
    echo "Error: Skill directory does not exist: $skill_path" >&2
    return 1
  fi

  # Check for skill.md (primary skill file)
  if [[ ! -f "$skill_path/skill.md" ]]; then
    echo "Warning: skill.md not found in $skill_path" >&2
    # Also check SKILL.md (alternate convention)
    if [[ ! -f "$skill_path/SKILL.md" ]]; then
      echo "Error: No skill.md or SKILL.md found in $skill_path" >&2
      errors=$((errors + 1))
    fi
  fi

  # Check skill.md is not empty
  local skill_file
  skill_file=$(_find_skill_md "$skill_path")
  if [[ -n "$skill_file" ]] && [[ ! -s "$skill_file" ]]; then
    echo "Error: Skill file is empty: $skill_file" >&2
    errors=$((errors + 1))
  fi

  if [[ "$errors" -gt 0 ]]; then
    return 1
  fi

  return 0
}

# Find the skill markdown file (skill.md or SKILL.md)
_find_skill_md() {
  local skill_path="$1"
  if [[ -f "$skill_path/skill.md" ]]; then
    echo "$skill_path/skill.md"
  elif [[ -f "$skill_path/SKILL.md" ]]; then
    echo "$skill_path/SKILL.md"
  fi
}

# ── Registry Sync ─────────────────────────────────────────────

# Sync all skills from a registry (install missing, update outdated)
# Usage: sync_registry "company-skills"
sync_registry() {
  local registry_name="$1"
  _require_config

  local registry_json
  registry_json=$(_get_registry "$registry_name") || return 1

  local auto_update
  auto_update=$(jq -r '.auto_update // false' "$REGISTRY_CONFIG")

  echo "Syncing registry: $registry_name"
  echo "────────────────────────────────────"

  local skill_count=0
  local installed=0
  local updated=0
  local skipped=0
  local failed=0

  while IFS=$'\t' read -r name version required path; do
    skill_count=$((skill_count + 1))
    local target_dir="$SKILLS_DIR/$name"

    if [[ ! -d "$target_dir" ]]; then
      echo "  Installing: $name@$version"
      if install_skill "$registry_name" "$name" "$version" 2>/dev/null; then
        installed=$((installed + 1))
      else
        failed=$((failed + 1))
        if [[ "$required" == "true" ]]; then
          echo "Error: Required skill '$name' failed to install" >&2
          return 1
        fi
      fi
    elif [[ "$auto_update" == "true" ]]; then
      local current_ver
      current_ver=$(_read_version_meta "$target_dir")
      if [[ "$current_ver" != "$version" ]]; then
        echo "  Updating: $name $current_ver -> $version"
        if update_skill "$registry_name" "$name" "$version" 2>/dev/null; then
          updated=$((updated + 1))
        else
          failed=$((failed + 1))
        fi
      else
        skipped=$((skipped + 1))
      fi
    else
      skipped=$((skipped + 1))
    fi
  done < <(echo "$registry_json" | jq -r '.skills[] | "\(.name)\t\(.version)\t\(.required)\t\(.path)"')

  echo "────────────────────────────────────"
  echo "Sync complete: $skill_count skills ($installed installed, $updated updated, $skipped up-to-date, $failed failed)"
}

# ── Version Metadata ──────────────────────────────────────────

# Write version metadata to an installed skill
_write_version_meta() {
  local target_dir="$1"
  local registry_name="$2"
  local skill_name="$3"
  local version="$4"

  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  jq -n \
    --arg registry "$registry_name" \
    --arg name "$skill_name" \
    --arg version "$version" \
    --arg installed_at "$now" \
    '{registry: $registry, name: $name, version: $version, installed_at: $installed_at}' \
    > "$target_dir/.registry-meta.json"
}

# Read the installed version from metadata
_read_version_meta() {
  local target_dir="$1"
  local meta_file="$target_dir/.registry-meta.json"

  if [[ -f "$meta_file" ]]; then
    jq -r '.version // "unknown"' "$meta_file"
  else
    echo "unknown"
  fi
}

# ── Status ────────────────────────────────────────────────────

# Show status of all installed registry skills
# Usage: show_registry_status
show_registry_status() {
  _require_config

  echo "════════════════════════════════════════════════════════════════"
  echo "  Skill Registry Status"
  echo "════════════════════════════════════════════════════════════════"
  echo ""

  local registries
  registries=$(jq -r '.registries[].name' "$REGISTRY_CONFIG")

  while IFS= read -r registry_name; do
    echo "  Registry: $registry_name"
    echo "  ────────────────────────────────────────"

    local registry_json
    registry_json=$(_get_registry "$registry_name") 2>/dev/null || continue

    printf "  %-25s %-12s %-12s %s\n" "SKILL" "EXPECTED" "INSTALLED" "STATUS"

    while IFS=$'\t' read -r name version required path; do
      local target_dir="$SKILLS_DIR/$name"
      local installed_ver="--"
      local status="missing"

      if [[ -d "$target_dir" ]]; then
        installed_ver=$(_read_version_meta "$target_dir")
        if [[ "$installed_ver" == "$version" ]]; then
          status="ok"
        else
          status="outdated"
        fi
      fi

      local req_marker=""
      [[ "$required" == "true" ]] && req_marker=" *"

      printf "  %-25s %-12s %-12s %s%s\n" "$name" "$version" "$installed_ver" "$status" "$req_marker"
    done < <(echo "$registry_json" | jq -r '.skills[] | "\(.name)\t\(.version)\t\(.required)\t\(.path)"')

    echo ""
  done <<< "$registries"

  echo "  * = required skill"
  echo ""
  echo "════════════════════════════════════════════════════════════════"
}

# ── Helpers ───────────────────────────────────────────────────

# Ensure a registry config is loaded
_require_config() {
  if [[ -z "$REGISTRY_CONFIG" ]]; then
    echo "Error: No registry config loaded. Call load_registry() first." >&2
    return 1
  fi
}

# ── Direct Execution ──────────────────────────────────────────

# When run directly (not sourced), handle subcommands
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  _print_usage() {
    echo "Usage: skill-registry.sh <command> [args...]"
    echo ""
    echo "Commands:"
    echo "  list    <registry>                    List skills in a registry"
    echo "  install <registry> <skill> [version]  Install a skill"
    echo "  update  <registry> <skill> [version]  Update a skill"
    echo "  rollback <registry> <skill> <version> Rollback to a version"
    echo "  sync    <registry>                    Sync all skills from registry"
    echo "  status                                Show installed skill status"
    echo ""
    echo "Environment:"
    echo "  CLAUDE_REGISTRY_CONFIG  Path to registry.json (default: ~/.claude/registry.json)"
  }

  config_path="${CLAUDE_REGISTRY_CONFIG:-$HOME/.claude/registry.json}"
  command="${1:-}"

  if [[ -z "$command" ]]; then
    _print_usage
    exit 1
  fi

  shift

  load_registry "$config_path" || exit 1

  case "$command" in
    list)
      [[ $# -lt 1 ]] && { echo "Usage: skill-registry.sh list <registry>" >&2; exit 1; }
      list_registry_skills "$1"
      ;;
    install)
      [[ $# -lt 2 ]] && { echo "Usage: skill-registry.sh install <registry> <skill> [version]" >&2; exit 1; }
      install_skill "$1" "$2" "${3:-}"
      ;;
    update)
      [[ $# -lt 2 ]] && { echo "Usage: skill-registry.sh update <registry> <skill> [version]" >&2; exit 1; }
      update_skill "$1" "$2" "${3:-}"
      ;;
    rollback)
      [[ $# -lt 3 ]] && { echo "Usage: skill-registry.sh rollback <registry> <skill> <version>" >&2; exit 1; }
      rollback_skill "$1" "$2" "$3"
      ;;
    sync)
      [[ $# -lt 1 ]] && { echo "Usage: skill-registry.sh sync <registry>" >&2; exit 1; }
      sync_registry "$1"
      ;;
    status)
      show_registry_status
      ;;
    *)
      echo "Error: Unknown command '$command'" >&2
      _print_usage
      exit 1
      ;;
  esac
fi
