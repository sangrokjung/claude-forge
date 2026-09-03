#!/bin/bash
# session-time-report.sh - SessionEnd + SessionStart Hook
# Tell the user when their session ended, how long it actually ran, and how much
# went through it (prompts, tool calls, files changed).
#
# Reads Claude Code transcripts and, if you point it at one, Codex rollout logs
# too: Codex 0.150 has its own SessionEnd event and flushes its log before firing
# it, and its hooks can call any script. install.sh only wires Claude Code, so
# the Codex side is two lines you add yourself (hooks/README.md has them).
#
# Analogy: the shop clock. Nobody writes down when they closed up, so the day
# just disappears. This stamps the card on the way out and reads it back to you
# when you next open the door.
#
# WHY TWO EVENTS. SessionEnd is where the numbers exist, but it cannot talk to
# you: executeSessionEndHooks only forwards a hook's output when the hook FAILED
# ("SessionEnd hook [cmd] failed: ..."), so a successful report is discarded
# (verified in the shipped CLI, 2.0.x and 2.1.x). SessionStart, by contrast, is a
# documented surface (see forge-update-check.sh). So SessionEnd measures and
# files the report, and the next SessionStart hands it to you, once.
#
# Hook trigger: SessionEnd (record mode, no argument)
#               SessionStart (report mode, argument: --last)
# Exit codes:   0 always. Neither event may be blocked or delayed.
# Input (stdin JSON): { session_id, transcript_path, cwd, hook_event_name, reason }
# Output:       record mode  - stdout, plus the pending file below
#               report mode  - the SessionStart JSON envelope on stdout
#                              ({"hookSpecificOutput": {"additionalContext": ...}}),
#                              which is what both agents surface and what the rest
#                              of this harness already uses (context-sync-suggest.sh)
# Log:          ~/.claude/work-log/session-time-<session_id>.json   (snapshot, 600)
#               ~/.claude/work-log/session-times.jsonl              (history, 600)
# State:        ~/.claude/work-log/.session-time-pending.jsonl      (queue, drained once, 600)
# Environment:  FORGE_SESSION_TIME_REPORT=0  kill switch (both modes)
#               FORGE_SESSION_GAP_MIN        idle minutes that start a new stretch (default 60)
#               FORGE_SESSION_MAX_MB         transcript scan budget in MB (default 128, max 512)
#               FORGE_SESSION_MAX_SEC        wall-clock budget for the scan (default 4, max 30;
#                                            0 skips the scan and reports nothing)
#               FORGE_SESSION_REPORT_LANG    en | ko (default: auto-detect from LANG/LC_ALL)
#
# Elapsed time is resume-aware (CRITICAL). Do NOT report last-minus-first over the
# whole transcript: a session reopened with --continue measures hundreds of hours of
# wall clock (416h observed in the wild). Timestamps are split wherever the gap
# exceeds FORGE_SESSION_GAP_MIN, and the headline always describes the LATEST
# stretch. Cumulative totals are appended only when they are trustworthy.
#
# Reads the transcript only. No network call, no dependency beyond python3. Two
# transcript dialects are understood, decided per line rather than per file:
# Claude writes {type, message:{content:[...]}}, Codex writes a rollout log of
# {timestamp, ordinal, type, payload:{...}}. Every
# log path is opened with O_NOFOLLOW + O_NONBLOCK and checked to be a regular
# file, so a symlink or a named pipe planted there is refused instead of followed
# or waited on, and nothing is ever written outside ~/.claude/work-log/. If either budget above runs out the report is dropped
# entirely: a partial tail scan would omit the newest events, which are the ones
# the headline is about.
# exit 0 required (never disturb session start or teardown)

[ "${FORGE_SESSION_TIME_REPORT:-1}" = "0" ] && exit 0
command -v python3 >/dev/null 2>&1 || exit 0

# Two ways in, because settings.json wires this twice. The SessionStart entry uses
# the inline env form, which is the form hooks/README.md documents for passing
# configuration to a hook. --last does the same thing and is what the tests and
# manual runs use.
FORGE_SESSION_MODE="${FORGE_SESSION_MODE:-record}"
[ "${1:-}" = "--last" ] && FORGE_SESSION_MODE="report"
[ "$FORGE_SESSION_MODE" = "report" ] || FORGE_SESSION_MODE="record"
export FORGE_SESSION_MODE

INPUT=$(cat)

# The payload travels by environment variable, not by pipe. A quoted heredoc
# (<<'PYEOF') blocks shell expansion, which is what keeps this injection-safe,
# but it also consumes stdin — piping INPUT in would feed the python source to
# itself. Same technique as db-guard.sh / remote-command-guard.sh.
MSG=$(FORGE_HOOK_INPUT="$INPUT" python3 <<'PYEOF' 2>/dev/null
import errno
import json
import os
import re
import stat
import sys
import time
from datetime import datetime, timezone

EDIT_TOOLS = {"Edit", "Write", "NotebookEdit", "MultiEdit"}

# Codex edits files by feeding an apply_patch envelope to a shell tool, so the
# only reliable file-change signal is the envelope's own header. The path ends at
# the first real or escaped newline, because the envelope usually arrives inside
# a JS string literal.
CODEX_PATCH = re.compile(r'\*\*\* (?:Add|Update|Delete) File: (.+?)(?:\\n|\n|"|$)')
CODEX_TOOL_ITEMS = ("custom_tool_call", "function_call")


def env_int(name, default, low, high):
    try:
        value = int(os.environ.get(name, ""))
    except ValueError:
        return default
    return value if low <= value <= high else default


def parse_ts(raw):
    """Always returns an aware datetime. A transcript that mixes naive and aware
    stamps would otherwise make the sort raise, and the report would vanish."""
    if not isinstance(raw, str) or not raw:
        return None
    try:
        stamp = datetime.fromisoformat(raw.replace("Z", "+00:00"))
    except ValueError:
        return None
    return stamp if stamp.tzinfo else stamp.replace(tzinfo=timezone.utc)


def open_budgeted(path, max_bytes):
    """Read at most max_bytes from the tail. Oversized transcripts must not
    stall teardown; the latest stretch lives at the tail anyway."""
    handle = open_plain(path)
    size = os.fstat(handle.fileno()).st_size
    if size <= max_bytes:
        return handle, False
    handle.seek(size - max_bytes)
    handle.readline()  # drop the partial line the seek landed in
    return handle, True


def plain_file(fd, path):
    """Reject anything that is not a regular file, closing the descriptor first."""
    try:
        if stat.S_ISREG(os.fstat(fd).st_mode):
            return
    except OSError:
        pass
    os.close(fd)
    raise OSError(errno.EINVAL, "not a regular file", path)


def open_private(path, append):
    """Create at 0600 in one step, follow no symlink, wait on no pipe.

    open() + chmod() leaves the file at the umask default while it already holds
    content, and both calls follow symlinks, so a link planted at the target path
    gets its contents replaced and its mode narrowed. O_NOFOLLOW plus a creation
    mode closes both. O_NOFOLLOW says nothing about file *type* though, and a
    named pipe planted at the same path would block the open until a reader
    appeared, hanging every session close. O_NONBLOCK plus the fstat check below
    turns that into an ordinary error."""
    flags = os.O_WRONLY | os.O_CREAT | os.O_NOFOLLOW | os.O_NONBLOCK
    flags |= os.O_APPEND if append else os.O_TRUNC
    fd = os.open(path, flags, 0o600)
    plain_file(fd, path)
    return os.fdopen(fd, "a" if append else "w", encoding="utf-8")


def open_plain(path):
    """Read side of the same guard: no symlink, no pipe, no device."""
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    plain_file(fd, path)
    return os.fdopen(fd, "r", encoding="utf-8", errors="replace")


READ_CHUNK = 1 << 20
MAX_LINE_BYTES = 16 << 20


def iter_lines(handle, deadline):
    """Yield lines, giving up the moment the budget runs out.

    Iterating the file object directly would read an arbitrarily long line before
    control came back, which let a single huge line ignore the deadline entirely.
    A line past MAX_LINE_BYTES is dropped rather than buffered: no real transcript
    record is that large, and holding it would trade a time problem for a memory
    one."""
    buffered = ""
    overlong = False
    while True:
        if time.monotonic() > deadline:
            raise TimeoutError("scan budget exhausted")
        block = handle.read(READ_CHUNK)
        if not block:
            break
        if overlong:
            head, sep, rest = block.partition("\n")
            if not sep:
                continue
            overlong = False
            block = rest
        buffered += block
        if "\n" not in buffered:
            if len(buffered) > MAX_LINE_BYTES:
                buffered = ""
                overlong = True
            continue
        parts = buffered.split("\n")
        buffered = parts.pop()
        for part in parts:
            yield part
        if len(buffered) > MAX_LINE_BYTES:
            buffered = ""
            overlong = True
    if buffered and not overlong:
        yield buffered


def read_claude(record):
    """Claude Code transcript line: {type, isSidechain, message:{content}}."""
    kind = record.get("type")
    message = record.get("message")
    sidechain = bool(record.get("isSidechain"))
    if kind == "user" and not sidechain and not record.get("isMeta"):
        body = message.get("content")
        if isinstance(body, str):
            return (1 if body.strip() else 0), 0, (), sidechain
        if isinstance(body, list) and any(
                isinstance(block, dict) and block.get("type") == "text"
                for block in body):
            return 1, 0, (), sidechain
        return 0, 0, (), sidechain
    if kind == "assistant":
        calls = 0
        touched = []
        for block in message.get("content") or []:
            if not isinstance(block, dict) or block.get("type") != "tool_use":
                continue
            calls += 1
            if block.get("name") in EDIT_TOOLS:
                payload = block.get("input")
                if isinstance(payload, dict):
                    target = payload.get("file_path") or payload.get("notebook_path")
                    if isinstance(target, str) and target:
                        touched.append(target)
        return 0, calls, tuple(touched), sidechain
    return 0, 0, (), sidechain


def unescape_path(text):
    """A patch header often carries one more layer of JSON escaping than the line
    around it, which leaves \\uXXXX literals in the path. Left alone, the same
    file counts twice: once escaped, once not."""
    if "\\u" not in text:
        return text
    try:
        return json.loads('"%s"' % text.replace('"', '\\"'))
    except ValueError:
        return text


def read_codex(record):
    """Codex rollout line: {timestamp, ordinal, type, payload:{type, ...}}."""
    payload = record.get("payload")
    kind = payload.get("type")
    if kind == "message":
        # role 'developer' is the harness briefing the model, not a person typing.
        if payload.get("role") != "user":
            return 0, 0, (), False
        for block in payload.get("content") or []:
            if isinstance(block, dict) and (block.get("text") or "").strip():
                return 1, 0, (), False
        return 0, 0, (), False
    if kind in CODEX_TOOL_ITEMS:
        blob = payload.get("input")
        if not isinstance(blob, str):
            blob = payload.get("arguments")
        touched = ()
        if isinstance(blob, str) and "*** " in blob:
            touched = tuple(
                found for found in (
                    unescape_path(match.group(1).strip().rstrip("\\"))
                    for match in CODEX_PATCH.finditer(blob)
                ) if found
            )
        return 0, 1, touched, False
    return 0, 0, (), False


def collect(path, max_bytes, deadline):
    """Turn transcript lines into (timestamp, prompt, tool_calls, files, sidechain).

    Abandons the whole report if the deadline passes. Stopping early would drop
    the newest events, which are exactly the ones the headline describes, so a
    partial scan is worth less than no report at all."""
    try:
        handle, truncated = open_budgeted(path, max_bytes)
    except OSError:
        return None
    events = []
    seen_claude = seen_codex = False
    with handle:
        try:
            lines = list(iter_lines(handle, deadline))
        except TimeoutError:
            return None
        for line in lines:
            line = line.strip()
            if not line:
                continue
            try:
                record = json.loads(line)
            except (ValueError, RecursionError):
                continue
            if not isinstance(record, dict):
                continue
            stamp = parse_ts(record.get("timestamp"))
            if stamp is None:
                continue
            if isinstance(record.get("message"), dict):
                seen_claude = True
                prompt, calls, files, sidechain = read_claude(record)
            elif isinstance(record.get("payload"), dict):
                seen_codex = True
                prompt, calls, files, sidechain = read_codex(record)
            else:
                prompt, calls, files, sidechain = 0, 0, (), False
            events.append((stamp, prompt, calls, files, sidechain))
    if not events:
        return None
    events.sort(key=lambda item: item[0])
    # A rollout that also carries Claude-shaped lines is not a thing, but if it
    # ever were, say nothing rather than guess.
    platform = "codex" if seen_codex and not seen_claude else (
        "claude" if seen_claude and not seen_codex else "")
    return events, truncated, platform


def split_stretches(events, gap_seconds):
    groups = [[events[0]]]
    for event in events[1:]:
        if (event[0] - groups[-1][-1][0]).total_seconds() > gap_seconds:
            groups.append([event])
        else:
            groups[-1].append(event)
    return groups


def tally(group):
    prompts = calls = sub_calls = 0
    files = set()
    for _, prompt, count, touched, sidechain in group:
        prompts += prompt
        if sidechain:
            sub_calls += count
        else:
            calls += count
        files.update(touched)
    return {
        "prompts": prompts,
        "tool_calls": calls,
        "subagent_tool_calls": sub_calls,
        "files_changed": len(files),
    }


def human(seconds):
    minutes = int(max(0, seconds)) // 60
    hours, minutes = divmod(minutes, 60)
    return "%dh %dm" % (hours, minutes) if hours else "%dm" % minutes


def plural(count, word):
    return "%d %s" % (count, word if count == 1 else word + "s")


def pick_lang():
    override = (os.environ.get("FORGE_SESSION_REPORT_LANG") or "").strip().lower()
    if override in ("en", "ko"):
        return override
    locale = os.environ.get("LC_ALL") or os.environ.get("LANG") or ""
    return "ko" if locale.lower().startswith("ko") else "en"


def log_dir():
    """~/.claude/work-log, created private. A directory that already exists is
    left as the user set it: this path is shared with the work-tracker hooks."""
    path = os.path.expanduser("~/.claude/work-log")
    try:
        os.makedirs(path, mode=0o700, exist_ok=True)
    except OSError:
        return None
    return path


def write_line(path, line, append):
    # OSError here covers the ordinary cases (read-only mount, full disk) and the
    # interesting one: ELOOP, meaning something planted a symlink at our path. Both
    # end the same way. This hook may not stand between the user and their session
    # over a log line, so it gives up quietly.
    try:
        with open_private(path, append) as handle:
            handle.write(line + "\n")
        return True
    except OSError:
        return False


HISTORY_MAX_BYTES = 1024 * 1024


def rotate(path):
    """Keep the newest half once the history crosses its ceiling."""
    try:
        if os.path.getsize(path) <= HISTORY_MAX_BYTES:
            return
        with open_plain(path) as handle:
            handle.seek(os.path.getsize(path) - HISTORY_MAX_BYTES // 2)
            handle.readline()
            kept = handle.read()
        with open_private(path, append=False) as handle:
            handle.write(kept)
    except OSError:
        pass


def write_log(record, session_id):
    directory = log_dir()
    if not directory:
        return None
    line = json.dumps(record, ensure_ascii=False)
    snapshot = os.path.join(directory, "session-time-%s.json" % session_id)
    history = os.path.join(directory, "session-times.jsonl")
    if write_line(history, line, append=True):
        rotate(history)
    return snapshot if write_line(snapshot, line, append=False) else None


def pending_path():
    return os.path.expanduser("~/.claude/work-log/.session-time-pending.jsonl")


def stash(record):
    """Queue the report for the next SessionStart.

    Appended, not overwritten: several sessions can end before any new one starts,
    and a plain write would drop every announcement but the last."""
    if log_dir():
        write_line(pending_path(), json.dumps(record, ensure_ascii=False), append=True)


STALE_CLAIM_SEC = 60


def read_claim(path):
    """Parse one claimed queue file and delete it, whatever the contents were.

    The removal is in a finally because a claimed file that survives a parse
    failure is a batch of announcements lost for good."""
    records = []
    try:
        with open_plain(path) as handle:
            for line in handle:
                line = line.strip()
                if not line:
                    continue
                try:
                    entry = json.loads(line)
                except (ValueError, RecursionError):
                    continue
                if isinstance(entry, dict):
                    records.append(entry)
    except OSError:
        pass
    finally:
        try:
            os.remove(path)
        except OSError:
            pass
    return records


def owner_gone(name, prefix):
    """True when the process that made this claim is no longer running.

    Age alone is not enough. mtime is settable by the same user, and a drain that
    stalls past the cutoff still owns its claim; taking it would show the same
    report twice. A recycled pid reads as alive, which only delays recovery to a
    later start."""
    suffix = name[len(prefix):]
    # No real pid is this large, and os.kill raises OverflowError rather than
    # OSError on one, which would escape every guard below it.
    if not suffix.isdigit() or len(suffix) > 7:
        return True          # not a pid we wrote, fall back to age
    try:
        os.kill(int(suffix), 0)
    except ProcessLookupError:
        return True
    except Exception:
        return False         # alive, owned by someone else, or unjudgeable
    return False


def stale_claims(path):
    """Claims left behind by a run that died mid-drain."""
    directory, prefix = os.path.dirname(path), os.path.basename(path) + ".claimed-"
    cutoff = time.time() - STALE_CLAIM_SEC
    found = []
    try:
        names = os.listdir(directory)
    except OSError:
        return found
    for name in names:
        # One unreadable entry must not cost the rest of the sweep.
        try:
            if not name.startswith(prefix) or not owner_gone(name, prefix):
                continue
            candidate = os.path.join(directory, name)
            if os.path.getmtime(candidate) < cutoff:
                found.append(candidate)
        except Exception:
            continue
    return sorted(found)


def drain():
    """Claim the queue and return everything in it, oldest first.

    The rename is the claim: it is atomic, so two sessions starting at once cannot
    both read the same entries, and nothing is rendered from a file we failed to
    take. Reading first and deleting after would replay the report on a delete
    failure, and lose entries appended in between."""
    path = pending_path()
    records = []
    # Recovering someone else's leftovers is a courtesy. It must never be able to
    # stop this session from claiming and reporting its own queue.
    try:
        for orphan in stale_claims(path):
            records.extend(read_claim(orphan))
    except Exception:
        records = []
    claimed = "%s.claimed-%d" % (path, os.getpid())
    try:
        os.rename(path, claimed)
    except OSError:
        return records
    records.extend(read_claim(claimed))
    return records


def render(record, previous, also=0):
    lang = pick_lang()
    stamp = record.get("ended_label") or "?"
    span = record.get("stretch_seconds") or 0
    active = record.get("active_seconds") or 0
    resumed = max(0, (record.get("stretches") or 1) - 1)
    truncated = bool(record.get("truncated"))
    prompts = record.get("prompts") or 0
    calls = record.get("tool_calls") or 0
    changed = record.get("files_changed") or 0
    sub_calls = record.get("subagent_tool_calls") or 0
    snapshot = record.get("snapshot_path") or ""
    # Two agents share this queue, so name the one being reported on.
    agent = {"codex": "Codex", "claude": "Claude Code"}.get(record.get("platform") or "", "")

    if lang == "ko":
        head = "[Claude Forge] %s%s세션 종료 %s" % (
            "직전 " if previous else "", (agent + " ") if agent else "", stamp)
        body = "소요 %s · 프롬프트 %d · 도구 %d · 변경 파일 %d" % (
            human(span), prompts, calls, changed)
        if sub_calls:
            body += " · 서브에이전트 %d" % sub_calls
        if truncated:
            body += " (마지막 구간만 집계)"
        elif resumed:
            body += " (재개 %d회, 누적 %s)" % (resumed, human(active))
        tail = "로그: %s"
    else:
        head = "[Claude Forge] %s%ssession ended %s" % (
            "previous " if previous else "", (agent + " ") if agent else "", stamp)
        body = "%s elapsed · %s · %s · %s" % (
            human(span), plural(prompts, "prompt"), plural(calls, "tool call"),
            plural(changed, "file") + " changed")
        if sub_calls:
            body += " · %s" % plural(sub_calls, "subagent call")
        if truncated:
            body += " (latest stretch only)"
        elif resumed:
            body += " (resumed %dx, %s total)" % (resumed, human(active))
        tail = "Log: %s"

    if also:
        body += (" · 그 전 세션 %d건은 로그에" % also) if lang == "ko" else (
            " · %d earlier %s in the log" % (also, "session" if also == 1 else "sessions"))

    lines = [head, body]
    if snapshot:
        home = os.path.expanduser("~")
        lines.append(tail % (snapshot.replace(home, "~", 1)
                             if snapshot.startswith(home) else snapshot))
    return "\n".join(lines)


def measure(payload):
    session_id = payload.get("session_id") or ""
    # The id becomes a filename, so strip anything that could escape the directory.
    session_id = re.sub(r"[^A-Za-z0-9_-]", "_", session_id)[:96]
    if not session_id:
        return None

    transcript = os.path.expanduser(payload.get("transcript_path") or "")
    if not transcript or not os.path.isfile(transcript):
        return None

    gap_seconds = env_int("FORGE_SESSION_GAP_MIN", 60, 1, 1440) * 60
    max_bytes = env_int("FORGE_SESSION_MAX_MB", 128, 1, 512) * 1024 * 1024

    deadline = time.monotonic() + env_int("FORGE_SESSION_MAX_SEC", 4, 0, 30)
    scanned = collect(transcript, max_bytes, deadline)
    if not scanned:
        return None
    events, truncated, platform = scanned

    stretches = split_stretches(events, gap_seconds)
    current = stretches[-1]
    counts = tally(current)
    started = current[0][0]
    ended = datetime.now().astimezone()
    span = int((current[-1][0] - started).total_seconds())
    active = sum(int((g[-1][0] - g[0][0]).total_seconds()) for g in stretches)

    record = {
        "event": "session_time_report",
        "session_id": session_id,
        "platform": platform,
        "cwd": payload.get("cwd") or "",
        "reason": payload.get("reason") or "",
        "ended_at": ended.isoformat(),
        "ended_label": ("%s %s" % (ended.strftime("%H:%M"), ended.strftime("%Z"))).strip(),
        "stretch_started_at": started.astimezone().isoformat(),
        "stretch_ended_at": current[-1][0].astimezone().isoformat(),
        "stretch_seconds": span,
        "stretches": len(stretches),
        "active_seconds": active,
        "truncated": truncated,
        "gap_minutes": gap_seconds // 60,
    }
    record.update(counts)
    record["snapshot_path"] = write_log(record, session_id) or ""
    stash(record)
    return record


try:
    if os.environ.get("FORGE_SESSION_MODE") == "report":
        queued = drain()
        # Newest first: the session you just left is the one you want to read about.
        text = render(queued[-1], previous=True, also=len(queued) - 1) if queued else None
        if text:
            # SessionStart is the one surface that reaches the user on both
            # agents, and both read this envelope. Plain text is only reliable
            # on Claude Code.
            text = json.dumps({"hookSpecificOutput": {
                "hookEventName": "SessionStart",
                "additionalContext": text,
            }}, ensure_ascii=False)
    else:
        incoming = json.loads(os.environ.get("FORGE_HOOK_INPUT") or "{}")
        measured = measure(incoming) if isinstance(incoming, dict) else None
        text = render(measured, previous=False) if measured else None
    if text:
        sys.stdout.write(text + "\n")
except Exception:
    sys.exit(0)
PYEOF
)

if [ -n "$MSG" ]; then
    printf '%s\n' "$MSG"
fi

exit 0
