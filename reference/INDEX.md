# 규칙 파일 인덱스

`~/.claude/rules/` (자동 로드) 및 `~/.claude/reference/` (필요 시 Read) 파일 목록.

## 핵심 규칙 (rules/ - 매 세션 자동 로드)

| 파일 | 용도 | 크기 |
|------|------|------|
| ~/.claude/rules/coding-style.md | 불변성, 파일 구조, 에러 핸들링, 코드 품질 | 핵심 |
| ~/.claude/rules/interaction.md | 언어(한국어), 비유 설명, 결론 먼저, context7 사용 규칙 | 핵심 |
| ~/.claude/rules/security.md | 시크릿 관리, 보안 체크리스트, 보안 대응 프로토콜 | 핵심 |
| ~/.claude/rules/git-workflow-v2.md | 커밋 메시지 형식, PR 워크플로우, GitHub org 관리 | 핵심 |
| ~/.claude/rules/date-calculation.md | 날짜/시간 계산 필수 도구 사용 (bash/python) | 핵심 |
| ~/.claude/rules/golden-principles.md | 핵심 원칙 7가지 | 핵심 |
| ~/.claude/rules/agents-v2.md | 에이전트 목록, 즉시 사용 규칙, 병렬 실행 패턴 | 핵심 |

## 도메인 규칙 (rules/ - 매 세션 자동 로드)

| 파일 | 용도 |
|------|------|
| ~/.claude/rules/architecture-dotnet.md | Clean Architecture 레이어 규칙, DI 패턴 |
| ~/.claude/rules/coding-style-dotnet.md | C# 코딩 스타일, 네이밍 규칙 |
| ~/.claude/rules/frontend-blazor.md | Blazor 컴포넌트 패턴, HttpOnly 쿠키 인증 |
| ~/.claude/rules/database-supabase.md | Supabase DB, RLS, EF Core 마이그레이션 |
| ~/.claude/rules/security-dotnet.md | .NET 보안, OWASP, 시크릿 관리 |
| ~/.claude/rules/testing-dotnet.md | xUnit, Moq, 테스트 전략 |
| ~/.claude/rules/azure-deployment.md | Azure 배포 규칙 |
| ~~testing.md~~ | **disabled** — testing-dotnet.md로 대체 |
| ~~coding-style.md~~ | **disabled** — coding-style-dotnet.md로 대체 |
| ~~security.md~~ | **disabled** — security-dotnet.md로 대체 |

## 참조 문서 (reference/ - 필요 시 Read 도구로 접근)

| 파일 | 용도 | 참조 |
|------|------|------|
| [agents-teams-ref.md](./agents-teams-ref.md) | Agent Teams 상세: 전제조건, 규칙, 리더 규율, 팀원 관리 | agents-v2.md에서 분리 |
| [agents-config-ref.md](./agents-config-ref.md) | MCP 분배 패턴, Subagent 선택 가이드 | agents-v2.md에서 분리 |
| [omc-adoption.md](./omc-adoption.md) | 활성/비활성 기능, 병합 에이전트, 스킬 우선순위, AST 도구 | **주 파일** |
| [omc-adoption-detail.md](./omc-adoption-detail.md) | 설치 정보, 업데이트 5단계, 롤백, 위험 관리 | omc-adoption.md에서 분리 |

## 파일 관계도

```
rules/ (자동 로드)
  agents-v2.md (핵심, ~4KB)
    → reference/agents-teams-ref.md  (팀 운영 상세, ~10KB)
    → reference/agents-config-ref.md (MCP 설정, ~1KB)

reference/ (필요 시 Read)
  omc-adoption.md (핵심, ~3KB)
    → omc-adoption-detail.md (설치/유지보수, ~3KB)
```

## 수정 가이드

- 에이전트 목록 추가/변경 → `~/.claude/rules/agents-v2.md`
- 팀 운영 규칙 변경 → `~/.claude/reference/agents-teams-ref.md`
- MCP 패턴 변경 → `~/.claude/reference/agents-config-ref.md`
- OMC 버전 업데이트 → `~/.claude/reference/omc-adoption.md` (버전 번호) + `omc-adoption-detail.md` (상세)
