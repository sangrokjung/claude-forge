---
description: RBAC 역할을 전환합니다. 역할별로 사용 가능한 커맨드, 에이전트, MCP가 달라집니다.
argument-hint: "[role_name]"
allowed-tools: ["Bash", "Read", "Glob"]
---

# /switch-role

RBAC 역할을 전환하여 권한 범위를 변경합니다.

## Instructions

### 1. 파라미터 파싱

`$ARGUMENTS`에서 역할 이름을 추출합니다.

- 인자가 없으면: 현재 역할 표시 + 사용 가능한 역할 목록 출력
- 인자가 있으면: 해당 역할로 전환 실행

### 2. 현재 역할 확인

프로젝트 디렉토리의 `settings.team.json`에서 현재 역할을 확인합니다:

```bash
TEAM_FILE="./settings.team.json"
if [ -f "$TEAM_FILE" ]; then
  CURRENT_ROLE=$(jq -r '.current_role // "none"' "$TEAM_FILE")
else
  CURRENT_ROLE="none"
fi
```

### 3. 사용 가능한 역할 목록

Claude Forge 설치 디렉토리의 `roles/` 폴더에서 모든 `.json` 파일을 검색합니다.
기본 제공 역할(admin, developer, reviewer, readonly) 외에 커스텀 역할도 지원합니다.

```bash
FORGE_DIR=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
ROLES_DIR="$FORGE_DIR/roles"

for role_file in "$ROLES_DIR"/*.json; do
  role_name=$(basename "$role_file" .json)
  description=$(jq -r '.description // ""' "$role_file")
done
```

커스텀 역할: `roles/` 디렉토리에 JSON 파일을 추가하면 자동으로 인식됩니다.

### 4. 역할 전환 실행

역할 전환은 `scripts/apply-role.sh`를 호출하여 수행합니다:

```bash
bash "$FORGE_DIR/scripts/apply-role.sh" "$ROLE_NAME" "$(pwd)"
```

### 5. 전환 결과 표시

전환 성공 후 새 역할의 권한 요약을 표시합니다:
- 사용 가능한 커맨드 수
- 할당된 에이전트 목록
- 활성화된 MCP 서버 목록

## Output Format

### 인자 없이 실행 시 (현재 역할 + 목록):

```
현재 역할: developer
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

사용 가능한 역할:
  admin       — 관리자 역할 — 모든 권한을 가진 최상위 역할
  developer   — 개발자 역할 — 개발에 필요한 주요 도구와 에이전트 접근 권한 [현재]
  reviewer    — 리뷰어 역할 — 코드 리뷰와 보안 분석에 특화된 읽기 중심 역할
  readonly    — 읽기 전용 역할 — 코드 탐색과 검색만 가능한 최소 권한 역할

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
전환하려면: /switch-role <role_name>
```

### 역할 전환 시:

```
역할 전환: developer -> admin
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

역할:       admin
설명:       관리자 역할 — 모든 권한을 가진 최상위 역할
커맨드:     all
에이전트:   all
MCP:        all

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
settings.team.json이 업데이트되었습니다.
```
