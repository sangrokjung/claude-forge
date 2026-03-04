#!/bin/bash
set -e

echo "Setting up Claude Forge .NET dev environment..."

# Install Claude Code CLI
if ! command -v claude >/dev/null 2>&1; then
    echo "Installing Claude Code..."
    npm install -g @anthropic-ai/claude-code
fi

# .NET: restore & build if solution exists
if ls *.sln 2>/dev/null | grep -q .; then
    echo "Found .NET solution — restoring packages..."
    dotnet restore
    dotnet build --no-restore -c Debug
fi

# .NET tool: EF Core CLI
if ! dotnet tool list -g | grep -q "dotnet-ef"; then
    echo "Installing dotnet-ef..."
    dotnet tool install --global dotnet-ef
fi

# Node 패키지 (Tailwind 등)
if [ -f "package.json" ]; then
    echo "Installing Node dependencies..."
    npm install
fi

# Playwright (E2E 테스트)
if grep -q "playwright" package.json 2>/dev/null || \
   find . -name "*.csproj" -exec grep -l "Playwright" {} \; 2>/dev/null | grep -q .; then
    echo "Installing Playwright browsers..."
    npx playwright install --with-deps chromium
fi

echo ""
echo "Dev environment ready!"
echo "  dotnet build    — 빌드"
echo "  dotnet test     — 테스트"
echo "  claude          — Claude Code 시작"
