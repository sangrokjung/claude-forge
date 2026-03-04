---
name: verify-deployment
description: 배포 전 필수 항목 검증. Dockerfile, 헬스체크, 환경변수 노출, 워크플로우 설정을 검사합니다.
disable-model-invocation: true
---

# verify-deployment

## Purpose

배포 전에 다음 항목을 자동으로 검증합니다:

1. **Dockerfile 안전성** — 비밀값 하드코딩, non-root 실행, 멀티스테이지 빌드 확인
2. **헬스체크** — `/health` 엔드포인트 존재 여부 확인
3. **환경변수 노출** — appsettings에 민감정보 하드코딩 여부
4. **워크플로우 설정** — 배포 워크플로우 충돌 (Azure + Docker 동시 활성화) 감지
5. **nginx 설정** — Blazor SignalR WebSocket 설정, 스티키 세션 확인

## When to Run

- 배포 전 (`/deploy azure`, `/deploy docker` 실행 전)
- Dockerfile 또는 워크플로우 변경 시
- infra/ 디렉토리 변경 시

## Related Files

| File | Purpose |
|------|---------|
| `Dockerfile` | 컨테이너 빌드 정의 |
| `infra/docker/docker-compose.yml` | Self-hosted 배포 설정 |
| `infra/docker/nginx.conf` | 로드밸런서 설정 |
| `.github/workflows/deploy-*.yml` | 배포 워크플로우 |
| `**/Program.cs` | 헬스체크 등록 확인 |
| `**/appsettings*.json` | 환경 설정 파일 |

---

## Workflow

### Step 1: Dockerfile 안전성 검사

```bash
# 1a. 비밀값 하드코딩 탐지
grep -nE "(password|secret|key|token|apikey)\s*=\s*['\"][^'\"]{6,}" \
  Dockerfile 2>/dev/null
```

**PASS**: 결과 없음
**FAIL**: 하드코딩된 비밀값 발견 → ARG 또는 런타임 환경변수로 이전

```bash
# 1b. root 실행 여부 확인 (USER 선언 없으면 root)
grep -n "^USER" Dockerfile 2>/dev/null
```

**PASS**: `USER` 선언 존재
**WARN**: 없으면 root로 실행됨 → `USER app` 추가 권장 (필수는 아님)

```bash
# 1c. 멀티스테이지 빌드 확인
grep -c "^FROM" Dockerfile 2>/dev/null
```

**PASS**: `FROM` 2개 이상 (빌드 + 런타임 분리)
**WARN**: 1개 → SDK 이미지가 그대로 배포됨 (이미지 크기 과다)

```bash
# 1d. HEALTHCHECK 선언 확인
grep -n "^HEALTHCHECK" Dockerfile 2>/dev/null
```

**PASS**: `HEALTHCHECK` 선언 존재
**FAIL**: 없음 → 컨테이너 상태 감지 불가

---

### Step 2: 헬스체크 엔드포인트 확인

```bash
# Program.cs에서 헬스체크 등록 여부 확인
grep -rn "MapHealthChecks\|AddHealthChecks" --include="*.cs" src/ 2>/dev/null
```

**PASS**: `AddHealthChecks` + `MapHealthChecks("/health")` 모두 존재
**FAIL**: 없음 → 배포 후 컨테이너/Azure App Service가 앱 상태를 알 수 없음

권장 코드:
```csharp
// Program.cs
builder.Services.AddHealthChecks()
    .AddNpgSql(connectionString, name: "database");
app.MapHealthChecks("/health");
```

---

### Step 3: appsettings 민감정보 노출 검사

```bash
# appsettings.json에서 비밀값 패턴 탐지 (Development 제외)
grep -rn --include="appsettings*.json" \
  -E "(Password|Secret|ApiKey|Token|ConnectionString)\s*:\s*\"[^\"]{8,}\"" \
  . 2>/dev/null | grep -v "Development\|Example\|placeholder"
```

**PASS**: 결과 없음 (또는 Development 파일에만 존재)
**FAIL**: Production/기본 appsettings에 비밀값 → 환경변수로 이전

```bash
# .env 파일이 .gitignore에 포함됐는지 확인
grep -E "^\.env$|^\.env\." .gitignore 2>/dev/null
```

**PASS**: `.env` 패턴이 .gitignore에 포함됨
**FAIL**: 없음 → `.env` 파일이 실수로 커밋될 수 있음

---

### Step 4: 워크플로우 충돌 감지

```bash
# 두 배포 워크플로우가 동시에 main 브랜치를 트리거하는지 확인
for f in .github/workflows/deploy-azure.yml .github/workflows/deploy-docker.yml; do
  if [ -f "$f" ]; then
    if grep -q "branches.*main\|branches.*master" "$f"; then
      echo "ACTIVE: $f"
    else
      echo "INACTIVE: $f"
    fi
  fi
done
```

**PASS**: 하나만 ACTIVE
**FAIL**: 둘 다 ACTIVE → main 푸시 시 양쪽에 동시 배포됨 → 하나를 `.disabled` 확장자로 변경

---

### Step 5: nginx Blazor 설정 확인

```bash
# SignalR WebSocket 업그레이드 설정 확인
grep -n "Upgrade.*websocket\|proxy_http_version 1.1" \
  infra/docker/nginx.conf 2>/dev/null
```

**PASS**: WebSocket Upgrade 설정 존재
**FAIL**: 없음 → Blazor Server/Auto의 실시간 연결 불가

```bash
# 스티키 세션 설정 확인
grep -n "ip_hash\|sticky" infra/docker/nginx.conf 2>/dev/null
```

**PASS**: `ip_hash` 또는 쿠키 기반 스티키 세션 설정 존재
**WARN**: 없음 → 멀티 인스턴스에서 Blazor 세션이 끊길 수 있음

---

## 결과 출력 형식

```
════════════════════════════════════════════════════════
  verify-deployment 결과
════════════════════════════════════════════════════════

  Dockerfile
    ✅ 멀티스테이지 빌드 (빌드 + 런타임 분리)
    ✅ HEALTHCHECK 선언
    ⚠️  USER 선언 없음 (root 실행) — 권장: USER app 추가

  헬스체크
    ✅ AddHealthChecks() 등록
    ✅ MapHealthChecks("/health") 등록

  appsettings 보안
    ✅ appsettings.json — 비밀값 없음
    ✅ .env → .gitignore 포함

  워크플로우
    ✅ deploy-azure.yml (ACTIVE)
    ✅ deploy-docker.yml (INACTIVE — .disabled 처리됨)

  nginx (Self-hosted용)
    ✅ WebSocket Upgrade 설정
    ✅ ip_hash 스티키 세션

────────────────────────────────────────────────────────
  PASS: 5  WARN: 1  FAIL: 0
  배포 준비 완료. 경고 항목은 선택적으로 개선 가능.
════════════════════════════════════════════════════════
```

## Severity 기준

| 수준 | 기준 | 배포 차단 여부 |
|------|------|--------------|
| FAIL | 헬스체크 없음, 비밀값 하드코딩, 워크플로우 충돌, WebSocket 미설정 | ✅ 차단 권장 |
| WARN | root 실행, 스티키 세션 없음, 단일스테이지 빌드 | ❌ 비차단 (권장 수정) |
| PASS | 모든 항목 통과 | — |
