---
allowed-tools: Bash(git:*), Bash(mkdir:*), Read, Write, Glob
description: 프로젝트 초기 설정 (v6)
argument-hint: [프로젝트명] [--type next|vite|go|python|rust|dotnet]
---

# /init-project - 프로젝트 초기화 (v6)

프로젝트 초기화 체크리스트. 최초 1회 실행하여 CLAUDE.md, spec.md, prompt_plan.md를 대화형으로 생성한다.

## 0단계: 파라미터 파싱

`$ARGUMENTS`에서 플래그를 파싱한다.

| 플래그 | 설명 |
|--------|------|
| `[프로젝트명]` | 프로젝트 이름 (없으면 디렉토리명 사용) |
| `--type [type]` | 프로젝트 유형 강제 지정 (next/vite/go/python/rust) |

## 1단계: 프로젝트 환경 감지

현재 디렉토리에서 프로젝트 정보를 자동으로 수집한다.

```
수집 항목:
  1. package.json / go.mod / Cargo.toml / pyproject.toml -> 기술 스택
  1a. *.sln / *.csproj / global.json -> .NET 기술 스택 (Blazor/API)
  2. .git 존재 여부 -> Git 초기화 상태
  3. README.md -> 프로젝트 설명
  4. 기존 CLAUDE.md -> 이미 초기화 여부
  5. 디렉토리 구조 -> 아키텍처 패턴
```

> `.sln` 파일이 발견되면 기술 스택을 `.NET`으로 자동 설정한다.

기존 CLAUDE.md가 있으면 사용자에게 덮어쓰기/병합/취소를 확인한다.

## 2단계: CLAUDE.md 생성

수집된 정보와 사용자 입력을 기반으로 CLAUDE.md를 생성한다.

### 포함 항목

```markdown
# [프로젝트명]

## 개요
[프로젝트 설명]

## 기술 스택
- [감지된 기술 스택]

## 빌드 & 테스트
<!-- .NET 프로젝트인 경우 -->
- 빌드: `dotnet build`
- 테스트: `dotnet test`
- 린트: `dotnet format --verify-no-changes`
- 마이그레이션: `dotnet ef migrations add [Name]`

<!-- JS/TS 프로젝트인 경우 -->
- 빌드: `npm run build`
- 테스트: `npm test`
- 린트: `eslint . / tsc --noEmit`

## 디렉토리 구조
[주요 디렉토리와 역할]

## 코딩 컨벤션
[감지된 컨벤션 또는 사용자 입력]
```

## 3단계: spec.md 생성

기능 명세 템플릿을 생성한다.

### 템플릿

```markdown
# [프로젝트명] - 기능 명세

## Feature 1: [기능명]
### 요구사항
1. [요구사항]
### API 명세
- [엔드포인트 정의]
### 데이터 모델
- [모델 정의]
### 비즈니스 로직
- [핵심 로직]
```

사용자에게 주요 기능을 대화형으로 물어보고 작성한다.

## 4단계: prompt_plan.md 생성

구현 계획을 Phase별로 생성한다.

### 템플릿

```markdown
# [프로젝트명] - 구현 계획

## Phase 1: [단계명]
- [ ] [작업 1]
- [ ] [작업 2]

## Phase 2: [단계명]
- [ ] [작업 1]
- [ ] [작업 2]

## 의존성
- Phase 2는 Phase 1 완료 후 진행
```

spec.md의 기능을 기반으로 Phase를 자동 분해한다.

## 5단계: .gitignore 확인

`.gitignore`에 다음 항목이 포함되어 있는지 확인하고, 없으면 추가를 제안한다.

```
# Claude Code (v6 Post-Dev Workflow)
.claude/handoff.md
.claude/checkpoints/
.claude/web-checklist-state.json
```

## 6단계: 출력

```
════════════════════════════════════════════════════════════════
 Init Project v6
════════════════════════════════════════════════════════════════

프로젝트: [프로젝트명]
기술 스택: [감지된 스택]

생성 완료:
  CLAUDE.md       ([N]줄)
  spec.md         ([N]줄)
  prompt_plan.md  ([N]줄)

.gitignore 업데이트: [추가됨/이미 포함]

디렉토리 구조:
  project/
    CLAUDE.md
    spec.md
    prompt_plan.md
    .claude/
      handoff.md       (gitignore)
      checkpoints/     (gitignore)

다음 단계:
  1. spec.md에 기능 명세 상세 작성
  2. prompt_plan.md에 구현 계획 구체화
  3. /orchestrate 로 작업 시작

════════════════════════════════════════════════════════════════
```
