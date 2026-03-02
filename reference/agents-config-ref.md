# Agent MCP 설정 참조

> 이 파일은 agents-v2.md에서 분리된 MCP 분배 및 설정 내용입니다.
> 핵심 에이전트 목록과 즉시 사용 규칙은 [agents-v2.md](agents-v2.md) 참조.
> 팀 운영 상세는 [agents-teams-ref.md](agents-teams-ref.md) 참조.

## MCP 분배 패턴 (팀 워크플로우)

| 패턴 | Frontend/Writer | Backend/Designer | Tester/Distributor |
|------|----------------|------------------|--------------------|
| 풀스택 | Browser Automation, Data Transform | Memory, System Commands | Browser Automation, Analytics |

## MCP-Aware Subagent 선택 가이드

| 필요 MCP | 권장 type | 이유 |
|----------|-----------|------|
| CI/CD, Browser Automation, HTTP, Memory | general-purpose | Write/Bash 접근 필요 |
| Web Search, Documentation, Content Search | Explore | 읽기 전용 리서치 |

## Agent Frontmatter Field Reference (v2.1.63)

### Supported Fields

| Field | Required | Type | Valid Values | Description |
|-------|----------|------|--------------|-------------|
| `name` | **Required** | string | kebab-case | Agent identifier |
| `description` | **Required** | string | Trigger conditions | Auto-routing criteria |
| `model` | Optional | enum | `sonnet`, `opus`, `haiku`, `inherit` | Model selection |
| `color` | Optional | enum | `blue`, `cyan`, `green`, `yellow`, `magenta`, `red` | UI visual identifier |
| `tools` | Optional | array | Tool name array | Allowed tools allowlist |
| `maxTurns` | Optional | number | Positive integer | Maximum turns |
| `isolation` | Optional | enum | `worktree` | Git worktree isolation (requires git repo) |
| `memory` | Optional | string | `project` | Agent-specific persistent memory directory |

### Known Limitations (Verified on v2.1.63)

#### tools allowlist: Write/Edit cannot be excluded

Even with `tools: ["Read", "Grep", "Glob"]`, **Write and Edit are always included** by the runtime. Bash, Agent, and other tools can be restricted. For read-only agents, add explicit constraints in the prompt: "CRITICAL: Never use Write or Edit tools."

#### permissionMode: not effective in frontmatter

The CLI `--permission-mode` and Agent tool `mode` parameter support `plan`, `default`, `bypassPermissions`, `acceptEdits`, `dontAsk`, but **the frontmatter `permissionMode` field is ignored**. Use prompt-level constraints instead.

#### memory: no scope differentiation

All agents use the same path pattern `~/.claude/agent-memory/{agent-name}/` regardless of the memory value.

#### isolation: worktree -- git repository required

`isolation: worktree` only works inside git repositories. Error in non-git environments: `Cannot create agent worktree: not in a git repository`

#### Color Semantic Guide

| Color | Meaning | Example Agents |
|-------|---------|----------------|
| blue | Analysis/Review | planner, architect, code-reviewer |
| cyan | Testing/Verification | tdd-guide, verify-agent, e2e-runner |
| green | Business/Success | (user-defined) |
| yellow | Maintenance/Data | refactor-cleaner, doc-updater |
| red | Security/Critical | security-reviewer |
| magenta | Creative/Research | (user-defined) |
