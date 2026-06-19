---
name: cc-dev-agent
description: Use when starting Claude Code projects, writing CLAUDE.md/spec.md, dispatching subagents, or requesting Agent Teams parallel development. Covers Spec-Driven Development, Context Engineering, and post-dev workflow.
---

# Claude Code Agent

Claude Code를 활용한 Spec-Driven 개발 워크플로우 및 Context Engineering 가이드.

## 핵심 원칙

1. **Context Engineering**: 제한된 컨텍스트 윈도우에서 토큰 유용성 최적화
2. **Spec-Driven**: 코드 전에 스펙(spec.md) 먼저 → 반복 수정 8배 감소
3. **TDD Loop**: Red(테스트) → Green(구현) → Refactor
4. **Sub-agents 활용**: Explore, Plan 에이전트로 작업 분산
5. **작성-검증 분리**: `/clear` 후 새 눈으로 검증 (Boris 원칙)

---

## 병렬 개발 (Agent Teams v6)

> Git Worktree 기반 병렬 개발은 레거시. Agent Teams가 팀 생성/정리를 자동 처리.

### 전제조건

- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`를 `1`로 설정
- 설정 위치: `~/.claude/settings.json`의 `env` 또는 셸 환경변수

### 사용법

```bash
/orchestrate --type feature   # 기능 구현
/orchestrate --type bugfix    # 버그 수정
/orchestrate --type refactor  # 리팩토링
```

→ **상세 가이드**: `references/sub-agents.md`

---

## 개발 완료 후 워크플로우 (Boris 방식)

> "Give Claude a way to verify its work. If Claude has that feedback loop, it will 2-3x the quality."

### 핵심 플로우

```
/orchestrate (선택) → 개발 → /handoff-verify
→ /sync-docs (머지 전 문서 동기화 의무)
→ /commit-push-pr --merge
→ /web-checklist
```

### 단계별 역할

| 단계 | 명령어 | 이유 |
|------|--------|------|
| 1 | `/orchestrate` (선택) | Agent Teams 병렬 개발 |
| 2 | 개발 | 기능 구현 |
| 3 | `/handoff-verify` | 의도 문서화 + fresh context 자동 검증 (v6 통합) |
| 4 | `/sync-docs` | **머지 전 문서 동기화 (의무 게이트)** — 문서 변경분이 머지 커밋에 포함됨 |
| 5 | `/commit-push-pr --merge` | 커밋 & PR & 머지 (v7: sync-docs 게이트 내장 — 4단계 누락 시 자동 실행) |
| 6 | `/web-checklist` | 웹 테스트 체크리스트 |

→ **상세 가이드**: `references/post-dev-workflow.md`

---

## Context Engineering

| 명령어 | 용도 | 사용 시점 |
|--------|------|-----------|
| `/clear` | 컨텍스트 완전 초기화 | 새 Task, 에러 루프 탈출, **검증 전** |
| `/compact` | 대화 요약 압축 | 60% 도달 시 |
| `/context` | 현재 사용량 확인 | 복잡한 작업 중 수시 체크 |

→ **상세 가이드**: `references/context-engineering.md`

---

## Sub-agents

| 유형 | 용도 |
|------|------|
| `Explore` | 빠른 코드베이스 검색 (Read-only) |
| `Plan` | 구현 계획 설계 |

**병렬 처리**: 최대 10개 동시 실행

→ **상세 가이드**: `references/sub-agents.md`

---

## 개발 5단계

```
Phase 1: 초기화 → CLAUDE.md 생성
Phase 2: 기획 → spec.md, prompt_plan.md 작성
Phase 3: 구현 → TDD Loop 반복 (핵심)
Phase 4: 검증 → 스펙 대조, 코드 리뷰
Phase 5: 배포 → 보안 검토, 최종 점검
```

### Think 키워드

| 키워드 | 용도 |
|--------|------|
| `think` | 단순 버그 |
| `think hard` | 다중 파일, 원인 불명 |
| `ultrathink` | 아키텍처, 설계 결함 |

→ **상세 사용법**: `references/troubleshooting.md`

---

## Quick Reference

### 필수 .gitignore (병렬 개발 충돌 방지)

```gitignore
.claude/context/
.claude/settings.json
.claude/settings.local.json
.claude/handoff.md
CLAUDE.local.md
```

### 참조 문서

| 파일 | 용도 |
|------|------|
| `references/post-dev-workflow.md` | 개발 완료 후 워크플로우 상세 |
| `references/sub-agents.md` | 서브에이전트 + Agent Teams |
| `references/prompts.md` | 복사용 프롬프트 |
| `references/context-engineering.md` | 컨텍스트 엔지니어링 심화 |
| `references/playwright-agents.md` | Playwright 테스트 에이전트 |
| `references/templates.md` | MD 파일 템플릿 |
| `references/troubleshooting.md` | 에러 해결 + Think 키워드 상세 |
