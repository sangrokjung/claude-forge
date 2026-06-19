#!/bin/bash
# Expensive MCP Warning - PreToolUse Hook
# Warns before calling expensive MCP tools (playwright)
#
# Hook trigger: PreToolUse (specific expensive MCP tools)
# Exit codes: 2 = require user approval for expensive tools, 0 = allow (non-expensive)

# Read tool call JSON from stdin
INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null)

# List of expensive MCP tools
# matcher는 settings.json에서 mcp__playwright__browser_run_code만 지정
# browser_run_code가 유일한 고비용 도구이므로 확장 불필요
EXPENSIVE_TOOLS=(
    "mcp__playwright__browser_run_code"
)

for expensive in "${EXPENSIVE_TOOLS[@]}"; do
    if [[ "$TOOL_NAME" == "$expensive" ]]; then
        echo "WARNING: High-cost MCP call: $TOOL_NAME" >&2
        echo "This tool uses a browser instance and incurs high costs." >&2
        echo "Consider lightweight alternatives: scrape_webpage, browser_snapshot, etc." >&2
        # Block - require user approval
        exit 2
    fi
done

exit 0
