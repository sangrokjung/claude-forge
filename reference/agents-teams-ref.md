# Agent Teams 상세 참조

> 이 파일은 agents-v2.md에서 분리된 팀 운영 상세 내용입니다.
> 핵심 에이전트 목록과 즉시 사용 규칙은 [agents-v2.md](agents-v2.md) 참조.

## Agent Teams

### 전제조건 (CRITICAL)

Agent Teams는 실험적이며 기본 비활성화 상태. 반드시 활성화 필요:

```json
// settings.json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

### 토큰 비용 경고

Agent Teams는 단일 세션보다 **훨씬 더 많은 토큰**을 사용한다.
각 팀원은 자신의 컨텍스트 윈도우를 가지며, 비용은 활성 팀원 수에 비례.
일상적 작업은 단일 세션이 더 비용 효율적.

### 컨텍스트 상속 (CRITICAL)

- 팀원은 프로젝트 컨텍스트(CLAUDE.md, MCP servers, skills)를 자동 로드
- **리더의 대화 기록은 상속하지 않음**
- 생성 프롬프트에 작업별 세부 사항을 반드시 포함
- CLAUDE.md는 정상 작동: 팀원들은 작업 디렉토리에서 CLAUDE.md를 읽음

### 권한 상속

- 팀원은 리더의 권한 설정으로 시작
- 리더가 `--dangerously-skip-permissions`이면 팀원도 동일
- 생성 후 개별 팀원 모드 변경 가능, 생성 시 개별 설정 불가

### 최적 사용 사례

- **연구 및 검토**: 여러 팀원이 문제의 다양한 측면 동시 조사
- **새 모듈/기능**: 팀원별 별도 파일 소유하여 병렬 구현
- **경쟁 가설 디버깅**: 다양한 이론을 병렬 테스트, 서로 반박
- **교차 계층 조율**: 프론트엔드/백엔드/테스트 각각 다른 팀원

### 사용하지 말아야 할 경우

- 순차적 작업 (이전 결과에 의존) → **-70% 성능 악화** (Google/MIT 연구)
- 동일 파일 편집이 필요한 작업
- 종속성이 많은 작업
- 단일 에이전트 정확도가 이미 45% 이상인 간단한 작업 → 수익 체감
→ 이 경우 단일 세션 또는 subagents 사용

### 팀 사용 판단 기준 (CRITICAL)

팀을 만들기 전 반드시 확인:

| 조건 | 팀 사용 | 단일 세션/subagent |
|------|---------|-------------------|
| 작업이 병렬화 가능한가? | O → 팀 (+81% 향상 가능) | X → 단일 세션 |
| 팀원끼리 논의/협업이 필요한가? | O → 팀 | X → subagent |
| 파일 소유권을 분리할 수 있는가? | O → 팀 | X → 단일 세션 |
| 토큰 비용 3-7x를 감당할 수 있는가? | O → 팀 | X → subagent |

근거: Google/MIT "Towards a Science of Scaling Agent Systems" (2025) -- 180개 구성 평가, 병렬 작업 +81%, 순차 작업 -70%

### 표시 모드 (teammateMode)

settings.json의 `teammateMode` 설정:

| 모드 | 설명 | 요구사항 |
|------|------|----------|
| `"auto"` (기본) | tmux 세션 내이면 분할 창, 아니면 in-process | 없음 |
| `"in-process"` | 메인 터미널 내 실행. Shift+Up/Down 전환 | 없음 |
| `"tmux"` | 각 팀원 별도 창. tmux/iTerm2 자동 감지 | tmux 또는 iTerm2 (it2 CLI + Python API) |

CLI 플래그: `claude --teammate-mode in-process`

현재 설정: `"tmux"` (iTerm2 분할 창 자동 감지)

- **In-process**: Shift+Up/Down으로 팀원 전환 (추가 설정 불필요)
- **분할 창 (tmux/iTerm2)**: 각 팀원 별도 창, 클릭으로 직접 상호작용
- **미지원**: VS Code 통합 터미널, Windows Terminal, Ghostty

### Default Team Composition

**최대 팀원 수: 4명 (CRITICAL)**

세션당 리더 포함 최대 4개 에이전트만 동시 운영. 초과 금지:
- Lead (자동) 1명 + Teammates 최대 3명
- 4명 초과 필요 시 작업을 순차 배치로 분할

팀 크기는 작업 복잡도에 따라 결정. 명시 지정 가능:
```
Create a team with 3 teammates to refactor these modules.
Use Sonnet for each teammate.
```

기본 구성 가이드:
1. Lead (자동) - 작업 분해, 역할 배정, 조율 (코딩 금지)
2. Teammates (최대 3명) - 작업에 따라 Lead가 동적으로 역할 배정

역할 구성 예시 (리더 제외, 팀원만):
- 구현 작업: 구현2 + 테스트1
- 리팩토링: 분석1 + 구현1 + 검증1
- 버그 조사: 조사2 + 수정1
- 신규 기능: 구현1 + 테스트1 + 보안1
- 코드 리뷰: 보안1 + 성능1 + 테스트커버리지1

### 계획 승인 모드 (Plan Approval)

위험하거나 복잡한 작업에서 팀원이 구현 전 계획 승인 필요:
```
Spawn an architect teammate to refactor the auth module.
Require plan approval before they make any changes.
```

- 팀원은 읽기 전용 계획 모드로 시작
- 계획 완료 시 리더에게 승인 요청 발송
- 리더가 승인하면 구현 시작, 거부하면 피드백에 따라 수정

### Teammate subagent_type 가이드

| Type | Tools | 용도 |
|------|-------|------|
| general-purpose | All (Read, Write, Edit, Bash 등) | 구현, 수정, 테스트 |
| Explore | Read-only | 빠른 코드베이스 탐색, 조사 |
| Plan | Read-only | 설계, 계획 수립 (구현 불가) |
| Bash | Terminal only | 명령어 실행 전용 |

### Team Lifecycle

```
TeamCreate → TaskCreate (tasks 배정) → Task (teammates 생성)
→ TaskUpdate (assign owner) → 작업 수행 → SendMessage (결과 보고)
→ [필요 시] 팀원 해고 → 승계 패키지 파일 기록 → 새 팀원 생성 (절차: "팀원 관리 원칙" 참조)
→ shutdown_request (모든 팀원) → TeamDelete (리더만 실행)
```

### Rules (CRITICAL)

- **리더 코딩 금지**: 리더는 조율만. 구현/리서치/코드베이스 탐색은 전부 팀원에게 위임. "Wait for teammates. Never implement directly." 프롬프트로 강제
- **Delegate Mode 사용 금지**: 버그 #25037로 팀원 권한 박탈됨. 프롬프트 방식으로 대체
- **팀원당 5~6개 task 배정**: 모두 생산적으로, 막히면 리더가 재배정
- **파일 소유권 분리**: 같은 파일을 2명이 편집하지 않도록 분리. 위반 시 덮어쓰기 발생
- **리더가 기다리기**: 팀원 완료 전 리더가 직접 구현 시작하면 안 됨
- **정리는 리더만**: TeamDelete는 반드시 리더가 실행 (팀원 실행 시 불일치 상태)
- **종료 순서**: 모든 팀원 shutdown → TeamDelete (활성 팀원 있으면 실패)
- **SendMessage 필수**: 일반 텍스트는 팀원에게 안 보임. 반드시 SendMessage 사용
- **broadcast 절약**: broadcast는 비용이 팀 크기에 비례 증가. 긴급한 경우에만 사용
- **팀원 idle은 정상**: 매 턴 후 idle 전환은 정상 동작. 메시지 보내면 자동 깨어남
- **세션당 1팀**: 새 팀 시작 전 현재 팀 정리 필수
- **세션 재개 불가**: /resume, /rewind는 in-process 팀원 복원 안 됨

### 리더 운영 규율 (CRITICAL)

리더의 컨텍스트 윈도우는 전체 작전을 기억하는 유일한 곳.
코드까지 짜면 기억이 순식간에 차서 팀 전체가 비효율적.

**리더가 하는 것:**
- 보고 수신 및 분석
- 사용자 소통
- 의사결정
- decisions.md 기록

**리더가 절대 안 하는 것:**
- 구현 (코딩)
- 리서치
- 코드베이스 탐색
→ 팀원에게 시킬 수 있으면 반드시 위임

**종합 분석 시 자기검증 3질문 (강제):**
1. 가장 어려운 결정이 뭐였나?
2. 어떤 대안을 왜 거부했나?
3. 가장 확신 없는 부분은?

근거: Anthropic 멀티에이전트 리서치 시스템 -- Opus 리더 + Sonnet subagent가 단독 Opus 대비 90.2% 성능 향상

### 기억 외부화 -- decisions.md (CRITICAL)

컨텍스트 압축 시 핵심 결정이 유실됨 (버그 #23620).
중요한 결정이 나올 때마다 파일에 즉시 기록.

**패턴:**
```
# decisions.md (리더가 관리)
## 2026-02-19
- [결정] API 인증은 JWT 대신 세션 기반으로 채택
  - 이유: 모바일 앱 미지원, 서버 사이드만
  - 거부한 대안: JWT (토큰 관리 복잡도)
- [결정] DB는 Supabase PostgreSQL 사용
  - 이유: 팀 경험, MCP 연동
```

**규칙:**
1. 중요 결정 나올 때마다 decisions.md에 즉시 기록
2. 팀원별 보고는 개별 파일 (reports/{teammate-name}.md) → 경쟁 조건 회피
3. 리더만 decisions.md 통합본 관리
4. 컨텍스트 유실되면 decisions.md 읽어서 복구

근거: Anthropic Context Engineering 공식 가이드 "Structured Note-Taking", Context-Folding 논문 (32K로 327K 능가)

### 팀원 관리 원칙

**교체 정책 (해고-재고용):**
- 다음 태스크가 이전 작업과 **무관하면** → 기존 팀원 종료 + 새 팀원 투입 (200K 컨텍스트 포화 방지)
- 이전 작업의 **연장선이면** → 유지
- 교체 시 같은 이름 **재사용 불가**. 반드시 새 이름 부여

**승계 패키지 (해고 전 필수):**
1. 팀원에게 결과 요약을 파일에 기록시킴 (reports/{name}-final.md)
2. 해고 (shutdown_request)
3. 새 팀원 생성 시 승계 파일 경로를 spawn 프롬프트에 포함

**Subagent 제한:**
- 팀원이 subagent를 생성할 수 있음 (3계층 구조)
- subagent에게는 **리서치/파일 읽기만** 허용. **코드 구현 위임 금지**
- 중첩 팀은 불가 (팀원이 TeamCreate 할 수 없음)

근거: Agent Lineage Evolution 논문 (2025) -- 에이전트를 세대로 재개념화, 선제적 갱신으로 품질 유지

### 팀원 통신 규칙

**기본: Hub-and-Spoke**
- 보고, 의사결정 요청은 **반드시 리더 경유**
- 팀원끼리 의사결정을 자체 해결하는 것은 **금지**

**예외: Peer-to-Peer 허용**
- 같은 모듈 작업 시 기술적 조율
- 파일 충돌 방지 협의
- 끝나면 리더에게 결과 요약만 보고

근거: Google/MIT 연구 -- 중앙 집중(hub-and-spoke) 오류 증폭 4.4x vs 독립(peer) 17.2x

### 3계층 구조 (리더 → 팀원 → Subagent)

```
Team Lead (조율만, 코딩 금지)
  → Teammate A (full session, subagent 생성 가능)
       → Subagent 1 (리서치/읽기만, A에게만 보고)
       → Subagent 2 (리서치/읽기만, A에게만 보고)
  → Teammate B (full session, subagent 생성 가능)
       → Subagent 3 (리서치/읽기만, B에게만 보고)
```

**제약:**
- Subagent는 다른 subagent를 생성할 수 없음
- 팀원은 팀(TeamCreate)을 생성할 수 없음 (리더만 가능)
- 기본은 2계층(리더+팀원)으로 충분. 3계층은 리서치 병렬화가 필요할 때만

근거: Anthropic 공식 -- "teammates ARE full Claude Code sessions, so they CAN spawn subagents"

### 페이즈 기반 팀 운영

대규모 작업 시 팀을 페이즈별로 교체:

```
[Phase 1: 리서치]
TeamCreate → 팀원 3명 (리서치 역할)
→ 각 팀원이 subagent 3-8개로 병렬 리서치
→ 팀원들이 리더에게 보고서 제출
→ 리더가 종합 → decisions.md에 핵심 결정 기록
→ 전원 해고 (shutdown_request × 3) → TeamDelete

[Phase 2: 구현]
TeamCreate → 새 팀원 3명 생성 (구현 역할)
→ spawn 프롬프트에 decisions.md + Phase 1 보고서 경로 포함
→ 각 팀원이 담당 파일 소유권 분리하여 구현
→ 완료 후 리더에게 보고
→ 전원 해고 → TeamDelete
```

**핵심:** 새 팀원은 머리가 깨끗한 상태에서 시작. 속도와 정확도 동시 향상.

### 알려진 버그 및 제한사항

주의: #25037(Delegate 금지), #23620(decisions.md 사용), #24130(개별 파일), #25131(idle 무시). 세션 재개 불가, 세션당 1팀, 중첩 팀 불가.

### 작업 크기 가이드

| 크기 | 판단 | 설명 |
|------|------|------|
| 너무 작음 | 조율 오버헤드 > 이점 | subagent 사용 권장 |
| 적절함 | 명확한 결과물이 있는 자체 포함 단위 | 함수, 테스트 파일, 검토 |
| 너무 큼 | 체크인 없이 오래 작동 | 더 작게 분할 |

### 팀원 직접 대화

- **In-process**: Shift+Up/Down → 선택 → 입력. Enter로 세션 보기, Escape로 중단, Ctrl+T로 작업 목록
- **분할 창**: 팀원 창 클릭 → 직접 상호작용

### 핸드오프 프로토콜

팀원은 리더의 대화 기록을 상속하지 않으므로, 구조화된 컨텍스트 전달이 필수다.

#### 컨텍스트 패키지 (팀원 생성 시)

리더가 팀원을 생성할 때, 다음 템플릿을 프롬프트에 포함하여 램프업 낭비를 제거한다.
패키지 내용은 git/파일시스템에서 **동적으로 수집**하며, 하드코딩하지 않는다.

```markdown
## Task Context (자동생성)
### 프로젝트 상태
- Branch: `git branch --show-current`
- 최근 커밋: `git log --oneline -3`
- 수정 파일: `git diff --name-only HEAD`

### 태스크 세부
- 목표: {TaskCreate description에서 추출}
- 의존성: {blockedBy 태스크 목록}
- 파일 소유권: {이 팀원에게 할당된 파일 경로}

### 관련 결정 (최근 5건)
- {.claude/decisions.md 또는 compact-snapshots에서 최근 5건}

### 제약
- golden-principles.md 핵심: 불변성, TDD, 800줄/50줄 제한, zod 검증
- sprint-contract.md DoD (존재 시)
```

#### 결과 핸드오프 파일 (팀원 종료 시)

`teammate-context-handoff.sh` 훅이 SubagentStop 이벤트에 반응하여 자동 생성한다.
저장 경로: `$PROJECT/.claude/handoffs/{agent_name}-{timestamp}.md`

파일 형식:
```markdown
# Task Result: {agent_name}
Generated: {timestamp}

## 변경 사항
- 수정 파일: {git diff --name-only 결과}
- 추가 라인: {insertions}
- 삭제 라인: {deletions}

## 핵심 요약
(팀원이 SendMessage로 리더에게 보낸 메시지 참조)

## 후속 작업
- 다음 에이전트가 알아야 할 사항
```

#### .claude/handoffs/ 디렉토리

| 항목 | 설명 |
|------|------|
| 용도 | 팀원 간 작업 결과 인수인계 |
| 생성 주체 | `teammate-context-handoff.sh` (SubagentStop 훅) |
| 파일명 규칙 | `{agent_name}-{YYYYMMDD-HHMMSS}.md` |
| 정리 시점 | TeamDelete 후 또는 다음 /orchestrate 실행 전 |
| git 추적 | `.gitignore`에 추가 권장 (임시 파일) |

활용:
- 새 팀원 생성 시 이전 팀원의 핸드오프 파일 경로를 spawn 프롬프트에 포함
- 페이즈 기반 팀 운영 시, Phase N의 핸드오프 파일을 Phase N+1 팀원에게 전달
- 리더가 decisions.md와 함께 핸드오프 파일을 참조하여 전체 진행 상황 파악
