#!/bin/bash
# api-error-auto-resume.sh — StopFailure hook. When a session dies on a
#     retryable API error (529 overload, 5xx, dropped stream), schedule an
#     unattended resume a couple of minutes later.
#
# Event:  StopFailure — fires after Claude Code's own retries are exhausted.
# Blocks: no. StopFailure output cannot steer control flow, so this hook is
#         informational and does its real work in a detached runner.
# Action: classify the failure, then (if every guard passes) detach-spawn
#         scripts/api-error-resume-runner.sh, which waits and resumes.
#
# Analogy: the caretaker who waits two minutes after a blackout, flips the
# breaker back on, and says "carry on where you left off". Unpaid bills and
# lost keys are left alone, and the breaker is never flipped more than a few
# times in a row.
#
# Retryable:     overloaded / internal_error / connection / timeout errors,
#                HTTP 408·5xx·529, a stream that stalled mid-response, and rate
#                limits the server marks as its own ("not your usage limit").
# Not retryable: billing, authentication, context window, invalid request,
#                permission, and your own plan usage limit.
#
# Fork-bomb guards (a global outage means every session fires at once):
#   1) per-session cap — 3 resumes per rolling 6h (CLAUDE_AUTO_RESUME_MAX_RETRIES),
#      reset when the session actually made progress after the last resume
#   2) per-session lock — the runner holds an mkdir lock, so a duplicate fire of
#      the same StopFailure is dropped without burning a cap slot
#   3) global stagger — the runner serializes real resumes 20s apart
#
# Environment (full table: rules/api-error-recovery.md):
#   CLAUDE_AUTO_RESUME_DISABLED=1         kill switch (so is the DISABLED file below)
#   CLAUDE_AUTO_RESUME_DELAY=120          seconds to wait before resuming
#   CLAUDE_AUTO_RESUME_MAX_RETRIES=3      per-session resumes per 6h
#   CLAUDE_AUTO_RESUME_RETRY_RATELIMIT=1  also retry plain rate_limit (off by default)
#   CLAUDE_AUTO_RESUME_DRY_RUN=1          runner logs its decision and resumes nothing
#
# Log:   ~/.claude/logs/api-error-auto-resume.log
#        Verdict words: RETRY (scheduled) / SKIP (left alone) / CAP / DUP / ERROR.
# State: ~/.claude/cache/auto-resume/{counts,locks,runs}
# Kill:  touch ~/.claude/cache/auto-resume/DISABLED
#
# Platform: developed and tested on macOS. Linux notes in rules/api-error-recovery.md.

set -uo pipefail

BASE="$HOME/.claude/cache/auto-resume"
LOG_DIR="$HOME/.claude/logs"
LOG="$LOG_DIR/api-error-auto-resume.log"
RUNNER="$HOME/.claude/scripts/api-error-resume-runner.sh"

mkdir -p "$BASE/counts" "$BASE/locks" "$BASE/runs" "$LOG_DIR" 2>/dev/null

log() { echo "[$(date '+%F %T')] [hook] $*" >> "$LOG" 2>/dev/null; }

# stat(1) is not portable: BSD/macOS takes -f, GNU/Linux takes -c.
#
# Branch on the OUTPUT, never on the exit status. On GNU coreutils `-f` means
# --file-system, where %m is not a valid directive: it can be reported as "?"
# with rc=0, so a status-only fallback would never reach the -c form and the
# caller would silently receive 0 — which is exactly the failure this helper
# exists to prevent (a 0 mtime makes the cap window dead and every lock stale).
# Accept a form only once its output is a plain integer.
_mtime() {
    local v
    v=$(stat -f %m "$1" 2>/dev/null); [[ "$v" =~ ^[0-9]+$ ]] && { printf '%s' "$v"; return; }
    v=$(stat -c %Y "$1" 2>/dev/null); [[ "$v" =~ ^[0-9]+$ ]] && { printf '%s' "$v"; return; }
    printf '0'
}
_fsize() {
    local v
    v=$(stat -f %z "$1" 2>/dev/null); [[ "$v" =~ ^[0-9]+$ ]] && { printf '%s' "$v"; return; }
    v=$(stat -c %s "$1" 2>/dev/null); [[ "$v" =~ ^[0-9]+$ ]] && { printf '%s' "$v"; return; }
    printf '0'
}

# ── Kill switch ───────────────────────────────────────────
if [[ "${CLAUDE_AUTO_RESUME_DISABLED:-0}" == "1" || -f "$BASE/DISABLED" ]]; then
    exit 0
fi

# A resume this hook spawned can fail again and re-enter here. That is allowed —
# the counters below are what bounds the recursion.
INPUT=$(cat)

# ── Log rotation (over 1MB, keep the last 256KB; temp name is PID-scoped) ──
if [[ -f "$LOG" ]]; then
    _size=$(_fsize "$LOG")
    if (( _size > 1048576 )); then
        tail -c 262144 "$LOG" > "$LOG.tmp.$$" 2>/dev/null && mv "$LOG.tmp.$$" "$LOG" 2>/dev/null
        rm -f "$LOG.tmp.$$" 2>/dev/null
    fi
fi

# ── Classification (python3): trust the stdin payload first, and fall back to
#    scanning the tail of the transcript when the payload is inconclusive ──
VERDICT_LINE=$(printf '%s' "$INPUT" | python3 -c '
import sys, json, os, re

raw = sys.stdin.read()
try:
    data = json.loads(raw) if raw.strip() else {}
except Exception:
    data = {}

session_id = str(data.get("session_id") or "")
transcript = str(data.get("transcript_path") or "")
cwd = str(data.get("cwd") or os.environ.get("PWD", ""))
if not session_id and transcript:
    b = os.path.basename(transcript)
    session_id = b[:-6] if b.endswith(".jsonl") else b

RETRYABLE = {"overloaded", "internal_error", "api_error", "server_error",
             "connection_error", "timeout", "network_error"}
FATAL = {"billing_error", "authentication_failed", "context_window_exceeded",
         "invalid_request", "permission_error"}
RETRY_STATUS = {408, 500, 502, 503, 504, 522, 524, 529}

etype = str(data.get("stop_reason") or data.get("error_type") or "").strip()
emsg = str(data.get("error") or data.get("message") or "")
data_text = json.dumps(data, ensure_ascii=False) if data else ""


def server_side(text):
    # Phrases by which the server says the throttle is its own, not your plan
    # usage. Only these two: an unqualified 429 stays a SKIP, because resuming
    # into your own exhausted usage limit only burns it faster.
    t = (text or "").lower()
    return ("not your usage limit" in t
            or "temporarily limiting requests" in t)


def stalled(text):
    # "API Error: Response stalled mid-stream" — the upstream stream was cut
    # part-way through a response. Transient and network-shaped, so it is judged
    # on the text regardless of how the error field is structured (some of these
    # arrive with no error_type at all, and were being dropped as inconclusive).
    t = (text or "").lower()
    return "stalled mid-stream" in t or "response stalled" in t


def parse_retry(text):
    t = (text or "").lower()
    m = re.search(r"retry in\s+(\d+)\s*m[^0-9]*(\d+)\s*s", t)
    if m:
        return int(m.group(1)) * 60 + int(m.group(2))
    m = re.search(r"retry in\s+(\d+)\s*s", t)
    if m:
        return int(m.group(1))
    m = re.search(r"retry in\s+(\d+)\s*m", t)
    if m:
        return int(m.group(1)) * 60
    return 0


retry_in = parse_retry(emsg) or parse_retry(data_text)

verdict = None
reason = ""

if etype in FATAL:
    verdict, reason = False, "fatal error_type=" + etype
elif etype in RETRYABLE:
    verdict, reason = True, "error_type=" + etype
elif etype == "rate_limit":
    if server_side(emsg) or server_side(data_text):
        verdict, reason = True, "server-side rate limit"
    elif os.environ.get("CLAUDE_AUTO_RESUME_RETRY_RATELIMIT") == "1":
        verdict, reason = True, "rate_limit (RETRY_RATELIMIT flag)"
    else:
        verdict, reason = False, "rate_limit (usage limit suspected)"

if verdict is None and (stalled(emsg) or stalled(data_text)):
    verdict, reason = True, "stalled mid-stream (transient)"

# Transcript tail as the authoritative record: last 256KB, newest 200 records.
# A naive "grep 529" over the file would false-positive on base64 payloads.
if verdict is None and transcript and os.path.isfile(transcript):
    try:
        with open(transcript, "rb") as f:
            f.seek(0, 2)
            size = f.tell()
            f.seek(max(0, size - 262144))
            tail = f.read().decode("utf-8", "replace").splitlines()
        for line in reversed(tail[-200:]):
            if "\"subtype\":\"api_error\"" not in line and "\"isApiErrorMessage\":true" not in line:
                continue
            try:
                rec = json.loads(line)
            except Exception:
                continue
            rec_text = json.dumps(rec, ensure_ascii=False)
            if not retry_in:
                retry_in = parse_retry(rec_text)
            if stalled(rec_text):
                verdict, reason = True, "transcript stalled mid-stream (transient)"
                break
            err = rec.get("error")
            if isinstance(err, dict):
                status = err.get("status")
                msg = str(err.get("message", "")).lower()
                if status in RETRY_STATUS or "overloaded" in msg or err.get("isNetworkDown"):
                    verdict, reason = True, "transcript api_error status=%s" % status
                elif status == 429:
                    if server_side(rec_text):
                        verdict, reason = True, "transcript 429 server-side"
                    else:
                        verdict, reason = False, "transcript 429 usage limit suspected"
                else:
                    verdict, reason = False, "transcript api_error status=%s not retryable" % status
            elif isinstance(err, str):
                if err in ("overloaded", "server_error", "internal_error", "api_error"):
                    verdict, reason = True, "synthetic " + err
                elif err == "rate_limit":
                    if server_side(rec_text):
                        verdict, reason = True, "synthetic server-side rate limit"
                    elif os.environ.get("CLAUDE_AUTO_RESUME_RETRY_RATELIMIT") == "1":
                        verdict, reason = True, "synthetic rate_limit (RETRY_RATELIMIT flag)"
                    else:
                        verdict, reason = False, "synthetic rate_limit (usage suspected)"
                else:
                    verdict, reason = False, "synthetic error=" + err
            break
    except Exception:
        pass

if verdict is None:
    verdict, reason = False, "inconclusive (etype=%s)" % (etype or "none")
if not session_id:
    verdict, reason = False, "no session_id"

# Tab-separated output. bash IFS collapses runs of tabs, so empty fields are
# carried as a "-" placeholder instead of vanishing.
def _f(s):
    s = s.replace("\t", " ").replace("\n", " ").strip()
    return s if s else "-"

sys.stdout.write("\t".join([
    "RETRY" if verdict else "SKIP",
    _f(session_id),
    _f(cwd),
    _f(reason),
    str(retry_in if retry_in else 0),
    _f(transcript),
]))
' 2>/dev/null)

IFS=$'\t' read -r ACTION SESSION_ID CWD REASON RETRY_IN TRANSCRIPT <<< "${VERDICT_LINE:-$(printf 'SKIP\t-\t-\tparse-failed\t0\t-')}"
[[ "$CWD" == "-" ]] && CWD=""
[[ "$SESSION_ID" == "-" ]] && SESSION_ID=""
[[ "$TRANSCRIPT" == "-" ]] && TRANSCRIPT=""
[[ "$RETRY_IN" =~ ^[0-9]+$ ]] || RETRY_IN=0

if [[ "$ACTION" != "RETRY" ]]; then
    log "SKIP session=${SESSION_ID:-?} reason=${REASON:-?}"
    exit 0
fi

# ── Duplicate-fire dedup: if a runner for this session is already waiting, drop
#    this one without spending a cap slot. StopFailure has been observed firing
#    twice within seconds for a single failure. ──
if [[ -d "$BASE/locks/${SESSION_ID}.lock" ]]; then
    log "DUP session=$SESSION_ID — runner already waiting, duplicate fire dropped (no cap spent)"
    exit 0
fi

# ── Guard 1: per-session retry cap (3 per rolling 6h) ─────
# The counter is incremented by the runner once it holds the lock, not here, so
# a duplicate fire cannot consume two slots.
MAX="${CLAUDE_AUTO_RESUME_MAX_RETRIES:-3}"
[[ "$MAX" =~ ^[0-9]+$ ]] || MAX=3
WINDOW=21600
CF="$BASE/counts/${SESSION_ID}.count"

# ── Progress-aware cap reset: if the session actually moved forward after the
#    last resume, zero the counter. So the cap really means "3 resumes in a row
#    that achieved nothing" — an overnight run that keeps recovering normally is
#    never cut off, while a resume loop that re-fails without progress still is.
if [[ -n "$TRANSCRIPT" && -f "$CF" && -f "$TRANSCRIPT" ]]; then
    _cfmt=$(_mtime "$CF")
    _progressed=$(python3 - "$TRANSCRIPT" "$_cfmt" <<'PYPROG' 2>/dev/null
import sys, json, os, datetime
path = sys.argv[1]
try:
    cfmt = float(sys.argv[2] or 0)
except Exception:
    cfmt = 0.0
out = "NO"
try:
    fmt = os.path.getmtime(path)
except Exception:
    fmt = 0
if cfmt > 0 and fmt > cfmt + 2:
    # Read the last 512KB only — this hook runs under an 8s timeout and must not
    # read a large transcript in full.
    with open(path, "rb") as f:
        f.seek(0, 2)
        size = f.tell()
        f.seek(max(0, size - 524288))
        lines = f.read().decode("utf-8", "replace").splitlines()
    for line in reversed(lines[-500:]):
        try:
            rec = json.loads(line)
        except Exception:
            continue
        ts = rec.get("timestamp")
        if not ts:
            continue
        try:
            ep = datetime.datetime.fromisoformat(str(ts).replace("Z", "+00:00")).timestamp()
        except Exception:
            continue
        if ep <= cfmt:
            break
        if rec.get("isApiErrorMessage"):
            continue
        if rec.get("type") in ("assistant", "user", "tool_result"):
            out = "YES"
            break
print(out)
PYPROG
)
    if [[ "$_progressed" == "YES" ]]; then
        echo 0 > "$CF" 2>/dev/null
        log "progress-aware cap reset: session moved forward after the last resume (session=$SESSION_ID)"
    fi
fi

now=$(date +%s)
count=0
if [[ -f "$CF" ]]; then
    mtime=$(_mtime "$CF")
    if (( now - mtime < WINDOW )); then
        count=$(cat "$CF" 2>/dev/null | tr -cd '0-9')
        [[ -n "$count" ]] || count=0
    fi
fi
if (( count >= MAX )); then
    log "CAP session=$SESSION_ID used=$count/$MAX — per-session resume cap reached, skipping"
    exit 0
fi

# ── Find the ancestor claude process (the runner uses it to tell whether the
#    original session is still alive, and whether it sits in a tmux pane) ──
CLAUDE_PID=""
_pid=$$
_i=0
while (( _i < 12 )); do
    _ppid=$(ps -o ppid= -p "$_pid" 2>/dev/null | tr -d ' ')
    [[ -z "$_ppid" || "$_ppid" == "0" || "$_ppid" == "1" ]] && break
    _cmd=$(ps -o command= -p "$_ppid" 2>/dev/null)
    if [[ "$_cmd" =~ (^|[/\ ])claude([\ ]|$) ]]; then
        CLAUDE_PID="$_ppid"
        break
    fi
    _pid="$_ppid"
    _i=$(( _i + 1 ))
done

# ── Sweep stale cache entries (7 days+) ───────────────────
find "$BASE/counts" "$BASE/runs" -type f -mtime +7 -delete >/dev/null 2>&1 &

# ── Detach-spawn the runner ───────────────────────────────
if [[ ! -x "$RUNNER" ]]; then
    log "ERROR runner missing or not executable: $RUNNER — nothing scheduled"
    exit 0
fi

log "RETRY scheduled session=$SESSION_ID reason=$REASON used=$count/$MAX pid=${CLAUDE_PID:-?} cwd=$CWD retry_in=${RETRY_IN}s delay=${CLAUDE_AUTO_RESUME_DELAY:-120}s"
nohup "$RUNNER" "$SESSION_ID" "$CWD" "$CLAUDE_PID" "$RETRY_IN" "$TRANSCRIPT" >/dev/null 2>&1 &

exit 0
