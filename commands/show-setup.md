---
description: 현재 Claude Forge 설치 상태와 프로젝트 정보를 보여줍니다.
argument-hint: ""
allowed-tools: ["Bash", "Read", "Glob"]
---

# /show-setup

현재 Claude Forge 설치 상태와 프로젝트 정보를 종합적으로 보여줍니다.

## Instructions

### 1. Claude Forge 설치 현황

1. Count agents in ~/.claude/agents/
2. Count commands in ~/.claude/commands/
3. Count skills in ~/.claude/skills/
4. Count hooks in ~/.claude/hooks/
5. Count rules in ~/.claude/rules/

### 2. 현재 프로젝트 상태 (프로젝트 폴더에서 실행 시)

1. 프로젝트 타입 감지 (package.json / go.mod / Cargo.toml / pyproject.toml)
2. Git 상태 (브랜치, 마지막 커밋, 변경 파일 수)
3. CLAUDE.md 존재 여부
4. 테스트 설정 존재 여부

### 3. 추천 다음 작업

현재 프로젝트 상태에 따라 가장 적합한 다음 커맨드를 추천합니다:

- 변경 파일이 있으면 -> `/handoff-verify`
- CLAUDE.md가 없으면 -> `/init-project`
- 테스트가 없으면 -> `/tdd`
- 모두 정상이면 -> `/plan [다음 기능]`

팀 설정 관련 추천:

- `~/.claude/settings.team.json`이 없으면 -> "팀 설정 파일을 만들어보세요 (setup/settings.team.example.json 참고)"
- `settings.team.json`이 있지만 `enforced_rules`가 비어있으면 -> "필수 규칙이 누락되었습니다. enforced_rules에 팀 규칙을 추가하세요"

### 4. 팀 설정 상태

1. `~/.claude/settings.team.json` 파일 존재 여부를 확인합니다
2. 파일이 존재하면 다음 정보를 표시합니다:
   - `team_name`: 팀 이름 (없으면 "미설정")
   - `enforced_rules`: 배열 길이 (필수 규칙 수)
   - `permissions.deny`: 배열 길이 (차단 패턴 수)
   - `permissions.allow`: 배열 길이 (허용 패턴 수)
   - RBAC 역할: Phase 2 대비, 현재는 "미설정" 표시
3. 파일이 없으면 "팀 설정 없음"으로 표시합니다

정보 추출 방법 (jq 사용):

```bash
TEAM_SETTINGS="$HOME/.claude/settings.team.json"

if [ -f "$TEAM_SETTINGS" ]; then
  TEAM_NAME=$(jq -r '.team_name // "미설정"' "$TEAM_SETTINGS")
  ENFORCED_COUNT=$(jq -r '.enforced_rules | length' "$TEAM_SETTINGS")
  DENY_COUNT=$(jq -r '.permissions.deny | length' "$TEAM_SETTINGS")
  ALLOW_COUNT=$(jq -r '.permissions.allow | length' "$TEAM_SETTINGS")
fi
```

## Output Format

```
My Claude Forge Setup
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Agents:   XX
Commands: XX
Skills:   XX
Hooks:    XX
Rules:    XX
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

현재 프로젝트: [프로젝트명]
  타입: [Node.js / Go / Python / ...]
  브랜치: [main]
  마지막 커밋: [커밋 메시지]
  변경 파일: [N]개

팀 설정:
  팀 이름:        [팀명 또는 "미설정"]
  필수 규칙:      [N]개
  차단 패턴:      [N]개
  허용 패턴:      [N]개
  역할:          [미설정]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

추천 다음 작업: [커맨드]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
github.com/sangrokjung/claude-forge
```

When `settings.team.json` does not exist, the team settings section displays:

```
팀 설정:      없음
```

## Clipboard

After displaying the summary, copy the text to the system clipboard:
- macOS: `pbcopy`
- Linux/WSL: `xclip -selection clipboard` or `xsel --clipboard`

Tell the user the summary has been copied to clipboard and is ready to share on X/Twitter or other social platforms.
