#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Claude Code Config Installer for Windows
    Claude Code 설정 파일 설치 스크립트 (Windows용)
.DESCRIPTION
    Windows(네이티브 또는 WSL2)에 Claude Code 설정을 설치합니다.
    agents, rules, commands, skills, settings 파일을 ~/.claude/에 복사합니다.

    -Upgrade : 기존 설치를 v3.0으로 업그레이드 (심볼릭/복사 대상 갱신 + 안내 출력)
    -DryRun  : 실제 파일 변경 없이 수행 예정 작업만 출력
.NOTES
    관리자 권한 필요: PowerShell 우클릭 -> 관리자 권한으로 실행
    Run as Administrator: Right-click PowerShell -> Run as Administrator
#>

param(
    [switch]$Upgrade,
    [switch]$DryRun,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

$RepoDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ClaudeDir = Join-Path $env:USERPROFILE ".claude"
$IsWSL = $false

if ($Help) {
    Write-Host "Usage: install.ps1 [-Upgrade] [-DryRun] [-Help]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Upgrade   Upgrade existing installation to v3.0"
    Write-Host "  -DryRun    Preview changes without modifying files"
    Write-Host "  -Help      Show this help message"
    Write-Host ""
    Write-Host "v3.0 Breaking Changes (see docs/MIGRATION.md):"
    Write-Host "  - MCP servers: 6 -> 3 (playwright, context7, jina-reader)"
    Write-Host "  - Hooks: 5 events -> 21 (opt-in via hooks/examples/)"
    Write-Host "  - Subagent frontmatter: v2 optional fields"
    Write-Host "  - Skills/Commands: hybrid policy (docs/SKILLS-VS-COMMANDS.md)"
    exit 0
}

function Write-UpgradeBanner {
    Write-Host "=========================================="
    Write-Host "  claude-forge v3.0 Upgrade"
    Write-Host "=========================================="
    Write-Host ""
    Write-Host "  Breaking changes since v2.1:"
    Write-Host "  - MCP: 6 servers -> 3 (playwright, context7, jina-reader)"
    Write-Host "    - Removed: memory, exa, github, fetch"
    Write-Host "    - Recipes: docs/MCP-MIGRATION.md"
    Write-Host "  - Hooks: 5 events -> 21 (opt-in via hooks/examples/)"
    Write-Host "  - Subagent frontmatter: v2 optional fields"
    Write-Host "  - Skills/Commands: hybrid policy (docs/SKILLS-VS-COMMANDS.md)"
    Write-Host ""
    if ($DryRun) {
        Write-Host "  [DRY-RUN] No files will be modified." -ForegroundColor Yellow
        Write-Host ""
    }
}

function Write-UpgradeSummary {
    Write-Host ""
    Write-Host "=========================================="
    Write-Host "  Upgrade Summary"
    Write-Host "=========================================="
    Write-Host "  Version       : v3.0.0"
    $modeLabel = if ($DryRun) { 'dry-run' } else { 'applied' }
    Write-Host "  Mode          : $modeLabel"
    Write-Host "  Repo          : $RepoDir"
    Write-Host "  Target        : $ClaudeDir"
    Write-Host ""
    Write-Host "  Expected counts:"
    Write-Host "    - 11 agents, 15 skills, 40 commands, 9+ rules, 17+ hooks"
    Write-Host ""
    Write-Host "  Next steps:"
    Write-Host "    1. Review docs/MIGRATION.md for detailed changes"
    Write-Host "    2. Opt-in new hooks from hooks/examples/ as needed"
    Write-Host "    3. Run 'claude mcp list' to verify 3 MCP servers"
    Write-Host ""
}

function Test-McpV3 {
    $mcpJson = Join-Path $RepoDir "mcp-servers.json"
    if (-not (Test-Path $mcpJson)) { return }

    Write-Host ""
    Write-Host "Validating mcp-servers.json (v3.0 minimal profile)..."
    try {
        $json = Get-Content $mcpJson -Raw | ConvertFrom-Json
    } catch {
        Write-Host "  [!] Unable to parse mcp-servers.json" -ForegroundColor Yellow
        return
    }

    $expected = @('playwright', 'context7', 'jina-reader')
    $missing = @()
    foreach ($name in $expected) {
        $inServers = $false
        $inInstallCmds = $false
        if ($json.PSObject.Properties.Name -contains 'servers' -and $json.servers.PSObject.Properties.Name -contains $name) {
            $inServers = $true
        }
        if ($json.PSObject.Properties.Name -contains 'install_commands' -and $json.install_commands.PSObject.Properties.Name -contains $name) {
            $inInstallCmds = $true
        }
        if (-not ($inServers -or $inInstallCmds)) { $missing += $name }
    }

    $total = 0
    if ($json.PSObject.Properties.Name -contains 'servers') {
        $total = @($json.servers.PSObject.Properties).Count
    }

    if ($missing.Count -eq 0) {
        Write-Host "  [OK] v3.0 core MCP entries present (3/3, total=$total)" -ForegroundColor Green
    } else {
        Write-Host "  [!] Missing v3.0 MCP entries: $($missing -join ', ')" -ForegroundColor Yellow
        Write-Host "      See docs/MCP-MIGRATION.md for remediation."
    }
}

function New-V3CompatLinks {
    Write-Host ""
    Write-Host "Creating v3.0 compat links..."
    # v2.1 path -> v3.0 path mappings
    $mappings = @(
        @{ Old = 'commands/debugging-strategies'; New = 'skills/debugging-strategies' }
    )
    $created = 0
    foreach ($m in $mappings) {
        $newTarget = Join-Path $RepoDir $m.New
        $oldLink = Join-Path $ClaudeDir $m.Old
        if ((Test-Path $newTarget) -and (-not (Test-Path $oldLink))) {
            if ($DryRun) {
                Write-Host "  [DRY-RUN] would create compat link: $($m.Old) -> $($m.New)"
            } else {
                $parent = Split-Path -Parent $oldLink
                if (-not (Test-Path $parent)) {
                    New-Item -ItemType Directory -Path $parent -Force | Out-Null
                }
                try {
                    Copy-Item -Path $newTarget -Destination $oldLink -Recurse -ErrorAction Stop
                    Write-Host "  [OK] compat link: $($m.Old) -> $($m.New)" -ForegroundColor Green
                    $created++
                } catch {
                    # non-fatal
                }
            }
        }
    }
    if ($created -eq 0 -and (-not $DryRun)) {
        Write-Host "  (no compat links needed)"
    }
}

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

        # Upgrade mode: preserve in place, refresh targets
        if ($Upgrade) {
            Write-Host "  Upgrade mode: preserving $ClaudeDir (targets will be refreshed)." -ForegroundColor Gray
            return
        }

        $reply = Read-Host "백업할까요? $backupDir (y/n)"
        if ($reply -eq "y") {
            if ($DryRun) {
                Write-Host "  [DRY-RUN] would move $ClaudeDir -> $backupDir" -ForegroundColor Yellow
            } else {
                Move-Item $ClaudeDir $backupDir
                Write-Host "[OK] 백업 완료: $backupDir (Backup created)" -ForegroundColor Green
            }
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

    if ($DryRun) {
        Write-Host "  [DRY-RUN] would ensure $ClaudeDir exists" -ForegroundColor Yellow
    } elseif (-not (Test-Path $ClaudeDir)) {
        New-Item -ItemType Directory -Path $ClaudeDir -Force | Out-Null
    }

    $directories = @("agents", "rules", "commands", "skills", "hooks", "cc-chips")
    foreach ($dir in $directories) {
        $source = Join-Path $RepoDir $dir
        if (Test-Path $source) {
            $dest = Join-Path $ClaudeDir $dir
            if ($DryRun) {
                Write-Host "  [DRY-RUN] would refresh $dir/" -ForegroundColor Yellow
                continue
            }
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
            if ($DryRun) {
                Write-Host "  [DRY-RUN] would refresh $file" -ForegroundColor Yellow
                continue
            }
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
    if ($Upgrade) { Write-UpgradeBanner }

    Test-Dependencies
    Backup-ExistingConfig
    Copy-ConfigFiles
    Test-McpV3

    if ($Upgrade) { New-V3CompatLinks }

    if ($DryRun) {
        Write-Host ""
        Write-Host "[DRY-RUN] Skipping verify/MCP install." -ForegroundColor Yellow
        if ($Upgrade) { Write-UpgradeSummary }
        return
    }

    $errors = Test-Installation
    if ($errors -eq 0) {
        Install-McpServers

        if ($Upgrade) { Write-UpgradeSummary }

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
