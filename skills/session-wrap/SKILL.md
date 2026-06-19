---
name: session-wrap
description: Use when wrapping up a session before ending. 4 parallel subagents detect doc updates, repeated patterns, learning points, and follow-ups, then a verifier deduplicates and presents choices. Triggers on /session-wrap, session wrap, session cleanup, end of session.
argument-hint: '[--dry-run] [--skip-docs] [--skip-learning] [--skip-scout] [--skip-followup]'
---

# /session-wrap 스킬

## 파이프라인 개요

```
입력: /session-wrap [--dry-run] [--skip-docs] [--skip-learning] [--skip-scout] [--skip-followup]

[Phase 0] 컨텍스트 수집
  ├─ git diff --stat (이번 세션 변경사항)
  ├─ ~/.claude/homunculus/observations.jsonl (최근 관찰)
  └─ /tmp/session-wrap/context.md 생성

[Phase 1] 병렬 4개 subagent (Explore, sonnet)
  ├─ doc-updater        → 문서 업데이트 필요 곳 탐지
  ├─ automation-scout   → 반복 패턴 발견 + 스킬 후보 제안
  ├─ learning-extractor → 배운 점 추출 (instinct 후보)
  └─ followup-suggester → 다음 작업 제안

[Phase 2] 순차 1개 subagent (Explore, sonnet)
  └─ duplicate-checker  → Phase 1 결과 중복 제거 + 카테고리 분류

[Phase 3] AskUserQuestion으로 사용자 선택

[Phase 4] 선택된 항목만 실행

[Phase 5] 리포트 출력 + session-wrap-followups.md 기록
```

## 파라미터 파싱

사용자 입력에서 다음을 추출:

| 파라미터 | 기본값 | 설명 |
|---------|--------|------|
| --dry-run | false | 탐지만 수행, 실행하지 않음 (Phase 3에서 중단) |
| --skip-docs | false | doc-updater subagent 생략 |
| --skip-learning | false | learning-extractor subagent 생략 |
| --skip-scout | false | automation-scout subagent 생략 |
| --skip-followup | false | followup-suggester subagent 생략 |

## Phase 0: 컨텍스트 수집

세션 중 변경사항과 관찰 데이터를 수집하여 subagent에 전달할 컨텍스트를 구성한다.

```bash
# 1. Git 변경사항 수집 (git repo인 경우만)
WORK_DIR=$(pwd)
if git -C "$WORK_DIR" rev-parse --is-inside-work-tree 2>/dev/null; then
  git -C "$WORK_DIR" diff --stat HEAD~5..HEAD > /tmp/session-wrap/git-changes.txt 2>/dev/null || true
  git -C "$WORK_DIR" diff --name-only HEAD~5..HEAD > /tmp/session-wrap/changed-files.txt 2>/dev/null || true
  git -C "$WORK_DIR" log --oneline -10 > /tmp/session-wrap/recent-commits.txt 2>/dev/null || true
fi

# 2. 관찰 데이터 수집 (최근 50개)
OBS_FILE="$HOME/.claude/homunculus/observations.jsonl"
if [ -f "$OBS_FILE" ]; then
  tail -50 "$OBS_FILE" > /tmp/session-wrap/recent-observations.jsonl
fi

# 3. 버퍼 데이터 수집 (있으면)
BUFFER_FILE="$HOME/.claude/homunculus/buffer.jsonl"
if [ -f "$BUFFER_FILE" ]; then
  tail -30 "$BUFFER_FILE" > /tmp/session-wrap/recent-buffer.jsonl
fi
```

`/tmp/session-wrap/` 디렉토리를 생성하고 위 수집을 실행한다.

## Phase 1: 병렬 Subagent 실행

4개 subagent를 **동시에** 실행한다. `--skip-*` 플래그로 특정 subagent를 건너뛸 수 있다.

각 subagent 프롬프트는 `references/` 디렉토리에 위치:

| Subagent | 프롬프트 파일 | 출력 파일 |
|----------|-------------|----------|
| doc-updater | `references/prompt-doc-updater.md` | `/tmp/session-wrap/results/doc-updates.json` |
| automation-scout | `references/prompt-automation-scout.md` | `/tmp/session-wrap/results/automation-patterns.json` |
| learning-extractor | `references/prompt-learning-extractor.md` | `/tmp/session-wrap/results/learning-points.json` |
| followup-suggester | `references/prompt-followup-suggester.md` | `/tmp/session-wrap/results/followup-tasks.json` |

### Subagent 실행 패턴

```
# 활성화된 subagent만 필터링
active_agents = [
  ("doc-updater", skip_docs 아니면),
  ("automation-scout", skip_scout 아니면),
  ("learning-extractor", skip_learning 아니면),
  ("followup-suggester", skip_followup 아니면),
]

# 병렬 Task 호출 (Explore, sonnet)
for agent in active_agents:
  Task(
    subagent_type="Explore",
    prompt=Read("references/prompt-{agent}.md") + context_data
  )
```

각 subagent는 결과를 JSON 파일로 `/tmp/session-wrap/results/`에 기록한다.

### 출력 JSON 스키마

모든 subagent의 출력은 동일한 아이템 스키마를 따른다:

```json
{
  "items": [
    {
      "id": "unique-id",
      "source": "doc-updater|automation-scout|learning-extractor|followup-suggester",
      "title": "항목 제목",
      "description": "상세 설명",
      "category": "auto|user|info",
      "priority": "high|medium|low",
      "action": "실행할 구체적 작업 (있으면)",
      "files": ["관련 파일 경로들"]
    }
  ]
}
```

카테고리 분류 기준:
- **auto**: 사용자 확인 없이 자동 실행 가능 (문서 타임스탬프 갱신 등)
- **user**: 사용자 선택이 필요 (스킬 생성, 코드 수정 등)
- **info**: 정보 제공만 (학습 포인트, 통계 등)

## Phase 2: 중복 검증

Phase 1의 모든 결과를 수집하여 duplicate-checker subagent에 전달한다.

프롬프트: `references/prompt-duplicate-checker.md`

역할:
1. 4개 subagent 결과를 병합
2. 의미적으로 중복되는 항목 제거 (더 구체적인 항목 유지)
3. 최종 카테고리 재분류 (auto/user/info)
4. 우선순위 정렬 (high → medium → low)

출력: `/tmp/session-wrap/results/merged-actions.json`

## Phase 3: 사용자 선택

`--dry-run`이면 여기서 중단하고 탐지 결과만 출력한다.

### 표시 형식

```
## 세션 정리 항목

### 자동 실행 (auto) - N건
1. [docs] README.md 타임스탬프 갱신
2. [docs] CODEMAPS/backend.md 모듈 추가

### 사용자 선택 필요 (user) - M건
3. [ ] [scout] "API 에러 처리" 패턴 → 스킬 후보
4. [ ] [followup] auth 모듈 리팩토링 제안
5. [ ] [learning] "Supabase RLS 패턴" instinct 생성

### 참고 정보 (info) - K건
6. [learning] 이번 세션에서 3개 새 라이브러리 사용
7. [stats] 변경 파일 12개, 커밋 5개

실행할 항목 번호를 선택하세요 (예: 1,3,4 또는 all 또는 auto-only):
```

AskUserQuestion으로 사용자 입력을 받는다.

- `all`: auto + 모든 user 항목 실행
- `auto-only`: auto 항목만 실행
- `1,3,4`: 특정 번호만 실행
- `none`: 아무것도 실행하지 않음

## Phase 4: 선택 항목 실행

사용자가 선택한 항목을 실행한다:

| 카테고리 | 실행 방식 |
|---------|----------|
| docs 업데이트 | Edit/Write로 직접 수정 |
| scout 스킬 후보 | `/tmp/session-wrap/skill-candidates.md`에 기록 |
| learning instinct | `~/.claude/homunculus/instincts/personal/`에 MD 파일 생성 |
| followup 작업 | `/tmp/session-wrap/session-wrap-followups.md`에 기록 |

## Phase 5: 리포트 출력

### 최종 리포트 형식

```
## Session Wrap 완료

### 실행 결과
- 문서 업데이트: N건 완료
- 스킬 후보 기록: M건
- Instinct 생성: K건
- 후속 작업 기록: L건

### 후속 작업 파일
/tmp/session-wrap/session-wrap-followups.md

### 스킬 후보 파일 (있으면)
/tmp/session-wrap/skill-candidates.md
```

후속 작업 파일(`session-wrap-followups.md`)은 다음 세션 시작 시 `/context-sync`로 로드할 수 있다.

## 에러 처리

| 상황 | 대응 |
|------|------|
| git repo 아님 | git 관련 컨텍스트 생략, 나머지 진행 |
| observations.jsonl 없음 | 관찰 데이터 없이 진행, 경고 표시 |
| subagent 실패 (일부) | 실패 subagent 결과 생략, 나머지로 진행 |
| 결과가 0건 | "정리할 항목이 없습니다" 출력 |
| /tmp 쓰기 불가 | 에러 메시지 출력 후 중단 |

## 관련 파일

| 파일 | 용도 |
|------|------|
| `references/prompt-doc-updater.md` | doc-updater subagent 프롬프트 |
| `references/prompt-automation-scout.md` | automation-scout subagent 프롬프트 |
| `references/prompt-learning-extractor.md` | learning-extractor subagent 프롬프트 |
| `references/prompt-followup-suggester.md` | followup-suggester subagent 프롬프트 |
| `references/prompt-duplicate-checker.md` | duplicate-checker subagent 프롬프트 |
| `references/output-schema.md` | 출력 JSON 스키마 상세 |
