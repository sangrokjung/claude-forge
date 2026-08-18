#!/usr/bin/env bash
# Pre-commit Security Guard 회귀 테스트
#
# 이 가드는 두 방향으로 틀릴 수 있고, 둘 다 실제로 일어났다:
#   - 감도 상실: v7 이전 `echo | grep -q`가 SIGPIPE(141) + pipefail로 **매치를 미매치로
#     삼켜** 진짜 토큰이 통과했다. 앞쪽에 매치가 있고 뒤에 본문이 큰 파일에서만 재현된다.
#   - 오탐: v9 이전 prefix 패턴이 문서·CI의 자리표시자(`ghp_xxxx…x`)를 진짜 키로 읽어
#     그 파일을 건드리는 커밋마다 차단했다(→ --no-verify 상시화 = 가드 무력화).
#
# 그래서 "진짜는 잡는다"와 "가짜는 안 잡는다"를 **양방향으로** 고정한다.
#
# 사용: bash scripts/tests/test_precommit_guard.sh [훅경로]
#       기본값은 install-precommit.sh에서 훅 본문을 추출해 검사한다.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INSTALLER="$REPO_ROOT/scripts/install-precommit.sh"
HOOK="${1:-}"
TMPHOOK=""

if [ -z "$HOOK" ]; then
  TMPHOOK=$(mktemp)
  python3 - "$INSTALLER" > "$TMPHOOK" <<'PY'
import re, sys, pathlib
t = pathlib.Path(sys.argv[1]).read_text()
m = re.search(r"^HOOK_CONTENT='(.*?)^'\n", t, re.S | re.M)
if not m:
    sys.exit("HOOK_CONTENT 블록을 찾지 못했습니다")
print(m.group(1).replace("'\\''", "'"), end='')
PY
  HOOK="$TMPHOOK"
fi

bash -n "$HOOK" || { echo "FAIL: 훅 문법 오류"; exit 1; }

PASS=0
FAIL=0

# run_case <이름> <BLOCK|PASS> <파일내용>
run_case() {
  local name="$1" want="$2" content="$3"
  local d out rc got
  d=$(mktemp -d)
  (
    cd "$d" || exit 1
    git init -q .
    git config user.email t@example.com
    git config user.name test
    printf '%s\n' "$content" > f.txt
    git add f.txt
  ) >/dev/null 2>&1
  out=$(cd "$d" && bash "$HOOK" 2>&1)
  rc=$?
  [ $rc -ne 0 ] && got=BLOCK || got=PASS
  if [ "$got" = "$want" ]; then
    printf '  ok   %-44s %s\n' "$name" "$got"
    PASS=$((PASS + 1))
  else
    printf '  FAIL %-44s want=%s got=%s\n       %s\n' "$name" "$want" "$got" "$(head -1 <<< "$out")"
    FAIL=$((FAIL + 1))
  fi
  rm -rf "$d"
}

# ⚠ 픽스처는 **런타임에 조립**한다. 온전한 형태를 이 파일에 리터럴로 적으면 가드가
#   자기 테스트 파일을 차단해(정당한 판정) 커밋 자체가 불가능해지고, 그걸 피하려
#   --no-verify를 쓰면 이 테스트가 막으려는 바로 그 습관을 테스트가 만든다.
#   조각은 각각 패턴 임계(연속 영숫자 40자·prefix+본문 길이)에 못 미치게 쪼갠다.
P_GH="ghp_";  B_GH="A1b2C3d4E5f6G7h8I9j0K1l2M3n4O5p6Q7r8"
P_AWS="AKIA"; B_AWS="3KLM9QRSTUV2WXYZ"
P_SK="sk-";   B_SK="proj7Xa9Bc2De4Fg6Hi8Jk0Lm1No3Pq5Rs"
P_SB="sbp_";  B_SB="9f3a2b7c1d4e8g5h6j0k2m4n6p8q1r3s"
P_SLK="xoxb-"; B_SLK="123456789012-AbCdEfGhIjKlMnOpQrStUvWx"
B64="QWxhZGRpbjpvcGVuIHNlc2FtZQ"; B64="${B64}QWxhZGRpbjpvcGVu"
PEM="-----BEGIN"; PEM="$PEM RSA PRIVATE KEY-----"
JWT="eyJhbGciOiJIUzI1NiJ9"; JWT="$JWT.eyJzdWIiOiIxIn0.abc-def_123"
SSH_ALG="ssh-ed25519"; SSH_BODY="AAAAC3NzaC1lZDI1NTE5AAAAIKr8VmT2wQxYz"; SSH_BODY="${SSH_BODY}AbCdEfGhIjKlMnOpQrStUvWxYz0"
PH_X="ghp_"; PH_X="${PH_X}$(printf 'x%.0s' $(seq 36))"
PH_0="ghp_"; PH_0="${PH_0}$(printf '0%.0s' $(seq 36))"
PH_AWS="AKIA"; PH_AWS="${PH_AWS}IOSFODNN7EXAMPLE"
PH_SK="sk-";  PH_SK="${PH_SK}$(printf 'a%.0s' $(seq 25))"

echo "── 진짜 시크릿은 차단한다 (감도) ──"
run_case "GitHub PAT"            BLOCK "token = ${P_GH}${B_GH}"
run_case "AWS 액세스 키"          BLOCK "aws = ${P_AWS}${B_AWS}"
run_case "OpenAI 키"             BLOCK "k = ${P_SK}${B_SK}"
run_case "Supabase PAT"          BLOCK "${P_SB}${B_SB}"
run_case "Slack 봇 토큰"          BLOCK "${P_SLK}${B_SLK}"
run_case "base64 블롭"            BLOCK "blob=${B64}"
run_case "PEM 개인키"             BLOCK "$PEM"
run_case "JWT"                   BLOCK "$JWT"

# v7 회귀: 앞쪽 매치 + 뒤에 큰 본문. grep -q 파이프였을 때 SIGPIPE로 매치가 삼켜졌다.
echo "── 앞쪽 매치 + 큰 본문 (v7 SIGPIPE 회귀) ──"
BIG="token = ${P_GH}${B_GH}"$'\n'
BIG="$BIG$(python3 -c "print(('평범한 본문 줄입니다 ' * 6 + chr(10)) * 400, end='')")"
run_case "매치가 첫 줄 + 뒤 3KB+ 본문"  BLOCK "$BIG"

echo "── 자리표시자는 통과시킨다 (오탐, v9) ──"
run_case "ghp_ 자리표시자(x 반복)"     PASS "WHITELIST=$PH_X"
run_case "ghp_ 자리표시자(0 반복)"     PASS "token: $PH_0"
run_case "AWS 공식 예제(EXAMPLE)"      PASS "key = $PH_AWS"
run_case "sk- 자리표시자(a 반복)"      PASS "OPENAI=$PH_SK"

echo "── 멀티바이트 문서에서 유한 시간 내 완료 (v10 hang 회귀) ──"
# 2026-08-18 spec 커밋 3회 timeout의 원인은 둘이었다(둘 다 v10이 고정):
#  ① homebrew bash 5.3.15(PATH 점유 시 #!/usr/bin/env bash가 잡음)가 64KB 미만
#     변수 herestring에서 deadlock → shebang /bin/bash 고정으로 해소
#  ② PATH의 grep이 ugrep이면 멀티바이트 본문 + {40,} 구간 반복에서 hang
#     → GREP=/usr/bin/grep 고정으로 해소
# 이 케이스는 두 고정 중 어느 쪽이 풀려도 watchdog으로 잡는다.
MB_DOC=$(python3 -c "
line = '한국어 본문과 특수문자 → — ≠ § 조합 reproduce→bisect→hypothesize→verify 그리고 maker≠checker 루프. '
print((line * 3 + chr(10)) * 60, end='')")
mb_dir=$(mktemp -d)
( cd "$mb_dir" && git init -q . && git config user.email t@example.com && git config user.name test
  printf '%s\n' "$MB_DOC" > doc.md && git add doc.md ) >/dev/null 2>&1
( cd "$mb_dir" && bash "$HOOK" >/dev/null 2>&1 ) &
MB_PID=$!
MB_OK=0
for _ in $(seq 1 15); do
  kill -0 "$MB_PID" 2>/dev/null || { MB_OK=1; break; }
  sleep 1
done
if [ "$MB_OK" -eq 1 ]; then
  wait "$MB_PID" 2>/dev/null; mb_rc=$?
  if [ "$mb_rc" -eq 0 ]; then
    printf '  ok   %-44s PASS(<15s)\n' "멀티바이트 heavy 문서"; PASS=$((PASS + 1))
  else
    printf '  FAIL %-44s 완료했으나 오차단 rc=%s\n' "멀티바이트 heavy 문서" "$mb_rc"; FAIL=$((FAIL + 1))
  fi
else
  kill -9 "$MB_PID" 2>/dev/null
  printf '  FAIL %-44s 15s 내 미완료 (hang — GREP 고정 풀림 의심)\n' "멀티바이트 heavy 문서"; FAIL=$((FAIL + 1))
fi
rm -rf "$mb_dir"

echo "── 정상 콘텐츠는 통과시킨다 ──"
run_case "평범한 코드"                 PASS 'const greeting = "hello world";'
SHA40="1642dc5aa1b2c3d4e5f6"; SHA40="${SHA40}0718293a4b5c6d7e8f90"
run_case "git SHA(40 hex)"             PASS "sha: $SHA40"
run_case "URL(슬래시 포함 장문)"        PASS 'https://example.com/very/long/path/segment/aaaaaaaaaaaaaaaaaaaa'
run_case "ssh 공개키"                  PASS "$SSH_ALG $SSH_BODY user@host"

[ -n "$TMPHOOK" ] && rm -f "$TMPHOOK"

echo
echo "결과: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
