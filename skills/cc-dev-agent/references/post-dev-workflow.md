# 개발 완료 후 워크플로우

Boris Cherny의 Claude Code 철학을 기반으로 한 개발 완료 후 검증 워크플로우.

---

## 핵심 철학

### 왜 `/clear` 후 검증인가?

**❌ 잘못된 방식**
```
[개발] → [같은 세션에서 검증] → [커밋]
              ↑
         Context Bias: 자기 코드라 문제를 못 봄
```

**✅ 올바른 방식**
```
[개발] → [/handoff] → [/clear] → [새 눈으로 검증] → [커밋]
                           ↑
                  컨텍스트 초기화로 bias 제거
```

### Boris Cherny의 원칙

> "Give Claude a way to verify its work. If Claude has that feedback loop, it will 2-3x the quality."

| 원칙 | 설명 |
|------|------|
| **작성-검토 분리** | 개발한 세션과 검증 세션을 분리 |
| **문서 기반 컨텍스트** | `/clear` 후에도 의도를 전달할 수 있도록 문서화 |
| **피드백 루프** | 테스트, 린트, 타입체크로 자동 검증 |

---

## 병렬 개발 (Agent Teams v6)

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

### 사용법

```bash
/orchestrate --type feature   # 기능 구현
/orchestrate --type bugfix    # 버그 수정
/orchestrate --type refactor  # 리팩토링
/orchestrate --dry-run        # 실행 전 계획 확인
```

### 제한사항

- 세션당 하나의 팀만 가능
- 팀원은 리더의 대화 기록을 상속하지 않음 (프롬프트에 컨텍스트 포함 필요)
- 세션 재개 불가 (/resume, /rewind 미지원)
- 중첩 팀 불가 (팀원이 하위 팀 생성 불가)

→ **상세 가이드**: `sub-agents.md` "Agent Teams" 참조

---

## 기본 워크플로우

### 충돌 방지 필수 설정

병렬 개발 전 `.gitignore` 확인:

```gitignore
# 필수 - Claude Code 자동 생성 파일
.claude/context/
.claude/settings.json
.claude/settings.local.json
.claude/handoff.md
CLAUDE.local.md
```

### 플로우차트

```
┌─────────────────────────────────────────────────────────────┐
│                    개발 워크플로우 (v6)                       │
├─────────────────────────────────────────────────────────────┤
│ 1. /orchestrate (선택) - Agent Teams 병렬 개발               │
│ 2. 개발 (기능 구현)                                          │
│ 3. /handoff - 의도 문서화                                    │
│ 4. /clear - Context Bias 제거                                │
│ 5. /verify-loop - 자동 재검증 (3회)                          │
│ 6. /sync-docs - 문서 동기화 (머지 전 의무 게이트)             │
│ 7. /commit-push-pr --merge - 커밋 & PR & 머지               │
│ 8. /web-checklist - 웹 테스트 체크리스트                      │
└─────────────────────────────────────────────────────────────┘
```

### 실제 사용 예시

```bash
# 1. 개발
# (직접 개발 또는 /orchestrate로 Agent Teams 병렬 개발)

# 2. 개발 완료 후
/handoff
/clear
/verify-loop

# 3. 검증 통과 후 — 문서 동기화 (머지 전 의무)
/sync-docs

# 4. 커밋 & PR & 머지 (v7: sync-docs 게이트 내장)
/commit-push-pr --merge
```

### 병렬 개발 예시 (Agent Teams)

```bash
# Agent Teams로 3명의 팀원이 병렬 작업
/orchestrate --type feature

# 팀 구성 (자동):
#   Lead: 작업 분배, 조율
#   Frontend Dev: UI 컴포넌트
#   Backend Dev: API, DB
#   QA Engineer: 테스트

# 완료 후 자동 정리 (shutdown → TeamDelete)
```

---

## 시나리오별 사용법

### `/handoff` 깜빡하고 `/clear` 해버린 경우

```bash
/verify "로그인 기능 구현, JWT 인증 추가, 토큰 만료 처리"
```

### 간단한 수정 (오타, 한 줄 버그)

```bash
/quick-commit "fix: 로그인 버튼 오타 수정"
```

**제한**: 변경 파일 3개, 20줄 이하일 때만 권장.

### 테스트 실패 후 재검증

**단순 에러**: 같은 세션에서 수정 → `/verify "import 누락 수정"`

**복잡한 수정**: `/handoff` → `/clear` → `/verify`

### Agent Teams 에러 발생 시

| 에러 | 원인 | 해결 |
|------|------|------|
| 팀원이 나타나지 않음 | tmux/iTerm2 미설정 | Shift+Down으로 확인, teammateMode 설정 점검 |
| 너무 많은 권한 프롬프트 | 사전 승인 미설정 | allowedTools 설정으로 사전 승인 |
| 팀원 오류 중지 | 팀원 에러 발생 | 리더가 TaskUpdate로 재배정 또는 새 팀원 생성 |

---

## 명령어 상세

### `/handoff`

`/clear` 전에 개발 의도를 `.claude/handoff.md`에 기록.

**내용**: 완료한 작업, 변경 파일 요약, 테스트 필요 사항, 알려진 이슈, 주의사항

### `/verify`

새 컨텍스트에서 철저한 검증. **전제조건**: `/clear` 후 실행 권장.

**컨텍스트 소스**:
1. `.claude/handoff.md` (있으면)
2. `CLAUDE.md`, `spec.md`, `prompt_plan.md` (있으면)
3. `$ARGUMENTS` (직접 입력)
4. `git diff` (변경 내용)

**검증 항목**: 코드 리뷰 (think hard), 빌드, 테스트, 린트, 타입체크

**결과 분류**:
- **Critical** (커밋 금지): 빌드 실패, 테스트 실패, 보안 취약점
- **Warning** (권장 수정): 린트 에러, 타입 에러
- **Info**: 개선 제안

### `/commit-push-pr`

검증 완료 후 커밋 & PR & 머지. **전제조건**: `/verify` 통과.
**v7**: 머지 옵션 사용 시 4.5단계에서 `/sync-docs`를 **의무 실행**한다 (머지 전 문서 동기화 게이트). 문서 변경분은 같은 커밋에 포함된다.

| 인자 | 설명 |
|------|------|
| `--merge` | PR 생성 + merge commit으로 머지 |
| `--squash` | PR 생성 + squash merge |
| `--rebase` | PR 생성 + rebase merge |
| `--draft` | Draft PR 생성 (머지 안 함) |
| `--no-verify` | 빌드/테스트 스킵 |
| `--skip-sync-docs` | 문서 동기화 게이트 스킵 (긴급 hotfix 전용) |

```bash
/commit-push-pr --merge              # 즉시 머지
/commit-push-pr feat: 로그인 --squash  # 커밋 정리 후 머지
```

### `/sync-docs`

| 문서 | 동기화 내용 |
|------|-------------|
| `prompt_plan.md` | 완료 Task 체크 (`[ ]` → `[x]`) |
| `spec.md` | 변경된 스펙 반영 |
| `CLAUDE.md` | 배운 규칙 추가 |

#### 📍 실행 시점 (v7 — 머지 전 의무)

**머지 전 실행이 표준이다.** `/commit-push-pr --merge`가 4.5단계 게이트로 자동 실행하므로 누락돼도 보장되지만, 수동 플로우에서는 커밋 전에 직접 실행한다.

```bash
/sync-docs                  # 머지 전 문서 동기화 (변경분이 머지 커밋에 포함)
/commit-push-pr --merge     # v7: sync-docs 게이트 내장
```

> 구버전(v6)은 "머지 후 `git pull` → `/sync-docs`" 순서였으나, 문서 누락 상태의 머지를 차단하기 위해 v7부터 **머지 전**으로 변경됐다.

---

## 지원 프로젝트 타입

| 프로젝트 | 감지 파일 | 테스트 명령어 |
|----------|-----------|---------------|
| Node.js | `package.json` | `npm run build && npm test` |
| Python | `requirements.txt`, `pyproject.toml` | `pytest` |
| Go | `go.mod` | `go build ./... && go test ./...` |
| Rust | `Cargo.toml` | `cargo build && cargo test` |
| Make | `Makefile` | `make test` |

---

## FAQ

### `/handoff` 없이 `/clear` 해버렸는데?

`/verify '의도 설명'`으로 의도를 직접 입력.

### 테스트가 실패했는데?

- **단순 에러**: 같은 세션에서 수정 → `/verify "수정 내용"`
- **복잡한 수정**: `/handoff` → `/clear` → `/verify`

### gh CLI가 없는데?

`/commit-push-pr`이 push까지만 하고 GitHub 웹 URL을 안내.

```bash
brew install gh  # macOS
sudo apt install gh  # Ubuntu
```

### 매번 `/handoff` 해야 하나?

`spec.md`, `prompt_plan.md`가 잘 관리되고 있다면 생략 가능. 문서에 없는 작업을 했다면 권장.

### Agent Teams를 사용하려면?

`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`를 `1`로 설정 후 `/orchestrate` 사용. 상세 가이드는 `sub-agents.md` 참조.
