---
allowed-tools: Bash(git:*), Read, Grep
description: PR 완료 후 Git Worktree 정리 (v6)
argument-hint: "[브랜치명 - 생략시 현재 워크트리]"
---

## Task

### 0단계: 환경 확인

```bash
git rev-parse --git-dir
git worktree list
git branch --show-current
pwd
```

### 1단계: 정리 대상 결정

**$ARGUMENTS 있으면:**
- 해당 브랜치의 워크트리 찾기

**$ARGUMENTS 없으면:**
- 현재 디렉토리가 워크트리인지 확인
- 메인 레포면:
  ```
  ❓ 정리할 워크트리를 지정하세요.

  현재 워크트리 목록:
  [git worktree list 결과]

  사용법: /worktree-cleanup feature/auth
  ```
  → 중단

### 2단계: PR 상태 확인

```bash
gh pr view --json state,mergedAt 2>/dev/null
```

**PR이 머지됨:**
→ 정리 진행

**PR이 아직 열려있음:**
```
⚠️ PR이 아직 머지되지 않았습니다.

PR 상태: [Open/Draft]
PR URL: [URL]

옵션:
1. "계속" - 강제 정리 (변경사항 유실 주의)
2. "취소" - PR 머지 후 다시 시도
```

**PR 없음 (gh CLI 없거나 PR 미생성):**
```
⚠️ PR 상태를 확인할 수 없습니다.

변경사항이 push 되었는지 확인하세요:
  git log origin/[브랜치]..HEAD

옵션:
1. "계속" - 강제 정리
2. "취소" - 확인 후 다시 시도
```

### 3단계: 워크트리 정리

**현재 워크트리에서 실행 중이면:**
```
⚠️ 현재 워크트리에서는 정리할 수 없습니다.

메인 레포로 이동 후 실행하세요:
  cd [메인 레포 경로]
  /worktree-cleanup [브랜치명]
```
→ 중단

**메인 레포에서 실행:**
```bash
# 워크트리 제거
git worktree remove [워크트리 경로]

# 머지된 브랜치면 삭제
git branch -d [브랜치명]

# 원격 브랜치도 삭제 (머지된 경우)
git push origin --delete [브랜치명] 2>/dev/null || true
```

### 3.5단계: 체크리스트 상태 정리

워크트리 내 `.claude/web-checklist-state.json` 확인:

**파일 있으면:**
- 완료율 읽기
- 미완료 항목 있으면 경고

```
📋 체크리스트 상태: [completion]% ([done]/[total])
```

미완료 항목이 있으면:
```
⚠️ 미완료 체크리스트 항목 [N]개:
  - [ID:N] [text]
  - [ID:N] [text]

워크트리 정리 후에는 복구할 수 없습니다.
```

### 4단계: 워크트리 통계 수집

워크트리 세션 동안의 작업 통계:

```bash
# 워크트리 브랜치의 커밋 수
git log --oneline [base]...[branch] | wc -l

# 변경 파일 수
git diff [base]...[branch] --stat | tail -1
```

### 5단계: 완료 안내

```
════════════════════════════════════════════════════════════════
✅ Worktree Cleanup Complete (v6)
════════════════════════════════════════════════════════════════

🗑️ 삭제: [워크트리 경로]
🌿 브랜치: [브랜치명] (deleted)

📊 워크트리 통계:
  커밋 수: [N]
  변경 파일: [N]
  추가/삭제: +[N] / -[N]

남은 워크트리:
[git worktree list 결과]

다음:
  /worktree-start [새 기능] | /next-task
════════════════════════════════════════════════════════════════
```

### 에러 처리

**워크트리에 커밋되지 않은 변경사항:**
```
❌ 커밋되지 않은 변경사항이 있습니다.

[git status 결과]

옵션:
1. 변경사항 커밋 후 다시 시도
2. 강제 삭제: git worktree remove --force [경로]
```

**브랜치가 머지되지 않음 (삭제 실패):**
```
⚠️ 브랜치가 머지되지 않아 삭제하지 않았습니다.

워크트리만 삭제되었습니다.
브랜치 강제 삭제: git branch -D [브랜치명]
```

---

## 사용 예시

```bash
# 현재 워크트리 정리 (메인 레포에서)
/worktree-cleanup feature/auth

# 브랜치명으로 정리
/worktree-cleanup fix/login-bug

# 워크트리 목록 확인 후 정리
git worktree list
/worktree-cleanup [대상 브랜치]
```
