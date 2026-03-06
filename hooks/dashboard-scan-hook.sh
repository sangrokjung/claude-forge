#!/bin/bash
# dashboard-scan-hook.sh — SessionStart hook
# Triggers background project scan for dashboard and cc-chips integration.
# Scans current project only (fast). Writes to cache.
#
# Hook trigger: SessionStart
# Timeout: 5000ms
# Exit codes: 0 always (never blocks session)
#
# Registration (add to settings.json SessionStart hooks):
#   {
#     "hooks": [
#       {
#         "type": "command",
#         "command": "~/.claude/hooks/dashboard-scan-hook.sh",
#         "timeout": 5000
#       }
#     ]
#   }

INPUT=$(cat)

# Background scan to avoid blocking session start
(
  python3 -c "
import sys, json, os, subprocess

try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)

# Get current working directory from input
workspace = d.get('workspace', {})
project_dir = workspace.get('project_dir') or workspace.get('current_dir') or os.getcwd()

# Validate project directory
if not os.path.isdir(project_dir):
    sys.exit(0)

# Locate project-scanner.sh (in ~/.claude/scripts)
scanner_path = os.path.expanduser('~/.claude/scripts/project-scanner.sh')
if not os.path.isfile(scanner_path):
    sys.exit(0)

# Run scanner for current project only
try:
    result = subprocess.run(
        ['bash', scanner_path, '--scan', project_dir],
        capture_output=True, text=True, timeout=10
    )
    if result.returncode != 0:
        sys.exit(0)

    project_json = result.stdout.strip()
    if not project_json:
        sys.exit(0)

except subprocess.TimeoutExpired:
    sys.exit(0)
except Exception:
    sys.exit(0)

# Read existing cache or create new
cache_path = os.path.expanduser('~/.claude/.dashboard-cache.json')
cache_data = []

if os.path.exists(cache_path):
    try:
        with open(cache_path) as f:
            cache_data = json.load(f)
            if not isinstance(cache_data, list):
                cache_data = []
    except Exception:
        cache_data = []

# Parse new project data
try:
    new_project = json.loads(project_json)
except Exception:
    sys.exit(0)

# Update or append project in cache
project_path = new_project.get('path')
found = False

for i, proj in enumerate(cache_data):
    if proj.get('path') == project_path:
        cache_data[i] = new_project
        found = True
        break

if not found:
    cache_data.append(new_project)

# Write cache atomically
cache_tmp = cache_path + '.tmp'
try:
    with open(cache_tmp, 'w') as f:
        json.dump(cache_data, f, indent=2, ensure_ascii=False)
    os.replace(cache_tmp, cache_path)
except Exception:
    if os.path.exists(cache_tmp):
        os.remove(cache_tmp)
    sys.exit(0)

" <<< "$INPUT" 2>/dev/null
) &

# Disown background process to prevent blocking
disown

exit 0
