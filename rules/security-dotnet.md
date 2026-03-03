# Security: .NET 10 + Supabase Auth

## 인증 흐름: JWT → HttpOnly Cookie

**JWT를 localStorage에 저장 금지** (XSS 취약점). **HttpOnly Cookie 방식** 사용:

```
① Blazor → .NET API /auth/login 호출
② .NET API → Supabase Auth로 로그인 요청
③ Supabase가 JWT 발급 → .NET API가 HttpOnly Cookie로 설정
④ 이후 모든 요청: 브라우저가 Cookie 자동 전송
   - SSR 모드: 서버가 Cookie 자동 수신 ✅
   - WASM 모드: 브라우저가 Cookie 자동 전송 ✅
```

```csharp
// .NET API — 로그인 시 HttpOnly Cookie 설정
[HttpPost("login")]
public async Task<IActionResult> Login([FromBody] LoginRequest req)
{
    var session = await supabaseClient.Auth.SignIn(req.Email, req.Password);
    Response.Cookies.Append("auth-token", session.AccessToken, new CookieOptions
    {
        HttpOnly = true,    // JS 접근 불가 (XSS 방어)
        Secure = true,      // HTTPS에서만 전송
        SameSite = SameSiteMode.Strict,
        Expires = DateTimeOffset.UtcNow.AddHours(1)
    });
    return Ok();
}
```

```csharp
// Program.cs — Cookie에서 JWT 읽어 검증
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Authority = $"https://{supabaseProjectRef}.supabase.co/auth/v1";
        options.Audience = "authenticated";
        // Cookie에서 토큰 추출
        options.Events = new JwtBearerEvents
        {
            OnMessageReceived = ctx =>
            {
                ctx.Token = ctx.Request.Cookies["auth-token"];
                return Task.CompletedTask;
            }
        };
    });

app.UseAuthentication();
app.UseAuthorization();
```

**Blazor Auto는 절대 Supabase에 직접 JWT 요청하지 않음** — 반드시 .NET API를 통해 인증.

## Secret 관리

```csharp
// NEVER: appsettings.json에 시크릿 직접 기입
{
  "Supabase": {
    "ServiceKey": "eyJhbGciOiJ..." // ❌ 절대 금지
  }
}

// CORRECT: 환경별 Secret 관리
// - Development: User Secrets (dotnet user-secrets set "Supabase:ServiceKey" "...")
// - Staging/Production: Azure Key Vault
```

Azure Key Vault 연동:

```csharp
// Program.cs
if (!builder.Environment.IsDevelopment())
{
    builder.Configuration.AddAzureKeyVault(
        new Uri($"https://{keyVaultName}.vault.azure.net/"),
        new DefaultAzureCredential()
    );
}
```

## CORS 엄격 설정

```csharp
// WRONG: Wildcard 허용
app.UseCors(policy => policy.AllowAnyOrigin()); // ❌

// CORRECT: 명시적 Origin만 허용
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowedOrigins", policy =>
    {
        policy.WithOrigins(
                configuration["Cors:AllowedOrigins"]!.Split(','))
            .AllowAnyMethod()
            .AllowAnyHeader()
            .AllowCredentials();
    });
});
```

## HTTPS 강제

```csharp
// 개발 환경을 제외한 모든 환경에서 HTTPS 리다이렉트
if (!app.Environment.IsDevelopment())
{
    app.UseHttpsRedirection();
    app.UseHsts();
}
```

## 입력 검증 (FluentValidation + MediatR Pipeline)

```csharp
// ValidationBehavior: 모든 Command/Query 진입 전 자동 검증
// ValidationException은 아래 ExceptionHandler 미들웨어가 Problem Details로 변환
public class ValidationBehavior<TRequest, TResponse> : IPipelineBehavior<TRequest, TResponse>
{
    public async Task<TResponse> Handle(TRequest request, RequestHandlerDelegate<TResponse> next, CancellationToken ct)
    {
        var failures = _validators
            .Select(v => v.Validate(request))
            .SelectMany(r => r.Errors)
            .Where(f => f != null)
            .ToList();

        if (failures.Any())
            throw new ValidationException(failures);

        return await next();
    }
}
```

### ValidationException → Problem Details 변환 (필수)

`ValidationBehavior`가 throw한 `ValidationException`을 클라이언트가 받을 수 있는 **Problem Details (RFC 7807)** 형태로 변환해야 합니다.
`architecture-dotnet.md`의 Result 패턴 원칙에 따라 클라이언트는 항상 일관된 에러 포맷을 받아야 합니다:

```csharp
// Program.cs — ValidationException을 400 Problem Details로 변환
builder.Services.AddProblemDetails();

app.UseExceptionHandler(exceptionHandlerApp =>
{
    exceptionHandlerApp.Run(async context =>
    {
        var exception = context.Features.Get<IExceptionHandlerFeature>()?.Error;

        var (status, title, errors) = exception switch
        {
            ValidationException ve => (400, "Validation Failed",
                ve.Errors.GroupBy(e => e.PropertyName)
                         .ToDictionary(g => g.Key, g => g.Select(e => e.ErrorMessage).ToArray())),
            _ => (500, "Internal Server Error", (Dictionary<string, string[]>?)null)
        };

        context.Response.StatusCode = status;
        await Results.Problem(
            title: title,
            statusCode: status,
            extensions: errors is not null
                ? new Dictionary<string, object?> { ["errors"] = errors }
                : null
        ).ExecuteAsync(context);
    });
});

app.UseAuthentication();
app.UseAuthorization();
```

클라이언트가 받는 응답:
```json
{
  "title": "Validation Failed",
  "status": 400,
  "errors": {
    "CustomerId": ["고객 ID가 필요합니다."],
    "Items": ["주문 항목이 없습니다."]
  }
}
```

## 보안 체크리스트 (커밋 전 필수)

- [ ] `appsettings.json`에 시크릿 없음 (API Key, Password, Token)
- [ ] 모든 API 엔드포인트에 `[Authorize]` 또는 `[AllowAnonymous]` 명시
- [ ] SQL은 EF Core 또는 파라미터화 쿼리만 사용 (Raw string SQL 금지)
- [ ] 에러 응답에 스택 트레이스 미포함 (Production 환경)
- [ ] Rate Limiting 설정 확인
- [ ] CORS Origins가 wildcard `*` 아님
- [ ] `ValidationException` → Problem Details 변환 미들웨어 등록 확인 (`UseExceptionHandler`)
