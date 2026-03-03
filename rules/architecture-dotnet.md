# Architecture: .NET 10 Clean Architecture

## 레이어 구조 (의존성 방향: 안쪽으로만)

```
Presentation (API / Blazor)
    ↓
Application (UseCase, CQRS, Interfaces)
    ↓
Domain (Entity, ValueObject, DomainEvent)
    ↑
Infrastructure (EF Core, Supabase, External Services)
```

**절대 금지**: 하위 레이어가 상위 레이어를 참조하는 역방향 의존성

## 프로젝트 구조

```
Solution.sln
├── src/
│   ├── Domain/                  # 순수 도메인 로직 (외부 참조 없음)
│   ├── Application/             # UseCase, CQRS, Interfaces
│   ├── Infrastructure/          # EF Core, Supabase, 외부 서비스
│   ├── Api/                     # .NET 10 Web API (Swagger)
│   └── Web/                     # Blazor Auto (.NET 10)
├── tests/
│   ├── Domain.Tests/            # Unit — Testcontainers 불필요
│   ├── Application.Tests/       # Unit — Mock 사용
│   ├── Infrastructure.Tests/    # Integration — Testcontainers (RLS 없는 테스트)
│   │                            # RLS 포함 테스트 → Supabase 테스트 프로젝트 사용
│   ├── Api.Tests/               # Integration — WebApplicationFactory
│   └── Architecture.Tests/      # 레이어 의존성 자동 검증
└── shared/
    └── Contracts/               # API DTO, 공유 상수
```

## CQRS (MediatR 사용)

모든 UseCase는 Command 또는 Query로 분리:

```csharp
// Command: 상태 변경 (Create, Update, Delete)
public record CreateOrderCommand(Guid CustomerId, List<OrderItem> Items) : IRequest<Result<Guid>>;

// Query: 조회 전용 (side-effect 없음)
public record GetOrderQuery(Guid OrderId) : IRequest<Result<OrderDto>>;
```

**규칙**:
- Command Handler는 Domain Event 발행 가능
- Query Handler는 읽기 전용, 절대 상태 변경 없음
- Handler 당 파일 1개 (SRP)

## Result 패턴 (Exception 남용 금지)

비즈니스 오류는 예외가 아닌 Result 타입으로 처리:

```csharp
// WRONG: 비즈니스 로직에 Exception 使用
throw new Exception("재고 부족");

// CORRECT: Result 패턴
public Result<Order> PlaceOrder()
{
    if (!HasStock()) return Result.Failure<Order>("재고가 부족합니다.");
    return Result.Success(new Order(...));
}
```

Exception은 진짜 예외(네트워크 단절, DB 연결 실패 등)에만 사용.

## Swagger (API 문서화 필수)

- 모든 API Controller에 XML 주석 필수
- API 버전별 Swagger 문서 분리 (`/api/v1/...`, `/api/v2/...`)
- DTO에 `[Required]`, `[SwaggerSchema]` 어노테이션 명시
- `SwaggerUI`는 Development 환경에서만 활성화

```csharp
/// <summary>주문 생성</summary>
/// <param name="command">주문 생성 요청</param>
/// <returns>생성된 주문 ID</returns>
/// <response code="201">주문 생성 성공</response>
/// <response code="400">잘못된 요청 (유효성 검증 실패)</response>
[HttpPost]
[ProducesResponseType(typeof(Guid), 201)]
[ProducesResponseType(400)]
public async Task<IActionResult> CreateOrder([FromBody] CreateOrderCommand command) { ... }
```

## API 버전 관리

- URL 기반 버전: `/api/v1/orders`, `/api/v2/orders`
- 신규 엔드포인트는 최신 버전으로 추가
- 이전 버전은 최소 1 메이저 버전 유지 후 deprecated 처리

## API 에러 응답 표준 (Problem Details, RFC 7807)

모든 API 에러는 일관된 Problem Details 형식으로 반환:

```csharp
// Program.cs
builder.Services.AddProblemDetails();
app.UseExceptionHandler();
```

```json
// 클라이언트가 받는 에러 응답 형태
{
  "type": "https://tools.ietf.org/html/rfc7807",
  "title": "Validation Failed",
  "status": 400,
  "errors": { "Name": ["이름은 필수입니다."] }
}
```

Result 패턴과 연결:

```csharp
// Controller에서 Result → Problem Details 변환
public async Task<IActionResult> CreateOrder([FromBody] CreateOrderCommand cmd)
{
    var result = await _mediator.Send(cmd);
    return result.IsSuccess
        ? CreatedAtAction(nameof(GetOrder), new { id = result.Value }, result.Value)
        : Problem(detail: result.Error, statusCode: 400);
}
```

## .NET Aspire 서비스 디스커버리

서비스 간 URL 하드코딩 절대 금지:

```csharp
// WRONG
var apiUrl = "https://localhost:7001"; // ❌

// CORRECT — Aspire 서비스 디스커버리
// AppHost에 등록된 이름 "api"로 자동 해석
client.BaseAddress = new Uri("http://api"); // ✅
```

## Health Check (필수)

```csharp
// Program.cs
builder.Services.AddHealthChecks()
    .AddDbContextCheck<AppDbContext>()
    .AddUrlGroup(new Uri(supabaseUrl), "Supabase");

app.MapHealthChecks("/health");
app.MapHealthChecks("/health/ready", new HealthCheckOptions
{
    Predicate = check => check.Tags.Contains("ready")
});
```

## Azure 배포 (App Service)

- **백엔드**: Azure App Service (Linux, .NET 10)
- **프론트엔드 (Blazor Auto)**: Azure App Service 또는 Azure Static Web Apps
- **Secret 관리**: Azure Key Vault (절대 `appsettings.json`에 시크릿 직접 기입 금지)
- **환경 구분**: `ASPNETCORE_ENVIRONMENT` = Development / Staging / Production
- `appsettings.{Environment}.json` 파일로 환경별 설정 분리

## SP / Trigger 선택 기준 (장단점 제시 후 사용자 선택)

구현 방식이 DB 레벨(SP/Trigger)과 애플리케이션 레벨 중 선택이 필요할 때, Claude는 **반드시 아래 관점으로 장단점을 제시하고 사용자가 선택**하게 한다:

| 관점 | SP/Trigger | 애플리케이션 레벨 |
|:-----|:----------|:----------------|
| 성능 | 네트워크 왕복 절감, DB 내 처리 빠름 | ORM 최적화 가능, 캐싱 전략 자유도 높음 |
| 유연성 | DB 종속, 언어 제한 (PL/pgSQL) | 언어 자유, 단위 테스트 용이 |
| 확장성 | DB 서버 스케일업에 제한 | 앱 서버 수평 확장 자유 |
| 유지보수 | 버전관리 어려움, 디버깅 복잡 | 코드베이스에서 통합 관리 |
| 적합한 경우 | 복잡한 집계, Audit Trigger, 원자적 다중 테이블 처리 | 비즈니스 규칙, 외부 API 연동, 테스트 필요한 로직 |

**Claude 행동 규칙**: 선택을 강요하지 말 것. 트레이드오프를 설명하고 "어떤 방향으로 진행할까요?"로 마무리.
