---
name: golden-principles
load: always
audience: team
sensitivity: L1
category: work-style
critical: false
description: 모든 컨텍스트 로드 핵심 원칙 12개 (불변성/시크릿/TDD/결론먼저/HARD-GATE 등)
---
# Golden Principles

> 이 파일은 모든 컨텍스트에서 로드되는 핵심 원칙 요약이다.
> 코딩 상세 규칙은 coding-style.md (코드 파일 작업 시 자동 로드).

| # | 원칙 | 핵심 | 상세 |
|---|------|------|------|
| 1 | 불변성 | spread로 새 객체. 원본 수정 금지 | coding-style.md |
| 2 | 시크릿 환경 변수화 | `process.env`만, 미설정 시 throw | coding-style.md |
| 3 | TDD | RED→GREEN→IMPROVE. 커버리지 80%+ | — |
| 4 | 결론 먼저 (CEO 브리핑) | 결론→파급("그로 인해 ~생길 수 있다")→근거→권고 4단 구조 | interaction.md |
| 5 | 작은 파일/함수 | 800줄/50줄/중첩4단계 | coding-style.md |
| 6 | 경계 검증 | zod 입력 검증, 파라미터화 쿼리 | coding-style.md |
| 7 | 비유로 설명 | 비유 1-2문장 먼저 → 기술 설명 | interaction.md |
| 8 | 컨텍스트 임계 | **Opus 4.7 1M context 기준**: 30% 초과 시 서브에이전트 위임, plan.md 있으면 50%. 70%/85%는 200K 시절 stale 표현 (2026-05-08 1M 갱신). hook 자동 발동: `CTX_MONITOR_WINDOW=1000000 × CTX_MONITOR_THRESHOLD=30` = 300K | CLAUDE.md "자동 위임" |
| 9 | HARD-GATE | 3파일+ 변경 **AND 핵심 로직/스키마/API 계약 변경 시** plan.md APPROVED 필수. 면제 (모두 AND 충족): ① 변경 파일 < 5 ② 변경 줄 < 100 ③ 핵심 로직/스키마/API 계약 미변경. 콘텐츠 작성·문서 sync·한 줄 fix는 자동 충족. 예외: auto-ship Stage 1 APPROVE 시 자동 전환 | CLAUDE.md L13, commands/sprint-contract.md, dev-team.md |
| 10 | 증거 기반 완료 | 실행 결과 없이 완료 주장 금지 | verification.md |
| 11 | SDD 리뷰 강제 | 서브에이전트 코드는 스펙 리뷰 필수 | — |
| 12 | 수술적 변경 | 요청받은 줄만 변경. 인접 정리 금지 | — |
| 13 | 메타 개선 | 동일 정정 2회+ 시 규칙 1줄 추가 권고 (`UserPromptSubmit` 훅 자동 감지) | meta-improvement.md |
| 14 | 알림 훅 정책 | cooldown ≥ 30초 + timeout ≠ 0 + group 다층 키 + 토큰 가드 (`hook-guard.sh`) | notification-hooks.md |
| 15 | launchctl 위생 | plist + 스크립트 동시 관리, exit 127 좀비 자동 검사 (cron 주 1회) | launchctl-hygiene.md |

## 날짜 계산 (CRITICAL)

날짜/시간 암산 금지. `date` 명령어 또는 `python3 -c "from datetime ..."` 사용. 타임존: Asia/Seoul.
deny 규칙의 python3 제한은 os/shutil 등 시스템 모듈 대상. datetime, json은 허용.

## CRITICAL 라벨 정의

`(CRITICAL)`이 붙은 항목은 위반 시 **데이터 손실 / 보안 사고 / 법적 리스크 / 비용 폭주** 중 하나가 발생하는 규칙이다. `IMPORTANT`보다 한 단계 위. 의문이 들면 사용자 확인 먼저, 합리화 금지.

**현재 사용처 (33회 / 26 rules)**: `data-policy` `mcp-token-policy` `image-provider-routing` `email` `saju-file-management` `fastcampus-qa-bot` `civil-law` `mediation` `labor-consultant` `chrome-devtools` `design-extract` `interaction` `verification` `agents-v2` `supabase-mcp` `gws` `personal-os` `sync-all` `first-principles` `performance-marketing` `research` `notion-idempotency` `ledger-sync-protocol` `html-to-pdf-fonts` `default-font-pretendard`. 각 rules의 `(CRITICAL)` 라벨은 본 정의를 적용한다.
