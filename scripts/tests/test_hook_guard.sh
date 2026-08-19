#!/bin/bash
# hook-guard.sh regression: cooldown suppresses within window, token guard
# rejects placeholders. Run: bash scripts/tests/test_hook_guard.sh
set -uo pipefail
LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/libs/hook-guard.sh"
[ -r "$LIB" ] || { echo "FAIL: libs/hook-guard.sh missing"; exit 1; }
PASS=0; FAIL=0
ok(){ printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }
no(){ printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }

# isolated cooldown state dir
export HOOK_GUARD_STATE_DIR=$(mktemp -d)
# shellcheck source=/dev/null
HOOK_GUARD_SKIP_STDIN=1 source "$LIB"

hook_cooldown "t-$$" 30           && ok "first call passes"        || no "first call passes"
hook_cooldown "t-$$" 30           && no "second call suppressed"   || ok "second call suppressed"
hook_cooldown "other-$$" 30       && ok "different key independent" || no "different key independent"

hook_token_valid "real-token-abc"     && ok "real token accepted"      || no "real token accepted"
hook_token_valid ""                   && no "empty rejected"           || ok "empty rejected"
hook_token_valid "YOUR_WEBHOOK_TOKEN" && no "placeholder rejected"     || ok "placeholder rejected"
hook_token_valid "REPLACE_ME"         && no "REPLACE_ME rejected"      || ok "REPLACE_ME rejected"

[ -n "${PYTHON3:-}" ] && ok "PYTHON3 defined" || no "PYTHON3 defined"
echo "PASS=$PASS FAIL=$FAIL"; exit $((FAIL > 0))
