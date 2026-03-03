# Claude Forge

Claude Code 설정 및 워크플로우 자동화 프레임워크 (Windows / .NET 환경)

## 기술 스택

- **언어**: C# / .NET 10
- **프론트엔드**: Blazor Auto
- **백엔드**: .NET API (Clean Architecture)
- **DB**: Supabase (PostgreSQL)
- **스타일**: Tailwind CSS v4.2

## 빌드 & 검증 명령어

```bash
# 빌드
dotnet build

# 테스트
dotnet test

# 포맷 검사 (린트 역할)
dotnet format --verify-no-changes

# EF Core 마이그레이션
dotnet ef migrations add [Name]
dotnet ef database update
```

## 핵심 디렉토리

```
commands/   # /plan, /tdd, /auto 등 커스텀 커맨드
agents/     # 전문 AI 에이전트
skills/     # 재사용 가능한 스킬
hooks/      # 자동화 훅 스크립트 (bash .sh — WSL2 또는 Git Bash 필요)
rules/      # 코딩 규칙
knowledge/  # 참고 문서 및 요약
docs/       # 사용자 문서, 이미지
```

> ⚠️ **hooks 실행 환경**: `hooks/*.sh` 파일은 bash 기반입니다.
> Windows에서는 **WSL2** 또는 **Git Bash** 환경이 필요합니다.
> Claude Code를 WSL2 터미널에서 실행하거나, Git Bash를 기본 셸로 설정하세요.

## Git 워크플로우

- 브랜치: `feature/`, `fix/`, `refactor/` 접두사 사용
- PR 전 `/handoff-verify` 필수 실행
- 커밋 후 `/sync`로 문서 동기화

## 주요 커맨드

| 커맨드 | 용도 |
|--------|------|
| `/guide` | 시작점 — 현재 상태 진단 |
| `/plan` | 구현 계획 수립 |
| `/tdd` | 테스트 주도 개발 |
| `/handoff-verify` | 빌드/테스트 자동 검증 |
| `/commit-push-pr` | 커밋 + PR 자동화 |
| `/sync` | 문서 동기화 |
| `/auto` | 전체 파이프라인 원버튼 실행 |

---

## 스킬 호환성 (.NET 환경 기준)

### ✅ .NET에서 정상 동작하는 스킬

| 스킬 | 동작 여부 | 비고 |
|------|-----------|------|
| `build-system` | ✅ 완전 지원 | `.csproj`/`.sln` 자동 감지, `dotnet build/test` 실행 |
| `verification-engine` | ✅ 지원 | CLAUDE.md에 명령어 명시 시 자동 참조 |
| `security-pipeline` | ✅ 지원 | 언어 무관, 파일 패턴 기반 보안 스캔 |
| `manage-skills` | ✅ 지원 | 프로젝트 패턴 분석 및 verify-* 스킬 관리 |
| `verify-implementation` | ✅ 지원 | verify-* 스킬 통합 실행 |
| `skill-factory` | ✅ 지원 | 세션 패턴 → 스킬 자동 생성 |
| `session-wrap` | ✅ 지원 | 언어 무관 |
| `strategic-compact` | ✅ 지원 | 언어 무관 |
| `continuous-learning-v2` | ✅ 지원 | 언어 무관 |
| `team-orchestrator` | ✅ 지원 | 언어 무관 |

### ⚠️ .NET에서 제한적으로 동작하는 스킬

| 스킬 | 제한 사항 | 대응 방법 |
|------|-----------|----------|
| `frontend-code-review` | `.tsx/.ts/.js` 전용 체크리스트 | `.razor/.cs` 용 `verify-blazor` 스킬 별도 필요 |

### ❌ .NET과 관련 없는 스킬 (JS/TS 환경 전용)

| 스킬 | 이유 |
|------|------|
| `cache-components` | React/Next.js 컴포넌트 캐싱 전용 |
| `eval-harness` | JS/Python LLM 평가 테스트 전용 |
| `prompts-chat` | JS 기반 채팅 프롬프트 패턴 전용 |

### 📝 .NET용 추가 권장 스킬 (`skills/`에 전역 설치됨)

| 스킬명 | 용도 |
|--------|------|
| `verify-blazor` | Blazor 컴포넌트 패턴, `@inject`/`@code`/`@rendermode` 구조 검증 |
| `verify-ef-migration` | EF Core 마이그레이션 네이밍·롤백·파괴적 변경 안전성 검증 |
| `verify-clean-arch` | Clean Architecture 레이어 의존성 방향 위반 탐지 |
