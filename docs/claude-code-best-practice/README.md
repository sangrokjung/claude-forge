# Claude Code Best Practice (curated index)

큐레이션된 학습 자료 인덱스입니다. 원본은 `vendor/claude-code-best-practice/`에 통째로 미러링되어 있으며, 아래 링크는 가장 가치 있는 문서들로 골라 정리한 것입니다.

- **Upstream:** https://github.com/shanraisshan/claude-code-best-practice
- **License:** MIT (원본 저장소 참고)
- **Vendor README:** [vendor/claude-code-best-practice/VENDOR.md](../../vendor/claude-code-best-practice/VENDOR.md)

> 편집 금지. 이 디렉토리는 색인이고, 실제 파일은 `vendor/`에 있습니다. 업데이트는 VENDOR.md의 Resync 절차를 따르세요.

## Best Practice 가이드 (9편)

Claude Code의 각 구성요소별 베스트 프랙티스 문서.

| 주제 | 파일 |
|------|------|
| CLI 시작 플래그 | [claude-cli-startup-flags.md](../../vendor/claude-code-best-practice/best-practice/claude-cli-startup-flags.md) |
| Slash Commands | [claude-commands.md](../../vendor/claude-code-best-practice/best-practice/claude-commands.md) |
| MCP 서버 | [claude-mcp.md](../../vendor/claude-code-best-practice/best-practice/claude-mcp.md) |
| Memory (CLAUDE.md) | [claude-memory.md](../../vendor/claude-code-best-practice/best-practice/claude-memory.md) |
| Power-ups | [claude-power-ups.md](../../vendor/claude-code-best-practice/best-practice/claude-power-ups.md) |
| settings.json | [claude-settings.md](../../vendor/claude-code-best-practice/best-practice/claude-settings.md) |
| Skills | [claude-skills.md](../../vendor/claude-code-best-practice/best-practice/claude-skills.md) |
| Subagents | [claude-subagents.md](../../vendor/claude-code-best-practice/best-practice/claude-subagents.md) |

## Tips 모음 (Boris & Thariq)

Anthropic 엔지니어들이 공유한 Claude Code 실전 팁.

- [Boris — 13 tips (Jan 2026)](../../vendor/claude-code-best-practice/tips/claude-boris-13-tips-03-jan-26.md)
- [Boris — 10 tips (Feb 2026)](../../vendor/claude-code-best-practice/tips/claude-boris-10-tips-01-feb-26.md)
- [Boris — 12 tips (Feb 2026)](../../vendor/claude-code-best-practice/tips/claude-boris-12-tips-12-feb-26.md)
- [Boris — 2 tips (Mar 10, 2026)](../../vendor/claude-code-best-practice/tips/claude-boris-2-tips-10-mar-26.md)
- [Boris — 2 tips (Mar 25, 2026)](../../vendor/claude-code-best-practice/tips/claude-boris-2-tips-25-mar-26.md)
- [Boris — 15 tips (Mar 30, 2026)](../../vendor/claude-code-best-practice/tips/claude-boris-15-tips-30-mar-26.md)
- [Thariq — tips (Mar 17, 2026)](../../vendor/claude-code-best-practice/tips/claude-thariq-tips-17-mar-26.md)

## Development Workflows

- [Cross-model workflow](../../vendor/claude-code-best-practice/development-workflows/cross-model-workflow/cross-model-workflow.md) — Claude + 다른 모델을 조합해 쓰는 패턴
- [RPI workflow](../../vendor/claude-code-best-practice/development-workflows/rpi/rpi-workflow.md) — Research → Plan → Implement 사이클

## Orchestration Workflow

Command → Agent → Skill 아키텍처 레퍼런스 구현.

- [orchestration-workflow.md](../../vendor/claude-code-best-practice/orchestration-workflow/orchestration-workflow.md) — 전체 흐름 다이어그램과 설명
- 데모 구현: `.claude/agents/weather-agent.md`, `.claude/commands/weather-orchestrator.md`, `.claude/skills/weather-fetcher/`, `.claude/skills/weather-svg-creator/` (모두 vendor 하위)

## Tutorial (신규 사용자용)

- [Day 0 — 설치](../../vendor/claude-code-best-practice/tutorial/day0/README.md) (mac/windows/linux)
- [Day 1 — 온보딩](../../vendor/claude-code-best-practice/tutorial/day1/README.md) — 프롬프팅, agents, skills 기초 (비엔지니어 대상)

## 원본 CLAUDE.md

리포지토리 개요와 구성요소 설명: [CLAUDE.md](../../vendor/claude-code-best-practice/CLAUDE.md)
