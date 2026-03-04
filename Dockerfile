# =============================================================
# Claude Forge — Universal Dockerfile
# Azure App Service / Self-hosted Docker 양쪽에서 동일하게 사용
# =============================================================

# ── 1단계: 빌드 ──────────────────────────────────────────────
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# NuGet 복원 (레이어 캐시 활용)
COPY *.sln* ./
COPY src/*/*.csproj ./
RUN find . -name "*.csproj" | while read f; do \
      dir=$(dirname "$f"); \
      mkdir -p "src/$dir" && mv "$f" "src/$dir/"; \
    done
RUN dotnet restore

# 전체 소스 복사 후 빌드
COPY . .
RUN dotnet publish src/Web/*.csproj \
      -c Release \
      -o /publish \
      --no-restore

# ── 2단계: 런타임 ─────────────────────────────────────────────
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app

# 타임존 설정 (한국)
ENV TZ=Asia/Seoul
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# curl 설치 (헬스체크용)
RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

# 빌드 아티팩트 복사
COPY --from=build /publish .

# 환경 변수 기본값
ENV ASPNETCORE_URLS=http://+:8080
ENV ASPNETCORE_ENVIRONMENT=Production

# 헬스체크 — Azure App Service & Docker 공통
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

EXPOSE 8080

ENTRYPOINT ["dotnet", "Web.dll"]
