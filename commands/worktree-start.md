---
allowed-tools: Bash(git:*), Read, Grep
description: 병렬 개발용 Git Worktree 생성 + 도메인 템플릿 (v6)
argument-hint: "[브랜치명] [--type feature|bugfix|refactor]"
---

## Task

### 0단계: 환경 확인

```bash
git rev-parse --git-dir
git worktree list
git branch -a
```

**git 레포 아니면:**
```
❌ git 레포가 아닙니다.
git init 먼저 실행하세요.
```
→ 중단

### 0.5단계: 충돌 방지 확인

```bash
# .gitignore에 Claude Code 자동 생성 파일이 있는지 확인
grep -E "\.claude/context/|\.claude/settings" .gitignore 2>/dev/null

# 추적 중인 Claude Code 파일 확인
git ls-files | grep "^\.claude/"
```

**Claude Code 파일이 .gitignore에 없으면:**
```
⚠️ 충돌 방지 설정 필요
════════════════════════════════════════

병렬 워크트리에서 Claude Code 자동 생성 파일로 인한
병합 충돌이 발생할 수 있습니다.

.gitignore에 추가 필요:
  .claude/context/
  .claude/settings.json
  .claude/settings.local.json

자동 추가 명령어:
  cat >> .gitignore << 'EOF'
  # Claude Code 자동 생성 파일 (충돌 방지)
  .claude/context/
  .claude/settings.json
  .claude/settings.local.json
  EOF
  git add .gitignore
  git commit -m "chore: .gitignore에 Claude Code 자동 생성 파일 추가"

계속 진행하시겠습니까? [y/N]
════════════════════════════════════════
```
→ 사용자 응답 대기

**Claude Code 파일이 Git에 추적 중이면:**
```
⚠️ Claude Code 파일이 Git에 추적 중입니다
════════════════════════════════════════

다음 파일이 추적 중이어서 병합 충돌이 발생할 수 있습니다:
[git ls-files 결과]

추적 해제 명령어:
  git rm -r --cached .claude/context/
  git add .gitignore
  git commit -m "chore: Claude Code 자동 생성 파일 추적 해제"

계속 진행하시겠습니까? [y/N]
════════════════════════════════════════
```
→ 사용자 응답 대기

### 1단계: 인자 파싱

**$ARGUMENTS에서 옵션 추출:**
- `--type feature` → 워크플로우 타입: feature (기본값)
- `--type bugfix` → 워크플로우 타입: bugfix
- `--type refactor` → 워크플로우 타입: refactor
- 나머지 → 브랜치명

**브랜치명 결정:**

**브랜치명 있으면:**
- `feature/`, `fix/`, `refactor/` 접두사 없으면 타입에 따라 자동 추가:
  - `--type feature` (기본) → `feature/` 접두사
  - `--type bugfix` → `fix/` 접두사
  - `--type refactor` → `refactor/` 접두사
- 예: `auth --type bugfix` → `fix/auth`

**브랜치명 없으면:**
```
❓ 브랜치명을 입력하세요.

사용법: /worktree-start auth
        /worktree-start feature/payment
        /worktree-start fix/login-bug
        /worktree-start refactor/utils --type refactor
```
→ 중단

### 2단계: 워크트리 생성

```bash
# 현재 디렉토리명 기준 상위에 생성
# 예: /Users/dev/myproject + feature/auth → /Users/dev/myproject-auth
BRANCH_NAME="[결정된 브랜치명]"
WORKTREE_DIR="../$(basename $(pwd))-${BRANCH_NAME##*/}"

# 브랜치 존재 여부 확인
git show-ref --verify --quiet refs/heads/$BRANCH_NAME
```

**브랜치 없으면 (새 기능):**
```bash
git worktree add -b $BRANCH_NAME $WORKTREE_DIR
```

**브랜치 있으면 (기존 작업 계속):**
```bash
git worktree add $WORKTREE_DIR $BRANCH_NAME
```

### 3단계: 도메인 감지

워크트리 생성 후 프로젝트 도메인 자동 감지:

```bash
# 프로젝트 파일 구조 분석
ls package.json pyproject.toml go.mod Cargo.toml Makefile 2>/dev/null
ls next.config.* nuxt.config.* vite.config.* 2>/dev/null
ls tsconfig.json 2>/dev/null
```

**도메인 감지 매핑:**

| 감지 파일 | 도메인 | 프레임워크 |
|-----------|--------|------------|
| `next.config.*` + `package.json` | Node.js/TypeScript | Next.js |
| `nuxt.config.*` + `package.json` | Node.js/TypeScript | Nuxt.js |
| `vite.config.*` + `package.json` | Node.js/TypeScript | Vite (React/Vue) |
| `package.json` (only) | Node.js | Express/기타 |
| `pyproject.toml` / `setup.py` | Python | Django/FastAPI/기타 |
| `go.mod` | Go | Go 서비스 |
| `Cargo.toml` | Rust | Rust 서비스 |
| `Makefile` (only) | Generic | Make 프로젝트 |

### 4단계: 완료 안내

```
════════════════════════════════════════════════════════════════
✅ Worktree Created (v6)
════════════════════════════════════════════════════════════════

📁 경로: [WORKTREE_DIR 절대경로]
🌿 브랜치: [BRANCH_NAME]
🔧 도메인: [감지된 도메인 타입] ([프레임워크])

다음 단계 (새 터미널에서):
  cd [WORKTREE_DIR 절대경로]
  claude

💡 병렬 작업 팁:
  • 각 워크트리에서 독립적으로 개발
  • 개발 완료 후: /handoff-verify
  • PR 완료 후: /worktree-cleanup

현재 워크트리 목록:
[git worktree list 결과]
════════════════════════════════════════════════════════════════
```

### 에러 처리

**워크트리 디렉토리 이미 존재:**
```
⚠️ 디렉토리가 이미 존재합니다: [경로]

옵션:
1. 해당 디렉토리에서 작업: cd [경로] && claude
2. 삭제 후 재생성: rm -rf [경로] && /worktree-start [브랜치]
```

**브랜치가 다른 워크트리에서 체크아웃 중:**
```
❌ 브랜치 '[브랜치명]'이 다른 워크트리에서 사용 중입니다.

[git worktree list 결과]

다른 브랜치명을 사용하거나, 기존 워크트리를 정리하세요:
  /worktree-cleanup [브랜치명]
```

---

## 인자 설명

| 인자 | 설명 |
|------|------|
| `[브랜치명]` | 워크트리 브랜치명 (접두사 자동 추가) |
| `--type feature` | 기능 개발 모드 (기본값) |
| `--type bugfix` | 버그 수정 모드 (빠른 사이클) |
| `--type refactor` | 리팩토링 모드 (아키텍처 중심) |

## 사용 예시

```bash
# 기본 (feature 타입)
/worktree-start auth

# 버그 수정 모드
/worktree-start login-error --type bugfix

# 리팩토링 모드
/worktree-start utils-cleanup --type refactor

# 접두사 직접 지정 (타입 무시)
/worktree-start feature/payment
/worktree-start fix/session-timeout
```
