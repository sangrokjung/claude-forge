---
name: build-system
version: 1.0.0
description: 프로젝트 빌드 시스템 자동 감지 및 실행 스킬
last_updated: 2026-03-03
---

# Build System Skill

## 개요

프로젝트의 빌드 시스템을 자동으로 감지하고 적절한 빌드/테스트 명령어를 실행합니다.

## 지원 빌드 시스템

| 빌드 시스템 | 감지 파일 | 빌드 명령어 | 테스트 명령어 |
|------------|----------|------------|--------------|
| **.NET** | `*.csproj` / `*.sln` | `dotnet build` | `dotnet test` |
| npm | `package.json` | `npm run build` | `npm test` |
| yarn | `yarn.lock` | `yarn build` | `yarn test` |
| pnpm | `pnpm-lock.yaml` | `pnpm build` | `pnpm test` |
| Python (pip) | `requirements.txt` | `pip install -r requirements.txt` | `pytest` |
| Python (poetry) | `pyproject.toml` | `poetry install` | `poetry run pytest` |
| Gradle | `build.gradle` | `./gradlew build` | `./gradlew test` |
| Maven | `pom.xml` | `mvn package` | `mvn test` |
| Cargo | `Cargo.toml` | `cargo build` | `cargo test` |
| Go | `go.mod` | `go build ./...` | `go test ./...` |
| Make | `Makefile` | `make` | `make test` |

## 사용법

프로젝트 루트에서 빌드 시스템을 자동 감지하고 실행합니다.

### 빌드

```bash
# 자동 감지 후 빌드
/build

# 특정 명령어로 빌드
/build --cmd="npm run build:prod"
```

### 테스트

```bash
# 자동 감지 후 테스트
/test

# 특정 테스트만 실행
/test --filter="unit"
```

## 감지 우선순위

1. `*.csproj` / `*.sln` → dotnet
2. `package-lock.json` → npm
3. `yarn.lock` → yarn
4. `pnpm-lock.yaml` → pnpm
5. `pyproject.toml` → poetry
6. `requirements.txt` → pip
7. `Cargo.toml` → cargo
8. `go.mod` → go
9. `build.gradle` → gradle
10. `pom.xml` → maven
11. `Makefile` → make

## 커스터마이징

프로젝트별로 `.claude/config.json`에서 빌드 명령어를 오버라이드할 수 있습니다:

```json
{
  "build": {
    "command": "npm run build:custom",
    "test_command": "npm run test:ci"
  }
}
```

---

## .NET 전용 명령어

`.csproj` 또는 `.sln` 파일이 감지되면 아래 명령어를 사용합니다.

| 목적 | 명령어 |
|------|--------|
| 빌드 | `dotnet build` |
| 테스트 | `dotnet test` |
| 포맷 검사 (린트) | `dotnet format --verify-no-changes` |
| 포맷 자동 적용 | `dotnet format` |
| EF 마이그레이션 생성 | `dotnet ef migrations add [Name]` |
| DB 업데이트 | `dotnet ef database update` |
| 실행 | `dotnet run --project [프로젝트경로]` |
| 퍼블리시 | `dotnet publish -c Release` |

### CLAUDE.md 기반 자동 인식

CLAUDE.md에 아래와 같이 명시하면 `/handoff-verify`, `/auto` 등이 자동으로 참조합니다:

```markdown
## 빌드 & 검증 명령어
- Build: `dotnet build`
- Test: `dotnet test`
- Lint: `dotnet format --verify-no-changes`
- Migration: `dotnet ef migrations add [Name]`
```
