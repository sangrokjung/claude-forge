---
name: team-orchestrator
description: Use when orchestrating Agent Teams for parallel development - team composition, task distribution, dependency management, and result aggregation. Triggers on /orchestrate, multi-agent coordination, parallel team work, task delegation to teammates.
version: 1.1.0
---

## Overview

team-orchestrator 스킬은 `/orchestrate` 커맨드의 핵심 엔진으로,
Agent Teams를 구성하고 작업을 분배하며 결과를 집계하는 오케스트레이션 로직을 정의한다.

## 전제조건

Agent Teams 전제조건(환경변수 설정)은 `reference/agents-teams-ref.md` 참조.

---

## Team Composition

### 팀 크기 결정

최대 팀원 수: Lead 1 + Teammates 3 (총 4명)

| 작업 규모 | 팀원 수 | 구성 |
|-----------|---------|------|
| 소 (파일 1-3개) | 1-2명 | 구현1 (+테스트1) |
| 중 (파일 4-8개) | 2-3명 | 구현1-2 + 테스트1 |
| 대 (파일 9개 이상) | 3명 | 구현2 + 테스트1 또는 패턴별 분리 |

### 역할 템플릿

**풀스택 기능 구현:**
| 역할 | subagent_type | 담당 |
|------|--------------|------|
| Frontend Dev | general-purpose | UI 구현, 컴포넌트 |
| Backend Dev | general-purpose | API, DB, 로직 |
| QA Engineer | general-purpose | 테스트, E2E |

**리팩토링:**
| 역할 | subagent_type | 담당 |
|------|--------------|------|
| Analyzer | Explore | 코드 분석/계획 |
| Implementer | general-purpose | 리팩토링 실행 |
| Verifier | general-purpose | 테스트/검증 |

**버그 조사:**
| 역할 | subagent_type | 담당 |
|------|--------------|------|
| Investigator 1 | Explore | 코드 분석 |
| Investigator 2 | Explore | 로그/환경 분석 |
| Fixer | general-purpose | 수정 구현 |

---

## Task Distribution

### 파일 소유권 분리 (CRITICAL)

같은 파일을 2명이 편집하면 덮어쓰기가 발생한다.
반드시 팀원별로 파일 소유권을 분리한다.

```
파일 소유권 결정 로직:
  1. 변경 예상 파일 목록 생성
  2. 파일별 모듈/도메인 분류
  3. 도메인 단위로 팀원 배정
  4. 공유 파일(types, config)은 한 팀원에게 독점 배정
```

### 작업 분해 규칙

팀원당 5-6개 Task를 배정한다.

| Task 크기 | 판단 기준 | 설명 |
|-----------|----------|------|
| 너무 작음 | 조율 오버헤드 > 이점 | 하나로 합치기 |
| 적절함 | 명확한 결과물이 있는 자체 포함 단위 | 함수, 테스트 파일, 검토 |
| 너무 큼 | 체크인 없이 오래 작동 | 더 작게 분할 |

### 의존성 관리

```
의존성 그래프 생성:
  Task A (types 정의) → Task B (API 구현) → Task C (UI 연동)

  선행 Task가 완료되어야 후행 Task 시작 가능
  순환 의존성 감지 시 경고
```

TaskCreate에서 `addBlockedBy` 필드로 의존성을 설정한다.

---

## Context Inheritance (CRITICAL)

팀원은 프로젝트 컨텍스트(CLAUDE.md, MCP servers, skills)를 자동 로드하지만,
**리더의 대화 기록은 상속하지 않는다.**

따라서 팀원 생성 프롬프트에 반드시 다음을 포함해야 한다:
- 작업 목적과 배경
- 관련 파일 경로
- 기대하는 결과물
- 주의사항/제약사항

```
# 좋은 예시
"Review the authentication module at src/auth/ for security vulnerabilities.
Focus on token handling, session management, and input validation.
The app uses JWT tokens stored in httpOnly cookies."

# 나쁜 예시
"보안 검토 해줘"  ← 팀원은 리더가 논의한 맥락을 모름
```

CLAUDE.md는 정상 작동: 팀원들은 작업 디렉토리에서 CLAUDE.md를 자동으로 읽는다.

---

## Plan Approval Mode

위험하거나 복잡한 작업에서 팀원이 구현 전 계획 승인을 받도록 할 수 있다:

```
Spawn an architect teammate to refactor the auth module.
Require plan approval before they make any changes.
```

동작:
1. 팀원이 읽기 전용 계획 모드에서 시작
2. 계획 완료 시 리더에게 plan_approval_request 발송
3. 리더가 승인 → 팀원이 구현 시작
4. 리더가 거부 (피드백 포함) → 팀원이 계획 수정 후 재제출

리더의 판단 기준을 프롬프트에 제공 가능:
- "테스트 커버리지를 포함하는 계획만 승인"
- "DB 스키마를 수정하는 계획 거부"

---

## Execution Flow

### 1. 분석 단계

```
1. prompt_plan.md / spec.md 읽기
2. 변경 필요 파일 목록 생성
3. 파일별 도메인 분류
4. 작업 복잡도 추정
```

### 2. 팀 구성 단계

```
1. 작업 규모에 따른 팀원 수 결정
2. 역할 템플릿 선택
3. 각 팀원에게 subagent_type 배정
4. 파일 소유권 분리
```

### 3. Task 생성 단계

```
1. TaskCreate로 Task 목록 생성
2. 팀원별 5-6개 Task 배정
3. 의존성 설정 (addBlockedBy)
4. TaskUpdate로 owner 배정
```

### 4. 실행 단계

```
1. 팀원 spawn (SendMessage)
2. 각 팀원이 자신의 Task 수행
3. 리더는 조율만 수행 (직접 구현 금지)
4. 팀원 완료 시 SendMessage로 보고
```

### 4-1. 자체 청구 (Self-Claim)

작업을 마친 팀원은 다음 미할당, 차단되지 않은 작업을 자체적으로 선택한다.
작업 청구는 **파일 잠금**을 사용하여 경합 조건(race condition)을 방지한다.

### 5. 결과 집계 단계

```
1. 모든 팀원의 Task 완료 확인
2. 파일 충돌 여부 검증
3. 통합 빌드/테스트 실행
4. 결과 요약 생성
```

---

## Result Aggregation

### 성공 판단 기준

```
전체 성공 조건:
  1. 모든 Task가 completed 상태
  2. 빌드 성공
  3. 타입 체크 통과
  4. 테스트 통과
```

### 부분 실패 처리

```
부분 실패 시:
  1. 실패한 Task 식별
  2. 실패 원인 분석 (의존성 문제, 파일 충돌 등)
  3. 재배정 또는 리더가 직접 해결
  4. 재시도 (최대 2회)
```

### 집계 출력 형식

```
════════════════════════════════════════════════════════════════
  Team Orchestration Result (v6)
════════════════════════════════════════════════════════════════

  팀원: [N]명
  총 Task: [N]개
  완료: [N]개 | 실패: [N]개

  팀원별 결과:
    [역할 1]: [완료 Task 수]/[배정 Task 수] - [상태]
    [역할 2]: [완료 Task 수]/[배정 Task 수] - [상태]
    [역할 3]: [완료 Task 수]/[배정 Task 수] - [상태]

  빌드: [PASS/FAIL]
  타입: [PASS/FAIL]
  테스트: [PASS/FAIL]

  다음 단계:
    /handoff-verify → /sync-docs → /commit-push-pr --merge --notify
    (sync-docs는 머지 전 의무 — commit-push-pr v7이 게이트 내장)

════════════════════════════════════════════════════════════════
```

---

## Error Recovery

### 팀원 무응답

```
1. SendMessage로 상태 확인 (1회)
2. 5분 초과 시 Task 재배정
3. 필요시 새 팀원 생성
```

### 파일 충돌 감지

```
1. 리더가 git status로 충돌 감지
2. 한 팀원에게 해당 파일 소유권 위임
3. 다른 팀원은 대기 후 진행
```

### Task 의존성 데드락

```
1. 순환 의존성 감지
2. 의존성 체인에서 가장 독립적인 Task 우선 실행
3. 리더가 수동으로 의존성 해소
```

---

## Integration

### /orchestrate 연동

`/orchestrate` 커맨드가 이 스킬을 호출하여:
1. prompt_plan.md 기반 작업 분해
2. 팀 구성 및 Task 배정
3. 실행 및 결과 집계

### /handoff-verify 연동

팀 작업 완료 후 /handoff-verify로 통합 검증을 수행한다.
