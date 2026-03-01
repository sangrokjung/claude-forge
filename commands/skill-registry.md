---
allowed-tools: Read, Glob, Grep, Bash(git:*), Bash(jq:*), Bash(cp:*), Bash(rm:*), Bash(mv:*), Bash(ls:*), Bash(mkdir:*), Bash(chmod:*), Bash(date:*), Bash(cat:*), Bash(wc:*), Bash(source:*), Bash(bash:*)
description: 프라이빗 스킬 레지스트리 관리 (설치, 업데이트, 롤백, 동기화)
argument-hint: list|install|update|rollback|sync|status [options]
---

# /skill-registry - 프라이빗 스킬 레지스트리 관리

---

## 서브커맨드

| 서브커맨드 | 설명 |
|-----------|------|
| `list` | 모든 레지스트리의 스킬 목록 |
| `install [name] [--version X.Y.Z]` | 스킬 설치 |
| `update [name\|--all]` | 스킬 업데이트 |
| `rollback [name] [version]` | 이전 버전으로 롤백 |
| `sync` | 전체 레지스트리 동기화 |
| `status` | 설치된 스킬 상태 표시 |

---

## 0단계: 환경 준비

### 레지스트리 설정 파일 탐색

```bash
REGISTRY_CONFIG="$HOME/.claude/registry.json"
```

설정 파일이 없으면:
```
레지스트리 설정 파일을 찾을 수 없습니다: ~/.claude/registry.json

설정 방법:
  1. 예제 파일 복사:
     cp setup/registry.example.json ~/.claude/registry.json

  2. 레지스트리 URL과 스킬 목록을 수정하세요.

참고: setup/registry.example.json
```
-> 중단

### 라이브러리 로드

```bash
FORGE_DIR=$(cd "$(dirname "$0")" && pwd)
source "$FORGE_DIR/scripts/skill-registry.sh"
load_registry "$REGISTRY_CONFIG"
```

로드 실패 시:
```
레지스트리 설정 로드 실패.
JSON 형식이 올바른지 확인하세요:
  jq . ~/.claude/registry.json
```
-> 중단

### 의존성 확인

```bash
command -v git >/dev/null || echo "git 필요"
command -v jq >/dev/null || echo "jq 필요"
```

---

## 1단계: 인자 파싱

**$ARGUMENTS에서 서브커맨드와 옵션 추출:**

```
/skill-registry list                        -> SUBCOMMAND=list
/skill-registry install custom-review       -> SUBCOMMAND=install, SKILL=custom-review
/skill-registry install custom-review --version 1.2.0
                                            -> SUBCOMMAND=install, SKILL=custom-review, VERSION=1.2.0
/skill-registry update custom-review        -> SUBCOMMAND=update, SKILL=custom-review
/skill-registry update --all                -> SUBCOMMAND=update, ALL=true
/skill-registry rollback custom-review 1.0.0
                                            -> SUBCOMMAND=rollback, SKILL=custom-review, VERSION=1.0.0
/skill-registry sync                        -> SUBCOMMAND=sync
/skill-registry status                      -> SUBCOMMAND=status
```

서브커맨드가 없으면:
```
사용법: /skill-registry <subcommand> [options]

서브커맨드:
  list                              모든 레지스트리의 스킬 목록
  install <name> [--version X.Y.Z]  스킬 설치
  update <name|--all>               스킬 업데이트
  rollback <name> <version>         이전 버전으로 롤백
  sync                              전체 레지스트리 동기화
  status                            설치된 스킬 상태 표시
```
-> 중단

---

## 2단계: 서브커맨드 실행

### list — 스킬 목록

모든 레지스트리를 순회하며 등록된 스킬을 표시합니다.

```bash
registries=$(jq -r '.registries[].name' "$REGISTRY_CONFIG")
for registry in $registries; do
  list_registry_skills "$registry"
done
```

**출력 형식:**
```
════════════════════════════════════════════════════════════════
  Skill Registry — 스킬 목록
════════════════════════════════════════════════════════════════

  Registry: company-skills
  URL: https://github.com/my-org/claude-forge-skills.git
  ────────────────────────────────────────
  SKILL                     VERSION      REQUIRED   PATH
  custom-review             1.2.0        yes        skills/custom-review
  deploy-checklist          0.9.1        no         skills/deploy-checklist

  Registry: team-alpha-skills
  URL: git@github.com:my-org/team-alpha-skills.git
  ────────────────────────────────────────
  SKILL                     VERSION      REQUIRED   PATH
  api-testing               2.0.0        yes        skills/api-testing

════════════════════════════════════════════════════════════════
```

---

### install — 스킬 설치

**필수 인자:** 스킬 이름.
스킬 이름이 없으면:
```
스킬 이름을 지정하세요.
사용법: /skill-registry install <name> [--version X.Y.Z]

사용 가능한 스킬:
  /skill-registry list
```
-> 중단

**실행 순서:**

1. **레지스트리 탐색** — 스킬 이름으로 레지스트리를 찾습니다.
   스킬이 여러 레지스트리에 있으면 첫 번째를 사용합니다.

```bash
registry_name=$(_find_registry_for_skill "$SKILL")
```

스킬을 찾을 수 없으면:
```
스킬 '$SKILL'을 어떤 레지스트리에서도 찾을 수 없습니다.

등록된 레지스트리:
  - company-skills
  - team-alpha-skills

등록된 스킬 확인:
  /skill-registry list
```
-> 중단

2. **중복 확인** — 이미 설치된 스킬인지 확인합니다.

```bash
ls -d "$HOME/.claude/skills/$SKILL" 2>/dev/null
```

이미 설치되어 있으면:
```
스킬 '$SKILL'이 이미 설치되어 있습니다.
현재 버전: [현재 버전]

업데이트하려면:
  /skill-registry update $SKILL
```
-> 중단

3. **의존성 해결** — skill.md의 `depends:` 필드를 파싱하여 의존 스킬을 먼저 설치합니다.

```bash
resolve_dependencies "$SKILL" "$registry_name"
```

순환 의존성 감지 시:
```
순환 의존성이 감지되었습니다:
  $SKILL -> dep-a -> dep-b -> $SKILL

의존성 구조를 확인하세요.
```
-> 중단

4. **설치 실행**

```bash
install_skill "$registry_name" "$SKILL" "$VERSION"
```

5. **검증**

```bash
verify_skill "$HOME/.claude/skills/$SKILL"
```

**성공 출력:**
```
════════════════════════════════════════════════════════════════
  Skill Registry — 설치 완료
════════════════════════════════════════════════════════════════

  스킬: $SKILL
  버전: $VERSION
  레지스트리: $registry_name
  경로: ~/.claude/skills/$SKILL

  의존성:
    (없음)  또는
    dep-a@1.0.0 (설치됨)
    dep-b@2.1.0 (이미 존재)

════════════════════════════════════════════════════════════════
```

**실패 시 (네트워크 오류):**
```
스킬 설치 실패: $SKILL

원인: 레지스트리 '$registry_name'에 연결할 수 없습니다.
URL: [URL]

확인 사항:
  1. 네트워크 연결
  2. SSH 키 또는 인증 정보
  3. 저장소 접근 권한

재시도:
  /skill-registry install $SKILL
```

**실패 시 (버전 미존재):**
```
스킬 설치 실패: $SKILL@$VERSION

버전 '$VERSION' (태그 v$VERSION)이 존재하지 않습니다.

사용 가능한 버전:
  v1.2.0
  v1.1.0
  v1.0.0

최신 버전으로 설치:
  /skill-registry install $SKILL
```

---

### update — 스킬 업데이트

**`--all` 플래그:**
모든 레지스트리의 모든 설치된 스킬을 업데이트합니다.

```bash
registries=$(jq -r '.registries[].name' "$REGISTRY_CONFIG")
for registry in $registries; do
  # 각 레지스트리의 스킬을 순회
  while IFS=$'\t' read -r name version required path; do
    if [ -d "$HOME/.claude/skills/$name" ]; then
      update_skill "$registry" "$name" "$version"
    fi
  done < <(list_registry_skills "$registry")
done
```

**특정 스킬 업데이트:**

```bash
registry_name=$(_find_registry_for_skill "$SKILL")
update_skill "$registry_name" "$SKILL"
```

스킬이 설치되어 있지 않으면:
```
스킬 '$SKILL'이 설치되어 있지 않습니다.

설치하려면:
  /skill-registry install $SKILL
```
-> 중단

**성공 출력:**
```
════════════════════════════════════════════════════════════════
  Skill Registry — 업데이트 완료
════════════════════════════════════════════════════════════════

  스킬: $SKILL
  이전: $OLD_VERSION
  최신: $NEW_VERSION
  레지스트리: $registry_name

  백업 위치: ~/.claude/.registry-cache/.backups/$SKILL/$OLD_VERSION

  롤백하려면:
    /skill-registry rollback $SKILL $OLD_VERSION

════════════════════════════════════════════════════════════════
```

---

### rollback — 버전 롤백

**필수 인자:** 스킬 이름, 대상 버전.

```bash
rollback_skill "$registry_name" "$SKILL" "$VERSION"
```

인자가 부족하면:
```
사용법: /skill-registry rollback <name> <version>

예시:
  /skill-registry rollback custom-review 1.0.0

현재 상태 확인:
  /skill-registry status
```
-> 중단

**성공 출력:**
```
════════════════════════════════════════════════════════════════
  Skill Registry — 롤백 완료
════════════════════════════════════════════════════════════════

  스킬: $SKILL
  이전: $OLD_VERSION
  롤백: $VERSION
  방법: 로컬 백업 복원  또는  레지스트리에서 재설치

════════════════════════════════════════════════════════════════
```

---

### sync — 레지스트리 동기화

모든 레지스트리의 스킬을 동기화합니다:
- 미설치 스킬: 설치
- auto_update가 true이고 버전이 다르면: 업데이트
- required 스킬 설치 실패 시: 전체 중단

```bash
registries=$(jq -r '.registries[].name' "$REGISTRY_CONFIG")
for registry in $registries; do
  sync_registry "$registry"
done
```

**성공 출력:**
```
════════════════════════════════════════════════════════════════
  Skill Registry — 동기화 완료
════════════════════════════════════════════════════════════════

  Registry: company-skills
  ────────────────────────────────────────
    custom-review      1.2.0    설치됨
    deploy-checklist   0.9.1    업데이트됨 (0.8.0 -> 0.9.1)

  Registry: team-alpha-skills
  ────────────────────────────────────────
    api-testing        2.0.0    최신 상태

  요약: 3 스킬 (1 설치, 1 업데이트, 1 최신)

════════════════════════════════════════════════════════════════
```

**필수 스킬 실패 시:**
```
동기화 실패 — 필수 스킬 설치 불가

  실패한 필수 스킬:
    custom-review (company-skills): 네트워크 오류

  모든 필수 스킬이 설치되어야 동기화가 완료됩니다.
  네트워크 연결과 인증을 확인한 후 재시도하세요:
    /skill-registry sync
```

---

### status — 상태 표시

설치된 레지스트리 스킬의 상태를 표시합니다.

```bash
show_registry_status
```

**출력 형식:**
```
════════════════════════════════════════════════════════════════
  Skill Registry Status
════════════════════════════════════════════════════════════════

  Registry: company-skills
  ────────────────────────────────────────
  SKILL                     EXPECTED     INSTALLED    STATUS
  custom-review             1.2.0        1.2.0        ok
  deploy-checklist          0.9.1        0.8.0        outdated

  Registry: team-alpha-skills
  ────────────────────────────────────────
  SKILL                     EXPECTED     INSTALLED    STATUS
  api-testing               2.0.0        --           missing *

  * = required skill

════════════════════════════════════════════════════════════════
```

---

## 에러 처리

### 네트워크 실패

git clone/fetch 실패 시:
```
레지스트리에 연결할 수 없습니다.

확인 사항:
  1. 네트워크 연결: ping github.com
  2. SSH 인증: ssh -T git@github.com
  3. HTTPS 인증: gh auth status
  4. 저장소 접근 권한

재시도: /skill-registry [원래 명령]
```

### 버전 미존재

요청한 버전 태그가 없을 때:
```
버전 '$VERSION' (태그 v$VERSION)을 찾을 수 없습니다.

사용 가능한 버전 (최신순):
  [태그 목록]

최신 버전으로 설치/업데이트:
  /skill-registry install $SKILL
  /skill-registry update $SKILL
```

### 순환 의존성

의존성 그래프에서 순환이 감지되면:
```
순환 의존성 감지 (깊이 제한: 10)

의존성 체인:
  A -> B -> C -> A

스킬의 depends: 필드를 확인하고 순환을 제거하세요.
```

---

## 다음 단계

| 작업 후 | 커맨드 |
|:--------|:-------|
| 스킬 설치 후 검증 | `/handoff-verify` |
| 스킬 목록 확인 | `/skill-registry list` |
| 전체 동기화 | `/skill-registry sync` |
