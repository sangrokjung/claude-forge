#!/usr/bin/env bats
# relay skill tests (bats-core). bash 3.2 compatible.

setup() {
  TESTS_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  SKILL_DIR="$(cd "$TESTS_DIR/.." && pwd)"
  SCRIPTS="$SKILL_DIR/scripts"
  HOOK="$(cd "$SKILL_DIR/../../hooks" && pwd)/post-compact-restore.sh"
  export RELAY_DIR="$BATS_TEST_TMPDIR/relay"
  export RELAY_CLIPBOARD_CMD="cat >\"$BATS_TEST_TMPDIR/clip.txt\""
  mkdir -p "$RELAY_DIR"
}

# ---- helper: fixed collect JSON fixture ----
_fixture_collect() {
  local proj_cwd="$1"
  cat <<JSON
{"project_name":"demo","cwd":"$proj_cwd","timestamp":"2026-06-27 10:00:00","hostname":"h","os":"Darwin","git":{"is_repo":true,"branch":"main","uncommitted_count":3,"status_short":"M a.ts","log":[{"hash":"abc1234","subject":"init"}],"diff_stat":""},"plan":{"exists":true,"status":"APPROVED","total":4,"done":1,"next_unchecked":"implement endpoint"},"auto_loop_todo":{"exists":false,"next_unchecked":null},"sprint_contract":{"exists":false},"session_summary":{"exists":false,"fresh":false,"path":null,"summary":null,"next_steps":[],"blockers":[]},"tasks":{"source":"none","items":[]},"artifacts":{"count":0,"sample":[]}}
JSON
}

# ---- helper: write a pointer file ----
_write_pointer() {
  local cwd="$1" created="$2"
  source "$SCRIPTS/relay-lib.sh"
  local hash ptr
  hash="$(relay_cwd_hash "$cwd")"
  ptr="$(relay_pointer_path "$hash")"
  jq -n --arg cwd "$cwd" --arg b "/tmp/relay-baton.md" --arg nt "test next task" \
        --arg co "carryover content line 1" --arg cr "$created" --argjson ttl 12 \
    '{cwd:$cwd,baton:$b,next_task:$nt,carryover:$co,created:$cr,ttl_hours:$ttl}' > "$ptr"
  printf '%s' "$hash"
}

# ==================== build-focus ====================

@test "build-focus: starts with compact, single line, has NEXT_TASK and file token" {
  run bash "$SCRIPTS/relay-build-focus.sh" "finish refactor" "src/app.ts utils.ts" "keep Postgres as the DB"
  [ "$status" -eq 0 ]
  [[ "$output" == /compact\ * ]]
  [ "$(printf '%s' "$output" | wc -l | tr -d ' ')" -eq 0 ]
  [[ "$output" == *"finish refactor"* ]]
  [[ "$output" == *"src/app.ts"* ]]
}

@test "build-focus: empty NEXT_TASK exits 2" {
  run bash "$SCRIPTS/relay-build-focus.sh" "   "
  [ "$status" -eq 2 ]
}

@test "build-focus: line length <= 600" {
  run bash "$SCRIPTS/relay-build-focus.sh" "task" "a.ts" "decision"
  [ "$status" -eq 0 ]
  [ "${#output}" -le 600 ]
}

@test "build-focus: more than 6 files yields overflow marker" {
  run bash "$SCRIPTS/relay-build-focus.sh" "task" "a b c d e f g h" ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"and 2 more"* ]]
}

@test "build-focus: single quote in NEXT_TASK is replaced" {
  run bash "$SCRIPTS/relay-build-focus.sh" "don't break it" "a.ts" ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"’"* ]]
  [[ "$output" == *"don’t break it"* ]]
}

@test "build-focus: empty files omits the files clause" {
  run bash "$SCRIPTS/relay-build-focus.sh" "task only" "" ""
  [ "$status" -eq 0 ]
  [[ "$output" != *"code context around"* ]]
}

# ==================== lib ====================

@test "lib: json_escape escapes quote and newline" {
  source "$SCRIPTS/relay-lib.sh"
  esc="$(relay_json_escape 'he said "hi"
line2')"
  # wrapping in JSON quotes must parse cleanly with jq
  printf '"%s"' "$esc" | jq -e . >/dev/null
  [[ "$esc" == *'\"'* ]]
  [[ "$esc" == *'\n'* ]]
}

@test "lib: cwd_hash stable and 12 chars" {
  source "$SCRIPTS/relay-lib.sh"
  h1="$(relay_cwd_hash /tmp/somedir)"
  h2="$(relay_cwd_hash /tmp/somedir)"
  [ "$h1" = "$h2" ]
  [ "${#h1}" -eq 12 ]
}

# ==================== collect ====================

@test "collect: git fixture reports repo plan log" {
  fix="$BATS_TEST_TMPDIR/gitfix"
  mkdir -p "$fix/.claude"
  cd "$fix"
  git init -q
  git config user.email t@t.com
  git config user.name tester
  echo hello > a.txt
  git add a.txt
  git commit -qm "first commit"
  printf '%s\n' '- [x] done item' '- [ ] todo item' 'STATUS: APPROVED' > .claude/plan.md
  run bash "$SCRIPTS/relay-collect.sh"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.git.is_repo == true' >/dev/null
  echo "$output" | jq -e '.plan.done == 1' >/dev/null
  echo "$output" | jq -e '.plan.total == 2' >/dev/null
  echo "$output" | jq -e '.plan.next_unchecked != null' >/dev/null
  echo "$output" | jq -e '.git.log | length >= 1' >/dev/null
}

@test "collect: non-git dir exits 0 is_repo false project_name" {
  fix="$BATS_TEST_TMPDIR/plain"
  mkdir -p "$fix"
  cd "$fix"
  run bash "$SCRIPTS/relay-collect.sh"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.git.is_repo == false' >/dev/null
  echo "$output" | jq -e --arg n "plain" '.project_name == $n' >/dev/null
}

@test "collect: dirty file surfaces in git status_short" {
  fix="$BATS_TEST_TMPDIR/dirtyfix"
  mkdir -p "$fix"
  cd "$fix"
  git init -q
  git config user.email t@t.com
  git config user.name tester
  echo hi > a.txt
  git add a.txt
  git commit -qm init
  echo change >> a.txt
  run bash "$SCRIPTS/relay-collect.sh"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.git.uncommitted_count >= 1' >/dev/null
  echo "$output" | jq -e '.git.status_short | contains("a.txt")' >/dev/null
}

@test "collect: RELAY_TASKS_FILE populates tasks, unset skips silently" {
  fix="$BATS_TEST_TMPDIR/tasksfix"
  mkdir -p "$fix"
  cd "$fix"
  tf="$BATS_TEST_TMPDIR/TASKS.md"
  printf '%s\n' '- [ ] write the report' '- [x] done already' > "$tf"
  RELAY_TASKS_FILE="$tf" run bash "$SCRIPTS/relay-collect.sh"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e --arg f "$tf" '.tasks.source == $f' >/dev/null
  echo "$output" | jq -e '.tasks.items | length == 1' >/dev/null
  echo "$output" | jq -e '.tasks.items[0] == "write the report"' >/dev/null

  run bash "$SCRIPTS/relay-collect.sh"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.tasks.source == "none"' >/dev/null
  echo "$output" | jq -e '.tasks.items == []' >/dev/null
}

# ==================== write-baton ====================

@test "write-baton: skeleton-only creates baton pointer last abs-path stdout" {
  proj="$BATS_TEST_TMPDIR/proj"
  mkdir -p "$proj"
  cj="$BATS_TEST_TMPDIR/collect.json"
  _fixture_collect "$proj" > "$cj"
  focus="$(bash "$SCRIPTS/relay-build-focus.sh" "finish payment module" "pay.ts" "use Stripe")"
  run bash "$SCRIPTS/relay-write-baton.sh" "finish payment module" "$cj" "$focus"
  [ "$status" -eq 0 ]
  baton="$(printf '%s\n' "$output" | tail -1)"
  [[ "$baton" == /* ]]
  [ -f "$baton" ]
  # pointer
  source "$SCRIPTS/relay-lib.sh"
  hash="$(relay_cwd_hash "$proj")"
  ptr="$(relay_pointer_path "$hash")"
  [ -f "$ptr" ]
  jq -e --arg b "$baton" '.baton == $b' "$ptr" >/dev/null
  # last
  [ "$(cat "$(relay_last_path)")" = "$baton" ]
  # content
  grep -q "finish payment module" "$baton"
  grep -q "Completion" "$baton"
  grep -qE '^cd /' "$baton"
}

@test "write-baton: structure lint passes (section1 present, section5 abs path, no dangling)" {
  proj="$BATS_TEST_TMPDIR/proj2"
  mkdir -p "$proj"
  cj="$BATS_TEST_TMPDIR/collect2.json"
  _fixture_collect "$proj" > "$cj"
  focus="$(bash "$SCRIPTS/relay-build-focus.sh" "add API tests" "api.ts" "")"
  run bash "$SCRIPTS/relay-write-baton.sh" "add API tests" "$cj" "$focus"
  [ "$status" -eq 0 ]
  baton="$(printf '%s\n' "$output" | tail -1)"
  grep -q '## 1' "$baton"
  grep -qE '^cd /' "$baton"
  ! grep -qi 'see other file' "$baton"
}

@test "write-baton: collect JSON via stdin dash" {
  proj="$BATS_TEST_TMPDIR/proj3"
  mkdir -p "$proj"
  cj="$BATS_TEST_TMPDIR/collect3.json"
  _fixture_collect "$proj" > "$cj"
  focus="$(bash "$SCRIPTS/relay-build-focus.sh" "stdin path" "x.ts" "")"
  run bash "$SCRIPTS/relay-write-baton.sh" "stdin path" - "$focus" < "$cj"
  [ "$status" -eq 0 ]
  baton="$(printf '%s\n' "$output" | tail -1)"
  [ -f "$baton" ]
  grep -q "stdin path" "$baton"
}

@test "write-baton: prose file spliced into section2 and section4" {
  proj="$BATS_TEST_TMPDIR/proj4"
  mkdir -p "$proj"
  cj="$BATS_TEST_TMPDIR/collect4.json"
  _fixture_collect "$proj" > "$cj"
  focus="$(bash "$SCRIPTS/relay-build-focus.sh" "splice prose" "z.ts" "")"
  prose="$BATS_TEST_TMPDIR/prose.md"
  printf '%s\n' '[from-code] this is the section 2 body.' '---§4---' 'Pitfall: watch for missing env var.' > "$prose"
  run bash "$SCRIPTS/relay-write-baton.sh" "splice prose" "$cj" "$focus" "$prose"
  [ "$status" -eq 0 ]
  baton="$(printf '%s\n' "$output" | tail -1)"
  grep -q "this is the section 2 body." "$baton"
  grep -q "Pitfall: watch for missing env var." "$baton"
}

# ==================== post-compact-restore ====================

@test "post-compact-restore: valid pointer emits restore text and consumes" {
  cwd="$BATS_TEST_TMPDIR/pcr1"
  mkdir -p "$cwd"
  created="$(date '+%Y-%m-%dT%H:%M:%S%z')"
  hash="$(_write_pointer "$cwd" "$created")"
  run bash "$HOOK" <<< "{\"cwd\":\"$cwd\"}"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
  [[ "$output" == *"test next task"* ]]
  source "$SCRIPTS/relay-lib.sh"
  [ -f "$(relay_consumed_path "$hash")" ]
}

@test "post-compact-restore: second invocation is silent (consume-once)" {
  cwd="$BATS_TEST_TMPDIR/pcr2"
  mkdir -p "$cwd"
  created="$(date '+%Y-%m-%dT%H:%M:%S%z')"
  _write_pointer "$cwd" "$created" >/dev/null
  run bash "$HOOK" <<< "{\"cwd\":\"$cwd\"}"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
  run bash "$HOOK" <<< "{\"cwd\":\"$cwd\"}"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "post-compact-restore: missing pointer silent exit 0" {
  run bash "$HOOK" <<< "{\"cwd\":\"$BATS_TEST_TMPDIR/nope\"}"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "post-compact-restore: mismatched cwd silent exit 0" {
  cwd="$BATS_TEST_TMPDIR/pcr3"
  mkdir -p "$cwd"
  created="$(date '+%Y-%m-%dT%H:%M:%S%z')"
  _write_pointer "$cwd" "$created" >/dev/null
  run bash "$HOOK" <<< "{\"cwd\":\"$BATS_TEST_TMPDIR/other-dir\"}"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "post-compact-restore: malformed stdin silent exit 0" {
  run bash "$HOOK" <<< "not json at all"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "post-compact-restore: expired pointer silent exit 0 and pointer removed" {
  cwd="$BATS_TEST_TMPDIR/pcr4"
  mkdir -p "$cwd"
  # created 48 hours ago (exceeds ttl 12h)
  created="$(date -v-48H '+%Y-%m-%dT%H:%M:%S%z' 2>/dev/null || date -d '48 hours ago' '+%Y-%m-%dT%H:%M:%S%z' 2>/dev/null)"
  hash="$(_write_pointer "$cwd" "$created")"
  source "$SCRIPTS/relay-lib.sh"
  ptr="$(relay_pointer_path "$hash")"
  [ -f "$ptr" ]
  run bash "$HOOK" <<< "{\"cwd\":\"$cwd\"}"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -f "$ptr" ]
}
