---
allowed-tools: Read, Glob, Bash(git:*), Bash(jq:*), Bash(readlink:*), Bash(cp:*), Bash(ln:*), Bash(rm:*), Bash(mv:*), Bash(ls:*), Bash(chmod:*), Bash(date:*), Bash(cat:*), Bash(mkdir:*), Bash(diff:*), Bash(wc:*), Bash(grep:*)
description: Claude Forge 프레임워크를 원격에서 최신 버전으로 업데이트
argument-hint: "[--check-only] [--force]"
---

# /forge-update - Claude Forge 자체 업데이트

---

## 플래그

| 플래그 | 설명 |
|--------|------|
| `--check-only` | 업데이트 확인만, 실제 pull하지 않음 |
| `--force` | 로컬 변경사항이 있어도 stash 후 강제 진행 |
| (없음) | 업데이트 확인 + pull + 후처리 |

---

## 1단계: 메타파일 로드

```bash
FORGE_META="$HOME/.claude/.forge-meta.json"
```

메타파일이 있으면:
```bash
REPO_PATH=$(jq -r '.repo_path' "$FORGE_META")
INSTALL_MODE=$(jq -r '.install_mode' "$FORGE_META")
CURRENT_VERSION=$(jq -r '.version' "$FORGE_META")
CURRENT_COMMIT=$(jq -r '.git_commit' "$FORGE_META")
```

메타파일이 없으면 (이전 버전 설치):
```bash
# symlink에서 저장소 경로 추론
REPO_PATH=$(cd -P "$(readlink "$HOME/.claude/agents")" 2>/dev/null && cd .. && pwd)
```

추론도 실패하면 에러:
```
Claude Forge 저장소를 찾을 수 없습니다.
다시 clone 후 install.sh를 실행하세요:
  git clone https://github.com/sangrokjung/claude-forge.git
  cd claude-forge && ./install.sh
```

---

## 2단계: 저장소 검증 (CRITICAL - 보안)

repo_path를 신뢰하기 전에 반드시 검증한다.

```bash
# 1. 경로 정규화 (심링크 해제)
REPO_PATH=$(cd "$REPO_PATH" 2>/dev/null && pwd -P)

# 2. .git 디렉토리 존재 확인
ls -d "$REPO_PATH/.git"

# 3. claude-forge 저장소인지 특징 파일로 검증
ls "$REPO_PATH/.claude-plugin/plugin.json"

# 4. remote URL이 claude-forge인지 확인
REMOTE_URL=$(cd "$REPO_PATH" && git remote get-url origin 2>/dev/null)
echo "$REMOTE_URL" | grep -q 'claude-forge'
```

검증 실패 시:
```
저장소 경로가 유효하지 않거나 claude-forge 저장소가 아닙니다: {REPO_PATH}
다시 clone 후 install.sh를 실행하세요.
```

---

## 3단계: 로컬 변경사항 체크

```bash
cd "$REPO_PATH"
git status --porcelain
```

변경사항이 있으면:
- `--force` 없음: 경고 메시지 출력 + 중단
  ```
  로컬 변경사항이 있습니다:
    {변경 파일 목록}
  --force 플래그로 stash 후 진행하거나, 수동으로 정리해주세요.
  ```
- `--force` 있음: `git stash` 실행 후 진행

---

## 4단계: 원격 fetch + 기본 브랜치 감지

```bash
git fetch origin
```

실패 시 (네트워크 오류):
```
원격 저장소에 연결할 수 없습니다.
네트워크 연결을 확인하세요.
```

기본 브랜치 동적 감지:
```bash
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
if [ -z "$DEFAULT_BRANCH" ]; then
    DEFAULT_BRANCH="main"
fi
```

---

## 5단계: 버전 비교

```bash
LOCAL_HEAD=$(git rev-parse HEAD)
REMOTE_HEAD=$(git rev-parse "origin/$DEFAULT_BRANCH")
```

동일하면:
```
════════════════════════════════════════════════════════════════
  Claude Forge Update
════════════════════════════════════════════════════════════════

  이미 최신 버전입니다.
  버전: v{CURRENT_VERSION} ({CURRENT_COMMIT})
  모드: {INSTALL_MODE}

════════════════════════════════════════════════════════════════
```

---

## 6단계: 변경 로그 확인

```bash
git log --oneline "$LOCAL_HEAD..$REMOTE_HEAD"
```

`--check-only` 플래그 시:
```
════════════════════════════════════════════════════════════════
  Claude Forge Update (check-only)
════════════════════════════════════════════════════════════════

  현재: v{CURRENT_VERSION} ({CURRENT_COMMIT})
  모드: {INSTALL_MODE}

  대기 중인 업데이트 ({N} commits):
    {커밋 로그}

  적용하려면: /forge-update

════════════════════════════════════════════════════════════════
```

`--check-only`가 아니면 7단계로 진행.

---

## 7단계: git pull

```bash
if ! git pull origin "$DEFAULT_BRANCH"; then
    # exit code != 0 이면 충돌 가능성
    git merge --abort 2>/dev/null
fi
```

충돌 발생 시:
```
════════════════════════════════════════════════════════════════
  Claude Forge Update (실패)
════════════════════════════════════════════════════════════════

  Merge 충돌이 발생했습니다. 자동 병합을 중단했습니다.
  수동 해결이 필요합니다:
    cd {REPO_PATH}
    git pull origin {DEFAULT_BRANCH}
    # 충돌 해결 후
    git add . && git commit

════════════════════════════════════════════════════════════════
```

---

## 7.5단계: 보안 파일 변경 감지 (copy 모드 전용)

copy 모드에서만 실행. 보안 관련 파일에 변경이 있으면 사용자에게 경고:

```bash
SECURITY_FILES="settings.json hooks/remote-command-guard.sh hooks/output-secret-filter.sh"
SECURITY_CHANGED=""
for f in $SECURITY_FILES; do
    if git diff --quiet "$LOCAL_HEAD..$REMOTE_HEAD" -- "$f" 2>/dev/null; then
        :
    else
        SECURITY_CHANGED="$SECURITY_CHANGED $f"
    fi
done
```

변경이 있으면 사용자에게 알린다:
```
경고: 보안 관련 파일이 변경되었습니다:
  {변경된 보안 파일 목록}
변경 내용을 확인한 후 계속하시겠습니까?
```

---

## 8단계: 서브모듈 업데이트

```bash
git submodule update --init --recursive
```

실패해도 경고만 표시하고 계속 진행 (cc-chips는 선택적).

---

## 9단계: install_mode별 후처리

### symlink 모드

symlink 건전성 검증. 깨진 symlink은 자동 재생성:

```bash
for item in agents rules commands scripts skills hooks cc-chips cc-chips-custom settings.json; do
    if [ -L "$HOME/.claude/$item" ] && [ ! -e "$HOME/.claude/$item" ]; then
        # 깨진 symlink → 재생성
        rm -f "$HOME/.claude/$item"
        ln -sf "$REPO_PATH/$item" "$HOME/.claude/$item"
    fi
done
```

### copy 모드

안전한 교체 패턴으로 파일 재복사. **보호 파일은 절대 덮어쓰지 않는다:**
- `.forge-meta.json`
- `settings.local.json`
- `.forge-onboarded`
- `.session-stats.json`
- `work-log/` 디렉토리
- `CLAUDE.md`

```bash
for dir in agents rules commands scripts skills hooks cc-chips cc-chips-custom; do
    if [ -d "$REPO_PATH/$dir" ]; then
        # 안전한 교체: 새 버전 복사 → 기존 백업 → 교체 → 백업 삭제
        cp -r "$REPO_PATH/$dir" "$HOME/.claude/${dir}.new"
        mv "$HOME/.claude/$dir" "$HOME/.claude/${dir}.old" 2>/dev/null
        mv "$HOME/.claude/${dir}.new" "$HOME/.claude/$dir"
        rm -rf "$HOME/.claude/${dir}.old"
    fi
done
cp "$REPO_PATH/settings.json" "$HOME/.claude/settings.json"
```

### cc-chips-custom 오버레이 재적용

```bash
# cc-chips-custom이 있으면 cc-chips에 오버레이
TARGET="$HOME/.claude/cc-chips"
[ -f "$REPO_PATH/cc-chips-custom/engine.sh" ] && cp "$REPO_PATH/cc-chips-custom/engine.sh" "$TARGET/engine.sh" && chmod +x "$TARGET/engine.sh"
[ -d "$REPO_PATH/cc-chips-custom/themes" ] && cp "$REPO_PATH/cc-chips-custom/themes/"*.sh "$TARGET/themes/" 2>/dev/null
```

---

## 10단계: 메타파일 갱신 + 결과 출력

### 메타파일 갱신

```bash
NEW_VERSION=$(jq -r '.version // "1.0.0"' "$REPO_PATH/.claude-plugin/plugin.json")
NEW_COMMIT=$(cd "$REPO_PATH" && git rev-parse --short HEAD)
NOW=$(date +"%Y-%m-%dT%H:%M:%S%z")

jq --arg v "$NEW_VERSION" --arg c "$NEW_COMMIT" --arg t "$NOW" \
   '.version = $v | .git_commit = $c | .updated_at = $t' \
   "$FORGE_META" > "$FORGE_META.tmp" && mv "$FORGE_META.tmp" "$FORGE_META"
chmod 600 "$FORGE_META"
```

### --force 사용 시 stash 복원

```bash
git stash pop
```

복원 실패 시 경고:
```
stash pop 실패. 수동으로 복원하세요:
  cd {REPO_PATH}
  git stash list       # stash 내역 확인
  git stash show       # 변경 내용 확인
  git stash pop        # 다시 시도 또는 git stash drop으로 삭제
```

### 결과 출력

```
════════════════════════════════════════════════════════════════
  Claude Forge Update
════════════════════════════════════════════════════════════════

  이전: v{PREV_VERSION} ({PREV_COMMIT})
  최신: v{NEW_VERSION} ({NEW_COMMIT})
  모드: {INSTALL_MODE}

  변경 내역 ({N} commits):
    {커밋 로그}

  {INSTALL_MODE} 상태:
    ✓ agents/     ✓ rules/      ✓ commands/
    ✓ hooks/      ✓ scripts/    ✓ skills/
    ✓ settings.json

  다음 세션부터 새 규칙/에이전트/커맨드가 적용됩니다.

════════════════════════════════════════════════════════════════
```
