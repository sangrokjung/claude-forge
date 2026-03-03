# Frontend: Blazor Auto (.NET 10)

## 절대 원칙: 직접 DB 접근 금지

Blazor 컴포넌트는 **절대 Supabase에 직접 접근하지 않습니다.**
모든 데이터는 반드시 .NET API 엔드포인트를 통해서만 접근:

```csharp
// WRONG: Supabase 클라이언트 직접 호출
var orders = await supabaseClient.From<Order>().Get(); // ❌

// CORRECT: API 클라이언트 통해 접근
var orders = await orderApiClient.GetOrdersAsync(); // ✅
```

## .NET Aspire AppHost 통합 설정

**TailwindCSS v4는 AppHost에서 백엔드보다 먼저 실행합니다:**

```csharp
// AppHost/Program.cs
// 1. TailwindCSS Watch 모드 (가장 먼저 실행)
var webProjectDir = Path.Combine(builder.AppHostDirectory, "..", "Solution.Web");
builder.AddExecutable("tailwindcss", "npx", webProjectDir,
    "@tailwindcss/cli",
    "-i", "./wwwroot/css/app.css",
    "-o", "./wwwroot/css/tailwindcss.css",
    "--watch");

// 2. API 백엔드
var api = builder.AddProject<Projects.Solution_Api>("api");

// 3. Blazor 프론트엔드 (마지막)
builder.AddProject<Projects.Solution_Web>("web")
    .WithReference(api);
```

`tailwindcss.css`는 `.gitignore`에 추가 (빌드 산출물).

## HttpClient: SSR/WASM 이중 설정

Aspire 서비스 디스커버리를 활용, URL 하드코딩 금지:

```csharp
// Server 프로젝트 Program.cs — Aspire 서비스 디스커버리
builder.Services.AddHttpClient("ApiClient",
    client => client.BaseAddress = new Uri("http://api"));

// WASM 프로젝트 Program.cs — 브라우저 Base URL 사용
builder.Services.AddHttpClient("ApiClient",
    client => client.BaseAddress = new Uri(builder.HostEnvironment.BaseAddress));
```

컴포넌트는 `IApiClient` 인터페이스만 사용 — SSR/WASM 구분 코드 금지.

## API 클라이언트 자동 생성 (OpenAPI 기반)

`Api` 프로젝트의 Swagger 스펙에서 타입 안전한 클라이언트 자동 생성:

```bash
# NSwag 또는 Kiota로 클라이언트 생성
dotnet tool install --global NSwag.ConsoleCore
nswag openapi2csclient \
  /input:https://localhost:7000/swagger/v1/swagger.json \
  /output:src/Web/ApiClients/GeneratedApiClient.cs
```

수동 HTTP 클라이언트 작성 금지 — 항상 생성된 클라이언트 사용.

## 공통 컴포넌트 라이브러리화 (필수)

3개 이상 위치에서 사용되는 컴포넌트는 즉시 공통 라이브러리로 이동:

```
src/
├── Web/                     # Blazor 앱
│   └── Pages/
└── Web.Components/          # 공통 컴포넌트 라이브러리 (Razor Class Library)
    ├── Buttons/
    ├── Forms/
    ├── Layouts/
    ├── Modals/
    └── Tables/
```

## EditForm: FormName 필수

**모든 EditForm에 `FormName` 없으면 SSR POST 바인딩 실패.** 나중에 추가 불가능:

```razor
@* WRONG *@
<EditForm Model="model" OnValidSubmit="HandleSubmit"> @* ❌ *@

@* CORRECT *@
<EditForm Model="model" FormName="create-order" OnValidSubmit="HandleSubmit"> @* ✅ *@
    <DataAnnotationsValidator />
    <ValidationSummary />
</EditForm>
```

## 메모리 관리 (필수)

Blazor Server 모드는 컴포넌트 인스턴스를 서버 메모리에 유지. 대용량 데이터 컴포넌트 상태 저장 금지:

```csharp
// ❌ WRONG: 페이지 전체 데이터를 컴포넌트 상태로 저장
private List<Order> _allOrders = new(); // 10만 건이면?

// ✅ CORRECT: 페이지에 필요한 데이터만 유지, 나머지는 서비스에서 쿼리
private List<OrderSummaryDto> _pagedOrders = new();
```

`IDisposable` / `IAsyncDisposable` 반드시 구현 — 이벤트, 타이머, 구독 해제:

```csharp
@implements IAsyncDisposable

@code {
    public async ValueTask DisposeAsync()
    {
        // 이벤트, 타이머, 구독 해제 필수
        await _hubConnection.DisposeAsync();
    }
}
```

## JS Interop 규칙 (localStorage, 사용자 설정 저장)

**JS Interop은 `OnAfterRenderAsync` 이후에만 호출.** SSR 렌더링 중 호출하면 런타임 에러:

```csharp
// ❌ WRONG: OnInitializedAsync에서 JS 호출 — SSR에서 연동 단절
protected override async Task OnInitializedAsync()
    => gridSettings = await JS.InvokeAsync<GridSettings>("localStorage.getItem", "grid");

// ✅ CORRECT: OnAfterRenderAsync에서만
protected override async Task OnAfterRenderAsync(bool firstRender)
{
    if (firstRender)
        gridSettings = await BrowserStorage.GetAsync<GridSettings>("grid-orders");
}
```

SSR 안전 래퍼 서비스 인터페이스 사용:

```csharp
public interface IBrowserStorageService
{
    ValueTask<T?> GetAsync<T>(string key);  // SSR 중엔 default 반환
    ValueTask SetAsync<T>(string key, T value);
}
```

### 그리드/드래그앤드롭 사용자 설정 저장 (필수)

그리드, 드래그앤드롭, 컬럼 순서 등 UI 커스터마이징은 **반드시 사용자별로 저장하고 복원**:

> ⚠️ **적용 범위**: 민감하지 않은 UI 설정(그리드 컬럼 순서, 테마, 정렬 기준 등)에만 사용.  
> 인증 토큰, 개인 식별 정보(PII), API Key 는 localStorage 저장 **절대 금지** — HttpOnly Cookie 또는 서버 세션 사용.

- 키 네이밍: `grid-{component-name}`, `dnd-{component-name}` 형식
- 저장 시점: UI 변경 즉시 (디바운스 없이)
- 로그아웃 후에도 유지 (localStorage는 만료 없음) — **UI 개인화 설정에만 해당**
- SSR 첫 렌더링: 기본값 사용 → `OnAfterRenderAsync` 후 localStorage 값으로 업데이트

## Blazor Auto 렌더링 모드 기준

| 상황 | 렌더링 모드 |
|:-----|:-----------|
| 초기 페이지 로드 (SEO 필요) | Static SSR |
| 인증 후 대시보드 (상호작용 많음) | Server 또는 Auto |
| 오프라인 가능해야 하는 기능 | WebAssembly |
| 기본값 | Auto (서버로 시작 → WASM으로 전환) |

```razor
@* 페이지 수준 렌더링 모드 명시 *@
@rendermode InteractiveAuto
```

## 에러 처리

```razor
@* 전역 에러 바운더리 *@
<ErrorBoundary>
    <ChildContent>@Body</ChildContent>
    <ErrorContent Context="ex">
        <ErrorDisplay Exception="ex" />
    </ErrorContent>
</ErrorBoundary>
```

## 환경 설정 관리

```json
// wwwroot/appsettings.json (공개 설정만 — API URL 등)
{
  "ApiBaseUrl": "https://api.your-domain.com"
}
// 절대 포함 금지: API Key, Secret, Connection String
```

Azure App Service 배포 시 환경변수는 Azure Portal의 Application Settings에서 관리.
