#!/bin/bash
# Rate Limiter - PreToolUse Hook (경량화 버전)
# Python → bash 산술 전환, atomic write
#
# Hook trigger: PreToolUse (mcp__*)
# Exit codes: 0 = 허용, 2 = 차단 (속도 제한 초과)
#
# 제한 (로컬): 분당 60, 시간당 1000, 일 8000
# 제한 (원격): 분당 30, 시간당 500, 일 5000

# 세션 ID 결정
if [[ -n "${OPENCLAW_SESSION_ID:-}" ]]; then
  SESSION_ID="${OPENCLAW_SESSION_ID}"
  LIMIT_MIN=30; LIMIT_HOUR=500; LIMIT_DAY=5000
else
  SESSION_ID="local-${PPID}"
  LIMIT_MIN=60; LIMIT_HOUR=1000; LIMIT_DAY=8000
fi

# 타임스탬프 파일 (/tmp로 전환 — 디스크 I/O 감소)
RATE_FILE="/tmp/claude-rate-limits-${SESSION_ID}.log"
SECURITY_LOG="$HOME/.claude/security.log"

NOW=$(date +%s)
MIN_AGO=$((NOW - 60))
HOUR_AGO=$((NOW - 3600))
DAY_AGO=$((NOW - 86400))

# 오래된 항목 정리 + 카운팅 (1회 순회)
COUNT_MIN=0
COUNT_HOUR=0
COUNT_DAY=0
CLEANED=""

if [[ -f "$RATE_FILE" ]]; then
  while IFS= read -r ts; do
    # 숫자가 아니면 건너뜀
    [[ "$ts" =~ ^[0-9]+$ ]] || continue
    if (( ts > DAY_AGO )); then
      CLEANED="${CLEANED}${ts}\n"
      (( COUNT_DAY++ ))
      if (( ts > HOUR_AGO )); then
        (( COUNT_HOUR++ ))
        if (( ts > MIN_AGO )); then
          (( COUNT_MIN++ ))
        fi
      fi
    fi
  done < "$RATE_FILE"
fi

# 제한 검사
BLOCKED=""
if (( COUNT_MIN >= LIMIT_MIN )); then
  BLOCKED="분당 속도 제한 초과 (${COUNT_MIN}/${LIMIT_MIN})"
  LIMIT_TYPE="per_minute"
elif (( COUNT_HOUR >= LIMIT_HOUR )); then
  BLOCKED="시간당 속도 제한 초과 (${COUNT_HOUR}/${LIMIT_HOUR})"
  LIMIT_TYPE="per_hour"
elif (( COUNT_DAY >= LIMIT_DAY )); then
  BLOCKED="일일 속도 제한 초과 (${COUNT_DAY}/${LIMIT_DAY})"
  LIMIT_TYPE="per_day"
fi

if [[ -n "$BLOCKED" ]]; then
  echo "BLOCKED: $BLOCKED" >&2
  # 정리만 저장 (차단된 요청은 카운트 안 함)
  printf '%b' "$CLEANED" > "${RATE_FILE}.tmp" && mv "${RATE_FILE}.tmp" "$RATE_FILE"
  # 보안 로그
  if [[ -n "$SECURITY_LOG" ]]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') | RATE_LIMITED | type=${LIMIT_TYPE} | session=${SESSION_ID}" >> "$SECURITY_LOG" 2>/dev/null
  fi
  exit 2
fi

# 현재 타임스탬프 추가 + 정리된 데이터 저장 (atomic write)
printf '%b' "${CLEANED}${NOW}\n" > "${RATE_FILE}.tmp" && mv -f "${RATE_FILE}.tmp" "$RATE_FILE"

exit 0
