---
allowed-tools: Bash(git:*), Read, Write, Glob, Grep, Task, TeamCreate, TaskCreate, TaskUpdate, TaskList, SendMessage
description: Agent Teams 기반 병렬 오케스트레이션 (v6)
argument-hint: "[--type feature|bugfix|refactor|review] [--parallel N] [--dry-run]"
---

# /orchestrate - Agent Teams 기반 병렬 오케스트레이션 (v6)

v5의 worktree 기반 병렬 실행을 **Agent Teams API**로 대체.
TeamCreate, TaskCreate, SendMessage 등을 활용한 네이티브 팀 조율.

## 전제조건 (CRITICAL)

Agent Teams는 **실험적 기능**이며 기본 비활성화 상태이다.
반드시 아래 환경변수를 설정해야 /orchestrate가 동작한다:

```json
// settings.json (프로젝트 또는 글로벌)
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

미설정 시 TeamCreate 등 팀 관련 도구가 사용 불가하다.

### 토큰 비용 경고

Agent Teams는 단일 세션보다 **훨씬 더 많은 토큰**을 사용한다.
각 팀원은 자신의 컨텍스트 윈도우를 가지며, 토큰 사용은 활성 팀원 수에 비례하여 증가한다.

- 연구, 검토, 새 기능 작업 → 추가 토큰의 가치가 있음
- 일상적 작업 → 단일 세션이 더 비용 효율적

## v5 대비 변경사항

| v5 | v6 |
|----|-----|
| git worktree 기반 병렬 | Agent Teams API (TeamCreate, TaskCreate, SendMessage) |
| 파일 시스템 분리 | 태스크 목록 기반 조율 |
| worktree 생성/정리 필요 | 자동 팀 라이프사이클 관리 |
| --effort 플래그 | 제거 (불필요한 복잡성) |
| --graph, --status 플래그 | --status 제거 (TaskList로 대체) |
| --milestone 플래그 | 제거 (task 필터링으로 대체) |

## 0단계: 파라미터 파싱

$ARGUMENTS에서 플래그를 추출한다:

| 플래그 | 기본값 | 설명 |
|--------|--------|------|
| `--dry-run` | false | 실행하지 않고 계획만 출력 |
| `--type` | auto | `feature` / `bugfix` / `refactor` / `review` |
| `--parallel` | 3 | 동시 팀원 수 상한 (최대 3) |

파싱 규칙:
- `--type`이 없으면 prompt_plan.md 키워드로 자동 감지한다.
- `--parallel`은 최대 3 (Agent Teams 제한: 리더 1 + 팀원 최대 3).

## 1단계: 프로젝트 도메인 감지

프로젝트 루트에서 설정 파일을 탐색하여 도메인을 결정한다.

```
탐색 순서 (첫 매칭 우선):
  package.json          → Node.js / TypeScript
  go.mod                → Go
  requirements.txt      → Python
  pyproject.toml        → Python
  Cargo.toml            → Rust
  Makefile (단독)       → Make-based
  *.sln / *.csproj      → .NET
```

감지 결과를 기반으로 도메인별 명령을 설정한다:

| 도메인 | 빌드 명령 | 테스트 명령 | 린트 명령 |
|--------|-----------|------------|-----------|
| Node.js/TS | `pnpm build` | `pnpm test` | `pnpm lint` |
| Go | `go build ./...` | `go test ./...` | `golangci-lint run` |
| Python | `python -m build` | `pytest` | `ruff check .` |
| Rust | `cargo build` | `cargo test` | `cargo clippy` |
| .NET | `dotnet build` | `dotnet test` | `dotnet format --verify-no-changes` |

도메인 감지에 실패하면 사용자에게 명시적으로 질문한다. 추측하지 않는다.

## 2단계: Task 파싱

`prompt_plan.md`에서 미완료 Task를 추출한다.

```
파싱 대상:
  - [ ] Task 설명 (depends: Task N)          → 미완료
  - [x] Task 설명                             → 완료 (스킵)
```

각 Task에서 추출하는 정보:
- Task 번호 / 이름
- depends 필드 (명시적 의존성)
- 관련 파일 경로 (설명에서 추론)
- 예상 복잡도 (라인 수, 파일 수 기반)

## 3단계: 의존성 분석

4가지 유형의 의존성을 분석한다:

### 명시적 의존성 (depends:)
```
- [ ] Task 3: API 엔드포인트 (depends: Task 1, Task 2)
  → Task 1, Task 2 완료 후 실행
```

### 파일 기반 의존성
```
Task A: src/lib/auth.ts 수정
Task B: src/app/api/login/route.ts 수정 (auth.ts import)
  → Task B는 Task A에 의존
```

### 모듈 기반 의존성
```
Task C: 새 모듈 src/lib/payment/ 생성
Task D: src/app/checkout/ 에서 payment 모듈 사용
  → Task D는 Task C에 의존
```

### 독립 Task
```
위 3가지에 해당하지 않는 Task → 병렬 실행 가능
```

의존성 결과를 DAG(Directed Acyclic Graph)로 구성한다.
순환 의존성이 감지되면 오류를 출력하고 중단한다:

```
[ERROR] 순환 의존성 감지:
  Task 3 → Task 5 → Task 3

해결 방법:
  prompt_plan.md에서 depends 필드를 수정하세요.
```

## 4단계: Type별 팀 구성

### Type 자동 감지 (--type 미지정 시)

prompt_plan.md 키워드 분석:
- `새 기능`, `구현`, `추가`, `feature` → `feature`
- `버그`, `수정`, `fix`, `hotfix` → `bugfix`
- `리팩토링`, `정리`, `마이그레이션`, `refactor` → `refactor`
- `리뷰`, `검토`, `분석`, `review` → `review`

### Type별 팀 구성

**feature** (팀원 3명):

| 역할 | subagent_type | 모델 | 담당 |
|------|--------------|------|------|
| Implementer 1 | general-purpose | sonnet | 핵심 기능 구현 |
| Implementer 2 | general-purpose | sonnet | 보조 기능 구현 |
| Tester | general-purpose | sonnet | 테스트 작성 + 리뷰 |

**bugfix** (팀원 2명):

| 역할 | subagent_type | 모델 | 담당 |
|------|--------------|------|------|
| Investigator | Explore | sonnet | 버그 원인 분석 |
| Fixer | general-purpose | sonnet | 수정 + 테스트 |

**refactor** (팀원 3명):

| 역할 | subagent_type | 모델 | 담당 |
|------|--------------|------|------|
| Analyzer | Explore | sonnet | 코드 분석 + 계획 |
| Implementer | general-purpose | sonnet | 리팩토링 실행 |
| Verifier | general-purpose | sonnet | 테스트 + 검증 |

**review** (팀원 3명):

| 역할 | subagent_type | 모델 | 담당 |
|------|--------------|------|------|
| Security Reviewer | Explore | sonnet | 보안 분석 |
| Performance Reviewer | Explore | sonnet | 성능 분석 |
| Quality Reviewer | Explore | sonnet | 코드 품질 분석 |

## 5단계: Wave 그룹화

의존성 DAG를 기반으로 Task를 Wave(동시 실행 그룹)로 나눈다.

```
Wave 1: [Task 1, Task 2, Task 4]     ← 의존성 없음, 병렬 실행
Wave 2: [Task 3]                      ← Task 1, 2에 의존
Wave 3: [Task 5, Task 6]             ← Task 3, 4에 의존
```

Wave별 제약:
- 동시 팀원 수는 `--parallel` 값 이하로 유지한다 (최대 3).
- 같은 파일을 수정하는 Task는 같은 Wave에 배치하지 않는다.
- Wave 내 Task 수가 `--parallel`을 초과하면 sub-wave로 분할한다.

## 6단계: 실행 모드

### --dry-run 모드

계획만 출력하고 실행하지 않는다:

```
════════════════════════════════════════════════════════════════
  Orchestration Engine v6 (type: feature)
  Agent Teams API
════════════════════════════════════════════════════════════════

  Domain: Node.js/TypeScript (pnpm)
  Tasks: 6 pending, 2 completed
  Waves: 3
  Team: Implementer 1 + Implementer 2 + Tester

Wave 1 (parallel: 3)
  Task 1: 인증 모듈 구현       → Implementer 1
  Task 2: DB 스키마 설정        → Implementer 2
  Task 4: 설정 파일 생성        → Tester (구현 겸)

Wave 2 (parallel: 1)
  Task 3: API 엔드포인트        → Implementer 1

Wave 3 (parallel: 2)
  Task 5: 프론트 연동           → Implementer 1
  Task 6: E2E 테스트            → Tester

════════════════════════════════════════════════════════════════

다음 단계:
  --dry-run 제거하고 다시 실행하면 Wave 1부터 시작합니다.
════════════════════════════════════════════════════════════════
```

### 실행 모드 (기본)

Agent Teams API를 사용하여 실제 실행한다:

**Step 1: 팀 생성**
```
TeamCreate → 팀 생성
```

**Step 2: 태스크 생성 (의존성 포함)**
```
TaskCreate → Wave 1 태스크들 (blockedBy 없음)
TaskCreate → Wave 2 태스크들 (blockedBy: Wave 1 태스크)
TaskCreate → Wave 3 태스크들 (blockedBy: Wave 2 태스크)
```

**Step 3: 팀원 생성 (Task 도구)**
```
Task → Implementer 1 (general-purpose, sonnet)
Task → Implementer 2 (general-purpose, sonnet)
Task → Tester (general-purpose, sonnet)
```

**Step 4: 태스크 배정**
```
TaskUpdate → Task 1 owner: Implementer 1
TaskUpdate → Task 2 owner: Implementer 2
TaskUpdate → Task 4 owner: Tester
```

**Step 5: 팀원 작업 수행**

각 팀원은:
1. TaskList로 자신의 태스크 확인
2. TaskGet으로 상세 정보 읽기
3. 작업 수행 (코드 구현/테스트/리뷰)
4. TaskUpdate로 완료 표시
5. SendMessage로 리더에게 결과 보고
6. 다음 unblocked 태스크를 **자체 청구(self-claim)** 후 진행

자체 청구 메커니즘:
- 작업을 마친 팀원은 다음 미할당, 차단되지 않은 작업을 자체적으로 선택
- 작업 청구는 **파일 잠금**을 사용하여 경합 조건(race condition)을 방지

컨텍스트 상속 주의 (CRITICAL):
- 팀원은 프로젝트 컨텍스트(CLAUDE.md, MCP servers, skills)를 자동으로 로드
- 단, **리더의 대화 기록은 상속하지 않음**
- 따라서 팀원 생성 프롬프트에 작업별 세부 사항을 반드시 포함해야 함
- CLAUDE.md는 정상적으로 작동: 팀원들은 작업 디렉토리에서 CLAUDE.md를 읽음

파일 소유권 분리 규칙:
- 리더가 태스크 배정 시 파일 소유권 명시
- 같은 파일을 2명이 편집하지 않도록 분리
- 충돌 감지 시 리더가 조정

**Step 6: Wave 완료 후 다음 Wave**

Wave 내 모든 태스크가 완료되면:
1. 리더가 결과 확인
2. 다음 Wave의 태스크가 자동으로 unblocked
3. 팀원에게 다음 태스크 배정

**Step 7: 전체 완료 후 정리**
```
SendMessage (shutdown_request) → 모든 팀원
TeamDelete → 팀 정리
```

## 7단계: 완료 리포트

모든 Wave가 완료되면 최종 리포트를 출력한다.

```
════════════════════════════════════════════════════════════════
  Orchestration Complete (v6)
════════════════════════════════════════════════════════════════

  Type: feature | Domain: Node.js/TypeScript
  Team: Implementer 1 + Implementer 2 + Tester

결과 요약:
  Tasks 완료: 6/6
  Waves 실행: 3
  팀원: 3명 (모두 종료됨)

태스크별 결과:
  Task 1: 인증 모듈 구현       → Implementer 1   DONE
  Task 2: DB 스키마 설정        → Implementer 2   DONE
  Task 3: API 엔드포인트        → Implementer 1   DONE
  Task 4: 설정 파일 생성        → Tester          DONE
  Task 5: 프론트 연동           → Implementer 1   DONE
  Task 6: E2E 테스트            → Tester          DONE

════════════════════════════════════════════════════════════════

다음 단계:
  /handoff-verify                검증
  /sync-docs                     문서 동기화
  /web-checklist                 수동 테스트 체크리스트 생성
════════════════════════════════════════════════════════════════
```

## 오류 처리

### 팀원 태스크 실패 시

1. 팀원이 SendMessage로 실패 보고
2. 리더가 판단:
   - Fixable: 팀원에게 수정 지시 (SendMessage)
   - Non-fixable: 태스크 재배정 또는 중단 판단
3. 같은 Wave의 다른 팀원은 계속 진행

### 팀원 무응답 시

1. SendMessage로 상태 확인
2. 5분 초과 시 태스크 재배정
3. 필요시 새 팀원 생성

### 파일 소유권 충돌 시

1. 리더가 충돌 감지 (같은 파일 2명 편집 시도)
2. 한 팀원에게 해당 파일 소유권 위임
3. 다른 팀원은 대기 후 진행

### 순환 의존성 감지 시

```
[ERROR] 순환 의존성 감지:
  Task 3 → Task 5 → Task 3

해결 방법:
  prompt_plan.md에서 depends 필드를 수정하세요.
```

## 사용 예시

```bash
# 기본 (자동 타입 감지, 팀원 3명)
/orchestrate

# 기능 구현 모드 (dry-run)
/orchestrate --type feature --dry-run

# 버그 수정 모드 (팀원 2명)
/orchestrate --type bugfix

# 리팩토링 모드 (팀원 3명)
/orchestrate --type refactor

# 코드 리뷰 모드
/orchestrate --type review

# 병렬 수 제한
/orchestrate --type feature --parallel 2
```

## 주의사항

- Agent Teams는 최대 리더 1 + 팀원 3으로 제한된다.
- 파일 소유권 분리는 필수이다. 같은 파일을 2명이 편집하면 덮어쓰기가 발생한다.
- 리더는 위임 모드(**Shift+Tab**으로 활성화)로 조율만 한다. 직접 구현하지 않는다.
- 모든 팀원 shutdown 후 TeamDelete를 실행한다.
- v5의 worktree 기반 명령 (`git worktree add` 등)은 더 이상 사용하지 않는다.
- broadcast는 비용이 팀 크기에 비례하여 증가하므로 **긴급한 경우에만** 사용한다.

## 표시 모드 (teammateMode)

팀원 표시 모드는 settings.json의 `teammateMode`로 설정한다:

| 모드 | 설명 | 요구사항 |
|------|------|----------|
| `"auto"` (기본) | tmux 세션 내이면 분할 창, 아니면 in-process | 없음 |
| `"in-process"` | 메인 터미널 내에서 실행. Shift+Up/Down으로 전환 | 없음 |
| `"tmux"` | 각 팀원이 별도 창. 터미널에 따라 tmux/iTerm2 자동 감지 | tmux 또는 iTerm2 (it2 CLI + Python API) |

```json
// settings.json
{ "teammateMode": "tmux" }
```

CLI 플래그: `claude --teammate-mode in-process`

분할 창 미지원: VS Code 통합 터미널, Windows Terminal, Ghostty

## 제한사항

| 제한사항 | 설명 |
|----------|------|
| 세션 재개 불가 | `/resume`, `/rewind`는 in-process 팀원을 복원하지 않음 |
| 세션당 1팀 | 새 팀 시작 전 현재 팀 정리 필수 |
| 중첩 팀 불가 | 팀원은 하위 팀이나 팀원을 생성할 수 없음 |
| 리더 고정 | 리더십 이전 또는 팀원 승격 불가 |
| 생성 시 권한 개별 설정 불가 | 모든 팀원은 리더의 권한 모드로 시작. 생성 후 개별 변경 가능 |
| 종료 지연 가능 | 팀원은 현재 요청/도구 호출 완료 후 종료 |
| 작업 상태 지연 가능 | 팀원이 완료 표시를 누락하여 종속 작업이 차단될 수 있음 |
| 분할 창 제한 | tmux 또는 iTerm2 필요. VS Code, Ghostty 등 미지원 |

## 문제 해결

### 팀원이 나타나지 않음
1. In-process 모드: **Shift+Down**으로 활성 팀원 순환
2. 작업이 팀을 필요로 할 만큼 복잡한지 확인
3. 분할 창 요청 시: `which tmux`로 tmux 설치 확인
4. iTerm2: `it2` CLI 설치 + Python API 활성화 확인

### 너무 많은 권한 프롬프트
- 팀원 생성 전 [권한 설정]에서 일반적인 작업을 사전 승인
- 팀원은 리더의 권한 설정을 상속

### 팀원이 오류로 중지
1. Shift+Up/Down (in-process) 또는 창 클릭 (분할) 으로 출력 확인
2. 추가 지시 사항 직접 제공
3. 대체 팀원 생성으로 작업 계속

### 리더가 작업 완료 전 종료
- "Wait for your teammates to complete their tasks" 입력
- 위임 모드(Shift+Tab) 활성화로 리더의 직접 구현 방지

### 고아 tmux 세션
```bash
tmux ls
tmux kill-session -t <session-name>
```
