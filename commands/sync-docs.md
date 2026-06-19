---
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(git:*), Bash(~/.claude/scripts/sync-housekeeping-scan.sh:*)
description: prompt_plan.md, spec.md, CLAUDE.md + rules/ 문서 동기화 (v7.1 — 흩어진 파일 housekeeping scan 통합)
argument-hint: "[--check-only]"
---

# /sync-docs - 문서 동기화 (v7.1)

> Scope: prompt_plan.md, spec.md, CLAUDE.md, .claude/rules/ 등 핵심 프로젝트 메타 문서 동기화. 일반 문서(README, API docs, 가이드)는 /update-docs를 사용하세요.

---

## 0단계: 작업 설명 확인

인자로 전달된 작업 설명을 확인한다.
인자가 없으면 최근 커밋 메시지에서 작업 내용을 추론한다.

```bash
git log --oneline -5
```

---

## 0.5단계: 흩어진 파일 housekeeping scan (CRITICAL, 2026-05-29 신설)

> 규칙: `~/qjc-office/dotclaude/rules/sync-housekeeping.md`

문서 동기화 전, cwd에 흩어진 untracked 파일을 감지한다. 실제 이동은 본 명령어가 수행하지 않으며, 감지만.

```bash
~/.claude/scripts/sync-housekeeping-scan.sh --json > /tmp/sync-docs-housekeeping.json
LEVEL=$(python3 -c "import json; print(json.load(open('/tmp/sync-docs-housekeeping.json'))['level'])")
```

| Level | 동작 |
|-------|------|
| `alert` (PII/시크릿 패턴 감지) | **즉시 중단** + `/save-work --apply`로 sanitize 권장 안내 |
| `warn` (민감 파일 의심 또는 10개+ 흩어진 문서) | 한국어 배너 stderr 출력 + 진행 유지 + `/save-work --apply` 권장 |
| `info` (흩어진 파일 1~9개) | 한 줄 카운트 출력 + 진행 유지 |
| `ok` (정상) | 출력 없이 진행 |

비활성: `export QJC_SYNC_HOUSEKEEPING_DISABLED=1`

---

## 1단계: 모드 결정 (CRITICAL)

인자에 `--check-only`가 포함되어 있으면:
- **모든 Write/Edit 도구 호출을 금지한다.**
- 각 단계에서 "변경이 필요한 항목"만 수집한다.
- 9단계의 --check-only 출력 형식을 사용한다.

이 판단은 이후 **모든 단계에 적용**된다. `--check-only` 모드에서는 Read/Glob/Grep/Bash(git)만 사용한다.

---

## 2단계: 변경된 코드 분석

현재 브랜치에서 변경된 파일과 내용을 파악한다.

**diff 범위 자동 감지:**

```bash
# main/master 브랜치와의 분기점 기반 (우선)
BASE=$(git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null)
if [ -n "$BASE" ] && [ "$BASE" != "$(git rev-parse HEAD)" ]; then
  git diff --name-only "$BASE"..HEAD
  git diff --stat "$BASE"..HEAD
else
  # 분기점이 없으면 (main 브랜치 자체) 최근 커밋 기반
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

---

## 충돌 해결 원칙

소스 코드(git diff)가 최우선 진실 소스(source of truth)이다.
문서 간 불일치가 발견되면, 코드 상태를 기준으로 모든 문서를 일관되게 업데이트한다.

---

## 3단계: prompt_plan.md 동기화

Glob 패턴으로 `prompt_plan.md`를 탐색한다:
- `./prompt_plan.md`
- `./.claude/prompt_plan.md`
- `./docs/prompt_plan.md`

업데이트 항목:
- 완료된 작업 항목 체크 (`- [x]`)
- 진행 상황 갱신
- 다음 단계 업데이트

파일이 없으면 건너뛴다.

---

## 4단계: spec.md 동기화

Glob 패턴으로 `spec.md`를 탐색한다:
- `./spec.md`
- `./docs/spec.md`
- `./.claude/spec.md`

업데이트 항목:
- 구현된 기능 반영
- API 변경사항 반영
- 데이터 모델 변경 반영

파일이 없으면 건너뛴다.

---

## 5단계: CLAUDE.md 동기화 (200줄 원칙 (Anthropic 공식))

Glob 패턴으로 `CLAUDE.md`를 탐색한다:
- `./CLAUDE.md`
- `./.claude/CLAUDE.md`

발견된 경로를 이후 단계에서도 일관되게 사용한다.

### 200줄 원칙 (Anthropic 공식) (CRITICAL)

CLAUDE.md는 **200줄 미만**을 유지한다. 이를 초과하면 Claude가 규칙을 무시하기 시작한다.

**CLAUDE.md에 허용되는 내용 (Core 정보만):**
- 프로젝트 개요 (1-3줄)
- 기술 스택 (5-10줄)
- 필수 명령어 (5-10줄)
- 핵심 디렉토리 구조 (5-8줄)
- Git 워크플로우 (3-5줄)
- Rules 참조 안내 (1-2줄)

**CLAUDE.md에 넣으면 안 되는 내용 → rules/로 이동:**
- 코딩 스타일/컨벤션 상세
- 테스트 규칙 상세
- API 설계 규칙
- 보안 체크리스트
- DB 패턴
- 프론트엔드/백엔드 패턴 상세

### 동기화 동작

1. CLAUDE.md를 Read로 읽는다.
2. 줄 수를 카운트한다.
3. 변경된 코드에 따라 업데이트할 항목을 결정한다:
   - 새로운 빌드/실행 명령어 → CLAUDE.md에 추가
   - 파일 구조 변경 → CLAUDE.md에 반영
   - 새로운 의존성 → CLAUDE.md에 기록
   - 코딩 규칙/패턴 상세 → **rules/ 파일로 라우팅** (6단계로)
4. 업데이트 후 **200줄 초과 여부**를 검증한다.
5. 초과하면 상세 내용을 rules/ 파일로 분리한다.

---

## 6단계: rules/ 동기화

`.claude/rules/` 디렉토리의 규칙 파일을 코드 변경에 맞게 동기화한다.

### 6-1. 기존 rules 탐색

```
Glob: .claude/rules/**/*.md
```

기존 rules 파일 목록과 각 파일의 주제를 파악한다.

### 6-2. 변경 내용 → rules 매핑 (실행 규칙, CRITICAL)

**glob 패턴 기반 자동 라우팅** — 변경 파일 목록을 아래 패턴과 매칭하여 대상 rules를 결정한다. 한 파일이 여러 패턴에 매칭되면 모두 업데이트 대상.

| 파일 패턴 (glob) | 대상 rules 파일 | 업데이트 동작 |
|------------------|-----------------|---------------|
| `supabase/functions/**/_shared/notify.ts` | `rules/discord-bot.md` | MENTION_ALLOWLIST 목록 / 새 NotificationType 반영 |
| `supabase/functions/**/_shared/*.ts` | `rules/edge-functions.md` | 공유 모듈 변경 기록 |
| `supabase/migrations/**/*.sql` | `rules/supabase.md` | 신규 테이블/RPC/인덱스 목록 |
| `supabase/functions/*/handlers/*.ts` | `rules/edge-functions.md` | 엔드포인트 목록 |
| `supabase/functions/*/index.ts` | `rules/edge-functions.md` | 라우팅 변경 |
| `dashboard/app/api/**/*.ts` | `rules/api-design.md` | API Route 추가/변경 |
| `dashboard/app/**/page.tsx`, `dashboard/app/**/_*.tsx` | `rules/react-components.md` | Server/Client 경계 점검 (rsc-guard 연동) |
| `dashboard/middleware.ts`, `**/auth/**` | `rules/security.md` | 인증/권한 경로 변경 |
| `dashboard/lib/skill-catalog.json` | `rules/three-tools.md` | 3대 원툴 목록 변경 감지 시 |
| `.claude/commands/*.md`, `.claude/agents/*.md` | `rules/three-tools.md` / `rules/agents.md` | 새 스킬/에이전트 등재 |
| `.claude/hooks/*.sh` | `rules/doc-sync.md` | 자동화 훅 변경 기록 |
| `.env*`, `*credentials*`, `*secret*` | `rules/env-sync.md` + `rules/security.md` | 환경변수 동기화 필수 |
| 패키지 버전 (`package.json`, `package-lock.json`) | `rules/doc-sync.md` (프로젝트 루트) | 주요 의존성 업데이트 기록 |
| 빌드/배포 설정 (`vercel.json`, `*.config.*`) | `rules/deploy.md` 또는 CLAUDE.md "Dashboard" 섹션 | 빌드 규칙 |
| `tests/**`, `*.test.*`, `*.spec.*` | `rules/testing.md` | 테스트 규칙 |

### 6-2-a. 매핑 실행 절차

1. **변경 파일 목록 수집** (2단계의 diff 결과 재사용)
2. **파일마다 glob 매칭** — 해당되는 대상 rules 후보 세트 생성
3. **기존 rules 파일 존재 여부 확인** — `.claude/rules/<name>.md` 없으면 5단계 예외 조항(300줄 초과 시) 외에는 **신규 생성 금지**, 알림만 출력
4. **변경 내용 요약** — diff를 읽고 해당 rules 파일의 관련 섹션을 간략히 업데이트 (5-10줄 이내)
5. **각 rules 파일 업데이트 시 frontmatter `paths` 유지/추가** — 해당 glob 패턴을 paths에 자동 등록

### 6-2-b. 명시적 skip 규칙

아래 파일은 rules 동기화 대상이 아니며 로그만 남긴다:
- `dashboard/app/guide/_*.{ts,tsx,json}` — 가이드 페이지 데이터는 skill-catalog에서 파생되므로 별도 rules 갱신 불필요
- `**/*.lock`, `**/scheduled_tasks.lock` — runtime artifact
- `.claude/qa-*.{md,json}`, `.claude/handoff.md` — session-local

### 6-3. Path-Specific frontmatter 유지

rules 파일에 `paths` frontmatter가 있으면 유지한다. 새 파일 생성 시 적절한 paths를 추가한다:

```markdown
---
paths:
  - "src/api/**/*.ts"
---
```

### 6-4. 판단 기준

- 기존 rules 파일에 해당 주제가 있으면 → **해당 파일 업데이트**
- 해당 주제의 rules 파일이 없으면 → **새 rules 파일 생성하지 않음** (알림만)
- CLAUDE.md에서 분리해야 할 내용이 있으면 → 기존 rules 파일에 이동하거나, 없으면 알림
- **예외:** 7단계에서 CLAUDE.md가 300줄을 초과하여 분리가 필수인 경우, 적절한 이름으로 새 rules 파일을 생성할 수 있다. 이 경우 paths frontmatter를 포함한다.

---

## 7단계: CLAUDE.md 줄 수 검증

5단계에서 발견한 CLAUDE.md 경로를 사용하여 줄 수를 최종 검증한다.

| 줄 수 | 상태 | 동작 |
|-------|------|------|
| ≤ 200 | 정상 | 완료 |
| 201-300 | 경고 | 출력에 경고 표시, 분리 제안 |
| > 300 | 초과 | 상세 내용을 rules/로 분리 실행 (6-4 예외 조항 적용) |

---

## 8단계: 커밋 안내 + project-status-snapshot 제안

동기화로 파일이 변경된 경우 다음 액션을 안내한다:
- `--check-only` 모드 → "적용하려면: /sync-docs"
- 변경 있음 → "다음: /quick-commit"
- 변경 없음 → 안내 생략

**프로젝트 상태 블록 제안 (Phase 9 통합)**:
- 레포 루트에 `README.md` 또는 `docs/STATUS.md`가 있고 `<!-- qjc-auto-status:start -->` 블록이 탐지되거나 os_projects에 프로젝트 등록됐으면 → 출력 말미에 **"권장: `/project-status-snapshot --dry-run`으로 진행상황 블록 갱신"** 한 줄 추가
- 자동 실행하지 않음 — 사용자 판단 유도

---

## 9단계: 출력

### 동기화 완료 시

```
════════════════════════════════════════════════════════════════
  Sync Docs v7 (문서 동기화)
════════════════════════════════════════════════════════════════

  작업: [완료한 작업 설명]

  동기화 결과:
    prompt_plan.md  [업데이트 / 없음 / 변경없음]
    spec.md         [업데이트 / 없음 / 변경없음]
    CLAUDE.md       [업데이트 / 없음 / 변경없음] (N줄)
    rules/          [N개 업데이트 / 변경없음]

  변경 요약:
    - [변경 항목 1]
    - [변경 항목 2]

  CLAUDE.md: N줄 (정상 / 경고: 200줄 초과)

  다음: /quick-commit

════════════════════════════════════════════════════════════════
```

### --check-only 모드 출력

```
════════════════════════════════════════════════════════════════
  Sync Docs v7 (check-only)
════════════════════════════════════════════════════════════════

  변경 필요 사항:

  prompt_plan.md:
    - [ ] → [x] Task 3: API 엔드포인트 구현
    - 진행률: 3/7 → 4/7

  spec.md:
    - API 섹션에 POST /api/users 추가 필요

  CLAUDE.md (현재 N줄):
    - 새 명령어 추가 필요: pnpm db:migrate
    - 경고: 300줄 초과 → rules/ 분리 필요
      → 코딩 컨벤션 (15줄) → rules/code-style.md로 이동 제안

  rules/:
    - rules/api-design.md: POST /api/users 엔드포인트 추가 필요
    - rules/database.md: users 테이블 스키마 변경 반영 필요

  적용하려면: /sync-docs (--check-only 없이 실행)

════════════════════════════════════════════════════════════════
```

### 동기화할 문서가 없는 경우

```
════════════════════════════════════════════════════════════════
  Sync Docs v7 (문서 동기화)
════════════════════════════════════════════════════════════════

  동기화 대상 문서를 찾을 수 없습니다.

  확인할 위치:
    - prompt_plan.md (프로젝트 루트, .claude/, docs/)
    - spec.md (프로젝트 루트, docs/, .claude/)
    - CLAUDE.md (프로젝트 루트, .claude/)
    - .claude/rules/*.md

════════════════════════════════════════════════════════════════
```

### CLAUDE.md 초과 분리 시

```
════════════════════════════════════════════════════════════════
  Sync Docs v7 (CLAUDE.md 분리)
════════════════════════════════════════════════════════════════

  CLAUDE.md가 N줄 → 200줄로 축소

  분리된 내용:
    → rules/code-style.md (15줄 이동, 신규 생성)
    → rules/testing.md (12줄 이동, 기존 파일)

  CLAUDE.md: N줄 → 200줄 (정상)

════════════════════════════════════════════════════════════════
```
