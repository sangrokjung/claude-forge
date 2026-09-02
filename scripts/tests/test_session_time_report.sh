#!/bin/bash
# session-time-report.sh regression: resume-aware elapsed time, counts, output
# channel, log file, and the defensive paths that must never break teardown.
# Run: bash scripts/tests/test_session_time_report.sh
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOOK="$ROOT/hooks/session-time-report.sh"
[ -r "$HOOK" ] || { echo "FAIL: hooks/session-time-report.sh missing"; exit 1; }
PASS=0; FAIL=0
ok(){ printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }
no(){ printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
# The hook writes under ~/.claude/work-log; relocate HOME so the suite cannot
# touch the developer's real logs.
export HOME="$WORK/home"
mkdir -p "$HOME"

bash -n "$HOOK" && ok "parses with bash -n" || no "parses with bash -n"
[ -x "$HOOK" ] && ok "executable bit set" || no "executable bit set"
MODE=$(cd "$ROOT" && git ls-files -s hooks/session-time-report.sh 2>/dev/null | awk '{print $1}')
[ "$MODE" = "100755" ] && ok "git index mode 100755" || no "git index mode 100755 (got '${MODE:-untracked}')"

# --- fixture: two stretches split by a 5 h gap -----------------------------
# Stretch A: 3 turns over 40 min. Gap: 5 h. Stretch B: 30 min, 2 prompts,
# 3 tool calls, 2 distinct files edited (one file touched twice).
TRANSCRIPT="$WORK/session.jsonl"
python3 - "$TRANSCRIPT" <<'PY'
import json, sys
from datetime import datetime, timedelta, timezone

base = datetime(2026, 9, 1, 1, 0, 0, tzinfo=timezone.utc)
rows = []

def at(minutes):
    return (base + timedelta(minutes=minutes)).isoformat().replace("+00:00", "Z")

def user(minutes, text="hello"):
    rows.append({"type": "user", "timestamp": at(minutes),
                 "message": {"content": text}})

def assistant(minutes, tools):
    blocks = []
    for name, path in tools:
        block = {"type": "tool_use", "name": name, "input": {}}
        if path:
            block["input"]["file_path"] = path
        blocks.append(block)
    rows.append({"type": "assistant", "timestamp": at(minutes),
                 "message": {"content": blocks}})

# stretch A: 0 -> 40 min
user(0)
assistant(5, [("Bash", None)])
user(20)
assistant(40, [("Edit", "/tmp/a.txt")])

# 5 h gap, then stretch B: 340 -> 370 min
user(340)
assistant(345, [("Bash", None), ("Edit", "/tmp/b.txt")])
user(360)
assistant(370, [("Write", "/tmp/b.txt")])

# noise that must be ignored: meta turn, sidechain prompt, unparseable line
rows.append({"type": "user", "timestamp": at(365), "isMeta": True,
             "message": {"content": "meta"}})
rows.append({"type": "user", "timestamp": at(366), "isSidechain": True,
             "message": {"content": "subagent prompt"}})

with open(sys.argv[1], "w") as fh:
    for row in rows:
        fh.write(json.dumps(row) + "\n")
    fh.write("this line is not json\n")
PY

payload(){ printf '{"session_id":"%s","transcript_path":"%s","cwd":"/tmp","hook_event_name":"SessionEnd","reason":"exit"}' "$1" "$2"; }

run(){ payload "$1" "$2" | FORGE_SESSION_REPORT_LANG=en "$HOOK"; }

# --- output channel: stdout carries the report, stderr stays clean ----------
# SessionEnd discards a successful hook's output, so the visible surface is the
# SessionStart replay tested further down. stdout is what both modes write to.
ERR=$(run sess-a "$TRANSCRIPT" 2>&1 >/dev/null)
OUT=$(run sess-a "$TRANSCRIPT" 2>/dev/null)
[ -z "$ERR" ] && ok "stderr stays clean" || no "stderr stays clean (got '$ERR')"
case "$OUT" in "[Claude Forge] Session ended"*) ok "stdout carries a tagged report";;
  *) no "stdout carries a tagged report (got '$OUT')";; esac
ERR="$OUT"   # the assertions below read the rendered report

# --- the core invariant: report the latest stretch, not the whole span ------
# Whole transcript spans 370 min (6h 10m). Latest stretch is 30 min.
case "$ERR" in *"30m elapsed"*) ok "elapsed = latest stretch, not whole span";;
  *) no "elapsed = latest stretch, not whole span (got '$ERR')";; esac
case "$ERR" in *"6h"*) no "does not leak the resumed wall-clock span";;
  *) ok "does not leak the resumed wall-clock span";; esac
case "$ERR" in *"resumed 1x"*) ok "resume count reported";;
  *) no "resume count reported (got '$ERR')";; esac

# --- counts are scoped to that stretch --------------------------------------
case "$ERR" in *"2 prompts"*) ok "prompts counted (meta and sidechain excluded)";;
  *) no "prompts counted (got '$ERR')";; esac
case "$ERR" in *"3 tool calls"*) ok "tool calls counted";;
  *) no "tool calls counted (got '$ERR')";; esac
case "$ERR" in *"1 file changed"*) ok "changed files deduplicated";;
  *) no "changed files deduplicated (got '$ERR')";; esac

# --- a wider gap threshold merges the stretches ------------------------------
WIDE=$(payload sess-w "$TRANSCRIPT" | FORGE_SESSION_GAP_MIN=600 FORGE_SESSION_REPORT_LANG=en "$HOOK" 2>/dev/null)
case "$WIDE" in *"6h 10m elapsed"*) ok "FORGE_SESSION_GAP_MIN widens the stretch";;
  *) no "FORGE_SESSION_GAP_MIN widens the stretch (got '$WIDE')";; esac

# --- Korean surface ----------------------------------------------------------
KO=$(payload sess-k "$TRANSCRIPT" | FORGE_SESSION_REPORT_LANG=ko "$HOOK" 2>/dev/null)
case "$KO" in *"세션 종료"*) ok "ko locale renders Korean";;
  *) no "ko locale renders Korean (got '$KO')";; esac

# --- log file ----------------------------------------------------------------
SNAP="$HOME/.claude/work-log/session-time-sess-a.json"
[ -f "$SNAP" ] && ok "snapshot log written" || no "snapshot log written"
[ -f "$HOME/.claude/work-log/session-times.jsonl" ] && ok "history log appended" \
  || no "history log appended"
PERM=$(ls -l "$SNAP" 2>/dev/null | cut -c1-10)
[ "$PERM" = "-rw-------" ] && ok "snapshot is mode 600" || no "snapshot is mode 600 (got '$PERM')"
python3 - "$SNAP" <<'PY' && ok "log carries the expected fields" || no "log carries the expected fields"
import json, sys
d = json.load(open(sys.argv[1]))
need = ["event", "session_id", "ended_at", "stretch_seconds", "stretches",
        "active_seconds", "truncated", "prompts", "tool_calls", "files_changed"]
missing = [k for k in need if k not in d]
assert not missing, missing
assert d["stretches"] == 2, d["stretches"]
assert d["stretch_seconds"] == 1800, d["stretch_seconds"]
assert d["prompts"] == 2 and d["tool_calls"] == 3 and d["files_changed"] == 1, d
PY

# --- report mode: SessionStart replays the last session exactly once ---------
PENDING="$HOME/.claude/work-log/.session-time-pending.jsonl"
run sess-p "$TRANSCRIPT" >/dev/null 2>&1
[ -f "$PENDING" ] && ok "record mode leaves a pending report" || no "record mode leaves a pending report"

REPLAY=$(printf '{"session_id":"new","source":"startup"}' | FORGE_SESSION_REPORT_LANG=en "$HOOK" --last 2>/dev/null)
case "$REPLAY" in "[Claude Forge] Previous session ended"*) ok "report mode replays the previous session";;
  *) no "report mode replays the previous session (got '$REPLAY')";; esac
case "$REPLAY" in *"30m elapsed"*) ok "replay keeps the measured numbers";;
  *) no "replay keeps the measured numbers (got '$REPLAY')";; esac
[ -f "$PENDING" ] && no "pending report is drained" || ok "pending report is drained"

AGAIN=$(printf '{"session_id":"new"}' | FORGE_SESSION_REPORT_LANG=en "$HOOK" --last 2>&1)
[ -z "$AGAIN" ] && ok "report mode is silent with nothing pending" \
  || no "report mode is silent with nothing pending (got '$AGAIN')"

# settings.json wires report mode through the inline env form; --last is the same
# switch for manual runs. Both must select report mode.
run sess-e "$TRANSCRIPT" >/dev/null 2>&1
ENVMODE=$(printf '{"session_id":"new"}' | FORGE_SESSION_MODE=report FORGE_SESSION_REPORT_LANG=en "$HOOK" 2>/dev/null)
case "$ENVMODE" in "[Claude Forge] Previous session ended"*) ok "FORGE_SESSION_MODE=report selects report mode";;
  *) no "FORGE_SESSION_MODE=report selects report mode (got '$ENVMODE')";; esac

# both wirings must resolve to a tracked file in this repo
python3 - "$ROOT" <<'PYCHK' && ok "settings.json wiring resolves to this hook" || no "settings.json wiring resolves to this hook"
import json, pathlib, sys
root = pathlib.Path(sys.argv[1])
settings = json.loads((root / "settings.json").read_text())
found = {"SessionEnd": False, "SessionStart": False}
for event, groups in settings.get("hooks", {}).items():
    if event not in found:
        continue
    for group in groups:
        for hook in group.get("hooks", []):
            command = hook.get("command", "")
            if "session-time-report.sh" not in command:
                continue
            found[event] = True
            path = command.split()[-1]
            assert path.startswith("~/.claude/"), command
            assert (root / path[len("~/.claude/"):]).is_file(), command
assert all(found.values()), found
PYCHK

# --- session_id is sanitized before it becomes a filename --------------------
payload "../../escaped" "$TRANSCRIPT" | "$HOOK" >/dev/null 2>&1
[ -e "$HOME/.claude/escaped.json" ] && no "session_id traversal blocked" \
  || ok "session_id traversal blocked"

# --- concurrent sessions: no announcement is silently dropped ----------------
# A single overwritten pending file loses every session but the last, which is a
# normal pattern for anyone running several terminals or worktrees at once.
CONC="$WORK/conc"
mkdir -p "$CONC"
payload conc-a "$TRANSCRIPT" | HOME="$CONC" "$HOOK" >/dev/null 2>&1
payload conc-b "$TRANSCRIPT" | HOME="$CONC" "$HOOK" >/dev/null 2>&1
QUEUED=$(printf '{"session_id":"new"}' | HOME="$CONC" FORGE_SESSION_REPORT_LANG=en "$HOOK" --last 2>/dev/null)
case "$QUEUED" in *"1 earlier session in the log"*) ok "queued sessions are all accounted for";;
  *) no "queued sessions are all accounted for (got '$QUEUED')";; esac
[ -f "$CONC/.claude/work-log/.session-time-pending.jsonl" ] && no "queue is claimed on drain" \
  || ok "queue is claimed on drain"
LEFT=0
for stray in "$CONC/.claude/work-log/"*.claimed-*; do
  [ -e "$stray" ] && LEFT=$((LEFT+1))
done
[ "$LEFT" = "0" ] && ok "no claimed leftovers" || no "no claimed leftovers ($LEFT)"

# --- a transcript mixing naive and aware timestamps still reports -------------
MIXED="$WORK/mixed.jsonl"
python3 - "$MIXED" <<'PYMIX'
import json, sys
rows = [
    {"type": "user", "timestamp": "2026-09-01T01:00:00", "message": {"content": "hi"}},
    {"type": "assistant", "timestamp": "2026-09-01T01:10:00Z",
     "message": {"content": [{"type": "tool_use", "name": "Bash", "input": {}}]}},
]
with open(sys.argv[1], "w") as fh:
    for row in rows:
        fh.write(json.dumps(row) + "\n")
PYMIX
MIX=$(payload sess-mx "$MIXED" | FORGE_SESSION_REPORT_LANG=en "$HOOK" 2>/dev/null)
case "$MIX" in "[Claude Forge] Session ended"*) ok "naive and aware timestamps mix cleanly";;
  *) no "naive and aware timestamps mix cleanly (got '$MIX')";; esac

# --- the history file has a ceiling -----------------------------------------
BIG="$WORK/big"
mkdir -p "$BIG/.claude/work-log"
python3 - "$BIG/.claude/work-log/session-times.jsonl" <<'PYBIG'
import sys
with open(sys.argv[1], "w") as fh:
    fh.write(('{"filler":"%s"}\n' % ("x" * 400)) * 6000)   # ~2.4 MB
PYBIG
payload sess-rot "$TRANSCRIPT" | HOME="$BIG" "$HOOK" >/dev/null 2>&1
SIZE=$(wc -c < "$BIG/.claude/work-log/session-times.jsonl")
[ "$SIZE" -lt 1048576 ] && ok "history rotates under its cap" || no "history rotates under its cap ($SIZE bytes)"
tail -1 "$BIG/.claude/work-log/session-times.jsonl" | grep -q session_time_report \
  && ok "rotation keeps the newest record" || no "rotation keeps the newest record"

# --- writes are private and never follow a symlink ---------------------------
FRESH="$WORK/fresh"
mkdir -p "$FRESH"
payload sess-f "$TRANSCRIPT" | HOME="$FRESH" "$HOOK" >/dev/null 2>&1
DIRPERM=$(ls -ld "$FRESH/.claude/work-log" 2>/dev/null | cut -c1-10)
[ "$DIRPERM" = "drwx------" ] && ok "log directory created private" \
  || no "log directory created private (got '$DIRPERM')"
for f in "session-time-sess-f.json" "session-times.jsonl" ".session-time-pending.jsonl"; do
  M=$(ls -l "$FRESH/.claude/work-log/$f" 2>/dev/null | cut -c1-10)
  [ "$M" = "-rw-------" ] && ok "$f created 600" || no "$f created 600 (got '$M')"
done

CANARY="$WORK/canary"
printf 'PRISTINE\n' > "$CANARY"; chmod 644 "$CANARY"
ln -s "$CANARY" "$FRESH/.claude/work-log/session-time-symsess.json"
payload symsess "$TRANSCRIPT" | HOME="$FRESH" "$HOOK" >/dev/null 2>&1
[ "$(cat "$CANARY")" = "PRISTINE" ] && ok "symlinked log path is not followed" \
  || no "symlinked log path is not followed (canary was overwritten)"
CM=$(ls -l "$CANARY" | cut -c1-10)
[ "$CM" = "-rw-r--r--" ] && ok "symlink target keeps its mode" || no "symlink target keeps its mode (got '$CM')"

# --- the scan gives up rather than reporting a partial tail ------------------
TIMEBOX=$(payload sess-t "$TRANSCRIPT" | FORGE_SESSION_MAX_SEC=1 FORGE_SESSION_REPORT_LANG=en "$HOOK" 2>/dev/null)
case "$TIMEBOX" in "[Claude Forge]"*) ok "a small transcript still fits the time budget";;
  *) no "a small transcript still fits the time budget (got '$TIMEBOX')";; esac

# With no budget at all the scan must abandon rather than report a partial read.
# Deleting the deadline check makes this assertion go red, which is the point:
# the previous version sampled the clock every 2000 lines and was never exercised.
SPENT=$(payload sess-d "$TRANSCRIPT" | FORGE_SESSION_MAX_SEC=0 "$HOOK" 2>&1)
[ -z "$SPENT" ] && ok "an exhausted time budget drops the report" \
  || no "an exhausted time budget drops the report (got '$SPENT')"

# The starvation case: a transcript of a few very large lines. A check that only
# samples every N lines never runs here, so the budget would be ignored entirely.
FEWBIG="$WORK/few-big.jsonl"
python3 - "$FEWBIG" <<'PYFEW'
import json, sys
with open(sys.argv[1], "w") as fh:
    for i in range(3):
        fh.write(json.dumps({"type": "user", "timestamp": "2026-09-01T01:0%d:00Z" % i,
                             "message": {"content": "x" * 200000}}) + "\n")
PYFEW
STARVE=$(payload sess-sv "$FEWBIG" | FORGE_SESSION_MAX_SEC=0 "$HOOK" 2>&1)
[ -z "$STARVE" ] && ok "the budget is checked on every line, not every Nth" \
  || no "the budget is checked on every line, not every Nth (got '$STARVE')"

# --- a named pipe planted at a log path must not stall the session ----------
# O_NOFOLLOW only refuses symlinks. A FIFO is a different file type, and opening
# one blocks until a reader appears, which would hang every close and open.
FIFOH="$WORK/fifo"
mkdir -p "$FIFOH/.claude/work-log"
mkfifo "$FIFOH/.claude/work-log/session-times.jsonl"
mkfifo "$FIFOH/.claude/work-log/.session-time-pending.jsonl"
mkfifo "$FIFOH/.claude/work-log/session-time-sess-fifo.json"
payload sess-fifo "$TRANSCRIPT" | HOME="$FIFOH" timeout 8 "$HOOK" >/dev/null 2>&1
[ $? -ne 124 ] && ok "a FIFO log path does not hang record mode" || no "a FIFO log path does not hang record mode"
printf '{"session_id":"n"}' | HOME="$FIFOH" timeout 8 "$HOOK" --last >/dev/null 2>&1
[ $? -ne 124 ] && ok "a FIFO queue does not hang report mode" || no "a FIFO queue does not hang report mode"

# a FIFO transcript must be ignored, not read
mkfifo "$WORK/fifo-transcript.jsonl"
FT=$(payload sess-ft "$WORK/fifo-transcript.jsonl" | timeout 8 "$HOOK" 2>&1)
FTRC=$?
{ [ $FTRC -ne 124 ] && [ -z "$FT" ]; } && ok "a FIFO transcript is ignored" \
  || no "a FIFO transcript is ignored (rc=$FTRC out='$FT')"

# --- defensive paths: never break teardown -----------------------------------
quiet(){ # command must exit 0 and print nothing on either stream
  local label="$1"; shift
  local out; out=$("$@" 2>&1); local rc=$?
  if [ $rc -eq 0 ] && [ -z "$out" ]; then ok "$label"; else no "$label (rc=$rc out='$out')"; fi
}
: > "$WORK/empty.jsonl"
payload sess-kill "$TRANSCRIPT" > "$WORK/kill.json"

quiet "empty stdin is silent"        sh -c "printf '' | '$HOOK'"
quiet "malformed json is silent"     sh -c "printf 'not json' | '$HOOK'"
quiet "json array is silent"         sh -c "printf '[1,2,3]' | '$HOOK'"
quiet "missing transcript is silent" sh -c "printf '{\"session_id\":\"x\",\"transcript_path\":\"/nope/none.jsonl\"}' | '$HOOK'"
quiet "kill switch silences it"      sh -c "FORGE_SESSION_TIME_REPORT=0 '$HOOK' < '$WORK/kill.json'"
quiet "empty transcript is silent"   sh -c "printf '{\"session_id\":\"e\",\"transcript_path\":\"$WORK/empty.jsonl\"}' | '$HOOK'"

echo "PASS=$PASS FAIL=$FAIL"; exit $((FAIL > 0))
