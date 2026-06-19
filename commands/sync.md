---
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(git:*)
description: git pull + 문서 동기화 통합 (pull → sync-docs v7 순차 실행)
argument-hint: [--no-pull] [--check-only] [작업설명]
---

# /sync - Git Pull + 문서 동기화

---

## 플래그

| 플래그 | 설명 |
|--------|------|
| `--no-pull` | pull 건너뛰고 문서 동기화만 실행 (`/sync-docs`와 동일) |
| `--check-only` | 문서 변경 필요 사항만 보여주고 수정하지 않음 |
| (없음) | pull + 문서 동기화 모두 실행 |

---

## Phase 1: Git Pull (`--no-pull` 시 스킵)

### 1-1. 현재 상태 확인

```bash
git branch --show-current
git status --short
```

커밋되지 않은 변경사항이 있으면 경고:
```
작업 중인 변경사항이 있습니다. stash 후 진행할까요? (Y/n)
```
- Y: `git stash` 후 진행, pull 후 `git stash pop`
- n: 그대로 pull 시도

### 1-2. Pull 실행

```bash
git pull origin main
```

충돌 발생 시 Phase 2 진행하지 않고 충돌 보고 후 중단.

---

## Phase 2: 문서 동기화 (sync-docs v7 로직)

### 2-0. 모드 결정 (CRITICAL)

`--check-only` 플래그가 있으면:
- **모든 Write/Edit 도구 호출을 금지한다.**
- 각 단계에서 "변경이 필요한 항목"만 수집한다.
- Read/Glob/Grep/Bash(git)만 사용한다.

### 2-1. 작업 설명 확인

인자로 전달된 작업 설명을 확인한다.
인자가 없으면 최근 커밋 메시지에서 작업 내용을 추론한다.

```bash
git log --oneline -5
```

### 2-2. 변경된 코드 분석

**diff 범위 자동 감지:**

```bash
BASE=$(git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null)
if [ -n "$BASE" ] && [ "$BASE" != "$(git rev-parse HEAD)" ]; then
  git diff --name-only "$BASE"..HEAD
  git diff --stat "$BASE"..HEAD
else
  COMMIT_COUNT=$(git rev-list --count HEAD 2>/dev/null || echo "0")
  if [ "$COMMIT_COUNT" -eq 0 ]; then
    echo "NO_COMMITS"
  elif [ "$COMMIT_COUNT" -ge 3 ]; then
    git diff --name-only HEAD~3..HEAD
    git diff --stat HEAD~3..HEAD
  else
    git diff --name-only HEAD~1..HEAD
    git diff --stat HEAD~1..HEAD
  fi
fi
```

`NO_COMMITS`가 출력되면 동기화할 변경사항이 없으므로 사용자에게 알리고 종료한다.

### 충돌 해결 원칙

소스 코드(git diff)가 최우선 진실 소스(source of truth)이다.

### 2-3. prompt_plan.md 동기화

Glob 패턴으로 `prompt_plan.md`를 탐색한다:
- `./prompt_plan.md`
- `./.claude/prompt_plan.md`
- `./docs/prompt_plan.md`

업데이트 항목:
- 완료된 작업 항목 체크 (`- [x]`)
- 진행 상황 갱신
- 다음 단계 업데이트

파일이 없으면 건너뛴다.

### 2-4. spec.md 동기화

Glob 패턴으로 `spec.md`를 탐색한다:
- `./spec.md`
- `./docs/spec.md`
- `./.claude/spec.md`

업데이트 항목:
- 구현된 기능 반영
- API 변경사항 반영
- 데이터 모델 변경 반영

파일이 없으면 건너뛴다.

### 2-5. CLAUDE.md 동기화 (200줄 원칙 (Anthropic 공식))

Glob 패턴으로 `CLAUDE.md`를 탐색한다:
- `./CLAUDE.md`
- `./.claude/CLAUDE.md`

**200줄 원칙 (Anthropic 공식) (CRITICAL):**

CLAUDE.md는 **200줄 미만**을 유지한다.

**CLAUDE.md에 허용되는 내용 (Core 정보만):**
- 프로젝트 개요, 기술 스택, 필수 명령어, 핵심 디렉토리, Git 워크플로우, Rules 참조

**CLAUDE.md에 넣으면 안 되는 내용 → rules/로 이동:**
- 코딩 스타일/컨벤션 상세, 테스트 규칙, API 설계, 보안, DB 패턴

동기화 동작:
1. CLAUDE.md를 Read로 읽고 줄 수 카운트
2. 빌드 명령어/파일 구조/의존성 변경 → CLAUDE.md에 반영
3. 코딩 규칙/패턴 상세 → rules/ 파일로 라우팅 (2-6단계)
4. 200줄 초과 시 상세 내용을 rules/로 분리

### 2-6. rules/ 동기화

`.claude/rules/` 디렉토리의 규칙 파일을 코드 변경에 맞게 동기화한다.

```
Glob: .claude/rules/**/*.md
```

**판단 기준:**
- 기존 rules 파일에 해당 주제가 있으면 → 해당 파일 업데이트
- 해당 주제의 rules 파일이 없으면 → 새 rules 파일 생성하지 않음 (알림만)
- **예외:** CLAUDE.md가 300줄을 초과하여 분리가 필수인 경우, 적절한 이름으로 새 rules 파일 생성 가능

### 2-7. CLAUDE.md 줄 수 최종 검증

| 줄 수 | 상태 | 동작 |
|-------|------|------|
| ≤ 200 | 정상 | 완료 |
| 201-300 | 경고 | 출력에 경고 표시, 분리 제안 |
| > 300 | 초과 | 상세 내용을 rules/로 분리 실행 |

---

## 출력

### 전체 실행 (pull + sync)

```
════════════════════════════════════════════════════════════════
  Sync v7 (pull + docs)
════════════════════════════════════════════════════════════════

  [Pull]
    브랜치: {branch}
    상태: {up-to-date | N commits pulled}

  [Docs]
    작업: {작업 설명}

    prompt_plan.md  {업데이트 | 없음 | 변경없음}
    spec.md         {업데이트 | 없음 | 변경없음}
    CLAUDE.md       {업데이트 | 없음 | 변경없음} (N줄)
    rules/          {N개 업데이트 | 변경없음}

    변경 요약:
      - {변경 항목 1}
      - {변경 항목 2}

    CLAUDE.md: N줄 (정상 / 경고: 200줄 초과)

  다음: /quick-commit

════════════════════════════════════════════════════════════════
```

### --no-pull (문서만)

```
════════════════════════════════════════════════════════════════
  Sync v7 (docs only)
════════════════════════════════════════════════════════════════

  작업: {작업 설명}

  동기화 결과:
    prompt_plan.md  {업데이트 | 없음 | 변경없음}
    spec.md         {업데이트 | 없음 | 변경없음}
    CLAUDE.md       {업데이트 | 없음 | 변경없음} (N줄)
    rules/          {N개 업데이트 | 변경없음}

  CLAUDE.md: N줄 (정상 / 경고: 200줄 초과)

  다음: /quick-commit

════════════════════════════════════════════════════════════════
```

### --check-only

```
════════════════════════════════════════════════════════════════
  Sync v7 (check-only)
════════════════════════════════════════════════════════════════

  변경 필요 사항:

  prompt_plan.md:
    - [ ] → [x] Task 3: API 엔드포인트 구현

  spec.md:
    - API 섹션에 POST /api/users 추가 필요

  CLAUDE.md (현재 N줄):
    - 새 명령어 추가 필요: pnpm db:migrate

  rules/:
    - rules/api-design.md: POST /api/users 추가 필요

  적용하려면: /sync (--check-only 없이 실행)

════════════════════════════════════════════════════════════════
```

### 충돌 발생 시

```
════════════════════════════════════════════════════════════════
  Sync (중단)
════════════════════════════════════════════════════════════════

  [Pull] 충돌 발생! 수동 해결 필요:
    {충돌 파일 목록}

  문서 동기화는 충돌 해결 후 /sync --no-pull 로 실행하세요.

════════════════════════════════════════════════════════════════
```

### 동기화할 문서가 없는 경우

```
════════════════════════════════════════════════════════════════
  Sync v7 (pull + docs)
════════════════════════════════════════════════════════════════

  [Pull]
    브랜치: {branch}
    상태: {up-to-date | N commits pulled}

  [Docs]
    동기화 대상 문서를 찾을 수 없습니다.

    확인할 위치:
      - prompt_plan.md (프로젝트 루트, .claude/, docs/)
      - spec.md (프로젝트 루트, docs/, .claude/)
      - CLAUDE.md (프로젝트 루트, .claude/)
      - .claude/rules/*.md

════════════════════════════════════════════════════════════════
```
