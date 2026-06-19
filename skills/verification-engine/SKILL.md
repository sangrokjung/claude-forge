---
name: verification-engine
description: Use when verifying build/test/lint before commit, PR, or completion claims. Runs verification pipeline in fresh subagent context with auto-repair. Triggers on /handoff-verify, pre-commit check, build verification, test validation.
version: 2.0.0
---

## 검증 원칙

Iron Law, Gate Function, Common Failures 체크리스트는 `rules/verification.md`에 정의되어 있다.
이 스킬은 해당 원칙의 **실행 엔진**이다.

---

## Overview

통합 검증 엔진 스킬은 `/handoff-verify` 커맨드의 핵심 동작을 정의한다.
v5의 `/verify` 단독 커맨드에서 v6의 `/handoff-verify` 통합 커맨드로 진화하였다.

핵심 변경: **Task 도구로 verify-agent 서브에이전트를 생성하여 fresh context에서 검증.**
`/clear` 없이도 편향 없는 검증이 가능하다.

---

## Trigger Conditions

### 직접 호출

| 트리거 | 설명 |
|--------|------|
| `/handoff-verify` | 핸드오프 + 기본 루프 검증 (최대 5회) |
| `/handoff-verify --once` | 핸드오프 + 단발 검증 |
| `/handoff-verify --loop 3` | 핸드오프 + 3회 루프 |
| `/handoff-verify --security` | 핸드오프 + 보안 검증 포함 |
| `/handoff-verify --coverage` | 핸드오프 + 테스트 커버리지 분석 |
| `/handoff-verify --extract` | 핸드오프 + 에러 추출/분류 모드 |
| `/handoff-verify --skip-handoff` | 핸드오프 생략 + 검증만 |

### 자동 호출

| 상황 | 동작 |
|------|------|
| `/commit-push-pr` 실행 전 | `--once` 모드로 사전 검증 |
| `/orchestrate` 검증 단계 | 루프 모드로 자동 실행 |

---

## Architecture (v6)

```
/handoff-verify 커맨드 (부모 컨텍스트)
   │
   ├── [1] handoff.md 자동 생성
   │     └── git diff 분석, 변경 의도 문서화
   │
   ├── [2] verify-agent 서브에이전트 생성 (Task 도구)
   │     └── Fresh context! (/clear 대체)
   │         │
   │         ├── handoff.md 읽기
   │         ├── 검증 파이프라인 실행
   │         ├── 실패 시 자동 수정 + 재시도
   │         └── 결과 반환
   │
   └── [3] 결과 수신 및 처리
         ├── PASS → handoff.md 정리, 다음 단계 안내
         └── FAIL → 에러 보고, 권장 조치 안내
```

### v5 대비 아키텍처 변경

| v5 | v6 |
|----|-----|
| /handoff → /clear → /verify | /handoff-verify (단일 커맨드) |
| 부모 컨텍스트에서 직접 검증 | 서브에이전트가 fresh context에서 검증 |
| /clear로 컨텍스트 손실 | 부모 컨텍스트 보존 |
| 수동 3단계 워크플로우 | 자동 1단계 워크플로우 |

---

## Verification Pipeline

### 단계별 실행 순서 (verify-agent 내부)

```
[1단계] 환경 파악
   ├── handoff.md 읽기 (변경 의도)
   ├── git status / diff
   ├── 프로젝트 타입 감지
   └── 패키지 매니저 감지
         │
[2단계] 빌드 검증
   ├── npm run build / go build / cargo build
   └── 빌드 실패 시 → Fixable 자동 수정
         │
[3단계] 타입 검사
   ├── tsc --noEmit / mypy / go vet
   └── 타입 오류 → Fixable 자동 수정
         │
[4단계] 린트 검사
   ├── eslint / golangci-lint / clippy
   └── 린트 오류 → Fixable 자동 수정
         │
[5단계] 테스트 실행
   ├── npm test / go test / cargo test
   └── 실패 시 → 에러 분석 + 수정 시도
         │
[6단계] 코드 리뷰 (effort에 따라)
   ├── low: 건너뜀
   ├── medium: 변경 파일만
   ├── high: 변경 파일 + 의존성
   └── max: 전체 영향 분석
         │
[7단계] 보안 검토 (--security 또는 effort:max)
   └── security-reviewer 서브에이전트 연동
```

### 루프 동작 원리

```
[실행 #1]
   │ FAIL → Fixable 자동 수정 → 재실행
   │
[실행 #2]
   │ FAIL → Fixable 자동 수정 → 재실행
   │
[실행 #3~5]
   │ FAIL → 수정 시도 → 재실행
   │
[5회 실패]
   └── /learn --from-error 제안
       최종 에러 리포트 → 부모에게 반환
```

---

## Fixable Auto-Repair

자동 수정 가능한 오류 9가지. 서브에이전트가 사용자 승인 없이 즉시 수정한다.

### Fixable 목록

| # | 유형 | 감지 패턴 | 수정 방법 |
|---|------|-----------|-----------|
| 1 | Missing Import | `Cannot find module`, `is not defined` | 소스 검색 → import 문 추가 |
| 2 | Unused Import | `is defined but never used` | import 행 제거 |
| 3 | Lint (auto-fixable) | eslint `--fix` 가능 항목 | `eslint --fix` 실행 |
| 4 | Type Mismatch | `Type '...' is not assignable` | 타입 캐스팅 또는 인터페이스 수정 |
| 5 | Missing Return Type | `Missing return type` | 반환값에서 타입 추론 → 추가 |
| 6 | Formatting | prettier / gofmt | 포매터 실행 |
| 7 | Missing Dependency | `Could not resolve` | package.json 확인 → 설치 제안 |
| 8 | Enum/Const Mismatch | Exhaustive check 실패 | 누락 케이스 추가 |
| 9 | Test Snapshot | `Snapshot mismatch` | 스냅샷 업데이트 제안 (승인 필요) |

### 수정 불가 항목 (사용자 판단 필요)

- 로직 오류 (비즈니스 로직 변경)
- 아키텍처 변경이 필요한 타입 오류
- 테스트 로직 자체의 오류
- 보안 취약점 (security-pipeline이 처리)

---

## Effort별 동작 차이

| effort | 빌드/타입/린트 | 테스트 | 코드 리뷰 | 보안 | 자동 수정 |
|--------|---------------|--------|-----------|------|-----------|
| low | 실행 | 실행 | 건너뜀 | 건너뜀 | import/lint만 |
| medium | 실행 | 실행 | 변경 파일만 | 패턴 매칭만 | Fixable 전체 |
| high | 실행 | 실행 | + 의존성 | 주요 패턴 | Fixable + 제안 |
| max | 실행 | 실행 | + 전체 영향 | security-reviewer | Fixable + 아키텍처 |

---

## Coverage Mode (--coverage)

`/handoff-verify --coverage` 실행 시 테스트 커버리지를 분석한다.

### 출력 형식

```
커버리지 리포트
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
전체:      72.3% (목표: 80%)
신규 코드:  45.2%
미커버 파일: 3개
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

미커버 함수:
  src/utils/parser.ts:parseConfig (0%)
  src/api/handler.ts:processRequest (12%)
  src/lib/cache.ts:invalidate (0%)

권장 테스트:
  1. parseConfig - 정상/비정상 입력 테스트
  2. processRequest - 요청/응답 통합 테스트
  3. invalidate - 캐시 무효화 단위 테스트
```

---

## Extract Mode (--extract)

`/handoff-verify --extract` 실행 시 에러를 추출하고 분류한다.

### 분류 체계

| 카테고리 | 설명 | 예시 |
|----------|------|------|
| BUILD | 빌드/컴파일 오류 | Module not found |
| TYPE | 타입 시스템 오류 | Type mismatch |
| LINT | 린트/스타일 오류 | Unexpected any |
| TEST | 테스트 실패 | Expected X, received Y |
| RUNTIME | 런타임 오류 | Cannot read property |
| SECURITY | 보안 패턴 | Hardcoded credential |

### 출력 형식

```
에러 추출 결과
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
총 에러: 12개
  BUILD:    3개 (Fixable: 2)
  TYPE:     4개 (Fixable: 3)
  LINT:     2개 (Fixable: 2)
  TEST:     2개 (Fixable: 0)
  SECURITY: 1개 (Fixable: 0)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
자동 수정 가능: 7/12 (58%)
```

---

## Integration Points

### /handoff-verify 커맨드

이 스킬은 `/handoff-verify` 커맨드의 핵심 로직을 정의한다.
커맨드 파일(`commands/handoff-verify.md`)이 이 스킬의 파이프라인을 실행한다.

### verify-agent 에이전트

서브에이전트(`agents/verify-agent.md`)가 이 스킬의 파이프라인을 실제로 실행한다.
부모 컨텍스트와 분리된 fresh context에서 동작한다.

### security-pipeline 스킬

`--security` 플래그 또는 effort:max 시 `security-pipeline` 스킬과 연동한다.
보안 검증 부분은 security-pipeline에 위임한다.

### /learn 커맨드

5회 루프 실패 시 `/learn --from-error`를 자동 제안하여
에러 패턴을 CLAUDE.md에 기록한다.

### /commit-push-pr 커맨드

커밋 전 사전 검증 게이트로 동작한다:
- PASS: 모든 검증 통과 → 커밋 진행
- WARN: 비치명적 이슈 존재 → 경고 후 계속
- FAIL: 빌드/타입/테스트 실패 → 커밋 차단
