#!/bin/bash

# CC CHIPS — Rendering engine for Claude Code status lines
# Set CC_CHIPS_THEME to pick a theme (claude, cool, retro, cyber).
# Defaults to claude.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
THEME="${CC_CHIPS_THEME:-claude}"

# Load theme colors
THEME_FILE="${SCRIPT_DIR}/themes/${THEME}.sh"
if [ ! -f "$THEME_FILE" ]; then
    echo "CC CHIPS: theme '${THEME}' not found at ${THEME_FILE}" >&2
    exit 1
fi
source "$THEME_FILE"

input=$(cat)

# ═══════════════════════════════════════════════════════════════════
# POWERLINE CAPS (rounded pill edges)
# ═══════════════════════════════════════════════════════════════════
CAP_LEFT=$(printf '\xee\x82\xb6')           # U+E0B6 left half circle
CAP_RIGHT=$(printf '\xee\x82\xb4')          # U+E0B4 right half circle

# ═══════════════════════════════════════════════════════════════════
# NERD FONT ICONS
# ═══════════════════════════════════════════════════════════════════
ICON_FOLDER=$(printf '\xef\x81\xbc')        # U+F07C  folder-open
ICON_GITHUB=$(printf '\xef\x82\x9b')        # U+F09B  github
ICON_BRANCH=$(printf '\xee\x9c\xa5')        # U+E725  dev-git_branch
ICON_BRAIN=$(printf '\xf3\xb0\xaf\x89')     # U+F0BC9 nf-md-space_invaders
ICON_MONITOR=$(printf '\xef\x8b\x90')       # U+F2D0  fa-window_maximize
ICON_DOLLAR=$(printf '\xee\xb7\xa8')         # U+EDE8  fa-coins
ICON_KEY=$(printf '\xf3\xb0\x8c\xb7')         # U+F0337 nf-md-key
ICON_CHART=$(printf '\xef\x82\x80')           # U+F080  fa-bar-chart
ICON_BOLT=$(printf '\xef\x83\xa7')            # U+F0E7  fa-bolt

BOLD="\033[1m"
RESET="\033[0m"

# ═══════════════════════════════════════════════════════════════════
# EXTRACT DATA
# ═══════════════════════════════════════════════════════════════════
session_id=$(echo "$input" | jq -r '.session_id // "unknown"')
session_short="${session_id:0:8}"
project_dir=$(echo "$input" | jq -r '.workspace.project_dir // .workspace.current_dir // "."')
short_path=$(echo "$project_dir" | sed "s|$HOME|~|")

# ═══════════════════════════════════════════════════════════════════
# GIT
# ═══════════════════════════════════════════════════════════════════
git_branch=""
git_dirty=""
if [ -d "$project_dir/.git" ] || git -C "$project_dir" rev-parse --git-dir > /dev/null 2>&1; then
    git_branch=$(git -C "$project_dir" branch --show-current 2>/dev/null)
    if [ -n "$git_branch" ]; then
        if ! git -C "$project_dir" diff --quiet 2>/dev/null || ! git -C "$project_dir" diff --cached --quiet 2>/dev/null; then
            git_dirty=" ≠"
        fi
    fi
fi

# ═══════════════════════════════════════════════════════════════════
# MODEL
# ═══════════════════════════════════════════════════════════════════
model=$(echo "$input" | jq -r '.model // "unknown"')
case "$model" in
    *opus*4.6*|*opus-4-6*) model_display="Opus 4.6" ;;
    *opus*4.5*|*opus-4-5*) model_display="Opus 4.5" ;;
    *opus*4*|*opus-4*) model_display="Opus 4" ;;
    *sonnet*4.5*|*sonnet-4-5*) model_display="Sonnet 4.5" ;;
    *sonnet*4*|*sonnet-4*) model_display="Sonnet 4" ;;
    *sonnet*3.5*|*sonnet-3-5*) model_display="Sonnet 3.5" ;;
    *haiku*4.5*|*haiku-4-5*) model_display="Haiku 4.5" ;;
    *haiku*3.5*|*haiku-3-5*) model_display="Haiku 3.5" ;;
    *) model_display="$model" ;;
esac

# ═══════════════════════════════════════════════════════════════════
# CONTEXT WINDOW
# ═══════════════════════════════════════════════════════════════════
usage=$(echo "$input" | jq '.context_window.current_usage')
input_tokens=0
output_tokens=0
cache_read=0
cache_write=0
context_pct=0

if [ "$usage" != "null" ]; then
    input_tokens=$(echo "$usage" | jq '.input_tokens // 0')
    output_tokens=$(echo "$usage" | jq '.output_tokens // 0')
    cache_read=$(echo "$usage" | jq '.cache_read_input_tokens // 0')
    cache_write=$(echo "$usage" | jq '.cache_creation_input_tokens // 0')
    current=$((input_tokens + cache_write + cache_read))
    size=$(echo "$input" | jq '.context_window.context_window_size')
    if [ "$size" != "null" ] && [ "$size" -gt 0 ] 2>/dev/null; then
        context_pct=$((current * 100 / size))
    fi
fi

# Context bar (5 blocks)
filled=$((context_pct * 5 / 100))
bar=""
for ((i=0; i<5; i++)); do
    if [ $i -lt $filled ]; then bar="${bar}■"; else bar="${bar}□"; fi
done

# ═══════════════════════════════════════════════════════════════════
# COST (Opus 4.5: $15/M in, $75/M out, $1.50/M cache read, $18.75/M cache write)
# ═══════════════════════════════════════════════════════════════════
cost_input_cents=$(( (input_tokens * 1500) / 1000000 ))
cost_output_cents=$(( (output_tokens * 7500) / 1000000 ))
cost_cache_read_cents=$(( (cache_read * 150) / 1000000 ))
cost_cache_write_cents=$(( (cache_write * 1875) / 1000000 ))
total_cents=$((cost_input_cents + cost_output_cents + cost_cache_read_cents + cost_cache_write_cents))

# ═══════════════════════════════════════════════════════════════════
# CACHE EFFICIENCY
# ═══════════════════════════════════════════════════════════════════
total_ctx=$((input_tokens + cache_read + cache_write))
if [ $total_ctx -gt 0 ]; then
    cache_pct=$((cache_read * 100 / total_ctx))
else
    cache_pct=0
fi

# ═══════════════════════════════════════════════════════════════════
# API RESPONSE TIME
# ═══════════════════════════════════════════════════════════════════
api_ms=$(echo "$input" | jq '.cost.total_api_duration_ms // 0')
if [ "$api_ms" != "null" ] && [ "$api_ms" -gt 0 ] 2>/dev/null; then
    api_sec=$(awk "BEGIN {printf \"%.1f\", $api_ms / 1000}")
else
    api_sec="0.0"
fi

if [ $total_cents -eq 0 ]; then
    cost_display="\$0"
elif [ $total_cents -lt 100 ]; then
    cost_display="\$0.$(printf '%02d' $total_cents)"
else
    dollars=$((total_cents / 100))
    cents=$((total_cents % 100))
    cost_display="\$${dollars}.$(printf '%02d' $cents)"
fi

# ═══════════════════════════════════════════════════════════════════
# BUILD STATUS LINE
# ═══════════════════════════════════════════════════════════════════

# CHIP 1: folder + path
printf "${FG_LEFT}${CAP_LEFT}${RESET}"
printf "${BG_LEFT}${BOLD}${FG_LEFT_TEXT} ${ICON_FOLDER} %s ${RESET}" "$short_path"
printf "${FG_LEFT}${CAP_RIGHT}${RESET}"

# CHIP 2: git info
if [ -n "$git_branch" ]; then
    printf " "
    printf "${FG_MID}${CAP_LEFT}${RESET}"
    printf "${BG_MID}${BOLD}${FG_MID_TEXT} ${ICON_GITHUB} ${ICON_BRANCH} %s${FG_MID_TEXT}%s${FG_MID_TEXT} ${RESET}" "$git_branch" "$git_dirty"
    printf "${FG_MID}${CAP_RIGHT}${RESET}"
fi

printf " "

# CHIP 3: model + context + cost
printf "${FG_RIGHT}${CAP_LEFT}${RESET}"
printf "${BG_RIGHT}${BOLD}${FG_RIGHT_TEXT} ${ICON_BRAIN} %s ${ICON_MONITOR} %s %d%% ${ICON_DOLLAR} %s ${ICON_KEY} %s ${RESET}" "$model_display" "$bar" "$context_pct" "$cost_display" "$session_short"
printf "${FG_RIGHT}${CAP_RIGHT}${RESET}"

# CHIP 4: cache efficiency + api response time
printf " "
printf "${FG_STATS}${CAP_LEFT}${RESET}"
printf "${BG_STATS}${BOLD}${FG_STATS_TEXT} ${ICON_CHART} %d%% ${ICON_BOLT} %ss ${RESET}" "$cache_pct" "$api_sec"
printf "${FG_STATS}${CAP_RIGHT}${RESET}"

printf "\n"
