#!/bin/bash
# api-error-auto-resume.sh classification regression.
#
# Every case runs the real hook against a throwaway $HOME, feeds it one
# StopFailure payload on stdin, and asserts the verdict word the hook wrote to
# its log. Verdict words are the hook's contract:
#
#   RETRY  resume scheduled (runner spawned)
#   SKIP   classified as not worth resuming
#   CAP    per-session retry cap reached
#   DUP    a runner for this session is already waiting
#   ERROR  runner missing / not executable, nothing scheduled
#
# Nothing here touches the real ~/.claude — HOME is redirected per case.
#
# Run:  bash scripts/tests/test_auto_resume_classify.sh
#
# To prove a case really discriminates, point it at another copy of the hook:
#       AUTO_RESUME_HOOK=/path/to/other.sh bash scripts/tests/test_auto_resume_classify.sh
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOOK="${AUTO_RESUME_HOOK:-$ROOT/hooks/api-error-auto-resume.sh}"
[ -r "$HOOK" ] || { echo "FAIL: hook not readable: $HOOK"; exit 1; }

LOG_REL=".claude/logs/api-error-auto-resume.log"
PASS=0; FAIL=0
ok(){ printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }
no(){ printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }

# Throwaway HOME carrying a stub runner. The hook refuses to schedule (and to
# log RETRY) when it cannot find an executable runner, so the stub stands in for
# scripts/api-error-resume-runner.sh and records the session id it was handed.
make_home() {
  local t
  t=$(mktemp -d) || return 1
  mkdir -p "$t/.claude/scripts"
  cat > "$t/.claude/scripts/api-error-resume-runner.sh" <<'STUB'
#!/bin/bash
printf '%s\n' "$1" > "$HOME/runner-session-id"
STUB
  chmod +x "$t/.claude/scripts/api-error-resume-runner.sh"
  printf '%s' "$t"
}

SETUP_FN=""      # optional function, called with the temp HOME before the run
HOOK_ENV=()      # optional extra env assignments for the next check

check() { # <name> <expected verdict word | -none-> <payload> [transcript json line]
  local name="$1" want="$2" payload="$3" tline="${4:-}"
  local T
  T=$(make_home) || { no "$name (mktemp failed)"; return; }
  [ -n "$SETUP_FN" ] && "$SETUP_FN" "$T"
  if [ -n "$tline" ]; then
    printf '%s\n' "$tline" > "$T/transcript.jsonl"
    payload="${payload//__TRANSCRIPT__/$T/transcript.jsonl}"
  fi
  printf '%s' "$payload" \
    | env HOME="$T" CLAUDE_AUTO_RESUME_DRY_RUN=1 ${HOOK_ENV[@]+"${HOOK_ENV[@]}"} \
      bash "$HOOK" >/dev/null 2>&1
  local log="$T/$LOG_REL" got=""
  [ -f "$log" ] && got=$(grep -oE '\[hook\] [A-Z]+' "$log" | tail -1 | awk '{print $2}')
  if [ "$want" = "-none-" ]; then
    if [ ! -s "$log" ]; then ok "$name"; else no "$name (want no verdict, got '${got:-?}')"; fi
  elif [ "$got" = "$want" ]; then
    ok "$name"
  else
    no "$name (want $want, got '${got:-no log}')"
    [ -f "$log" ] && sed 's/^/         /' "$log" | tail -2
  fi
  SETUP_FN=""; HOOK_ENV=()
  rm -rf "$T"
}

seed_cap()      { mkdir -p "$1/.claude/cache/auto-resume/counts"; echo 3 > "$1/.claude/cache/auto-resume/counts/cap1.count"; }
# A session at the cap, whose counter was last touched 100s ago. Whether the
# next event is CAP or RETRY then depends purely on the progress-aware reset.
seed_capped_at() {
  local home="$1" cf="$1/.claude/cache/auto-resume/counts/$2.count"
  mkdir -p "$home/.claude/cache/auto-resume/counts"
  echo 3 > "$cf"
  python3 -c 'import os,sys,time; t=time.time()-100; os.utime(sys.argv[1],(t,t))' "$cf"
}
seed_capped_progress() { seed_capped_at "$1" prog1; }
seed_capped_noprogress() { seed_capped_at "$1" prog2; }
seed_lock()     { mkdir -p "$1/.claude/cache/auto-resume/locks/dup1.lock"; }
seed_disabled() { mkdir -p "$1/.claude/cache/auto-resume"; : > "$1/.claude/cache/auto-resume/DISABLED"; }
drop_runner()   { rm -f "$1/.claude/scripts/api-error-resume-runner.sh"; }

echo "hook: $HOOK"
echo "-- retryable (server-side / transient) --"
check "error_type=overloaded"          RETRY '{"session_id":"s1","error_type":"overloaded","error":"Overloaded"}'
check "stop_reason=internal_error"     RETRY '{"session_id":"s2","stop_reason":"internal_error"}'
check "connection_error"               RETRY '{"session_id":"s3","error_type":"connection_error"}'
check "server-side rate limit"         RETRY '{"session_id":"s4","error_type":"rate_limit","error":"Server is temporarily limiting requests (not your usage limit). Retry in 156s."}'
check "stalled mid-stream (no etype)"  RETRY '{"session_id":"s5","error":"API Error: Response stalled mid-stream"}'
check "transcript api_error 529"       RETRY '{"session_id":"s6","transcript_path":"__TRANSCRIPT__"}' \
  '{"type":"assistant","isApiErrorMessage":true,"timestamp":"2026-08-19T00:00:00Z","error":{"status":529,"message":"Overloaded"}}'
check "transcript synthetic overloaded" RETRY '{"session_id":"s7","transcript_path":"__TRANSCRIPT__"}' \
  '{"type":"assistant","subtype":"api_error","isApiErrorMessage":true,"timestamp":"2026-08-19T00:00:00Z","error":"overloaded"}'

echo "-- not retryable --"
check "billing_error"                  SKIP '{"session_id":"f1","error_type":"billing_error","error":"billing"}'
check "authentication_failed"          SKIP '{"session_id":"f2","error_type":"authentication_failed","error":"auth"}'
check "context_window_exceeded"        SKIP '{"session_id":"f3","error_type":"context_window_exceeded"}'
check "plain rate_limit (usage)"       SKIP '{"session_id":"f4","error_type":"rate_limit","error":"API Error: 429 rate_limit"}'
check "transcript 429 no signal"       SKIP '{"session_id":"f5","transcript_path":"__TRANSCRIPT__"}' \
  '{"type":"assistant","isApiErrorMessage":true,"timestamp":"2026-08-19T00:00:00Z","error":{"status":429,"message":"rate limit"}}'
check "inconclusive payload"           SKIP '{"session_id":"f6","stop_reason":"error","error":"something odd"}'
check "no session_id"                  SKIP '{"error_type":"overloaded"}'
# Account-rotation phrases are proxy-specific and were cut on port: a pool that
# reports "all accounts exhausted" is not a signal this distribution knows how
# to read, so it falls back to the conservative usage-limit verdict.
check "accounts exhausted -> not a signal" SKIP \
  '{"session_id":"f7","error_type":"rate_limit","error":"429 All 11 accounts exhausted."}'

echo "-- guards --"
# Note: SETUP_FN / HOOK_ENV are set on their own line, not as a command prefix —
# an array assignment cannot be a prefix, and it would silently reach check()
# empty (the whole guard would then be untested).
SETUP_FN=seed_cap
check "per-session cap reached"  CAP   '{"session_id":"cap1","error_type":"overloaded"}'
SETUP_FN=seed_lock
check "duplicate fire deduped"   DUP   '{"session_id":"dup1","error_type":"overloaded"}'
SETUP_FN=drop_runner
check "runner missing"           ERROR '{"session_id":"nr1","error_type":"overloaded"}'
SETUP_FN=seed_disabled
check "DISABLED file"          -none-  '{"session_id":"k1","error_type":"overloaded"}'
HOOK_ENV=(CLAUDE_AUTO_RESUME_DISABLED=1)
check "DISABLED env var"       -none-  '{"session_id":"k2","error_type":"overloaded"}'

# Progress-aware cap reset. Both cases start at the cap (3/3) with the counter
# stamped 100s ago; the only difference is what the transcript recorded since.
# A real assistant turn zeroes the counter (an overnight run that keeps
# recovering is never cut off); an api-error record -- which is all a fruitless
# resume leaves behind -- must not.
RECENT_TS=$(python3 -c 'import datetime;print((datetime.datetime.now(datetime.timezone.utc)-datetime.timedelta(seconds=10)).strftime("%Y-%m-%dT%H:%M:%SZ"))')
SETUP_FN=seed_capped_progress
check "cap reset when the session progressed" RETRY \
  '{"session_id":"prog1","error_type":"overloaded","transcript_path":"__TRANSCRIPT__"}' \
  "{\"type\":\"assistant\",\"timestamp\":\"$RECENT_TS\",\"message\":{\"role\":\"assistant\"}}"
SETUP_FN=seed_capped_noprogress
check "cap holds when only errors followed" CAP \
  '{"session_id":"prog2","error_type":"overloaded","transcript_path":"__TRANSCRIPT__"}' \
  "{\"type\":\"assistant\",\"isApiErrorMessage\":true,\"timestamp\":\"$RECENT_TS\",\"error\":{\"status\":529}}"

echo "-- handoff --"
T=$(make_home)
if [ -n "$T" ]; then
  printf '%s' '{"session_id":"handoff-1","error_type":"overloaded","cwd":"/tmp"}' \
    | env HOME="$T" CLAUDE_AUTO_RESUME_DRY_RUN=1 bash "$HOOK" >/dev/null 2>&1
  for _ in 1 2 3 4 5 6 7 8 9 10; do [ -s "$T/runner-session-id" ] && break; sleep 0.2; done
  if [ "$(cat "$T/runner-session-id" 2>/dev/null)" = "handoff-1" ]; then
    ok "runner is spawned with the session id"
  else
    no "runner is spawned with the session id"
  fi
  rm -rf "$T"
fi

echo "PASS=$PASS FAIL=$FAIL"; exit $((FAIL > 0))
