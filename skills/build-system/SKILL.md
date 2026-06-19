---
name: build-system
version: 1.0.0
description: Use when detecting and running project build systems automatically. Supports npm/yarn/pnpm/pip/poetry/gradle/maven/cargo/go/make. Triggers on build, test run, project setup, package manager detection.
last_updated: 2026-01-31
---

# Build System Skill

## 개요

프로젝트의 빌드 시스템을 자동으로 감지하고 적절한 빌드/테스트 명령어를 실행합니다.

## 지원 빌드 시스템

| 빌드 시스템 | 감지 파일 | 빌드 명령어 | 테스트 명령어 |
|------------|----------|------------|--------------|
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

1. `package-lock.json` → npm
2. `yarn.lock` → yarn
3. `pnpm-lock.yaml` → pnpm
4. `pyproject.toml` → poetry
5. `requirements.txt` → pip
6. `Cargo.toml` → cargo
7. `go.mod` → go
8. `build.gradle` → gradle
9. `pom.xml` → maven
10. `Makefile` → make

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
