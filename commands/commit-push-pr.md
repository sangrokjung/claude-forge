---
allowed-tools: Bash(git:*), Bash(gh:*), Bash(npm:*), Bash(python:*), Bash(go:*), Bash(cargo:*), Bash(make:*), Read, Grep, Glob, Edit, Write, Skill(sync-docs)
description: 머지 전 /sync-docs 문서 동기화 의무 게이트 → 검증 → 커밋 & PR & 머지 + MCP 알림 (v7)
argument-hint: "[커밋 메시지] [--merge|--squash|--rebase] [--draft] [--no-verify] [--no-checklist] [--skip-security] [--skip-sync-docs] [--notify]"
---

## Task

### 0단계: Context 수집

```bash
git status --short
git branch --show-current
git rev-parse --abbrev-ref origin/HEAD 2>/dev/null | sed 's/origin\///' || echo "main"
git log --oneline -3
git diff --staged --stat 2>/dev/null || git diff --stat
git remote get-url origin 2>/dev/null
gh --version 2>/dev/null | head -1 || echo "not installed"
```

---

### 1단계: 인자 파싱

**$ARGUMENTS에서 옵션 추출:**
- `--merge` → 머지 모드: merge commit
- `--squash` → 머지 모드: squash merge
- `--rebase` → 머지 모드: rebase merge
- `--draft` → Draft PR (머지 옵션과 함께 사용 불가)
- `--no-verify` → 빌드/테스트 스킵
- `--no-checklist` → 머지 후 웹 체크리스트 생성 스킵
- `--skip-security` → 보안 사전 검증 스킵
- `--skip-sync-docs` → 문서 동기화 게이트 스킵 (긴급 hotfix 전용, v7 신규 — 머지 모드에서는 경고 출력)
- `--notify` → 머지 후 MCP 알림 발송 (v6 신규)
- 나머지 → 커밋 메시지

**`--draft`와 머지 옵션 동시 사용 시:**
```
--draft와 머지 옵션(--merge/--squash/--rebase)은 함께 사용할 수 없습니다.

Draft PR은 머지하지 않고 리뷰용으로 생성됩니다.
```
→ 중단

---

### 2단계: 사전 체크

**변경사항 없으면:**
```
커밋할 변경사항이 없습니다.

현재 상태:
- 브랜치: [브랜치명]
- 마지막 커밋: [커밋 메시지]
```
→ 중단

**main/master 브랜치면:**
```
main 브랜치에서 직접 커밋하려고 합니다.

권장: 브랜치 생성 후 작업
  git checkout -b feature/[기능명]

옵션:
1. "브랜치 생성" - 새 브랜치 만들고 진행
2. "계속" - main에 직접 커밋 (PR 생략)
3. "취소" - 작업 중단
```

---

### 3단계: 빌드/테스트 검증

**`--no-verify` 있으면 스킵.**

프로젝트 타입별 검증:

| 파일 | 타입 | 검증 명령 |
|------|------|----------|
| package.json | Node.js | `npm run build && npm test` |
| pyproject.toml / setup.py | Python | `python -m pytest` |
| go.mod | Go | `go build ./... && go test ./...` |
| Cargo.toml | Rust | `cargo build && cargo test` |
| Makefile | Make | `make test` |

**실패 시:**
```
검증 실패

[에러 메시지]

해결 후 다시 시도하거나:
  /commit-push-pr --no-verify
```
→ 중단

---

### 3.5단계: Merge Gate (자동 품질 관문)

커밋 전 아래 4개 조건을 **AND**로 검증한다. 하나라도 FAIL이면 커밋을 중단한다.

| 검증 항목 | 명령어 | FAIL 조건 | --no-verify 시 |
|-----------|--------|-----------|---------------|
| 빌드 | `npm run build` | exit code ≠ 0 | 스킵 가능 |
| 테스트 | `npm test` | exit code ≠ 0 | 스킵 가능 |
| 린트 | `npm run lint` | exit code ≠ 0 | 스킵 가능 |
| 보안 스캔 | security-reviewer agent | CRITICAL 발견 | **스킵 불가** |

**게이트 실패 시 출력 형식:**
```
┌─────────────┬────────┬──────────────────┐
│ 검증 항목    │ 결과   │ 상세              │
├─────────────┼────────┼──────────────────┤
│ 빌드        │ PASS   │                   │
│ 테스트      │ FAIL   │ 2 tests failed    │
│ 린트        │ PASS   │                   │
│ 보안 스캔   │ PASS   │                   │
└─────────────┴────────┴──────────────────┘
❌ Merge Gate FAIL: 테스트 실패. 커밋을 중단합니다.
```

**규칙:**
- `--no-verify` 플래그가 있으면 빌드/테스트/린트는 스킵 가능
- 보안 스캔에서 CRITICAL이 발견되면 `--no-verify`여도 **반드시 차단**
- 모든 검증이 PASS면 다음 단계(4단계)로 진행

---

### 4단계: 보안 검증

> **머지 옵션이 있을 때만 실행.** PR만 생성하는 경우 스킵.
> `--skip-security` 있으면 스킵 (경고 출력 후).

**`--skip-security` 사용 시:**
```
보안 검증을 건너뜁니다 (--skip-security)
   머지 후 반드시 수동 보안 검토를 수행하세요.
```
→ 5단계로 진행

**보안 검증 실행:**

**4-1. 변경 파일 수집:**
```bash
git diff --cached --name-only 2>/dev/null || git diff --name-only
```

**4-2. 보안 민감 파일 자동 감지:**

다음 패턴에 해당하는 파일이 변경 목록에 있으면 보안 검증 **강제 실행** (--skip-security 무시):

| 패턴 | 영역 |
|------|------|
| `auth/*`, `**/auth/**` | 인증 |
| `payment/*`, `**/payment/**` | 결제 |
| `session/*`, `**/session/**` | 세션 |
| `*secret*`, `*token*`, `*password*` | 시크릿 |
| `middleware*`, `**/middleware/**` | 미들웨어 |
| `.env*`, `*credentials*` | 환경변수/자격증명 |
| `**/api/admin/**` | 관리자 API |

**4-3. 보안 스캔 항목:**

| 검사 항목 | 패턴 | 심각도 |
|-----------|------|--------|
| 하드코딩된 시크릿 | `sk-`, `pk_`, `AKIA`, `ghp_`, `password\s*=\s*["']` | CRITICAL |
| SQL 인젝션 | 문자열 보간 SQL, `${}` in query | CRITICAL |
| XSS 취약점 | `dangerouslySetInnerHTML`, `innerHTML =` | HIGH |
| 민감 데이터 로깅 | `console.log.*password`, `console.log.*token` | HIGH |
| 하드코딩 URL | `http://localhost` in production code | MEDIUM |
| 취약한 의존성 | `package.json` 변경 시 known vulnerabilities | MEDIUM |
| 인증 우회 | `auth.*skip`, `verify.*false`, `bypass` | HIGH |
| CORS 설정 | `Access-Control-Allow-Origin: *` | MEDIUM |

**4-4. 결과 처리:**

**CRITICAL 발견 시 → 머지 차단:**
```
보안 검증 실패 - 머지 차단
─────────────────────────────────

CRITICAL 이슈 발견:

  [파일:라인] [CWE-XXX] [설명]

수정 제안:
  [구체적 수정 방법]

수정 후 다시 시도:
  /commit-push-pr [원래 옵션들]
─────────────────────────────────
```
→ 중단

**HIGH/MEDIUM만 발견 시 → 경고 후 진행:**
```
보안 검증 완료 (경고 있음)
─────────────────────────────────

HIGH: [N]건
  [파일:라인] [설명]

MEDIUM: [N]건
  [파일:라인] [설명]

머지를 계속 진행합니다.
─────────────────────────────────
```
→ 5단계로 진행

**이슈 없음:**
```
보안 검증 통과
─────────────────────────────────
  스캔 파일: [N]개
  발견 이슈: 없음 (CWE scan clean)
─────────────────────────────────
```
→ 5단계로 진행

**보안 검증 결과 변수 저장:**
- `$SECURITY_STATUS` → "pass" | "warn" | "block"
- `$SECURITY_SUMMARY` → PR 본문에 포함할 요약 텍스트

---

### 4.5단계: /sync-docs 문서 동기화 게이트 (머지 전 의무, v7 CRITICAL)

> **머지 옵션(`--merge`/`--squash`/`--rebase`)이 있으면 이 단계는 의무다.**
> 인라인 요약 갱신으로 대체 금지 — 반드시 **Skill 도구로 실제 `/sync-docs` 스킬을 실행**한다.
> 사용자에게 되묻지 않고 자동 실행한다 (frontmatter `Skill(sync-docs)` 사전 승인).

**실행 규칙:**

| 모드 | 동작 |
|------|------|
| 머지 모드 (`--merge`/`--squash`/`--rebase`) | **`sync-docs` 의무 실행. 스킵 불가** (`--skip-sync-docs` 명시 시에만 경고 후 스킵 — 긴급 hotfix 전용) |
| PR-only / `--draft` | `sync-docs` 기본 실행 (`--skip-sync-docs`로 스킵 가능) |

**실행 방법 (자동 — 사용자 확인 불필요):**

```
Skill 도구 호출: skill = "sync-docs"
```

`/sync-docs` v7.1이 수행하는 것:
1. `prompt_plan.md` → 완료 항목 체크 + 진행 상황 갱신
2. `spec.md` → 구현 기능/API/데이터 모델 반영
3. `CLAUDE.md` → 명령어/구조 변경 반영 (200줄 원칙)
4. `.claude/rules/` → glob 매핑 기반 규칙 동기화
5. 흩어진 파일 housekeeping scan (PII/시크릿 감지)

**게이트 규칙:**
- sync-docs가 변경한 문서는 5단계 `git add -A`로 **같은 커밋에 포함**한다 (별도 커밋 생성 금지)
- sync-docs housekeeping scan이 `alert`(PII/시크릿)를 반환하면 → **커밋/머지 중단** + `/save-work --apply` 안내
- `--skip-sync-docs` + 머지 모드 조합 시 경고 출력 후 진행:

```
⚠ 문서 동기화 게이트를 건너뜁니다 (--skip-sync-docs)
   머지 후 반드시 /sync-docs를 수동 실행하세요. (긴급 hotfix 전용)
```

**동기화 결과 변수 저장:**
- `$SYNC_DOCS_STATUS` → "done" | "no-change" | "skipped"

---

### 5단계: 스테이징 & 커밋

```bash
git add -A
```

**커밋 메시지 결정:**
1. `$ARGUMENTS`에 메시지 있으면 → 그대로 사용
2. 없으면 → 변경 내용 분석해서 Conventional Commits 형식으로 생성

**Conventional Commits:**
| Type | 용도 |
|------|------|
| feat | 새 기능 |
| fix | 버그 수정 |
| refactor | 리팩토링 |
| docs | 문서 |
| test | 테스트 |
| chore | 기타 |
| style | 포맷팅 |
| perf | 성능 개선 |

**커밋 메타데이터 (v6):**
커밋 메시지 본문에 보안 스캔 결과 포함 (선택적):
```
[type]: [description]

security-scan: [pass|warn|skipped]
```

```bash
git commit -m "[메시지]"
```

---

### 6단계: Push

```bash
git push
```

**원격 브랜치 없으면:**
```bash
git push --set-upstream origin [브랜치명]
```

**Push 실패 시:**
```
Push 실패

원인 분석:
1. 원격과 충돌 → `git pull --rebase` 후 재시도
2. 권한 문제 → `gh auth status` 확인
3. 보호된 브랜치 → PR로 머지 필요

수동 해결 후:
  git push
```
→ 중단

---

### 7단계: PR 생성

**gh CLI 없으면:**
```
커밋 & Push 완료

PR 생성 (GitHub 웹):
   https://github.com/[owner]/[repo]/pull/new/[브랜치]

gh CLI 설치하면 자동 PR 생성 & 머지:
   brew install gh && gh auth login
```
→ 종료

**main/master 브랜치면:**
```
main 브랜치에 직접 Push 완료 (PR 생략)
```
→ 종료

**기존 PR 확인:**
```bash
gh pr view --json number,url,state 2>/dev/null
```

있으면 → 7-1단계로 (기존 PR 처리)
없으면 → 7-2단계로 (새 PR 생성)

---

#### 7-1단계: 기존 PR 처리

**머지 옵션 없으면:**
```
기존 PR에 Push 완료

PR #[번호]: [URL]
```
→ 종료

**머지 옵션 있으면:**
→ 8단계로 (머지 실행)

---

#### 7-2단계: 새 PR 생성

PR 본문 생성:
```markdown
## 변경 사항

[커밋 메시지]

## 커밋 목록

[git log origin/베이스..HEAD --oneline 결과]

## 변경 파일

[git diff origin/베이스..HEAD --stat 결과]

## 보안 스캔

[보안 검증 결과 요약 - $SECURITY_SUMMARY]
- 스캔 상태: [pass / warn / skipped]
- 발견 이슈: [요약 또는 "없음"]

## 체크리스트

- [x] 빌드 통과
- [x] 테스트 통과
- [x] 보안 스캔 완료
```

**Draft PR (`--draft`):**
```bash
gh pr create --draft --title "[커밋 메시지]" --body "[본문]"
```
→ Draft 완료 출력 후 종료

**일반 PR:**
```bash
gh pr create --title "[커밋 메시지]" --body "[본문]"
```

---

### 8단계: 머지 (옵션 있을 때만)

**머지 옵션 없으면 이 단계 스킵 → 10단계로**

**CI 체크 대기:**
```bash
gh pr checks --watch
```

**CI 실패 시:**
```
CI 체크 실패

[실패한 체크 목록]

수정 후 다시 시도하세요.
```
→ 중단

**머지 실행:**

| 옵션 | 명령어 |
|------|--------|
| `--merge` | `gh pr merge --merge --delete-branch` |
| `--squash` | `gh pr merge --squash --delete-branch` |
| `--rebase` | `gh pr merge --rebase --delete-branch` |

**머지 실패 시 자동 에스컬레이션:**

**Stage 1: 자동 rebase 시도 (최대 1회)**
1. `git fetch origin main && git rebase origin/main` 실행
2. 충돌 없으면 → `git push --force-with-lease` → 머지 재시도
3. 충돌 발생 시 → `git rebase --abort` → Stage 2로

**Stage 2: escalation-fixer (Opus)**
4. Agent 도구로 escalation-fixer 호출:
   - prompt: 머지 충돌 에러 + `git diff` + 충돌 파일 목록
   - 에이전트가 충돌 해결 → 커밋 → 푸시 → 머지 재시도
5. 머지 성공 시 → 9단계로
6. 실패 시 → Stage 3

**Stage 3: Telegram Hard Block**
7. Telegram 알림: `telegram-notify.sh escalation` (머지 실패)
8. 안내:
```
════════════════════════════════════════════════════════════════
🚨 MERGE FAILED - 자동 해결 실패
════════════════════════════════════════════════════════════════

에러: [머지 에러 메시지]
시도:
  Stage 1: auto rebase → 실패 (충돌)
  Stage 2: escalation-fixer → 실패
  Stage 3: Telegram Hard Block

수동 해결:
1. 충돌 해결: git fetch && git rebase origin/main
2. 재시도: /commit-push-pr --merge

📱 Telegram 알림 발송 완료
⏸️ 작업 중단 - 사람 지시 대기
════════════════════════════════════════════════════════════════
```
→ 중단

**머지 성공 후 로컬 정리:**
```bash
git checkout main
git pull
```

→ **9단계로 (웹 체크리스트 자동 생성)**

---

### 9단계: 웹 체크리스트 자동 생성 (머지 성공 시)

> **머지 성공 후 자동 실행.** `--no-checklist` 옵션 시 스킵.
> 머지 옵션 없이 PR만 생성한 경우에도 스킵 → 9-N단계로.

**9-1. 변경 파일 수집:**
```bash
git log --oneline -1
git diff HEAD~1 --name-only
git diff HEAD~1 --stat
```

**9-2. 컨텍스트 로드 (있는 것만):**
- `.claude/handoff.md` → "테스트 필요 사항", "주의사항" 섹션
- `spec.md` → 기능 요구사항
- `prompt_plan.md` → 현재 Task 상세

**9-3. 변경 영역 자동 분류:**

| 카테고리 | 파일 패턴 | 테스트 영역 |
|----------|-----------|-------------|
| UI/화면 | `*.tsx`, `*.jsx`, `components/*` | 화면 표시, 반응형, 인터랙션 |
| API/서버 | `api/*`, `server/*`, `route*` | 엔드포인트, 응답 |
| 인증 | `auth/*`, `login/*`, `session/*`, `middleware*` | 로그인, 로그아웃, 권한 |
| 결제 | `payment/*`, `billing/*`, `subscription/*` | 결제 플로우, 금액 |
| 데이터 | `*.sql`, `supabase/*`, `db/*`, `migration*` | 데이터 정합성 |
| 스타일 | `*.css`, `*.scss`, `tailwind.*` | 레이아웃, 디자인 |
| 설정 | `*.config.*`, `*.env*`, `package.json` | 환경 설정, 의존성 |

**9-4. 체크리스트 생성 규칙:**

handoff.md의 "테스트 필요 사항"이 있으면 → **최우선으로 반영** (가장 구체적인 정보원)
없으면 → 변경 파일 패턴 + spec.md 기반으로 생성

**카테고리별 체크 항목:**

UI 변경 시:
- [ ] 변경된 화면 정상 렌더링
- [ ] 반응형 확인 (모바일/데스크톱)
- [ ] 로딩/에러/빈 상태 표시
- [ ] 콘솔 에러 없음

인증 변경 시:
- [ ] 로그인/로그아웃 정상 동작
- [ ] 세션 만료 시 동작
- [ ] 권한별 접근 제어

결제 변경 시:
- [ ] 테스트 결제 (sandbox)
- [ ] 금액 정확성
- [ ] 실패 케이스 처리
- [ ] 완료 후 상태 업데이트

API 변경 시:
- [ ] 엔드포인트 정상 응답
- [ ] 에러 응답 처리
- [ ] 인증/권한 체크

데이터 변경 시:
- [ ] 기존 데이터 정합성
- [ ] 새 데이터 CRUD 정상
- [ ] 마이그레이션 적용 확인

설정 변경 시:
- [ ] 환경변수 설정 확인
- [ ] 의존성 설치 정상
- [ ] 빌드 정상

---

### 9-N단계: MCP 알림 발송 (--notify, v6 신규)

> **`--notify` 플래그가 있을 때만 실행.**
> 머지 성공 후 이해관계자에게 배포 알림을 MCP로 발송한다.

**9-N-1. Gmail MCP — 배포 알림 이메일:**

```
ToolSearch → "select:mcp__gmail__send_email"
```

이메일 내용:
```
수신: [이해관계자 이메일 — 사용자에게 확인]
제목: [배포 알림] [커밋 메시지]

안녕하세요,

다음 변경 사항이 배포되었습니다.

## 변경 내용
- PR: #[번호] [제목]
- 브랜치: [브랜치] → [베이스]
- 머지 방식: [merge/squash/rebase]

## 변경 파일 요약
[git diff 요약]

## 확인 필요 사항
[handoff.md 주의사항 또는 변경 분석 기반]

감사합니다.
```

**9-N-2. Google Calendar MCP — 배포 기록:**

```
ToolSearch → "select:mcp__google-calendar__create-event"
```

이벤트 내용:
```
제목: [Deploy] [커밋 메시지]
시간: [현재 시간] (30분 이벤트)
설명: PR #[번호], [변경 파일 수]개 파일
```

**9-N-3. N8N MCP — 추가 알림 (선택):**

n8n 워크플로우가 설정되어 있으면:
```
ToolSearch → "select:mcp__n8n-mcp__n8n_test_workflow"
```

Slack/Discord 등 추가 채널에 알림 트리거.

---

### 10단계: 완료 출력

**PR만 생성 (머지 옵션 없음):**
```
════════════════════════════════════════════════════════════════
  Commit & PR Complete (v7)
════════════════════════════════════════════════════════════════

  커밋: [해시] [메시지]
  브랜치: [브랜치] → [베이스]
  PR #[번호]: [URL]
  문서 동기화: [sync-docs 완료 | 변경 없음 | 스킵 (--skip-sync-docs)]
  보안: [스캔 안 함 (PR only)]

다음 단계:
  PR 리뷰 후: /commit-push-pr --merge --notify
════════════════════════════════════════════════════════════════
```

**PR 생성 + 머지 완료 (체크리스트 포함):**
```
════════════════════════════════════════════════════════════════
  Commit & PR & Merge Complete (v7)
════════════════════════════════════════════════════════════════

  커밋: [해시] [메시지]
  머지: [브랜치] → [베이스] ([merge/squash/rebase])
  브랜치 삭제됨: [브랜치]
  문서 동기화: [sync-docs 완료 | 변경 없음 | 스킵 (--skip-sync-docs)]
  보안: Pass (CWE scan clean) | Warn ([N]건) | Skipped
  알림: [발송됨 (--notify) | 미발송]

────────────────────────────────────────────────────────────────
  서버 테스트 체크리스트
────────────────────────────────────────────────────────────────

  변경 영역: [감지된 카테고리 목록]

## 기능 확인
- [ ] [handoff.md 또는 변경 분석 기반 항목 1]
- [ ] [항목 2]

## UI 확인 (UI 변경 시)
- [ ] 변경 화면 정상 렌더링
- [ ] 반응형 확인
- [ ] 콘솔 에러 없음

## 환경별 확인

### localhost (http://localhost:3000)
- [ ] 기능 동작 확인

### 프로덕션
- [ ] 배포 완료 확인 (Vercel/서버)
- [ ] 기능 동작 확인
- [ ] 에러 모니터링 확인

────────────────────────────────────────────────────────────────
  주의: [handoff.md 주의사항 또는 변경 분석 기반]
────────────────────────────────────────────────────────────────

다음 단계:
  위 체크리스트 확인
════════════════════════════════════════════════════════════════
```

**PR 생성 + 머지 완료 (--no-checklist 시):**
```
════════════════════════════════════════════════════════════════
  Commit & PR & Merge Complete (v7)
════════════════════════════════════════════════════════════════

  커밋: [해시] [메시지]
  머지: [브랜치] → [베이스] ([merge/squash/rebase])
  브랜치 삭제됨: [브랜치]
  문서 동기화: [sync-docs 완료 | 변경 없음 | 스킵 (--skip-sync-docs)]
  보안: Pass (CWE scan clean) | Warn ([N]건) | Skipped
  알림: [발송됨 (--notify) | 미발송]

다음 단계:
  /web-checklist - 웹 테스트 체크리스트 (수동)
════════════════════════════════════════════════════════════════
```

**Draft PR:**
```
════════════════════════════════════════════════════════════════
  Draft PR Created (v7)
════════════════════════════════════════════════════════════════

  커밋: [해시] [메시지]
  브랜치: [브랜치]
  Draft PR #[번호]: [URL]

Ready 전환:
  gh pr ready

계속 작업:
  [코드 수정] → /commit-push-pr --draft
════════════════════════════════════════════════════════════════
```

---

## 인자 설명

| 인자 | 설명 |
|------|------|
| `[메시지]` | 커밋 메시지 (없으면 자동 생성) |
| `--merge` | PR 생성 + merge commit으로 머지 |
| `--squash` | PR 생성 + squash merge |
| `--rebase` | PR 생성 + rebase merge |
| `--draft` | Draft PR 생성 (머지 안 함) |
| `--no-verify` | 빌드/테스트 스킵 |
| `--no-checklist` | 머지 후 웹 체크리스트 생성 스킵 |
| `--skip-security` | 보안 사전 검증 스킵 |
| `--skip-sync-docs` | 문서 동기화 게이트 스킵 (긴급 hotfix 전용, v7 신규) |
| `--notify` | 머지 후 MCP 알림 발송 (v6 신규) |

## 사용 예시

```bash
# PR만 생성 (리뷰 필요할 때)
/commit-push-pr

# PR 생성 + 즉시 머지 (v7 기본 플로우: sync-docs 게이트 → 검증 → 머지)
/commit-push-pr --merge

# 머지 + MCP 알림
/commit-push-pr --merge --notify

# 머지하되 체크리스트 스킵 (docs만 변경 등)
/commit-push-pr --merge --no-checklist

# Squash 머지 (커밋 정리) + 알림
/commit-push-pr --squash --notify

# Rebase 머지 (히스토리 유지)
/commit-push-pr feat: 로그인 기능 --rebase

# Draft PR (WIP)
/commit-push-pr --draft

# 긴급 수정 + 즉시 머지 + 모든 검증 스킵 + 알림 (hotfix 전용 — 머지 후 /sync-docs 수동 실행 의무)
/commit-push-pr fix: hotfix --merge --no-verify --no-checklist --skip-security --skip-sync-docs --notify

# 보안 검증만 스킵 (빌드/테스트와 sync-docs 게이트는 유지)
/commit-push-pr --merge --skip-security
```

## 보안 검증 상세

### 강제 보안 검증 트리거

다음 파일 패턴이 변경 목록에 포함되면 `--skip-security`를 사용해도 보안 검증이 강제 실행됩니다:

| 패턴 | 이유 |
|------|------|
| `auth/*`, `**/auth/**` | 인증 로직 변경은 항상 검증 |
| `payment/*`, `**/payment/**` | 결제 로직은 항상 검증 |
| `session/*`, `**/session/**` | 세션 관리는 항상 검증 |
| `*secret*`, `*token*`, `*password*` | 시크릿 관련 파일은 항상 검증 |
| `middleware*`, `**/middleware/**` | 미들웨어는 보안 게이트 |
| `.env*`, `*credentials*` | 환경변수/자격증명 노출 방지 |
| `**/api/admin/**` | 관리자 API는 항상 검증 |

### CWE 매핑

| 검사 항목 | CWE | 심각도 |
|-----------|-----|--------|
| 하드코딩 시크릿 | CWE-798 | CRITICAL |
| SQL 인젝션 | CWE-89 | CRITICAL |
| XSS | CWE-79 | HIGH |
| 민감 데이터 로깅 | CWE-532 | HIGH |
| 인증 우회 | CWE-287 | HIGH |
| 잘못된 CORS | CWE-942 | MEDIUM |
| 하드코딩 URL | CWE-547 | MEDIUM |

## 에러 복구

**Push 충돌:**
```bash
git pull --rebase
git rebase --continue
git push
```

**머지 충돌:**
```bash
git fetch origin
git rebase origin/main
# 충돌 해결
git push --force-with-lease
/commit-push-pr --merge
```

**gh 인증 문제:**
```bash
gh auth status
gh auth login
```

**보안 검증 오탐 (false positive):**
```bash
# 1. 해당 패턴이 실제 보안 이슈가 아닌 경우
# 2. 코드 리뷰로 확인 후
/commit-push-pr --merge --skip-security

# 보안 민감 파일이면 --skip-security가 무시됨
# 이 경우 코드를 수정하여 패턴을 제거하거나
# 보안 리뷰어와 상의 후 진행
```
