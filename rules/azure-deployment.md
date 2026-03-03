# Azure Deployment

## 인프라 구성

| 서비스 | 용도 | 권장 플랜 |
|:-------|:-----|:---------|
| **Azure App Service** (Linux) | .NET 10 Web API 백엔드 | B2 이상 (프로덕션) |
| **Azure App Service** / **Static Web Apps** | Blazor Auto 프론트엔드 | Free/B1 (Static Web Apps 권장) |
| **Azure Key Vault** | 모든 Secret 중앙 관리 | Standard |
| **Azure Application Insights** | APM + 로그 수집 | 사용량 기반 |
| **Azure Container Registry** | Docker 이미지 (선택) | Basic |

## Secret 관리 (Azure Key Vault 필수)

**`appsettings.json`에 시크릿 직접 기입 절대 금지.**

```csharp
// Program.cs — Key Vault 자동 연동
if (!builder.Environment.IsDevelopment())
{
    var keyVaultUri = new Uri(builder.Configuration["Azure:KeyVaultUri"]!);
    builder.Configuration.AddAzureKeyVault(keyVaultUri, new DefaultAzureCredential());
}
```

Key Vault Secret 네이밍 규칙 (`--`은 `:` 대체):
- `Supabase--ServiceKey` → `Config["Supabase:ServiceKey"]`
- `Serilog--N8nWebhookUrl` → `Config["Serilog:N8nWebhookUrl"]`

## 환경 분리

| 환경 | `ASPNETCORE_ENVIRONMENT` | 설명 |
|:-----|:------------------------|:-----|
| 개발 | `Development` | 로컬, User Secrets |
| 스테이징 | `Staging` | Azure (테스트), Key Vault |
| 프로덕션 | `Production` | Azure (운영), Key Vault |

```
appsettings.json              # 공통 설정 (시크릿 없음)
appsettings.Development.json  # 개발 설정 (로컬 URL 등)
appsettings.Staging.json      # 스테이징 설정
appsettings.Production.json   # 프로덕션 설정
```

## Application Insights + Serilog 연동

```csharp
// Serilog → Application Insights + n8n Webhook (둘 다 사용)
// ① Application Insights SDK를 먼저 DI에 등록
builder.Services.AddApplicationInsightsTelemetry();

// ② UseSerilog에서 DI로 주입된 TelemetryConfiguration 사용
//    (TelemetryConfiguration.Active 는 .NET 6+ deprecated → 사용 금지)
builder.Host.UseSerilog((ctx, services, lc) => lc
    .ReadFrom.Configuration(ctx.Configuration)
    .WriteTo.Console()
    .WriteTo.ApplicationInsights(
        services.GetRequiredService<TelemetryConfiguration>(),
        TelemetryConverter.Traces)
    .WriteTo.Http(
        requestUri: ctx.Configuration["Serilog:N8nWebhookUrl"]!,
        restrictedToMinimumLevel: LogEventLevel.Error)
);
```

Application Insights에서 확인 가능한 것:
- 전체 요청 로그 (성공/실패)
- 성능 추적 (응답시간, DB 쿼리)
- Error/Exception 상세 (스택 트레이스)
- 커스텀 메트릭 및 이벤트

n8n에서 확인 가능한 것:
- Error/Critical 레벨 실시간 알림 (Slack, Teams, 이메일)
- 워크플로우 트리거 (특정 에러 패턴 감지 시 자동 대응)

## CI/CD 기본 구성 (GitHub Actions)

```yaml
# .github/workflows/deploy.yml 기본 구조
name: Deploy to Azure

on:
  push:
    branches: [main, staging]   # main → 프로덕션, staging → 스테이징

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Test
        run: dotnet test  # 모든 테스트 통과 시에만 배포

  deploy:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to Azure App Service
        uses: azure/webapps-deploy@v3
```

**배포 전 테스트 실패 시 자동 중단** — 테스트 없는 배포 금지.

## Health Check 연동

배포 후 반드시 Health Check 엔드포인트로 정상 확인:

```
GET /health       → DB 연결, 외부 서비스 상태
GET /health/ready → 트래픽 수신 준비 여부
```

Azure App Service의 Health Check 경로에 `/health` 설정하여 비정상 인스턴스 자동 교체.

## Scale Out (다중 인스턴스) 주의사항

> [!IMPORTANT]
> Scale Out은 "나중에 서버 늘릴 때 처리하는 것"이 아닙니다.
> **처음 코드 작성 시부터 아래 3가지를 반드시 대응해야 합니다.**
> 나중에 고치면 배포된 사용자 쿠키 전체 무효화(강제 로그아웃) 또는 서비스 장애가 발생합니다.

### 1. Data Protection 키 공유 (Cookie 인증 필수)

HttpOnly Cookie 방식에서 **기본 설정은 인스턴스별로 암호화 키가 다릅니다.**
서버를 2대 이상으로 늘리는 순간 인스턴스 A가 만든 쿠키를 인스턴스 B가 복호화하지 못해 **랜덤하게 401 인증 오류** 발생:

```csharp
// ❌ WRONG: 기본 설정 — 서버 1대만 작동
builder.Services.AddDataProtection();

// ✅ CORRECT: 처음부터 Azure Blob에 키 공유
// (서버 1대여도 동일하게 작동, 나중에 코드 변경 불필요)
builder.Services.AddDataProtection()
    .PersistKeysToAzureBlobStorage(
        new Uri(configuration["Azure:DataProtectionBlobUri"]!))
    .ProtectKeysWithAzureKeyVault(
        new Uri(configuration["Azure:DataProtectionKeyId"]!),
        new DefaultAzureCredential());
```

### 2. ARR Affinity(세션 선호도) — Azure Portal 설정

Blazor Auto는 Server 모드 시작 시 SignalR 연결을 사용합니다.
로드밸런서가 같은 유저를 다른 서버로 보내면 **Blazor Circuit이 끊겨 화면이 흰 화면 또는 연결 오류** 발생:

```
설정 위치: Azure App Service → 구성 → 일반 설정 → ARR 선호도 → 켜기
```

| 모드 | Sticky Session 필요 여부 |
|:-----|:------------------------|
| Blazor Server 렌더링 중 | ✅ 반드시 필요 |
| WASM으로 전환 완료 후 | 불필요 (브라우저가 직접 API 호출) |
| .NET API (순수 REST) | 불필요 |

> Azure App Service의 ARR Affinity는 쿠키(`ARRAffinity`) 기반으로 동작합니다.

### 3. Connection Pool 계산 (Supabase 연결 한도)

인스턴스가 늘어나면 **총 DB 연결 수 = 인스턴스 수 × 풀 크기**:

```
인스턴스 3대 × Maximum Pool Size 20 = 최대 60 연결
Supabase Free   : 60 연결 한도  → 인스턴스 3대에서 포화
Supabase Pro    : 200 연결 한도 → 인스턴스 10대까지 여유
```

Scale Out 전 `Maximum Pool Size`를 조정하거나 Supabase 플랜 업그레이드 계획 수립 필요:

```csharp
// appsettings.Production.json
"ConnectionStrings": {
  "DefaultConnection": "...;Maximum Pool Size=15;" // 인스턴스 수 고려해서 조정
}
```

### Scale Out 전 체크리스트

- [ ] `AddDataProtection()` → Azure Blob + Key Vault 키 공유 설정 확인
- [ ] Azure Portal: ARR Affinity **켜기** 확인
- [ ] `인스턴스 수 × Pool Size ≤ Supabase 연결 한도` 계산 확인
- [ ] Health Check `/health` 엔드포인트 응답 확인 (Azure가 자동으로 비정상 인스턴스 교체)

