---
allowed-tools: Bash(git:*), Bash(npm:*), Bash(pnpm:*), Bash(npx:*), Bash(go:*), Bash(cargo:*), Bash(make:*), Bash(python:*), Bash(curl:*), Read, Write, Edit, Glob, Grep, Task, Skill(sync-docs), Skill(commit-push-pr), Skill(handoff-verify), Skill(quick-commit)
description: 계획부터 PR까지 원버튼 자동 실행. 중간에 멈추지 않습니다.
argument-hint: "[작업 설명] [--mode feature|bugfix|refactor] [--no-notify] [--no-branch] [--no-security]"
---

# /auto - 원스톱 자동 워크플로우 (v7)

개별 커맨드를 하나씩 호출하는 대신, 전체 파이프라인을 한 번에 자동 실행합니다.
CRITICAL 보안 이슈에서만 중단하며, 그 외에는 끝까지 진행합니다.

---

## 0단계: 인자 파싱

$ARGUMENTS에서 옵션을 추출한다:

| 인자 | 기본값 | 설명 |
|------|--------|------|
| `--mode` | feature | 실행 모드: feature / bugfix / refactor |
| `--no-notify` | false | Moshi 알림 비활성화 |
| `--no-branch` | false | 브랜치 자동 생성 비활성화 |
| `--no-security` | false | security-scan 단계 스킵 |
| `--autonomous` | false | plan.md 자율 승인 + 방향 확인 자동 처리. 5줄+ 구체적 브리프 권장. Security ≥ 4 필수, CRITICAL 시 즉시 중단 |
| 나머지 텍스트 | - | 작업 설명 (필수) |

작업 설명이 없으면 에러를 출력하고 종료한다:

```
사용법: /auto [작업 설명] [옵션]

예시:
  /auto 로그인 페이지 만들기
  /auto --mode bugfix 결제 금액이 0원으로 표시되는 버그
  /auto --mode refactor 인증 모듈 정리
  /auto 결제 기능 추가 --no-notify
```

---

## 1단계: 모드별 파이프라인 결정

### feature 모드 (기본)

```
env-check -> plan -> tdd -> code-review -> simplify -> security-scan -> handoff-verify -> sync-docs -> commit-push-pr --merge -> notify
```

1. **env-check**: 브랜치 확인. main/master면 feature 브랜치 자동 생성.
2. **plan**: 구현 계획 수립. 사용자 확인 없이 자동 확정.
3. **tdd**: 테스트 먼저 작성 후 구현. RED -> GREEN -> IMPROVE 사이클.
4. **code-review**: 작성한 코드의 보안 + 품질 검사. CRITICAL/HIGH 이슈는 자동 수정.
5. **simplify** (v8 신설, 2026-04-17): `/simplify` 스킬 실행. code-review 후 정돈된 코드에서 중복·과도한 추상화·불필요한 코드를 제거. 실패 시 `--skip-simplify` 폴백으로 자동 넘어감(파이프라인 중단 아님). 참조: `~/qjc-office/dotclaude/plans/zesty-stirring-stream.md` §3·§6.
6. **security-scan**: security-reviewer 에이전트로 OWASP Top 10 스캔. simplify 후 재검증하여 단순화로 인한 보안 이슈 없는지 확인. CRITICAL 발견 시 자동 수정 시도.
7. **handoff-verify**: 빌드/테스트/린트 자동 검증. 실패 시 3단계 에스컬레이션 (자동 수정 → Opus 에이전트 → Telegram Hard Block).
8. **sync-docs**: 문서 동기화 (prompt_plan.md, spec.md, CLAUDE.md + rules/). **머지 전 의무 게이트 (CRITICAL)** — Skill 도구로 실제 `/sync-docs` 스킬을 실행한다 (인라인 요약 대체 금지). 실패 시 머지 진행 금지.
9. **commit-push-pr --merge**: 커밋 메시지 자동 생성, 푸시, PR 생성, 자동 머지 (feature branch에서만). v7부터 sync-docs 게이트 내장 — 8단계가 이미 실행됐으면 중복 실행 없이 통과.
10. **notify**: Moshi webhook + Telegram으로 완료/실패 알림 발송.

> **simplify 폴백 규칙**: /simplify 스킬 실행 중 3개 이상 파일에서 린트/타입 에러 발생 시, 변경 롤백 후 `skip-simplify` 플래그로 다음 단계 진행. `pipeline-metrics.jsonl`에 `simplify_skipped=true`로 기록. 2주간 실패율 > 10% 시 opt-in 방식으로 롤백 검토.

### bugfix 모드

```
env-check -> explore -> tdd -> handoff-verify -> sync-docs -> quick-commit -> notify
```

1. **env-check**: 브랜치 확인. main/master면 fix 브랜치 자동 생성.
2. **explore**: 관련 코드 탐색으로 버그 원인 파악.
3. **tdd**: 버그를 재현하는 테스트 작성 후 수정.
4. **handoff-verify**: 빌드/테스트 검증 (--once 모드).
5. **sync-docs**: 문서 동기화 (prompt_plan.md, spec.md, CLAUDE.md + rules/). Skill 도구로 실제 `/sync-docs` 스킬을 실행 — 커밋 전 의무.
6. **quick-commit**: 자동 생성된 커밋 메시지로 빠른 커밋 + 푸시.
7. **notify**: Moshi webhook으로 완료/실패 알림 발송.

### refactor 모드

```
env-check -> refactor-clean -> code-review -> handoff-verify -> sync-docs -> commit-push-pr --merge -> notify
```

1. **env-check**: 브랜치 확인. main/master면 refactor 브랜치 자동 생성.
2. **refactor-clean**: 사용하지 않는 코드, 중복 제거, 구조 개선.
3. **code-review**: 리팩토링 결과 검사.
4. **handoff-verify**: 기존 기능이 깨지지 않았는지 검증.
5. **sync-docs**: 문서 동기화 (prompt_plan.md, spec.md, CLAUDE.md + rules/). **머지 전 의무 게이트 (CRITICAL)** — Skill 도구로 실제 `/sync-docs` 스킬을 실행한다. 실패 시 머지 진행 금지.
6. **commit-push-pr --merge**: 커밋 메시지 자동 생성, 푸시, PR 생성, 자동 머지 (refactor branch에서만). v7부터 sync-docs 게이트 내장.
7. **notify**: Moshi webhook + Telegram으로 완료/실패 알림 발송.

---

## 2단계: 환경 확인 (env-check)

파이프라인 시작 전 기본 환경을 확인한다:

1. Git 레포 확인 (`git rev-parse --is-inside-work-tree`)
2. 프로젝트 타입 감지 (package.json / go.mod / Cargo.toml / pyproject.toml)
3. 패키지 매니저 감지 (pnpm-lock.yaml / yarn.lock / bun.lockb / npm)
4. **브랜치 확인** (`git branch --show-current`)
   - main 또는 master에 있으면 자동으로 브랜치 생성:
     - feature 모드: `feat/<kebab-case-description>`
     - bugfix 모드: `fix/<kebab-case-description>`
     - refactor 모드: `refactor/<kebab-case-description>`
   - `--no-branch` 플래그가 있으면 브랜치 생성 스킵
   - 이미 feature/fix/refactor 브랜치에 있으면 그대로 사용

Git 레포가 아니면 안내 후 중단.

---

## 3단계: 파이프라인 실행

각 단계를 순차적으로 실행한다.
중간에 멈추지 않는다.

### 단계 전환 규칙

- 각 단계 완료 후 즉시 다음 단계로 진행한다.
- 사용자 확인을 요청하지 않는다.
- CRITICAL 보안 이슈 발견 시에만 중단하고 사용자에게 보고한다.

### plan 단계 자동 확정 (feature 모드)

일반적으로 `/plan`은 사용자 확인을 기다리지만, `/auto` 모드에서는:
1. 계획을 수립한다.
2. 계획을 출력한다 (사용자가 볼 수 있도록).
3. 자동으로 확정하고 다음 단계로 진행한다.

### Definition of Done 자동 생성

plan 확정 후, `.claude/handoff.md`에 DoD 체크리스트를 자동 생성한다:

```markdown
## Definition of Done
- [ ] 빌드 성공 (프로젝트 빌드 명령어)
- [ ] 테스트 통과 (프로젝트 테스트 명령어)
- [ ] 린트 통과 (프로젝트 린트 명령어)
- [ ] 커버리지 80%+ (해당 시)
- [ ] 보안 스캔 통과 (CRITICAL 0건)
- [ ] 기존 기능 회귀 없음
- [ ] 에스컬레이션 없이 완료 (Stage 1에서 해결)
```

handoff-verify 단계에서 이 체크리스트를 기준으로 검증한다.

### security-scan 단계 (feature 모드)

code-review 이후, handoff-verify 이전에 실행:
1. security-reviewer 에이전트를 Task로 실행 (fresh context).
2. OWASP Top 10 항목 기준으로 변경된 파일을 스캔.
3. CRITICAL 발견 시 자동 수정을 시도하고, 수정 불가 시 중단.
4. HIGH/MEDIUM 이슈는 로그에 기록하고 계속 진행.
5. `--no-security` 플래그가 있으면 이 단계를 스킵.

### 에러 처리

- **Fixable 에러** (린트, import, 타입 단순 오류): 자동 수정 후 계속 진행.
- **Non-fixable 에러** (로직 오류, 아키텍처 문제): 3단계 에스컬레이션 체인 실행:
  1. Stage 1: 현재 컨텍스트에서 최대 3회 자동 수정 시도
  2. Stage 2: build-error-resolver (Sonnet) → escalation-fixer (Opus) 순차 호출
  3. Stage 3: 모두 실패 시 Telegram Hard Block 알림 + 작업 중단
  - 에스컬레이션 이력은 `~/.claude/escalation-log.json`에 자동 기록됨
- **CRITICAL 보안 이슈**: 즉시 중단, 사용자에게 보고.

### notify 단계

파이프라인 최종 단계. `--no-notify` 플래그가 없으면 Moshi webhook으로 알림 발송:

**성공 시:**
```bash
curl -s -X POST https://api.getmoshi.app/api/webhook \
  -H "Content-Type: application/json" \
  -d "{\"token\": \"$MOSHI_WEBHOOK_TOKEN\", \"title\": \"Done\", \"message\": \"Auto v7 [mode]: [작업 설명 요약]\"}"
```

**실패 시:**
```bash
curl -s -X POST https://api.getmoshi.app/api/webhook \
  -H "Content-Type: application/json" \
  -d "{\"token\": \"$MOSHI_WEBHOOK_TOKEN\", \"title\": \"Error\", \"message\": \"Auto v7 [mode] failed at [단계]: [에러 요약]\"}"
```

---

## 4단계: 결과 요약

전체 파이프라인이 완료되면 한 번에 요약을 출력한다:

### 성공 시

```
======================================================================
  Auto Complete (v7) - [mode] 모드
======================================================================

  작업: [작업 설명]
  브랜치: [브랜치명]

  실행 결과:
    [0] Env Check      DONE   [브랜치명] (자동 생성 / 기존 사용)
    [1] Plan           DONE   [N]개 단계 계획
    [2] TDD            DONE   [N]개 테스트, [N]% 커버리지
    [3] Code Review    DONE   CRITICAL 0 / HIGH 0
    [4] Security Scan  DONE   이슈 없음
    [5] Verify         PASS   빌드+테스트+린트 통과
    [6] Sync Docs      DONE   prompt_plan.md, CLAUDE.md 동기화
    [7] Commit & PR    DONE   PR #[번호]: [URL] (auto-merged)
    [8] Notify         SENT   Moshi + Telegram 알림 발송 완료

======================================================================
```

### 부분 실패 시

```
======================================================================
  Auto Incomplete (v7) - [mode] 모드
======================================================================

  작업: [작업 설명]
  브랜치: [브랜치명]

  실행 결과:
    [0] Env Check      DONE
    [1] Plan           DONE
    [2] TDD            DONE
    [3] Code Review    WARN   HIGH 2건 (자동 수정됨)
    [4] Security Scan  WARN   MEDIUM 1건 (기록됨)
    [5] Verify         FAIL   테스트 2개 실패
    [6] Sync Docs      SKIP   (검증 실패로 스킵)
    [7] Commit & PR    SKIP   (검증 실패로 스킵)
    [8] Notify         SENT   실패 알림 발송

  실패 상세:
    - src/auth.ts:45 - 타입 불일치 (자동 수정 실패)
    - src/auth.test.ts:30 - 예상값 불일치

  수동 수정 후:
    /handoff-verify -> /sync-docs -> /commit-push-pr --merge

======================================================================
```

---

## 사용 예시

```bash
# 새 기능 (기본 모드)
/auto 로그인 페이지 만들기

# 버그 수정
/auto --mode bugfix 결제 금액이 0원으로 표시되는 버그

# 코드 정리
/auto --mode refactor 인증 모듈 정리

# 알림 없이 실행
/auto 결제 기능 추가 --no-notify

# 브랜치 자동 생성 없이
/auto --mode bugfix 로그인 실패 버그 --no-branch

# 보안 스캔 스킵
/auto 내부 유틸 함수 추가 --no-security

# 복합 플래그
/auto 사용자 프로필 기능 --no-notify --no-security
```

---

## 주의사항

- `/auto`는 각 단계의 세부 동작을 개별 커맨드(`/plan`, `/tdd` 등)에 위임합니다.
- 중간 과정이 모두 출력되므로 진행 상황을 실시간으로 확인할 수 있습니다.
- CRITICAL 보안 이슈 외에는 멈추지 않으므로, 민감한 작업은 개별 커맨드를 사용하세요.
- 각 단계를 더 세밀하게 제어하고 싶다면 개별 커맨드를 순서대로 사용하세요.
- main/master 브랜치에서 실행하면 자동으로 feature 브랜치를 생성합니다 (`--no-branch`로 비활성화 가능).
