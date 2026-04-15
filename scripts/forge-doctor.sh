#!/bin/bash
# forge-doctor.sh — Claude Forge 설치 무결성 점검
#
# 검사 항목:
#   1. 필수 의존성 (node, jq, git, claude CLI)
#   2. ~/.claude 디렉토리 + .forge-meta.json
#   3. forge symlink 무결성 (broken link 없는지)
#   4. 저장소 경로 존재 + git 상태
#   5. plugin.json 버전 vs 메타파일 버전
#   6. MCP 서버 등록 상태 (claude mcp list)
#   7. 셸 alias 설치 여부
#   8. 백업 디렉토리 개수
#
# Exit codes:
#   0 — 모두 정상
#   1 — 경고 있음 (사용엔 지장 없음)
#   2 — 치명적 문제 (사용 불가)
#
# Options:
#   --quiet   요약만 출력
#   --json    machine-readable JSON 출력

set -e

CLAUDE_DIR="$HOME/.claude"
QUIET=false
JSON=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --quiet) QUIET=true ;;
        --json) JSON=true ;;
        -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
DIM='\033[2m'
NC='\033[0m'

ERRORS=0
WARNINGS=0
RESULTS=()

ok()    { RESULTS+=("OK|$1"); $QUIET || $JSON || echo -e "  ${GREEN}✓${NC} $1"; }
warn()  { RESULTS+=("WARN|$1"); WARNINGS=$((WARNINGS+1)); $QUIET || $JSON || echo -e "  ${YELLOW}!${NC} $1"; }
err()   { RESULTS+=("ERR|$1"); ERRORS=$((ERRORS+1)); $QUIET || $JSON || echo -e "  ${RED}✗${NC} $1"; }
info()  { $QUIET || $JSON || echo -e "  ${DIM}$1${NC}"; }
section() { $QUIET || $JSON || echo -e "\n${BLUE}$1${NC}"; }

$JSON || $QUIET || cat << 'BANNER'

   ╔═╗┬  ┌─┐┬ ┬┌┬┐┌─┐  ╔═╗┌─┐┬─┐┌─┐┌─┐
   ║  │  ├─┤│ │ ││├┤   ╠╣ │ │├┬┘│ ┬├┤
   ╚═╝┴─┘┴ ┴└─┘─┴┘└─┘  ╚  └─┘┴└─└─┘└─┘   doctor

BANNER

# ─── 1. Dependencies ──────────────────────────────────────────────
section "Dependencies"
for cmd in node jq git; do
    if command -v "$cmd" >/dev/null; then
        ver=$("$cmd" --version 2>/dev/null | head -1 | tr -d '\n')
        ok "$cmd ($ver)"
    else
        err "$cmd not found"
    fi
done

if command -v claude >/dev/null; then
    ok "claude CLI ($(claude --version 2>/dev/null | head -1 || echo 'unknown'))"
else
    warn "claude CLI not in PATH (install: https://claude.ai/code)"
fi

# ─── 2. ~/.claude + meta ──────────────────────────────────────────
section "Install state"
if [ -d "$CLAUDE_DIR" ]; then
    ok "~/.claude exists"
else
    err "~/.claude not found — run install.sh"
    # Bail out — nothing else makes sense
    [[ $JSON == true ]] && echo '{"errors":1,"warnings":0,"status":"not_installed"}'
    exit 2
fi

META="$CLAUDE_DIR/.forge-meta.json"
REPO_PATH=""
INSTALL_MODE=""
META_VERSION=""

if [ -f "$META" ]; then
    if jq empty "$META" 2>/dev/null; then
        ok ".forge-meta.json valid JSON"
        REPO_PATH=$(jq -r '.repo_path // ""' "$META")
        INSTALL_MODE=$(jq -r '.install_mode // ""' "$META")
        META_VERSION=$(jq -r '.version // ""' "$META")
        info "repo: $REPO_PATH"
        info "mode: $INSTALL_MODE  ·  version: $META_VERSION"
    else
        err ".forge-meta.json is not valid JSON"
    fi
else
    warn ".forge-meta.json missing (legacy install? re-run install.sh)"
fi

# ─── 3. Symlink integrity ─────────────────────────────────────────
section "Forge items in ~/.claude"
FORGE_ITEMS=(agents rules commands scripts skills hooks cc-chips cc-chips-custom settings.json)
for item in "${FORGE_ITEMS[@]}"; do
    target="$CLAUDE_DIR/$item"
    if [ -L "$target" ]; then
        if [ -e "$target" ]; then
            link_target=$(readlink "$target")
            ok "$item (symlink → $link_target)"
        else
            err "$item (BROKEN symlink → $(readlink "$target"))"
        fi
    elif [ -e "$target" ]; then
        if [ "$INSTALL_MODE" = "copy" ]; then
            ok "$item (copy)"
        else
            warn "$item (regular file/dir, expected symlink)"
        fi
    else
        err "$item (missing)"
    fi
done

# ─── 4. Repo state ────────────────────────────────────────────────
section "Repository"
if [ -n "$REPO_PATH" ]; then
    if [ -d "$REPO_PATH" ]; then
        ok "repo path exists"
        if [ -d "$REPO_PATH/.git" ]; then
            git_branch=$(git -C "$REPO_PATH" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")
            git_commit=$(git -C "$REPO_PATH" rev-parse --short HEAD 2>/dev/null || echo "?")
            git_dirty=""
            if ! git -C "$REPO_PATH" diff-index --quiet HEAD -- 2>/dev/null; then
                git_dirty=" (dirty)"
            fi
            ok "git: $git_branch @ $git_commit$git_dirty"
        else
            warn "repo has no .git (downloaded as zip?)"
        fi

        # Plugin version vs meta version
        plugin_json="$REPO_PATH/.claude-plugin/plugin.json"
        if [ -f "$plugin_json" ]; then
            plugin_ver=$(jq -r '.version // ""' "$plugin_json" 2>/dev/null)
            if [ -n "$plugin_ver" ] && [ -n "$META_VERSION" ] && [ "$plugin_ver" != "$META_VERSION" ]; then
                warn "version drift: plugin.json=$plugin_ver, meta=$META_VERSION (run /forge-update or install.sh)"
            elif [ -n "$plugin_ver" ]; then
                ok "version $plugin_ver matches meta"
            fi
        fi
    else
        err "repo path does not exist: $REPO_PATH"
    fi
fi

# ─── 5. MCP servers ───────────────────────────────────────────────
section "MCP servers"
if command -v claude >/dev/null; then
    mcp_out=$(claude mcp list 2>&1 || true)
    mcp_count=$(echo "$mcp_out" | grep -cE '^[a-zA-Z]' || echo 0)
    if [ "$mcp_count" -gt 0 ]; then
        ok "$mcp_count MCP servers registered"
    else
        warn "no MCP servers registered (run install.sh to add recommended set)"
    fi
else
    info "skipped (claude CLI not available)"
fi

# ─── 6. Shell aliases ─────────────────────────────────────────────
section "Shell aliases"
alias_found=false
for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
    [ -f "$rc" ] || continue
    if grep -q "^# Claude Code aliases" "$rc" 2>/dev/null; then
        ok "alias block in $(basename "$rc")"
        alias_found=true
    fi
done
$alias_found || warn "no 'cc'/'ccr' aliases (optional — run install.sh to add)"

# ─── 7. Backups ───────────────────────────────────────────────────
section "Backups"
backup_count=$(find "$HOME" -maxdepth 1 -name '.claude.backup.*' -type d 2>/dev/null | wc -l | tr -d ' ')
if [ "$backup_count" -gt 0 ]; then
    ok "$backup_count backup(s) in ~"
    if [ "$backup_count" -gt 5 ]; then
        warn "$backup_count backups is a lot — consider cleaning oldest"
    fi
else
    info "no backups (clean install)"
fi

# ─── Summary ──────────────────────────────────────────────────────
if $JSON; then
    printf '{"errors":%d,"warnings":%d,"status":"%s","results":[' \
        "$ERRORS" "$WARNINGS" \
        "$([ $ERRORS -gt 0 ] && echo fail || ([ $WARNINGS -gt 0 ] && echo warn || echo ok))"
    first=true
    for r in "${RESULTS[@]}"; do
        $first || printf ','
        first=false
        level="${r%%|*}"
        msg="${r#*|}"
        printf '{"level":"%s","msg":%s}' "$level" "$(jq -Rn --arg s "$msg" '$s')"
    done
    printf ']}\n'
else
    echo ""
    if [ $ERRORS -gt 0 ]; then
        echo -e "${RED}✗ $ERRORS error(s), $WARNINGS warning(s)${NC}"
        echo "  Re-run install.sh from the repo to fix."
    elif [ $WARNINGS -gt 0 ]; then
        echo -e "${YELLOW}! $WARNINGS warning(s) — install is usable${NC}"
    else
        echo -e "${GREEN}✓ All checks passed — install is healthy${NC}"
    fi
fi

[ $ERRORS -gt 0 ] && exit 2
[ $WARNINGS -gt 0 ] && exit 1
exit 0
