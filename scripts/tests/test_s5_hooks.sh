#!/bin/bash
# Regression fixtures for the S5 hooks (hooks/loop-detection.sh, hooks/auto-verify-fix.sh).
#
# Covers the two defects the original one-file smoke test could not see:
#   * loop-detection counted with `grep -c ... || echo 0`, which produced the
#     two-line string "0\n0" — a bash arithmetic error on the first edit of
#     every file after the first one in a session (needs a TWO-file fixture).
#   * both hooks keyed their state off env vars Claude Code never sets, so the
#     state was machine-global instead of session-scoped (needs TWO session ids).
#
# Run with: bash scripts/tests/test_s5_hooks.sh

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOOP_HOOK="$ROOT/hooks/loop-detection.sh"
VERIFY_HOOK="$ROOT/hooks/auto-verify-fix.sh"

PASS=0
FAIL=0
# Unique per run: the hooks write to fixed /tmp paths, so distinct ids are what
# keeps repeated runs (and concurrent ones) from contaminating each other.
RUN_ID="s5test$$-$(date +%s)"
WORK="$(mktemp -d)"

ok()   { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL + 1)); printf '  FAIL %s\n     %s\n' "$1" "${2:-}"; }

payload() {  # payload <tool> <session_id> <file_path>
    printf '{"tool_name":"%s","session_id":"%s","tool_input":{"file_path":"%s"}}' "$1" "$2" "$3"
}

# --- loop-detection ---------------------------------------------------------
echo "-- loop-detection --"

SA="${RUN_ID}-A"
SB="${RUN_ID}-B"
FILE_A="$WORK/alpha.ts"
FILE_B="$WORK/beta.ts"

# 1. Two-file fixture: the second file's FIRST edit must be clean. Before the
#    fix this emitted "syntax error in expression (error token is "0")".
payload Edit "$SA" "$FILE_A" | bash "$LOOP_HOOK" >/dev/null 2>&1
ERR=$(payload Edit "$SA" "$FILE_B" | bash "$LOOP_HOOK" 2>&1 >/dev/null)
RC=$?
if [ "$RC" -eq 0 ] && [ -z "$ERR" ]; then
    ok "first edit of a second file is clean (no double-zero COUNT)"
else
    bad "first edit of a second file is clean (no double-zero COUNT)" "rc=$RC stderr=$ERR"
fi

# 2. session_id comes from the payload, not the environment: two ids must not
#    share a state file.
if [ -f "/tmp/claude-loop-detect-${SA}.jsonl" ]; then
    ok "payload session_id keys the state file"
else
    bad "payload session_id keys the state file" "/tmp/claude-loop-detect-${SA}.jsonl missing"
fi

payload Edit "$SB" "$FILE_A" | bash "$LOOP_HOOK" >/dev/null 2>&1
if [ -f "/tmp/claude-loop-detect-${SB}.jsonl" ] &&
   [ "$(grep -c . "/tmp/claude-loop-detect-${SB}.jsonl")" = "1" ]; then
    ok "a second session gets its own state file"
else
    bad "a second session gets its own state file" "session B state did not start empty"
fi

# 3. Threshold still fires inside one session (5 edits of the same file).
SC="${RUN_ID}-C"
OUT=""
for _ in 1 2 3 4 5; do
    OUT=$(payload Edit "$SC" "$FILE_A" | bash "$LOOP_HOOK" 2>/dev/null)
done
if printf '%s' "$OUT" | grep -q 'Loop Detection'; then
    ok "5 same-file edits in one session still warn"
else
    bad "5 same-file edits in one session still warn" "no warning emitted: $OUT"
fi

# 4. …and a different session does NOT inherit that count.
SD="${RUN_ID}-D"
OUT=$(payload Edit "$SD" "$FILE_A" | bash "$LOOP_HOOK" 2>/dev/null)
if [ -z "$OUT" ]; then
    ok "a fresh session does not inherit the previous session's count"
else
    bad "a fresh session does not inherit the previous session's count" "leaked warning: $OUT"
fi

# --- auto-verify-fix --------------------------------------------------------
echo "-- auto-verify-fix --"

BROKEN="$WORK/broken.py"
printf 'def f(:\n    pass\n' > "$BROKEN"
HASH=$(python3 -c "import hashlib,sys;print(hashlib.md5(sys.argv[1].encode()).hexdigest())" "$BROKEN")

SE="${RUN_ID}-E"
SF="${RUN_ID}-F"
OUT=$(payload Edit "$SE" "$BROKEN" | bash "$VERIFY_HOOK" 2>/dev/null)
if printf '%s' "$OUT" | grep -q 'additionalContext'; then
    ok "a syntax error surfaces as additionalContext"
else
    bad "a syntax error surfaces as additionalContext" "got: $OUT"
fi

if [ -f "/tmp/auto-verify-fix-${SE}-${HASH}" ]; then
    ok "payload session_id keys the suppression marker"
else
    bad "payload session_id keys the suppression marker" "marker for session E missing"
fi

# Suppression is per session: drive E past the count>3 cutoff, then confirm a
# different session still reports.
for _ in 1 2 3 4; do
    payload Edit "$SE" "$BROKEN" | bash "$VERIFY_HOOK" >/dev/null 2>&1
done
OUT_E=$(payload Edit "$SE" "$BROKEN" | bash "$VERIFY_HOOK" 2>/dev/null)
OUT_F=$(payload Edit "$SF" "$BROKEN" | bash "$VERIFY_HOOK" 2>/dev/null)
if [ -z "$OUT_E" ] && printf '%s' "$OUT_F" | grep -q 'additionalContext'; then
    ok "suppression is session-scoped, not machine-global"
else
    bad "suppression is session-scoped, not machine-global" "E='$OUT_E' F(len)=${#OUT_F}"
fi

# A marker older than the 6h TTL must be ignored rather than silencing forever.
MARKER="/tmp/auto-verify-fix-${SE}-${HASH}"
printf '99' > "$MARKER"
touch -t "$(date -v-7H '+%Y%m%d%H%M' 2>/dev/null || date -d '7 hours ago' '+%Y%m%d%H%M')" "$MARKER"
OUT=$(payload Edit "$SE" "$BROKEN" | bash "$VERIFY_HOOK" 2>/dev/null)
if printf '%s' "$OUT" | grep -q 'additionalContext'; then
    ok "a marker past the TTL cannot suppress forever"
else
    bad "a marker past the TTL cannot suppress forever" "still silent with a 7h-old marker"
fi

# --- shape checks -----------------------------------------------------------
echo "-- shape --"
for h in "$LOOP_HOOK" "$VERIFY_HOOK" "$ROOT/hooks/emdash-slop-guard.sh"; do
    name=$(basename "$h")
    if bash -n "$h" 2>/dev/null; then ok "$name parses"; else bad "$name parses"; fi
    if [ -x "$h" ]; then ok "$name is executable"; else bad "$name is executable" "chmod +x missing"; fi
done

echo
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
