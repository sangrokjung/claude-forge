# Coding Style: C# / .NET 10

## Nullable Reference Types (필수)

모든 프로젝트에서 nullable 활성화:

```xml
<!-- .csproj -->
<Nullable>enable</Nullable>
<TreatWarningsAsErrors>true</TreatWarningsAsErrors>
```

```csharp
// WRONG: nullable 무시
string name = null;

// CORRECT: 명시적 nullable
string? name = null;
string nonNullName = GetName() ?? throw new InvalidOperationException("Name required");
```

## 불변성 (Immutability)

상태 변경은 새 객체로, 원본 직접 수정 금지:

```csharp
// WRONG: 직접 변경
public void Update(string name) { this.Name = name; }

// CORRECT: record with 표현식
public record UserDto(Guid Id, string Name, string Email);
var updated = user with { Name = "홍길동" };
```

Domain Entity는 `private set` 또는 `init`으로 외부 변경 차단:

```csharp
public class Order
{
    public Guid Id { get; private set; }
    public OrderStatus Status { get; private set; }

    public void Complete() // 상태 변경은 도메인 메서드로만
    {
        if (Status != OrderStatus.Pending)
            throw new DomainException("완료할 수 없는 상태입니다.");
        Status = OrderStatus.Completed;
        AddDomainEvent(new OrderCompletedEvent(Id));
    }
}
```

## 로깅: Serilog + n8n Webhook (둘 다 사용)

### Serilog 설정 (Structured Logging 필수)

```csharp
// WRONG: Console.WriteLine, Debug.WriteLine 절대 사용 금지
Console.WriteLine("주문 생성: " + orderId);

// CORRECT: ILogger<T> + Structured Logging
private readonly ILogger<OrderService> _logger;

_logger.LogInformation("주문 생성 완료. {OrderId} {CustomerId}", orderId, customerId);
_logger.LogError(ex, "주문 생성 실패. {OrderId}", orderId);
```

### n8n Webhook 에러 알림 연동

Error/Critical 레벨 로그는 Serilog HTTP Sink → n8n Webhook으로 전송:

```json
// appsettings.json — Console, ApplicationInsights만 포함 (Http Sink는 여기 넣지 않음)
{
  "Serilog": {
    "WriteTo": [
      { "Name": "Console" },
      { "Name": "ApplicationInsights" }
    ]
  }
}
```

Http Sink는 **`appsettings.json`에 절대 포함하지 않습니다.**  
`ReadFrom.Configuration()`이 `requestUri: null`을 읽으면 런타임 크래시가 발생하고, 코드에서 중복 추가하면 Http Sink가 2개 등록됩니다.

대신 `Program.cs`에서 **URL 존재 여부를 확인 후 조건부로 추가**합니다:

```csharp
// Program.cs — Http Sink는 코드에서만, URL이 설정된 경우에만 추가
builder.Host.UseSerilog((ctx, services, lc) =>
{
    lc.ReadFrom.Configuration(ctx.Configuration) // Console + ApplicationInsights (json에서)
      .WriteTo.ApplicationInsights(
          services.GetRequiredService<TelemetryConfiguration>(),
          TelemetryConverter.Traces);

    // n8n Webhook URL이 설정된 환경에서만 활성화 (미설정 시 조용히 건너뜀)
    var webhookUrl = ctx.Configuration["Serilog:N8nWebhookUrl"];
    if (!string.IsNullOrEmpty(webhookUrl))
    {
        lc.WriteTo.Http(
            requestUri: webhookUrl,
            restrictedToMinimumLevel: LogEventLevel.Error);
    }
});
```

**로컬 개발**: `dotnet user-secrets set "Serilog:N8nWebhookUrl" "https://n8n.your-domain.com/webhook/..."`  
**프로덕션**: Azure Key Vault에 `Serilog--N8nWebhookUrl` Secret 등록  
**미설정 시**: Http Sink 자체가 등록되지 않으므로 크래시 없음 ✅


n8n Webhook payload에는 다음이 포함되어야 함:
- `Timestamp`, `Level`, `Message`, `Exception` (스택 트레이스 포함)
- `Environment` (dev/staging/prod), `Application`, `MachineName`
- 최소 Slack/Teams/이메일 알림 Workflow 트리거

## 파일 구조 기준

- 파일당 최대 **400줄** (초과 시 분리 필수)
- 메서드당 최대 **30줄** (단일 책임 원칙)
- 중첩 깊이 최대 **4단계** (초과 시 Early Return 또는 메서드 분리)
- 파일명 = 클래스명 (1파일 1클래스 원칙)

## 입력 검증: FluentValidation

```csharp
public class CreateOrderCommandValidator : AbstractValidator<CreateOrderCommand>
{
    public CreateOrderCommandValidator()
    {
        RuleFor(x => x.CustomerId).NotEmpty();
        RuleFor(x => x.Items).NotEmpty().WithMessage("주문 항목이 없습니다.");
        RuleFor(x => x.Items).Must(items => items.Count <= 100)
            .WithMessage("주문 항목은 100개를 초과할 수 없습니다.");
    }
}
```

시스템 경계(API 진입점)에서 **반드시** 검증. Domain 내부는 신뢰 영역.

## 코드 품질 체크리스트

작업 완료 선언 전 필수 확인:
- [ ] Nullable Reference Types 경고 없음
- [ ] `Console.WriteLine` / `Debug.WriteLine` 없음 — `ILogger<T>` 사용
- [ ] 하드코딩된 문자열/숫자 없음 (상수 또는 설정으로 분리)
- [ ] 메서드 30줄 이하
- [ ] 파일 400줄 이하
- [ ] `Result<T>` 패턴 사용 (비즈니스 오류를 Exception으로 throw하지 않음)
- [ ] XML 주석 완성 (API Controller, Public 메서드)
- [ ] 빌드 성공: `dotnet build` exit code 0
