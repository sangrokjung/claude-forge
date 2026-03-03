# Testing: .NET 10 + xUnit (TDD 필수)

## TDD 워크플로우 (절대 예외 없음)

```
1. RED   → 실패하는 테스트 먼저 작성
2. GREEN → 테스트를 통과하는 최소 구현
3. IMPROVE → 리팩토링 (테스트는 여전히 통과해야 함)
```

**금지**: 구현 코드 작성 후 테스트 추가. 반드시 테스트가 먼저.

## 테스트 파일 경로

```
tests/
├── Domain.Tests/           # Unit Tests — 순수 도메인 로직
│   └── **/*.Tests.cs
├── Application.Tests/      # Unit Tests — UseCase, Mock 사용
│   └── **/*.Tests.cs
├── Infrastructure.Tests/   # Integration Tests — Testcontainers
│   └── **/*.Tests.cs
├── Api.Tests/              # Integration Tests — WebApplicationFactory
│   └── **/*.Tests.cs
└── Architecture.Tests/     # Architecture Tests — 레이어 의존성 검증
    └── *.Tests.cs
```

## 테스트 피라미드 (비율 준수)

```
         E2E (Playwright for .NET)
        ▲ 적음 — 핵심 사용자 시나리오만
       ▲▲▲
      ▲▲▲▲▲ Integration Tests (Testcontainers)
     ▲▲▲▲▲▲▲
    ▲▲▲▲▲▲▲▲▲ Unit Tests (많음 — 도메인, 유즈케이스)
```

역피라미드 금지: Unit 없이 Integration만 짜면 느리고 취약함.

## Unit Test 작성 기준 (xUnit + Moq + FluentAssertions)

```csharp
public class OrderTests
{
    [Fact]
    public void Complete_WhenStatusIsPending_ShouldChangeStatusToCompleted()
    {
        // Arrange
        var order = new Order(Guid.NewGuid(), OrderStatus.Pending);

        // Act
        order.Complete();

        // Assert
        order.Status.Should().Be(OrderStatus.Completed);
    }

    [Fact]
    public void Complete_WhenStatusIsNotPending_ShouldThrowDomainException()
    {
        // Arrange
        var order = new Order(Guid.NewGuid(), OrderStatus.Completed);

        // Act
        var act = () => order.Complete();

        // Assert
        act.Should().Throw<DomainException>();
    }
}
```

## Integration Test 환경 선택 기준

| 테스트 대상 | 환경 | 이유 |
|:-----------|:-----|:-----|
| Repository, EF Core 쿼리 (RLS 없음) | **Testcontainers** (plain PostgreSQL) | 빠름, 격리 보장 |
| RLS 정책, `auth.uid()` 함수 포함 로직 | **Supabase 테스트 프로젝트** | `auth.uid()` 등 Supabase 전용 함수 필요 |
| SP / Trigger 검증 | **Testcontainers** (EF Core Migration 자동 적용) | SP/Trigger는 Migration에 포함됨 |

> ⚠️ 일반 PostgreSQL 컨테이너에는 `auth.uid()`, `auth.jwt()` 함수가 없음 — RLS 정책 테스트 불가

### Supabase 테스트 프로젝트 설정

```json
// appsettings.Test.json (git-ignored)
{
  "Supabase": {
    "Url": "https://xxxx.supabase.co",  // 전용 테스트 프로젝트
    "ServiceKey": "..."                  // User Secrets 또는 CI Secret
  }
}
```

**테스트 격리 정책**: 각 테스트 클래스는 `IAsyncLifetime`으로 테스트 전 데이터 시딩, 테스트 후 롤백.

## Integration Test: Testcontainers (RLS 없는 테스트)

In-Memory DB는 SP/Trigger를 지원하지 않으므로 **Testcontainers로 실제 PostgreSQL** 사용:

```csharp
public class OrderRepositoryTests : IAsyncLifetime
{
    private readonly PostgreSqlContainer _postgres = new PostgreSqlBuilder()
        .WithImage("postgres:16")
        .Build();

    public async Task InitializeAsync()
    {
        await _postgres.StartAsync();
        // EF Core 마이그레이션 자동 적용 (SP, Trigger 포함)
        using var context = CreateContext();
        await context.Database.MigrateAsync();
    }

    [Fact]
    public async Task CreateOrder_ShouldSetAuditColumnsViaTrigger()
    {
        using var context = CreateContext();
        var order = new Order(...);
        context.Orders.Add(order);
        await context.SaveChangesAsync();

        var saved = await context.Orders.FindAsync(order.Id);
        saved!.CreatedAt.Should().BeCloseTo(DateTimeOffset.UtcNow, TimeSpan.FromSeconds(5));
    }

    public async Task DisposeAsync() => await _postgres.DisposeAsync();
}
```

## Architecture Test (레이어 의존성 자동 검증)

```csharp
// Architecture.Tests/LayerDependencyTests.cs
public class LayerDependencyTests
{
    [Fact]
    public void Domain_ShouldNotDependOnApplication()
    {
        var result = Types.InAssembly(DomainAssembly)
            .ShouldNot().HaveDependencyOn(ApplicationAssembly.FullName)
            .GetResult();

        result.IsSuccessful.Should().BeTrue();
    }

    [Fact]
    public void Domain_ShouldNotDependOnInfrastructure()
    {
        var result = Types.InAssembly(DomainAssembly)
            .ShouldNot().HaveDependencyOn(InfrastructureAssembly.FullName)
            .GetResult();

        result.IsSuccessful.Should().BeTrue();
    }
}
```

## 테스트 커버리지 기준

- **Domain**: 90% 이상 (핵심 비즈니스 로직)
- **Application**: 80% 이상
- **Infrastructure**: 70% 이상 (Testcontainers Integration)
- **전체**: 80% 이상

```bash
# 커버리지 측정
dotnet test --collect:"XPlat Code Coverage"
reportgenerator -reports:"**/coverage.cobertura.xml" -targetdir:"coverage" -reporttypes:Html
```

## 테스트 빌드 명령

```bash
dotnet test                          # 전체 테스트
dotnet test --filter "Category=Unit" # Unit 테스트만
dotnet test --filter "Category=Integration" # Integration 테스트만
```

`--filter "Category=Unit"` 동작 조건: 테스트 클래스 또는 메서드에 **`[Trait]` 어노테이션**이 있어야 합니다:

```csharp
[Trait("Category", "Unit")]
public class OrderTests
{
    [Fact]
    public void Complete_WhenStatusIsPending_ShouldChangeStatusToCompleted() { ... }
}

[Trait("Category", "Integration")]
public class OrderRepositoryTests : IAsyncLifetime
{
    [Fact]
    public async Task CreateOrder_ShouldSetAuditColumnsViaTrigger() { ... }
}
```
