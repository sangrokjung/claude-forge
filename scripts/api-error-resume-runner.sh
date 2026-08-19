#!/bin/bash
# api-error-resume-runner.sh — delayed resume runner, detach-spawned by the
#     StopFailure hook (hooks/api-error-auto-resume.sh). Waits (2 minutes by
#     default, longer if the server told us when to retry) and then resumes the
#     session that died.
#
# Usage: api-error-resume-runner.sh <session_id> <cwd> [claude_pid] [retry_in] [transcript]
#
# Resume path, chosen from the state of the original session process:
#   - process is dead (headless -p run, or the session already exited)
#       -> claude --resume <session_id> -p "<continue instruction>"
#   - process is alive inside a tmux pane
#       -> tmux send-keys types the instruction into the live REPL
#   - process is alive but not in tmux (an ordinary terminal tab)
#       -> TAKEOVER (on by default): only after a two-factor idle check, end the
#          original process gracefully and headless-resume the same session id.
#          Cancelled the moment the session looks like it is still working.
#
# Guards: per-session mkdir lock (no double booking) + 20s global stagger (no
#     stampede when every session fails at once) + the runaway caps below
#     (concurrency, hourly/daily totals, and self-disable after repeated resumes
#     that achieve nothing).
#
# Notifications are optional and pluggable — see notify() below.
# Environment variables are inherited from the hook; the full table lives in
# rules/api-error-recovery.md.
#
# Platform: developed and tested on macOS. Linux notes in rules/api-error-recovery.md.

set -uo pipefail

SESSION_ID="${1:?session_id required}"
CWD="${2:-$HOME}"
CLAUDE_PID="${3:-}"
RETRY_IN="${4:-0}"
[[ "$RETRY_IN" =~ ^[0-9]+$ ]] || RETRY_IN=0
TRANSCRIPT="${5:-}"

umask 077   # run logs contain the resumed session's full output — keep them 600

DELAY="${CLAUDE_AUTO_RESUME_DELAY:-120}"
[[ "$DELAY" =~ ^[0-9]+$ ]] || DELAY=120
DRY="${CLAUDE_AUTO_RESUME_DRY_RUN:-0}"
MAXRT="${CLAUDE_AUTO_RESUME_MAX_RUNTIME:-7200}"
[[ "$MAXRT" =~ ^[0-9]+$ ]] || MAXRT=7200
TAKEOVER="${CLAUDE_AUTO_RESUME_TAKEOVER:-1}"

# ── Dynamic wait: when the server says "Retry in Ns", wait until then plus a
#    buffer, so Claude Code gets its own chance to recover before we step in ──
RETRY_BUFFER="${CLAUDE_AUTO_RESUME_RETRY_BUFFER:-30}"
[[ "$RETRY_BUFFER" =~ ^[0-9]+$ ]] || RETRY_BUFFER=30
MAX_DELAY="${CLAUDE_AUTO_RESUME_MAX_DELAY:-900}"
[[ "$MAX_DELAY" =~ ^[0-9]+$ ]] || MAX_DELAY=900
EFF_DELAY="$DELAY"
if (( RETRY_IN > 0 )); then
    _want=$(( RETRY_IN + RETRY_BUFFER ))
    (( _want > EFF_DELAY )) && EFF_DELAY="$_want"
fi
(( EFF_DELAY > MAX_DELAY )) && EFF_DELAY="$MAX_DELAY"

BASE="$HOME/.claude/cache/auto-resume"
LOG="$HOME/.claude/logs/api-error-auto-resume.log"
# counts/ belongs in this list even though the hook normally creates it first:
# the runner writes the per-session cap counter itself, and that write fails
# silently (output is discarded) if the directory is not there — which would
# leave the cap permanently at zero.
mkdir -p "$BASE/counts" "$BASE/locks" "$BASE/runs" "$HOME/.claude/logs" 2>/dev/null

log() { echo "[$(date '+%F %T')] [runner:${SESSION_ID:0:8}] $*" >> "$LOG" 2>/dev/null; }

# Pluggable notification: set FORGE_NOTIFY_CMD to any command taking
# "<title>" "<message>" (e.g. a curl wrapper). Unset = silent no-op.
# It must be a single executable path — arguments belong inside that script, so
# nothing here word-splits or evaluates user text.
notify() {
    [ -n "${FORGE_NOTIFY_CMD:-}" ] || return 0
    "$FORGE_NOTIFY_CMD" "$1" "$2" 2>/dev/null || true
}

# stat(1) is not portable: BSD/macOS takes -f, GNU/Linux takes -c.
#
# Branch on the OUTPUT, never on the exit status. On GNU coreutils `-f` means
# --file-system, where %m is not a valid directive: it can be reported as "?"
# with rc=0, so a status-only fallback would never reach the -c form and the
# caller would silently receive 0 — which would make every lock look stale and
# leave the takeover idle gate permanently open. Accept a form only once its
# output is a plain integer.
_mtime() {
    local v
    v=$(stat -f %m "$1" 2>/dev/null); [[ "$v" =~ ^[0-9]+$ ]] && { printf '%s' "$v"; return; }
    v=$(stat -c %Y "$1" 2>/dev/null); [[ "$v" =~ ^[0-9]+$ ]] && { printf '%s' "$v"; return; }
    printf '0'
}

# ══ RUNAWAY GUARD ════════════════════════════════════════════════════════════
# The hook's progress-aware cap reset can mistake a resume's own footprint for
# progress and zero the counter, which would defeat the cap. So the runner keeps
# an independent ledger of its own and enforces these caps regardless.
GUARD_NOPROGRESS_MAX="${CLAUDE_AUTO_RESUME_NOPROGRESS_MAX:-2}"   # resumes in a row that achieved nothing -> self-disable
GUARD_MAX_CONCURRENT="${CLAUDE_AUTO_RESUME_MAX_CONCURRENT:-6}"   # runners running at once
GUARD_HOURLY_MAX="${CLAUDE_AUTO_RESUME_HOURLY_MAX:-24}"          # resumes across all sessions per 1h
GUARD_DAILY_MAX="${CLAUDE_AUTO_RESUME_DAILY_MAX:-80}"            # resumes across all sessions per 24h
GUARD_RETRY_429="${CLAUDE_AUTO_RESUME_RETRY_429:-0}"             # 1 = resume even after a 429 (not recommended)
[[ "$GUARD_NOPROGRESS_MAX" =~ ^[0-9]+$ ]] || GUARD_NOPROGRESS_MAX=2
[[ "$GUARD_MAX_CONCURRENT" =~ ^[0-9]+$ ]] || GUARD_MAX_CONCURRENT=6
[[ "$GUARD_HOURLY_MAX"     =~ ^[0-9]+$ ]] || GUARD_HOURLY_MAX=24
[[ "$GUARD_DAILY_MAX"      =~ ^[0-9]+$ ]] || GUARD_DAILY_MAX=80

GUARD_RUNDIR="$BASE/running"
GUARD_LEDGER="$BASE/global.ledger"
GUARD_STREAKDIR="$BASE/streak"
mkdir -p "$GUARD_RUNDIR" "$GUARD_STREAKDIR" 2>/dev/null

# Self kill switch — hook and runner both stop on the presence of $BASE/DISABLED,
# so there is a single place to pull the plug.
_guard_disable_all() {
    printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$BASE/DISABLED" 2>/dev/null
    log "SELF-DISABLE: $* — automatic resume is now off everywhere. Re-enable: rm $BASE/DISABLED"
    notify "Auto-resume disabled" "Runaway guard tripped: $*"
}

_guard_register_pid() { : > "$GUARD_RUNDIR/$$" 2>/dev/null; }
_guard_cleanup()      { rmdir "$LOCK" 2>/dev/null; rm -f "$GUARD_RUNDIR/$$" 2>/dev/null; }
_guard_ledger_add() {
    printf '%s %s\n' "$(date +%s)" "${SESSION_ID:0:8}" >> "$GUARD_LEDGER" 2>/dev/null
    tail -n 400 "$GUARD_LEDGER" > "$GUARD_LEDGER.tmp.$$" 2>/dev/null \
        && mv "$GUARD_LEDGER.tmp.$$" "$GUARD_LEDGER" 2>/dev/null
    rm -f "$GUARD_LEDGER.tmp.$$" 2>/dev/null
}

# ── Cap 1: a 429 / usage limit stops us outright ───────────────────────────
# A 429 is the server saying "stop sending". Resuming into it only adds load,
# and a rate-limit loop is exactly what turns automatic resume into a fork bomb.
# Override with CLAUDE_AUTO_RESUME_RETRY_429=1 if you really want it.
_guard_429_state="none"
_guard_check_429() {
    local phase="$1" v
    if [[ "$GUARD_RETRY_429" == "1" ]]; then _guard_429_state="bypassed"; return 0; fi
    if [[ -z "$TRANSCRIPT" || ! -f "$TRANSCRIPT" ]]; then _guard_429_state="no-transcript"; return 0; fi
    v=$(python3 - "$TRANSCRIPT" <<'PY429' 2>/dev/null
import sys, json, re
RATE = re.compile(r"(rate[ _-]?limit|429|usage limit|retry in)", re.I)
try:
    with open(sys.argv[1], "rb") as f:
        f.seek(0, 2); size = f.tell(); f.seek(max(0, size - 262144))
        lines = f.read().decode("utf-8", "replace").splitlines()
except Exception:
    lines = []
out = "OTHER"
for line in reversed(lines[-200:]):
    if '"isApiErrorMessage":true' not in line and '"subtype":"api_error"' not in line:
        continue
    try:
        rec = json.loads(line)
    except Exception:
        continue
    err = rec.get("error")
    status = err.get("status") if isinstance(err, dict) else None
    if status == 429 or RATE.search(json.dumps(rec, ensure_ascii=False)):
        out = "RATE"
    break
print(out)
PY429
)
    if [[ "$v" == "RATE" ]]; then
        _guard_429_state="rate-limit"
        log "GUARD-429($phase): last API error was a 429 / usage limit — resuming would only add load. Stopping."
        exit 0
    fi
    _guard_429_state="ok"
}
_guard_check_429 "pre"

# ── Cap 2: how many runners are already going ─────────────────────────────
_guard_live=0
for _p in "$GUARD_RUNDIR"/*; do
    [[ -e "$_p" ]] || continue
    _pid="${_p##*/}"
    if [[ "$_pid" =~ ^[0-9]+$ ]] && kill -0 "$_pid" 2>/dev/null; then
        _guard_live=$(( _guard_live + 1 ))
    else
        rm -f "$_p" 2>/dev/null   # sweep the trace of a runner that is gone
    fi
done
if (( _guard_live >= GUARD_MAX_CONCURRENT )); then
    log "GUARD-CONCURRENCY: ${_guard_live} runners already going (limit $GUARD_MAX_CONCURRENT) — skipping this resume"
    exit 0
fi

# ── Cap 3: hourly / daily totals across every session ─────────────────────
_guard_now=$(date +%s); _guard_h=0; _guard_d=0
if [[ -f "$GUARD_LEDGER" ]]; then
    while read -r _ts _rest; do
        [[ "$_ts" =~ ^[0-9]+$ ]] || continue
        (( _guard_now - _ts < 3600 ))  && _guard_h=$(( _guard_h + 1 ))
        (( _guard_now - _ts < 86400 )) && _guard_d=$(( _guard_d + 1 ))
    done < <(tail -n 400 "$GUARD_LEDGER" 2>/dev/null)
fi
if (( _guard_h >= GUARD_HOURLY_MAX )); then
    log "GUARD-RATE: ${_guard_h} resumes in the last hour (limit $GUARD_HOURLY_MAX) — skipping"
    exit 0
fi
if (( _guard_d >= GUARD_DAILY_MAX )); then
    log "GUARD-RATE: ${_guard_d} resumes in the last 24h (limit $GUARD_DAILY_MAX) — skipping"
    exit 0
fi

# ── Cap 4: record whether this resume achieved anything (called after it ends) ──
# Progress means "an assistant turn that is not an error appeared after we
# resumed". The prompt the resume itself injected is not progress — that is the
# exact hole this closes in the hook's own cap reset.
_guard_record_outcome() {
    local t0="$1" rc="$2" runlog="$3"
    local sf="$GUARD_STREAKDIR/${SESSION_ID}.streak"
    local streak progressed="NO"
    streak=$(cat "$sf" 2>/dev/null | tr -cd '0-9'); [[ -n "$streak" ]] || streak=0
    if [[ -n "$TRANSCRIPT" && -f "$TRANSCRIPT" ]]; then
        progressed=$(python3 - "$TRANSCRIPT" "$t0" <<'PYOUT' 2>/dev/null
import sys, json, datetime
path = sys.argv[1]
try:
    t0 = float(sys.argv[2] or 0)
except Exception:
    t0 = 0.0
try:
    with open(path, "rb") as f:
        f.seek(0, 2); size = f.tell(); f.seek(max(0, size - 524288))
        lines = f.read().decode("utf-8", "replace").splitlines()
except Exception:
    lines = []
out = "NO"
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
    if ep <= t0:
        break
    if rec.get("isApiErrorMessage"):
        continue
    if rec.get("type") == "assistant":   # an injected user prompt is not progress
        out = "YES"
        break
print(out)
PYOUT
)
    else
        if [[ "$rc" == "0" && -s "$runlog" ]] \
           && ! grep -qiE "API Error|overloaded|rate.?limit" "$runlog" 2>/dev/null; then
            progressed="YES"
        fi
    fi
    [[ "$progressed" == "YES" || "$progressed" == "NO" ]] || progressed="NO"
    if [[ "$progressed" == "YES" ]]; then
        echo 0 > "$sf" 2>/dev/null
        log "OUTCOME: progress confirmed — no-progress streak reset to 0"
    else
        streak=$(( streak + 1 ))
        echo "$streak" > "$sf" 2>/dev/null
        log "OUTCOME: resume achieved nothing — streak=${streak}/${GUARD_NOPROGRESS_MAX}"
        if (( streak >= GUARD_NOPROGRESS_MAX )); then
            _guard_disable_all "${streak} resumes in a row achieved nothing (session=${SESSION_ID:0:8})"
        fi
    fi
}

# Self-test entry point: evaluate the guards, print their state, exit. No effects.
if [[ "${CLAUDE_AUTO_RESUME_SELFTEST:-0}" == "1" ]]; then
    echo "SELFTEST-OK: 429=$_guard_429_state concurrent=${_guard_live}/${GUARD_MAX_CONCURRENT} hourly=${_guard_h}/${GUARD_HOURLY_MAX} daily=${_guard_d}/${GUARD_DAILY_MAX} noprogress_max=${GUARD_NOPROGRESS_MAX}"
    exit 0
fi
# ══ /RUNAWAY GUARD ═══════════════════════════════════════════════════════════

# Sweep stale cache entries, so the runner stays tidy even if run on its own.
find "$BASE/counts" "$BASE/runs" -type f -mtime +7 -delete >/dev/null 2>&1 &

# ── Guard: per-session lock (no double booking; a stale lock is reclaimed atomically) ──
# Staleness threshold = wait (DELAY*3) + longest headless run (MAXRT) + 600s slack,
# so a lock held by a resume that is genuinely running is never stolen.
LOCK="$BASE/locks/${SESSION_ID}.lock"
if ! mkdir "$LOCK" 2>/dev/null; then
    lm=$(_mtime "$LOCK")
    if (( $(date +%s) - lm > DELAY * 3 + MAXRT + 600 )); then
        # mv is atomic: if two runners race to reclaim, exactly one wins
        if mv "$LOCK" "$LOCK.stale.$$" 2>/dev/null; then
            rm -rf "$LOCK.stale.$$" 2>/dev/null
            mkdir "$LOCK" 2>/dev/null || { log "lost the lock race — exiting"; exit 0; }
            log "reclaimed a stale lock, continuing"
        else
            log "lost the stale-lock reclaim race — exiting"
            exit 0
        fi
    else
        log "a resume is already scheduled for this session — skipping duplicate"
        exit 0
    fi
fi
trap '_guard_cleanup' EXIT
_guard_register_pid

# ── Increment the per-session cap counter exactly once, now that we hold the
#    lock (so duplicate hook fires cannot spend two slots) ──
CF="$BASE/counts/${SESSION_ID}.count"
_c=$(cat "$CF" 2>/dev/null | tr -cd '0-9'); [[ -n "$_c" ]] || _c=0
_cm=$(_mtime "$CF")
(( $(date +%s) - _cm >= 21600 )) && _c=0   # outside the 6h window: same contract as the hook
echo $(( _c + 1 )) > "$CF" 2>/dev/null
log "cap counter incremented: $((_c+1))"

# ── Wait (jitter spreads out simultaneous spawns) ─────────
jitter=$(( RANDOM % 30 ))
log "waiting $((EFF_DELAY + jitter))s (eff_delay=$EFF_DELAY [delay=$DELAY retry_in=$RETRY_IN] + jitter=$jitter) pid=${CLAUDE_PID:-?} cwd=$CWD"
sleep $(( EFF_DELAY + jitter ))

# ── Re-check the kill switch (it can be pulled while we wait) ──
if [[ "${CLAUDE_AUTO_RESUME_DISABLED:-0}" == "1" || -f "$BASE/DISABLED" ]]; then
    log "disabled while waiting — stopping"
    exit 0
fi

# ── Guard: global stagger — real resumes go out 20s apart ──
if [[ -f "$HOME/.claude/libs/hook-guard.sh" ]]; then
    # shellcheck source=/dev/null
    source "$HOME/.claude/libs/hook-guard.sh" 2>/dev/null || true
fi
if type hook_cooldown >/dev/null 2>&1; then
    # sleep 21 > cooldown 20 guarantees one runner per round; 30 rounds (~10.5
    # minutes) and we give up rather than join a stampede.
    _n=0
    _got=0
    while (( _n < 30 )); do
        if hook_cooldown "api-auto-resume-spawn" 20; then
            _got=1
            break
        fi
        sleep 21
        _n=$(( _n + 1 ))
    done
    if (( ! _got )); then
        log "could not get a stagger slot in 30 rounds — giving up to avoid a stampede. Resume manually."
        exit 0
    fi
fi

# The situation may have turned into a 429 while we waited — re-check, then
# record this resume in the global ledger.
_guard_check_429 "post-sleep"
_guard_ledger_add

MSG="${CLAUDE_AUTO_RESUME_PROMPT:-The previous turn was cut short by an Anthropic API error (server overload). Pick the work back up and finish it; do not redo steps that already completed. Note that this is an unattended automatic resume: do not take outward or hard-to-undo actions (sending email or messages, merging PRs, deploying, deleting data, payments). Stop just before any such step and report the state instead.}"

# ── headless resume (continues the same session id) — used by the dead-process
#    path and by the non-tmux takeover ──
headless_resume() {
    local runlog="$BASE/runs/$(date +%Y%m%d-%H%M%S)-${SESSION_ID:0:8}.log"
    if [[ "$DRY" == "1" ]]; then
        log "DRY-RUN: would run claude --resume $SESSION_ID -p <continue prompt> (cwd=$CWD) — not executing"
        return 0
    fi
    # No load gate here: a resume spawns a fresh process tree, so on a machine
    # that is already saturated it is worth queueing behind whatever load gate
    # you use. This distribution ships no such queue, so we go straight ahead.
    log "load gate not configured — proceeding"
    log "headless resume starting (runlog=$runlog)"
    local _t0; _t0=$(date +%s)   # baseline for the progress check
    cd "$CWD" 2>/dev/null || cd "$HOME" 2>/dev/null \
        || { log "cannot enter $CWD or $HOME — aborting the resume"; return 0; }
    # bash 3.2 compatible empty-array expansion
    local extra=()
    if [[ -n "${CLAUDE_AUTO_RESUME_PERMISSION_MODE:-}" ]]; then
        extra=(--permission-mode "$CLAUDE_AUTO_RESUME_PERMISSION_MODE")
    fi
    # The nested claude inherits this environment. Claude Code's own process
    # markers are always cleared so the child does not believe it is running
    # inside the parent session. Auth variables are inherited by default —
    # stripping them would break anyone who authenticates with an API key. Set
    # CLAUDE_AUTO_RESUME_STRIP_API_KEY=1 if your interactive sessions log in some
    # other way and you do not want resumes billed to a stray key in the env.
    local strip_auth=()
    if [[ "${CLAUDE_AUTO_RESUME_STRIP_API_KEY:-0}" == "1" ]]; then
        strip_auth=(-u ANTHROPIC_AUTH_TOKEN -u ANTHROPIC_API_KEY)
    fi
    env -u CLAUDECODE -u CLAUDE_CODE_ENTRYPOINT -u CLAUDE_CODE_SSE_PORT \
        ${strip_auth[@]+"${strip_auth[@]}"} \
        claude --resume "$SESSION_ID" -p "$MSG" ${extra[@]+"${extra[@]}"} >>"$runlog" 2>&1 &
    local cpid=$!
    # Watchdog: if the server stays down and the headless run hangs, kill it after
    # MAXRT (2h by default) so processes do not pile up.
    ( sleep "$MAXRT"; kill -0 "$cpid" 2>/dev/null && kill "$cpid" 2>/dev/null ) &
    local wpid=$!
    wait "$cpid"
    local rc=$?
    # Tear the watchdog down, including its child sleep (no orphan sleeps).
    pkill -P "$wpid" 2>/dev/null
    kill "$wpid" 2>/dev/null
    log "headless resume finished rc=$rc (runlog=$runlog)"
    _guard_record_outcome "$_t0" "$rc" "$runlog"
    notify "Auto-resume executed" "Session ${SESSION_ID:0:8} auto-resumed after API error (rc=$rc)"
    return 0
}

# ── Idle check: is the session sitting stuck on an error, or still working?
#    Returns 0 = idle and stuck (safe to take over)
#            1 = working / recovering / too early to tell (cancel)
#            2 = already dead (resume straight away)
is_idle_stuck() {
    local pid="$1"
    local min_age="${CLAUDE_AUTO_RESUME_IDLE_MIN_AGE:-45}"
    [[ "$min_age" =~ ^[0-9]+$ ]] || min_age=45
    # (1) transcript signal: the newest meaningful record must still be the API
    #     error, with no sign of progress since.
    if [[ -n "$TRANSCRIPT" && -f "$TRANSCRIPT" ]]; then
        local tmt age state
        tmt=$(_mtime "$TRANSCRIPT")
        age=$(( $(date +%s) - tmt ))
        state=$(python3 - "$TRANSCRIPT" <<'PYIDLE' 2>/dev/null
import sys, json
# Read the last 256KB only — never load a large transcript in full.
with open(sys.argv[1], "rb") as f:
    f.seek(0, 2)
    size = f.tell()
    f.seek(max(0, size - 262144))
    lines = f.read().decode("utf-8", "replace").splitlines()
out = "UNKNOWN"
for line in reversed(lines[-120:]):
    try:
        rec = json.loads(line)
    except Exception:
        continue
    if rec.get("isApiErrorMessage") or rec.get("subtype") == "api_error":
        out = "STUCK"
        break
    t = rec.get("type")
    if t == "assistant" and not rec.get("isApiErrorMessage"):
        out = "PROGRESS"
        break
    if t == "user":
        out = "PROGRESS"
        break
print(out)
PYIDLE
)
        if [[ "$state" == "PROGRESS" ]]; then
            return 1   # newest record is real work — it recovered, do not kill it
        fi
        if [[ "$state" == "STUCK" && "$age" -lt "$min_age" ]]; then
            return 1   # it is an error, but it just happened — too early to judge
        fi
    fi
    # (2) two CPU samples — a process busy generating is not idle
    local c1 c2
    c1=$(ps -o %cpu= -p "$pid" 2>/dev/null | tr -d ' '); c1="${c1%%.*}"; [[ "$c1" =~ ^[0-9]+$ ]] || c1=0
    sleep 3
    kill -0 "$pid" 2>/dev/null || return 2   # died mid-sample — already dead
    c2=$(ps -o %cpu= -p "$pid" 2>/dev/null | tr -d ' '); c2="${c2%%.*}"; [[ "$c2" =~ ^[0-9]+$ ]] || c2=0
    if (( c1 > 25 || c2 > 25 )); then
        return 1   # actively computing — not idle
    fi
    return 0
}

# ── Is the original session process still alive? Pick the path from there ──
alive=0
if [[ -n "$CLAUDE_PID" ]] && kill -0 "$CLAUDE_PID" 2>/dev/null; then
    # Guard against PID reuse: make sure it is still a claude process
    _cmd=$(ps -o command= -p "$CLAUDE_PID" 2>/dev/null)
    [[ "$_cmd" =~ (^|[/\ ])claude([\ ]|$) ]] && alive=1
fi

if (( alive )); then
    # Alive: inject into the REPL if it is in a tmux pane, otherwise take over.
    tty=$(ps -o tty= -p "$CLAUDE_PID" 2>/dev/null | tr -d ' ')
    pane=""
    if [[ -n "$tty" && "$tty" != "??" ]] && command -v tmux >/dev/null 2>&1; then
        pane=$(tmux list-panes -a -F "#{pane_tty} #{pane_id}" 2>/dev/null \
               | awk -v t="/dev/$tty" '$1==t{print $2; exit}')
    fi
    if [[ -n "$pane" ]]; then
        # Safety 1: in copy-mode, capture-pane reads the scrollback instead of the
        # live screen, so we would neither see a dialog nor land the keystrokes.
        in_mode=$(tmux display-message -t "$pane" -p '#{pane_in_mode}' 2>/dev/null)
        if [[ "$in_mode" == "1" ]]; then
            log "pane=$pane is in copy-mode — not injecting. Resume manually."
            exit 0
        fi
        # Safety 2: if a permission dialog or menu is open, a stray Enter would
        # approve it. Never inject into one.
        DIALOG_RE='Do you want|Would you like|Allow this|❯ +[0-9]+\.|Yes, and|Esc to cancel|permission|Trust the files|Paste code'
        screen=$(tmux capture-pane -t "$pane" -p 2>/dev/null | tail -25)
        if printf '%s' "$screen" | grep -qiE "$DIALOG_RE"; then
            log "pane=$pane shows a dialog/prompt — not injecting (risk of auto-approval). Resume manually."
            exit 0
        fi
        if [[ "$DRY" == "1" ]]; then
            log "DRY-RUN: would tmux send-keys to pane=$pane — not executing"
            exit 0
        fi
        if tmux send-keys -t "$pane" -l "$MSG" 2>>"$LOG"; then
            sleep 1
            # Safety 3: re-capture right before Enter — a dialog may have appeared
            # between the first capture and the keystrokes (TOCTOU).
            screen2=$(tmux capture-pane -t "$pane" -p 2>/dev/null | tail -25)
            if printf '%s' "$screen2" | grep -qiE "$DIALOG_RE"; then
                log "pane=$pane raised a dialog just before Enter — withholding Enter (text is typed, not sent). Check manually."
                exit 0
            fi
            tmux send-keys -t "$pane" Enter 2>>"$LOG"
            log "resumed: tmux send-keys pane=$pane"
        else
            log "tmux send-keys failed on pane=$pane — resume manually"
        fi
    else
        # Alive outside tmux (an ordinary terminal tab) — take it over so the work
        # continues without a person present.
        if [[ "$TAKEOVER" != "1" ]]; then
            log "session alive (pid=$CLAUDE_PID tty=${tty:-?}), not tmux, takeover disabled — skipping. Resume manually."
            exit 0
        fi
        is_idle_stuck "$CLAUDE_PID"; _idle=$?
        if (( _idle == 2 )); then
            log "original process died while preparing the takeover — going straight to headless resume"
            headless_resume
            exit 0
        fi
        if (( _idle != 0 )); then
            log "session alive (pid=$CLAUDE_PID), not tmux, but it is working/recovering or it is too early to tell — takeover cancelled. Resume manually if needed."
            exit 0
        fi
        if [[ "$DRY" == "1" ]]; then
            log "DRY-RUN: would take over — SIGTERM pid=$CLAUDE_PID then headless resume. Not executing."
            exit 0
        fi
        log "taking over a non-tmux session: confirmed idle and stuck, ending pid=$CLAUDE_PID gracefully"
        kill -TERM "$CLAUDE_PID" 2>/dev/null
        _k=0
        while (( _k < 10 )) && kill -0 "$CLAUDE_PID" 2>/dev/null; do sleep 1; _k=$(( _k + 1 )); done
        if kill -0 "$CLAUDE_PID" 2>/dev/null; then
            log "still alive 10s after SIGTERM — sending SIGKILL to pid=$CLAUDE_PID"
            kill -KILL "$CLAUDE_PID" 2>/dev/null
            sleep 2
        fi
        if kill -0 "$CLAUDE_PID" 2>/dev/null; then
            log "could not end pid=$CLAUDE_PID — cancelling the resume rather than opening the session twice. Resume manually."
            exit 0
        fi
        log "original session ended — continuing it with a headless resume"
        headless_resume
    fi
else
    # Dead (headless -p finished, or the session exited): continue the same
    # session id with a headless resume.
    log "process is gone — headless resume path"
    headless_resume
fi

exit 0
