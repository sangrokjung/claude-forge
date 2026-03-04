---
allowed-tools: Bash(git:*), Bash(docker:*), Bash(az:*), Read, Write, Edit, Glob, Grep
description: 배포 대상 선택 및 전환 (Azure ↔ Self-hosted Docker)
argument-hint: [azure|docker|status|switch]
---

# /deploy — 배포 대상 선택 및 전환

Azure App Service와 Self-hosted Docker 중 배포 대상을 선택하거나 전환합니다.

## 사용법

```bash
/deploy status          # 현재 배포 설정 확인
/deploy azure           # Azure 배포 설정 가이드
/deploy docker          # Self-hosted Docker 배포 설정 가이드
/deploy switch azure    # Docker → Azure 전환
/deploy switch docker   # Azure → Docker 전환
```

---

## 0단계: 인자 파싱

`$ARGUMENTS`에서 서브커맨드를 추출한다:

| 인자 | 동작 |
|------|------|
| `status` (기본) | 현재 배포 설정 진단 |
| `azure` | Azure 배포 가이드 출력 |
| `docker` | Self-hosted Docker 가이드 출력 |
| `switch azure` | Docker → Azure 전환 체크리스트 |
| `switch docker` | Azure → Docker 전환 체크리스트 |

---

## status — 현재 배포 설정 진단

다음을 확인하고 출력한다:

### 확인 항목

1. **활성 워크플로우 감지**
   ```bash
   ls .github/workflows/
   ```
   - `deploy-azure.yml` 존재 + 활성화 여부
   - `deploy-docker.yml` 존재 + 활성화 여부

2. **인프라 파일 존재 여부**
   ```bash
   ls Dockerfile .dockerignore infra/docker/ infra/azure/ 2>/dev/null
   ```

3. **환경변수 설정 상태**
   ```bash
   # Azure 관련 secrets 설정 여부 (GitHub CLI로 확인)
   gh secret list 2>/dev/null | grep -E "AZURE|ACR|SERVER_HOST"
   ```

4. **현재 타겟 추론**
   - Azure secrets 있음 → Azure 타겟
   - SERVER_HOST secrets 있음 → Docker 타겟
   - 둘 다 없음 → 미설정

### 출력 형식

```
════════════════════════════════════════════════════════
  배포 설정 현황
════════════════════════════════════════════════════════

  현재 타겟: [Azure App Service | Self-hosted Docker | 미설정]

  파일 상태:
    Dockerfile              [✅ 존재 | ❌ 없음]
    .dockerignore           [✅ 존재 | ❌ 없음]
    infra/docker/           [✅ 존재 | ❌ 없음]
    infra/azure/            [✅ 존재 | ❌ 없음]

  워크플로우:
    dotnet-ci.yml           [✅ 활성 | ❌ 없음]
    deploy-azure.yml        [✅ 활성 | ⚠️ 비활성 | ❌ 없음]
    deploy-docker.yml       [✅ 활성 | ⚠️ 비활성 | ❌ 없음]

  Secrets:
    Azure                   [✅ 설정됨 | ❌ 미설정]
    Docker 서버             [✅ 설정됨 | ❌ 미설정]

  다음 단계:
    /deploy azure    — Azure 배포 설정하기
    /deploy docker   — Self-hosted Docker 설정하기
════════════════════════════════════════════════════════
```

---

## azure — Azure 배포 설정 가이드

### 필요한 Azure 리소스

```
Azure 구독
├── Resource Group
├── Azure Container Registry (ACR)    ← Docker 이미지 저장소
└── App Service Plan (Standard S2+)
    ├── App Service (production slot)
    └── App Service (staging slot)    ← 무중단 배포용
```

### 단계별 가이드 출력

```
════════════════════════════════════════════════════════
  Azure 배포 설정 가이드
════════════════════════════════════════════════════════

  1. Azure 리소스 생성
  ─────────────────────
  # 리소스 그룹
  az group create --name myapp-rg --location koreacentral

  # Container Registry
  az acr create --name myappregistry --resource-group myapp-rg \
    --sku Basic --admin-enabled true

  # App Service Plan (Standard S2 이상 — 슬롯 스왑 지원)
  az appservice plan create --name myapp-plan --resource-group myapp-rg \
    --sku S2 --is-linux

  # App Service
  az webapp create --name myapp --resource-group myapp-rg \
    --plan myapp-plan --deployment-container-image-name nginx

  # Staging 슬롯
  az webapp deployment slot create --name myapp \
    --resource-group myapp-rg --slot staging

  2. GitHub Secrets 등록
  ─────────────────────
  다음을 GitHub → Settings → Secrets → Actions에 등록:

  AZURE_CLIENT_ID          # Service Principal App ID
  AZURE_TENANT_ID          # Azure Tenant ID
  AZURE_SUBSCRIPTION_ID    # 구독 ID
  ACR_LOGIN_SERVER         # myappregistry.azurecr.io
  ACR_USERNAME             # myappregistry
  ACR_PASSWORD             # az acr credential show 로 확인
  AZURE_WEBAPP_NAME        # myapp
  AZURE_RESOURCE_GROUP     # myapp-rg

  3. Blazor ARR Affinity 설정 (스티키 세션)
  ─────────────────────
  az webapp update --name myapp --resource-group myapp-rg \
    --client-affinity-enabled true

  4. 앱 환경변수 설정
  ─────────────────────
  az webapp config appsettings set --name myapp \
    --resource-group myapp-rg \
    --settings \
      ASPNETCORE_ENVIRONMENT=Production \
      Supabase__Url="https://your-project.supabase.co" \
      Supabase__AnonKey="your-anon-key"

  5. 헬스체크 엔드포인트 확인
  ─────────────────────
  Program.cs에 추가됐는지 확인:
    app.MapHealthChecks("/health");

  완료 후 push → GitHub Actions 자동 배포 시작

════════════════════════════════════════════════════════
```

---

## docker — Self-hosted Docker 배포 설정 가이드

### 단계별 가이드 출력

```
════════════════════════════════════════════════════════
  Self-hosted Docker 배포 설정 가이드
════════════════════════════════════════════════════════

  1. 서버 준비 (Ubuntu 22.04 LTS 권장)
  ─────────────────────
  # Docker 설치
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker $USER

  # 배포 디렉토리 생성
  mkdir -p ~/deploy && cd ~/deploy
  cp /path/to/infra/docker/docker-compose.yml .
  cp /path/to/infra/docker/nginx.conf .
  cp /path/to/infra/docker/.env.example .env
  # .env 파일 편집: 실제 값으로 채우기

  2. GitHub Secrets 등록
  ─────────────────────
  SERVER_HOST        # 서버 IP 또는 도메인
  SERVER_USER        # SSH 사용자명 (예: ubuntu)
  SERVER_SSH_KEY     # SSH 개인키 (cat ~/.ssh/id_ed25519)
  SERVER_PORT        # SSH 포트 (기본 22)
  DEPLOY_PATH        # 서버 배포 경로 (예: /home/ubuntu/deploy)

  3. SSL 인증서 발급 (Let's Encrypt)
  ─────────────────────
  # 서버에서:
  docker compose --profile ssl up certbot
  # 이후 nginx.conf의 DOMAIN 환경변수 설정

  4. 수동 배포 테스트
  ─────────────────────
  docker compose pull
  docker compose up -d
  curl http://localhost/health

  5. 스케일 업/다운
  ─────────────────────
  docker compose up -d --scale app=3   # 인스턴스 3개
  docker compose up -d --scale app=1   # 인스턴스 1개 (트래픽 적을 때)

════════════════════════════════════════════════════════
```

---

## switch — 배포 대상 전환

### switch azure (Docker → Azure)

```
════════════════════════════════════════════════════════
  Docker → Azure 전환 체크리스트
════════════════════════════════════════════════════════

  [ ] 1. deploy-docker.yml 비활성화
        파일명 변경: deploy-docker.yml → deploy-docker.yml.disabled
        또는 on.push.branches 에서 main 제거

  [ ] 2. deploy-azure.yml 활성화
        이미 존재하면 on.push.branches에 main 추가

  [ ] 3. Azure 리소스 생성 (/deploy azure 가이드 참고)

  [ ] 4. GitHub Secrets 등록 (Azure 관련 8개)

  [ ] 5. ARR Affinity 활성화 (Blazor 스티키 세션)

  [ ] 6. 환경변수 동기화
        infra/docker/.env → Azure App Settings로 이전
        민감한 값은 Key Vault 참조 권장:
          @Microsoft.KeyVault(SecretUri=https://...)

  [ ] 7. 헬스체크 URL 업데이트
        https://[webapp-name].azurewebsites.net/health

  [ ] 8. 커밋 & 푸시 → 자동 배포 확인

════════════════════════════════════════════════════════
```

### switch docker (Azure → Docker)

```
════════════════════════════════════════════════════════
  Azure → Self-hosted Docker 전환 체크리스트
════════════════════════════════════════════════════════

  [ ] 1. deploy-azure.yml 비활성화
        파일명 변경: deploy-azure.yml → deploy-azure.yml.disabled

  [ ] 2. deploy-docker.yml 활성화
        on.push.branches에 main 추가

  [ ] 3. 서버 준비 (Docker 설치 확인)

  [ ] 4. GitHub Secrets 등록 (서버 SSH 관련 5개)

  [ ] 5. 환경변수 동기화
        Azure App Settings → infra/docker/.env로 이전
        서버에 .env 파일 배포

  [ ] 6. nginx SSL 인증서 설정

  [ ] 7. 헬스체크 URL 업데이트
        http://[server-ip]/health

  [ ] 8. Blazor 스티키 세션 확인
        nginx.conf에 ip_hash; 설정 있는지 확인

  [ ] 9. 커밋 & 푸시 → 자동 배포 확인

════════════════════════════════════════════════════════
```

---

## 공통 주의사항

### Blazor Auto + 로드밸런싱 시 필수

```csharp
// Program.cs — 헬스체크 등록 (필수)
builder.Services.AddHealthChecks()
    .AddNpgSql(connectionString, name: "database")
    .AddUrlGroup(new Uri(supabaseUrl), name: "supabase");

app.MapHealthChecks("/health");

// Forwarded Headers (nginx/Azure 프록시 뒤에서 HTTPS 인식)
app.UseForwardedHeaders(new ForwardedHeadersOptions {
    ForwardedHeaders = ForwardedHeaders.XForwardedFor
                     | ForwardedHeaders.XForwardedProto
});
```

### 환경별 appsettings 구조

```
appsettings.json              # 공통 기본값 (민감정보 없음)
appsettings.Development.json  # 로컬 개발 (gitignore에 포함)
appsettings.Production.json   # 프로덕션 기본값 (환경변수로 오버라이드)
```

Azure/Docker 모두 환경변수로 덮어쓰므로 `appsettings.Production.json`에는 비밀값을 두지 않는다.
