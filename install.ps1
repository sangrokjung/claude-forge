#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Claude Code Config Installer for Windows
    Claude Code 설정 파일 설치 스크립트 (Windows용)
.DESCRIPTION
    Windows(네이티브 또는 WSL2)에 Claude Code 설정을 설치합니다.
    agents, rules, commands, skills, settings 파일을 ~/.claude/에 복사합니다.
.NOTES
    관리자 권한 필요: PowerShell 우클릭 -> 관리자 권한으로 실행
    Run as Administrator: Right-click PowerShell -> Run as Administrator
#>

$ErrorActionPreference = "Stop"

$RepoDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ClaudeDir = Join-Path $env:USERPROFILE ".claude"
$IsWSL = $false

# --------------------------------------------------
# 시작 안내
# --------------------------------------------------
Write-Host ""
Write-Host "   ╔═╗┬  ┌─┐┬ ┬┌┬┐┌─┐  ╔═╗┌─┐┬─┐┌─┐┌─┐" -ForegroundColor Cyan
Write-Host "   ║  │  ├─┤│ │ ││├┤   ╠╣ │ │├┬┘│ ┬├┤ " -ForegroundColor Cyan
Write-Host "   ╚═╝┴─┘┴ ┴└─┘─┴┘└─┘  ╚  └─┘┴└─└─┘└─┘" -ForegroundColor Cyan
Write-Host ""
Write-Host "   Production-grade Claude Code Framework" -ForegroundColor White
Write-Host "   github.com/sangrokjung/claude-forge" -ForegroundColor Gray
Write-Host ""

# --------------------------------------------------
# 관리자 권한 확인
# --------------------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "이 스크립트는 관리자 권한이 필요합니다." -ForegroundColor Red
    Write-Host ""
    Write-Host "실행 방법:" -ForegroundColor Yellow
    Write-Host "  Windows 11: 시작 버튼 우클릭 -> '터미널(관리자)' 선택"
    Write-Host "  Windows 10: 시작 메뉴에서 'PowerShell' 검색 -> 우클릭 -> '관리자 권한으로 실행'"
    Write-Host ""
    exit 1
}

# --------------------------------------------------
# 필수 프로그램 확인 (Checking dependencies)
# --------------------------------------------------
function Test-Dependencies {
    Write-Host "필수 프로그램 확인 중... (Checking dependencies)" -ForegroundColor White
    $missing = @()

    if (-not (Get-Command "node" -ErrorAction SilentlyContinue)) { $missing += "nodejs" }
    if (-not (Get-Command "git" -ErrorAction SilentlyContinue)) { $missing += "git" }

    # .NET SDK 확인 (선택적 — .NET 프로젝트 사용 시)
    if (-not (Get-Command "dotnet" -ErrorAction SilentlyContinue)) {
        Write-Host "[참고] .NET SDK가 설치되지 않았습니다. .NET 프로젝트 사용 시 필요합니다." -ForegroundColor Yellow
        Write-Host "       설치: winget install Microsoft.DotNet.SDK.10" -ForegroundColor Yellow
        Write-Host ""
    }
    else {
        $dotnetVersion = (dotnet --version 2>$null)
        Write-Host "[OK] .NET SDK 확인: $dotnetVersion" -ForegroundColor Green
    }

    if ($missing.Count -gt 0) {
        Write-Host "설치되지 않은 프로그램이 있습니다: $($missing -join ', ')" -ForegroundColor Red
        Write-Host ""
        Write-Host "아래 명령어로 설치하세요:" -ForegroundColor Yellow
        foreach ($dep in $missing) {
            Write-Host "  winget install $dep"
        }
        Write-Host ""
        Write-Host "설치 후 터미널을 재시작하고 이 스크립트를 다시 실행하세요." -ForegroundColor Yellow
        exit 1
    }

    Write-Host "[OK] 필수 프로그램 확인 완료 (All dependencies satisfied)" -ForegroundColor Green
}

# --------------------------------------------------
# 기존 설정 백업 (Backup existing config)
# --------------------------------------------------
function Backup-ExistingConfig {
    if (Test-Path $ClaudeDir) {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $backupDir = "$ClaudeDir.backup.$timestamp"
        Write-Host ""
        Write-Host "기존 ~/.claude 폴더가 발견되었습니다. (Existing config found)" -ForegroundColor Yellow
        $reply = Read-Host "백업할까요? $backupDir (y/n)"
        if ($reply -eq "y") {
            Move-Item $ClaudeDir $backupDir
            Write-Host "[OK] 백업 완료: $backupDir (Backup created)" -ForegroundColor Green
        }
        else {
            Write-Host "백업을 건너뜁니다. 기존 파일이 덮어쓰기될 수 있습니다." -ForegroundColor Yellow
        }
    }
}

# --------------------------------------------------
# 설정 파일 복사 (Copy config files)
# --------------------------------------------------
function Copy-ConfigFiles {
    Write-Host ""
    Write-Host "설정 파일 복사 중... (Copying configuration files)" -ForegroundColor White

    if (-not (Test-Path $ClaudeDir)) {
        New-Item -ItemType Directory -Path $ClaudeDir -Force | Out-Null
    }

    $directories = @("agents", "rules", "commands", "skills", "hooks", "cc-chips")
    foreach ($dir in $directories) {
        $source = Join-Path $RepoDir $dir
        if (Test-Path $source) {
            $dest = Join-Path $ClaudeDir $dir
            if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
            Copy-Item $source $dest -Recurse
            Write-Host "  [OK] $dir/ 복사 완료" -ForegroundColor Gray
        }
        else {
            Write-Host "  [건너뜀] $dir/ 폴더가 없습니다" -ForegroundColor Yellow
        }
    }

    $files = @("hooks.json", "settings.json")
    foreach ($file in $files) {
        $source = Join-Path $RepoDir $file
        if (Test-Path $source) {
            $dest = Join-Path $ClaudeDir $file
            Copy-Item $source $dest -Force
            Write-Host "  [OK] $file 복사 완료" -ForegroundColor Gray
        }
        else {
            Write-Host "  [건너뜀] $file 파일이 없습니다" -ForegroundColor Yellow
        }
    }
}

# --------------------------------------------------
# MCP 서버 설치 (Install MCP servers)
# --------------------------------------------------
function Install-McpServers {
    Write-Host ""
    Write-Host "MCP 서버 설치... (Installing MCP servers)" -ForegroundColor White

    if (-not (Get-Command "claude" -ErrorAction SilentlyContinue)) {
        Write-Host "[참고] Claude CLI를 찾을 수 없습니다. MCP 서버 설치를 건너뜁니다." -ForegroundColor Yellow
        Write-Host "       설치 방법: winget install Anthropic.ClaudeCode" -ForegroundColor Yellow
        return
    }

    $reply = Read-Host "권장 MCP 서버를 설치할까요? (y/n)"
    if ($reply -ne "y") {
        Write-Host "MCP 서버 설치를 건너뜁니다." -ForegroundColor Gray
        return
    }

    $coreServers = @(
        @{ Name = "context7"; Cmd = "claude mcp add context7 -- npx -y @upstash/context7-mcp" },
        @{ Name = "playwright"; Cmd = "claude mcp add playwright -- npx @playwright/mcp@latest" },
        @{ Name = "memory"; Cmd = "claude mcp add memory -- npx -y @modelcontextprotocol/server-memory" },
        @{ Name = "sequential-thinking"; Cmd = "claude mcp add sequential-thinking -- npx -y @modelcontextprotocol/server-sequential-thinking" }
    )

    foreach ($server in $coreServers) {
        Write-Host "  $($server.Name) 설치 중..."
        try {
            Invoke-Expression $server.Cmd 2>$null
            Write-Host "  [OK] $($server.Name) 설치 완료" -ForegroundColor Green
        }
        catch {
            Write-Host "  [참고] $($server.Name) - 이미 설치되었거나 설치에 실패했습니다" -ForegroundColor Yellow
        }
    }
}

# --------------------------------------------------
# 설치 확인 (Verify installation)
# --------------------------------------------------
function Test-Installation {
    Write-Host ""
    Write-Host "설치 확인 중... (Verifying installation)" -ForegroundColor White
    $errors = 0

    $items = @("agents", "rules", "commands", "skills", "cc-chips", "hooks.json", "settings.json")
    foreach ($item in $items) {
        $path = Join-Path $ClaudeDir $item
        if (Test-Path $path) {
            Write-Host "  [OK] $item" -ForegroundColor Green
        }
        else {
            Write-Host "  [실패] $item 이 없습니다" -ForegroundColor Red
            $errors++
        }
    }

    return $errors
}

# --------------------------------------------------
# Main
# --------------------------------------------------
function Main {
    Test-Dependencies
    Backup-ExistingConfig
    Copy-ConfigFiles

    $errors = Test-Installation
    if ($errors -eq 0) {
        Install-McpServers

        Write-Host ""
        Write-Host "  ╔══════════════════════════════════════════════════════╗" -ForegroundColor Green
        Write-Host "  ║           Claude Forge installed!                    ║" -ForegroundColor Green
        Write-Host "  ╠══════════════════════════════════════════════════════╣" -ForegroundColor Green
        Write-Host "  ║  11 agents · 36 commands · 6-layer security         ║" -ForegroundColor Green
        Write-Host "  ╚══════════════════════════════════════════════════════╝" -ForegroundColor Green
        Write-Host ""
        Write-Host "  Next steps:" -ForegroundColor Cyan
        Write-Host "    1. Open a new terminal"
        Write-Host "    2. Run 'claude' to start"
        Write-Host "    3. Run 'claude mcp list' to verify MCP servers"
        Write-Host ""
        Write-Host "  ★ Star us if this helped: github.com/sangrokjung/claude-forge" -ForegroundColor Yellow
        Write-Host "  ? Issues: github.com/sangrokjung/claude-forge/issues" -ForegroundColor Yellow
    }
    else {
        Write-Host ""
        Write-Host "설치가 완료되었지만 $errors 개의 오류가 있습니다." -ForegroundColor Red
        Write-Host "위의 [실패] 항목을 확인하세요." -ForegroundColor Yellow
        exit 1
    }
}

Main
