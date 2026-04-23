# v2.1 → v3.0 마이그레이션 가이드

> **TL;DR** — v3.0은 대부분의 사용자에게 **순수 추가 릴리스**입니다. 유일한 Breaking Change는 MCP 기본 세트(6 → 3)이며, 제거된 3개 서버는 전부 `mcp-servers.optional.json`에서 한 번의 복사/붙여넣기로 복구 가능합니다. Subagent · hooks · skills · commands · `settings.json`은 기존 동작을 건드리지 않고 새 기능만 추가합니다. 마이그레이션 프로젝트가 아닌 **5분짜리 업그레이드**로 계획하세요.

## 1분 업그레이드

```bash
cd path/to/claude-forge
git pull
./install.sh --upgrade
```

Happy path는 이게 전부입니다. `install.sh --upgrade`(T7)가 v2.1 레이아웃을 감지하고, 관련 심볼릭 링크를 `~/.claude/.backup-<timestamp>/`로 백업한 뒤, `mcp-servers.json` / `settings.json` / frontmatter를 best-effort로 업데이트합니다. 사용자가 직접 작성한 파일은 건드리지 않습니다.

`mcp-servers.json` 또는 `settings.json`을 수동으로 커스터마이즈했다면, 재실행 전에 [Step 2](#step-2-mcp-migration)와 [Step 6](#step-6-settingsjson)을 먼저 확인하세요.

## 한눈에 보는 변경사항

| 영역 | v2.1 | v3.0 | Breaking? |
|------|------|------|-----------|
| MCP 기본 서버 | 6개 (`memory`, `exa`, `github`, `fetch`, `playwright`, `context7`) | 3개 (`playwright`, `context7`, `jina-reader`) + `mcp-servers.optional.json` | **Yes** (복구 가능) |
| Hooks 이벤트 | 5개 연결 (`PreToolUse`, `SessionStart`, `UserPromptSubmit`, `PostToolUse`, `Stop`) | 21개 카탈로그화, 9개 opt-in 예제 (`hooks/examples/`) | No (추가) |
| Subagent frontmatter | 5개 필드 (`name`, `description`, `tools`, `model`, `color`) | 13개 필드 — 10개 선택 (`isolation`, `background`, `maxTurns`, `skills`, `mcpServers`, `effort`, `hooks`, `permissionMode`, `disallowedTools`, `memory`) | No (추가) |
| Skills vs Commands | 문서화되지 않음, `commands/` 아래 디렉토리 형태 8개 | Hybrid 정책 문서화(`docs/SKILLS-VS-COMMANDS.md`); 8개가 `skills/`로 이동 + 1년 심볼릭 링크 | No (심볼릭 링크 유지) |
| CLAUDE.md | 스타터 템플릿 없음 | `setup/CLAUDE.md.template`(≤ 60줄) + `docs/CLAUDE-MD-GUIDE.md`(로드 계층, @import, 200줄 원칙) | No (추가) |
| settings.json | 기본 권한 + hooks | 최상위에 `tui`, `disableSkillShellExecution`, `enabledMcpjsonServers` 추가 | No (필드 부재 시 v2.1 동작) |
| MCP allow-list | `mcp__memory`, `mcp__exa`, `mcp__github`, `mcp__fetch` 허용 | `mcp__playwright`, `mcp__context7`, `mcp__jina-reader`로 대체 | Yes (MCP 변경과 동일) |

아래 각 단계는 설치 순서대로 이 표의 행들을 순회합니다.

## 단계별 마이그레이션

### Step 1: 현재 설정 백업

어떤 변경이든 시작하기 전에 `~/.claude/`를 스냅샷해 두면, 문제 발생 시 30초 안에 롤백할 수 있습니다.

```bash
# 1. 실행 중인 설정 스냅샷
cp -R ~/.claude ~/.claude.bak-$(date +%Y%m%d-%H%M)

# 2. claude-forge 저장소 상태 확인
cd path/to/claude-forge
git status   # 비어 있거나 WIP만 존재해야 함
git branch   # pull 준비 상태 확인
```

`install.sh --upgrade`도 자체적으로 `~/.claude/.backup-<timestamp>/` 아래 백업을 작성하지만, 수동 복사본은 installer가 건드리지 않는 파일(로컬 hooks, 직접 작성한 agents, 개인 skills)까지 포함하는 저렴한 보험입니다.

### Step 2: MCP 마이그레이션

전체 레시피는 [`docs/MCP-MIGRATION.md`](docs/MCP-MIGRATION.md)에 있습니다. 요약하면:

1. `mcp-servers.json`은 이제 **3개 서버**만 포함: `playwright`, `context7`, `jina-reader`.
2. 기본에서 제거된 4개(`memory`, `exa`, `github`, `fetch`)는 [`mcp-servers.optional.json`](mcp-servers.optional.json)에 4개 추가 서버(`time`, `sequential-thinking`, `supabase`, `chrome-devtools`)와 함께 보관.
3. 복구하려면 해당 엔트리를 `mcp-servers.json`의 `"servers"` 아래에 복사한 뒤 `./install.sh --upgrade` 재실행.
4. 각 제거의 근거(Auto Memory, 내장 `WebSearch`, `gh` CLI, `jina-reader`)는 `docs/MCP-MIGRATION.md` 참조.

`memory` / `exa` / `github` / `fetch`를 자동화에서 사용 중이라면, Step 6 이전에 먼저 복구하여 `enabledMcpjsonServers` 힌트와 실제 상태를 일치시키세요.

### Step 2.5: 제거된 MCP 도구를 참조하던 5개 agent 점검

v2.1은 `Tool_Usage` 섹션에서 `mcp__exa__*` 또는 `mcp__memory__*`를 직접 호출하던 5개 agent를 제공했습니다. v3.0에서는 이 호출을 **내장 도구 기본 + MCP 선택 대체** 구조로 재작성했지만, 5개 중 하나라도 로컬에서 커스터마이즈했다면 로컬 복사본을 다시 확인하세요:

| Agent | v2.1에서 사용한 도구 | v3.0 대체 |
|-------|-----------------------|-----------|
| `agents/security-reviewer.md` | `mcp__exa__web_search_exa` | 내장 `WebSearch` (Exa 선택) |
| `agents/architect.md` | `mcp__exa__web_search_exa` | 내장 `WebSearch` (Exa 선택) |
| `agents/refactor-cleaner.md` | `mcp__memory__*` | Auto Memory(`~/.claude/projects/<project>/memory/`) 또는 텍스트 로그, memory MCP 선택 |
| `agents/doc-updater.md` | `mcp__memory__*` | Auto Memory 또는 `git log`, memory MCP 선택 |
| `agents/database-reviewer.md` | `mcp__memory__*` | Auto Memory 또는 마이그레이션 파일, memory MCP 선택 |

**v2.1 문구를 개인 포크에 유지했다면**: (a) v3.0 사본을 pull 받아 커스터마이즈를 다시 적용하거나, (b) Step 2에서 `mcp-servers.optional.json`으로부터 해당 MCP 서버를 복구하여 기존 도구 이름이 다시 해결되도록 하세요.

**기본 제공 agent를 그대로 사용 중**: 추가 조치 불필요. v3.0이 수동 MCP 설정 없이도 내장 도구로 자동 폴백합니다.

### Step 3: Hooks (선택)

이미 설치된 hook 스크립트는 **그대로 동작합니다**. v3.0은 **21개 이벤트 카탈로그**(`hooks/README.md`)와 **9개 shell 예제**(`hooks/examples/`)를 추가합니다:

```
hooks/examples/
├── post-compact.sh.example
├── post-tool-use-failure.sh.example
├── pre-compact.sh.example
├── stop-failure.sh.example
├── subagent-start.sh.example
├── subagent-stop.sh.example
├── task-created.sh.example
├── worktree-create.sh.example
└── worktree-remove.sh.example
```

활성화 방법:

```bash
# 1. 예제를 복사한 뒤 이름 변경 (.example 제거)
cp hooks/examples/stop-failure.sh.example hooks/stop-failure.sh
chmod +x hooks/stop-failure.sh

# 2. ~/.claude/settings.json의 해당 이벤트에 등록
#    이벤트별 정확한 블록 형태는 hooks/README.md 참조
```

기본 `settings.json`은 여전히 v2.1의 5개 hook(`PreToolUse`, `SessionStart`, `UserPromptSubmit`, `PostToolUse`, `Stop`, 그리고 `TaskCompleted`)만 연결합니다. opt-in 하기 전까지 새로운 hook은 실행되지 않으므로, 업그레이드가 런타임 동작을 바꾸지 않습니다.

### Step 4: Subagent frontmatter (선택)

v2.1 agent는 5개 필드를 사용합니다. v3.0은 **10개 선택 필드**를 추가합니다(전체 목록은 `docs/AGENT-FRONTMATTER-V2.md`, T2에서 작성):

```yaml
---
name: code-reviewer
description: Expert code review specialist...
tools: ["Read", "Grep", "Glob", "Bash"]
model: opus
memory: project
color: blue
# v3.0 선택 필드 — 필요할 때만 주석 해제
# isolation: worktree       # agent 작업을 git worktree로 격리
# background: true          # 블로킹 없이 백그라운드 실행
# maxTurns: 20              # 대화 길이 제한
# skills: [code-review]     # skill 프리로드
# mcpServers: [context7]    # MCP 범위 제한
# effort: max               # 심층 추론
# hooks:                    # agent별 hook
#   PreToolUse: [...]
# permissionMode: acceptEdits
# disallowedTools: [WebFetch]
---
```

기존 v2.1 frontmatter는 **완전히 지원됩니다**. Deprecation 없음. 새 필드는 명확히 도움이 되는 곳에만 추가하세요 — 파괴적 리팩토링에는 `isolation: worktree`, 무한 루프 방지에는 `maxTurns`, 심층 리뷰에는 `effort: max`. agent별 실전 레시피는 T2 레퍼런스 참조.

### Step 5: Skills/Commands 정리

항상 skill처럼 동작하던 디렉토리 형태 엔트리 8개가 `commands/`에서 `skills/`로 이동했습니다. 기존 경로는 **1년간 심볼릭 링크로 유지**(제거 예정: **2027-04-01**)되므로 첫날 아무것도 깨지지 않습니다.

| v2.1 경로 | v3.0 경로 |
|-----------|-----------|
| `commands/debugging-strategies/` | `skills/debugging-strategies/` |
| `commands/dependency-upgrade/` | `skills/dependency-upgrade/` |
| `commands/evaluating-code-models/` | `skills/evaluating-code-models/` |
| `commands/evaluating-llms-harness/` | `skills/evaluating-llms-harness/` |
| `commands/extract-errors/` | `skills/extract-errors/` |
| `commands/security-compliance/` | `skills/security-compliance/` |
| `commands/stride-analysis-patterns/` | `skills/stride-analysis-patterns/` |
| `commands/summarize/` | `skills/summarize/` |

이 이동을 이끈 정책은 [`docs/SKILLS-VS-COMMANDS.md`](docs/SKILLS-VS-COMMANDS.md)에 문서화되어 있습니다. 휴리스틱: `references/` 하위 트리가 있고 재사용 가능한 지식으로 로드되면 skill, 사용자가 타이밍을 결정하는 부작용(side effect)을 가진 단일 `.md`면 command.

개인 스크립트나 hook에서 이 경로를 참조한다면 여유 있게 새 `skills/` 경로로 전환하세요 — 심볼릭 링크가 시간을 벌어줍니다.

### Step 6: settings.json

v3.0 `settings.json`은 v2.1 위에 **최상위 3개 필드**를 추가합니다:

```json
{
  "tui": true,
  "disableSkillShellExecution": false,
  "enabledMcpjsonServers": ["playwright", "context7", "jina-reader"]
}
```

의미:

- **`tui`** — 2026 터미널 UI(풍부한 statusline, 인라인 skill 힌트)에 opt-in. 생략하거나 `false`로 두면 v2.1 CLI 렌더링 유지. 하위 호환.
- **`disableSkillShellExecution`** — `true`일 때 skill이 subshell을 spawn하지 못함. 조직 정책에서 요구하지 않는 한 `false` 유지 — 제공된 여러 skill(`/build-fix`, `/e2e`, `/auto`)이 shell 접근을 필요로 함.
- **`enabledMcpjsonServers`** — `mcp-servers.json` 엔트리 중 실제로 부팅될 명시적 allowlist. `"servers"` 키와 일치하거나 부분집합이어야 함. Step 2에서 `memory` / `exa`를 복구하면 여기에도 추가.

`permissions.allow` 블록도 변경되었습니다: `mcp__memory`, `mcp__exa`, `mcp__github`, `mcp__fetch`가 **제거**되었고, `mcp__playwright`가 **추가**되었습니다. 옛 MCP 서버를 복구한다면, `mcp__<server>__*` allow 엔트리도 다시 추가해 매 호출마다 tool search prompt가 뜨지 않도록 하세요.

## 호환성 타임라인

| 항목 | Deprecation 상태 | Sunset |
|------|------------------|--------|
| `commands/<skill>/` → `skills/<skill>/` 심볼릭 링크 | 1년 유지, 2026-10 이후 `show-setup`에서 경고 | **2027-04-01** |
| v2.1 mcp-servers 기본값(`memory`, `exa`, `github`, `fetch`) | 기본에서 제거, `mcp-servers.optional.json`에서 복구 가능 | Sunset 없음 — optional 카탈로그 유지 |
| v2.1 5필드 agent frontmatter | 완전 지원, deprecation 계획 없음 | Sunset 없음 |
| v2.1 hooks 이벤트 세트(5개 연결 이벤트) | 여전히 기본, 새 이벤트는 엄격히 opt-in | Sunset 없음 |
| `permissions.allow`의 `WebFetch` | 이미 v2.1에서 `deny`로 차단, 변경 없음 | 해당 없음 |
| v3.0 신규 3필드를 제외한 v2.1 `settings.json` | 완전 유효, 신규 필드 부재 시 v2.1 시맨틱 기본값 | Sunset 없음 |

핵심 원칙: **v3.0은 v2.1 설정을 깨뜨리지 않기 위해 매우 노력했습니다**. 물리적으로 끊어지는 것은 MCP 기본 목록뿐이며, 구 세트 복구는 서버당 JSON 2줄 + 재설치면 됩니다.

## 롤백

업그레이드 후 문제가 생기면, 전체 롤백은 세 줄입니다.

```bash
# 1. v2.1 claude-forge 트리 복원
cd path/to/claude-forge
git checkout v2.1.0        # 업그레이드 전 태그

# 2. Step 1의 ~/.claude 스냅샷 복원
rm -rf ~/.claude
mv ~/.claude.bak-YYYYMMDD-HHMM ~/.claude

# 3. v2.1 심볼릭 링크 재설치
./install.sh
```

한 조각만 되돌리고 싶다면(예: MCP 기본), `mcp-servers.json`을 수동 편집 후 `./install.sh --upgrade`를 재실행하세요. Installer는 idempotent하며 사용자 파일을 덮어쓰지 않습니다.

## FAQ

**Q1. `settings.json`을 건드린 적이 없습니다. `install.sh --upgrade`가 덮어쓰나요?**
아닙니다. Installer는 v3.0의 새 최상위 3필드가 누락된 경우에만 삽입하고, `permissions.allow`는 v2.1이 관리하던 MCP 도구 이름만 업데이트합니다. 수동 편집한 키는 보존됩니다.

**Q2. 제 자동화가 `mcp__github__*`에 의존합니다. 어떻게 하나요?**
`mcp-servers.optional.json`의 `github` 엔트리를 `mcp-servers.json`에 복사하고, `permissions.allow`에 `"mcp__github__*"`을 다시 추가한 뒤, `enabledMcpjsonServers`에도 서버 이름을 넣고 `./install.sh --upgrade`를 실행하세요. 기존 도구 호출이 그대로 동작합니다.

**Q3. Auto Memory**와** 옛 `memory` MCP를 병행하고 싶습니다.**
지원됩니다. Auto Memory는 `~/.claude/projects/<project>/memory/`에 있고, `memory` MCP를 추가하면 그 위에 **팀 공유 지식 그래프**가 얹혀집니다. 충돌하지 않습니다.

**Q4. v2.1 agent YAML이 그대로 파싱되나요?**
네. 새 10필드는 모두 선택입니다. 키가 없으면 harness는 v2.1 시맨틱(격리 없음, foreground, 무제한 turn, agent 가시 기본 tool-set, 기본 model effort, agent 범위 hook 없음)으로 폴백합니다.

**Q5. 2027-04에 사라지는 `commands/<skill>/` 심볼릭 링크, 뭘 업데이트해야 하나요?**
`~/.claude/commands/debugging-strategies/` 같은 경로를 하드코딩한 개인 스크립트/hook/문서 → `~/.claude/skills/debugging-strategies/`로 전환. `show-setup`이 2026-10부터 오래된 참조에 플래그를 달기 시작하므로 경고 기간이 있습니다.

**Q6. `disableSkillShellExecution: true`가 제공된 skill을 깨뜨리나요?**
일부는 그렇습니다. `/build-fix`, `/e2e`, `/auto`, `/handoff-verify`, `/quick-commit`은 모두 shell 명령을 실행합니다. 조직에서 이 플래그를 의무화한다면, skill wrapper 대신 메인 대화에서 `Bash` 도구를 직접 호출해 해당 워크플로우를 실행하세요.

**Q7. v3.0을 점진적으로 채택할 수 있나요 — MCP 먼저, hooks 나중?**
네. 위 각 단계는 독립적입니다. 유일한 하드 커플링은 "`mcp-servers.json`에 MCP 서버를 되돌리면, `enabledMcpjsonServers`와 `permissions.allow`에도 추가해야 한다"는 것뿐. 나머지는 각자 일정대로 진행 가능.

## 참조 문서

- [`docs/MCP-MIGRATION.md`](docs/MCP-MIGRATION.md) — 서버별 대체 레시피 (memory / exa / github / fetch)
- [`docs/SKILLS-VS-COMMANDS.md`](docs/SKILLS-VS-COMMANDS.md) — Step 5를 이끈 hybrid 정책
- [`docs/AGENT-FRONTMATTER-V2.md`](docs/AGENT-FRONTMATTER-V2.md) — Step 4 필드 레퍼런스 (T2)
- [`docs/CLAUDE-MD-GUIDE.md`](docs/CLAUDE-MD-GUIDE.md) — 200줄 원칙, 로드 계층, @import
- [`hooks/README.md`](hooks/README.md) — 21개 이벤트 카탈로그, matcher 스키마
- [`mcp-servers.optional.json`](mcp-servers.optional.json) — 복구용 서버 카탈로그
- [`setup/CLAUDE.md.template`](setup/CLAUDE.md.template) — 새 프로젝트용 스타터 CLAUDE.md
- [English version](MIGRATION.md)
