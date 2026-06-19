# Sub-agents 상세 가이드

## 개요

Sub-agents는 메인 에이전트가 스폰하는 별도의 Claude 인스턴스. Task tool을 통해 스폰되며, 복잡한 작업을 자율적으로 처리.

---

## 에이전트 유형

| 유형 | 도구 | 컨텍스트 상속 | 용도 |
|------|------|---------------|------|
| `general-purpose` | 전체 | ✅ 상속 | 복잡한 멀티스텝 작업 |
| `Explore` | Read-only | ❌ 새 slate | 빠른 코드베이스 검색 |
| `Plan` | 전체 | ✅ 상속 | 구현 계획 설계 |
| `claude-code-guide` | Read, WebSearch | - | Claude Code 질문 |

### Explore 에이전트

**특징**: 파일 생성/수정 엄격히 금지, 읽기 전용

**프롬프트**:
```
Launch explore agent with Sonnet 4.5
```

모델 지정으로 Haiku 대신 Sonnet 사용 가능.

### 컨텍스트 상속 주의

> 모델이 관련 파일 각각을 직접 거치는 것이 중요합니다. Explore 에이전트는 요약을 반환하므로 손실 압축일 수 있음. 중요한 세부사항은 Opus가 직접 읽게 하기.

---

## Task Tool 사용하지 말아야 할 때

- 특정 파일 경로 읽기 → Read 또는 Glob 사용
- 특정 클래스 정의 검색 → Glob 사용
- 2-3개 파일 내 코드 검색 → Read 사용

---

## 병렬 Sub-agents

### 핵심 제약

| 항목 | 값 |
|------|-----|
| 최대 동시 실행 | **10개** |
| 초과 시 동작 | 큐잉 (대기열) |
| 처리 방식 | **배치 단위** |

### 배치 처리 동작

```
요청: 20개 태스크를 4개 병렬로 실행

실제 동작:
├── Batch 1: Task 1-4 동시 실행 → 완료 대기
├── Batch 2: Task 5-8 동시 실행 → 완료 대기
└── ... (모든 배치 완료될 때까지)
```

**중요**: 개별 태스크 완료 시 즉시 다음 시작하는 스트리밍 방식이 **아님**.

### 의존성 그룹화 (필수)

병렬 처리 전 **반드시** 의존성 충돌 없는 태스크 그룹화 필요.

```
❌ 잘못된 예: 로그인 테스트 + 로그인 후 프로필 수정 테스트 병렬 실행
✅ 올바른 예: 독립적인 페이지 테스트들 병렬 실행
```

---

## Agent Teams (v6)

> Git Worktree 기반 병렬 개발은 레거시. Agent Teams가 팀 생성/정리를 자동 처리.

### 전제조건

`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`를 `1`로 설정:

```json
// ~/.claude/settings.json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

### Subagents vs Agent Teams

| | Subagents | Agent Teams |
|---|---|---|
| 컨텍스트 | 자체 윈도우; 결과만 호출자에 반환 | 자체 윈도우; 완전 독립 |
| 통신 | 메인 에이전트에게만 보고 | 팀원끼리 직접 메시지 |
| 조율 | 메인 에이전트가 관리 | 공유 작업 목록으로 자체 조율 |
| 최적 용도 | 결과만 중요한 집중 작업 | 논의/협업이 필요한 복잡한 작업 |
| 토큰 비용 | 낮음 (결과 요약) | 높음 (각 팀원 별도 인스턴스) |

### 사용법

```bash
/orchestrate --type feature   # 기능 구현
/orchestrate --type bugfix    # 버그 수정
/orchestrate --type refactor  # 리팩토링
```

### 팀 구성 (최대 4명)

- Lead (자동) 1명 + Teammates 최대 3명
- 파일 소유권 분리 필수 (같은 파일 2명 편집 금지)
- 팀원당 5-6개 Task 배정

### 핵심 제한사항

- 팀원은 리더의 대화 기록을 상속하지 않음 (프롬프트에 컨텍스트 포함 필요)
- 세션당 하나의 팀만 가능
- 세션 재개 불가 (/resume, /rewind 미지원)
- 중첩 팀 불가 (팀원이 하위 팀 생성 불가)

### Team Lifecycle

```
TeamCreate → TaskCreate → Task(teammate spawn)
→ TaskUpdate(assign) → 작업 → SendMessage(보고)
→ shutdown_request → TeamDelete
```

---

## ⚠️ 충돌 방지 필수 설정 (CRITICAL)

Claude Code는 세션마다 `.claude/context/` 디렉토리 파일을 **자동 수정**합니다.
병렬 워크트리에서 이 파일들이 각각 수정되면 **병합 시 충돌이 발생**합니다.

### 충돌 발생 메커니즘

```
시점 1: main 브랜치에서 워크트리 2개 생성
├── project-auth (feature/auth)
└── project-upload (feature/upload)

시점 2: 병렬 개발 중 (각 워크트리에서 Claude Code 실행)
├── feature/auth: .claude/context/*.md 자동 수정 (버전 B)
└── feature/upload: .claude/context/*.md 자동 수정 (버전 C)

시점 3: 병합 시도
├── main ← feature/auth 성공 (버전 B)
└── main ← feature/upload 충돌! (버전 B vs 버전 C)
```

### 필수 `.gitignore` 설정

**프로젝트 `.gitignore`에 반드시 추가:**

```gitignore
# Claude Code 자동 생성 파일 (병렬 워크트리 충돌 방지)
.claude/context/
.claude/settings.json
.claude/settings.local.json
.claude/handoff.md
CLAUDE.local.md
```

### 기존 추적 파일 해제

이미 Git이 추적 중인 경우:

```bash
# 추적 해제 (파일은 유지)
git rm -r --cached .claude/context/
git add .gitignore
git commit -m "chore: .gitignore에 Claude Code 자동 생성 파일 추가"
```

### 충돌 발생 시 해결

```bash
# 방법 1: 한쪽 버전 선택
git checkout --theirs .claude/context/playwright-ready.md
git add .
git commit -m "chore: 충돌 해결"

# 방법 2: 충돌 파일 삭제 (.gitignore에 추가 후)
git rm -r --cached .claude/context/
git add .gitignore
git commit -m "chore: Claude Code 자동 생성 파일 충돌 해결"
```

---

## Custom Sub-agents 만들기

### 방법 1: 수동

`.claude/agents/your-agent-name.md` 생성

### 방법 2: /agents 명령 (권장)

```
/agents
```

### 예시: code-reviewer 에이전트

```markdown
---
name: code-reviewer
description: 코드 품질 및 보안 리뷰
tools: Read, Grep
model: sonnet
---

시니어 코드 리뷰어로서 검토:
1. 보안 취약점 (SQL Injection, XSS)
2. 성능 이슈 (N+1, 불필요한 루프)
3. 가독성 및 유지보수성

이슈를 Critical/Major/Minor로 분류.
```

---

## 주의사항

- 많은 병렬 sub-agents가 Claude Code **flickering 버그** 유발 가능
- 각 Task는 **~20K 토큰 오버헤드** 발생
- 활성 멀티 에이전트 세션은 단일 스레드 대비 **3-4배** 토큰 소비

---

## YOLO 모드

병렬 처리 시 매번 허락 받으면 생산성 급감.

```bash
claude --dangerously-skip-permissions
```

**권장 상황**: 테스트 코드 작성, 새로운 파일 생성, 코드베이스 탐색 (읽기 전용)

**주의**: 프로덕션 코드 직접 수정 시 사용 자제
