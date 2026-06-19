<#
.SYNOPSIS
    Windows Team Member Onboarding Script
    Windows 팀원 온보딩 스크립트
.DESCRIPTION
    Windows PC를 Claude Code 개발 환경으로 설정합니다.
    필요한 도구 설치, SSH 키 생성, Mac 서버 접속을 설정합니다.
.PARAMETER MacServer
    Mac 서버의 Tailscale 호스트명 또는 IP (예: mac-mini.tailscale.com)
.PARAMETER Username
    Mac 서버의 SSH 사용자 이름
.EXAMPLE
    .\setup-windows.ps1 -MacServer "mac-mini" -Username "dev"
#>

param(
    [string]$MacServer = "",
    [string]$Username = ""
)

$ErrorActionPreference = "Stop"

# --------------------------------------------------
# 시작 안내
# --------------------------------------------------
Write-Host ""
Write-Host "Windows 팀원 온보딩 스크립트" -ForegroundColor Cyan
Write-Host "=============================" -ForegroundColor Cyan
Write-Host ""
Write-Host "이 스크립트는 Windows PC를 Claude Code 개발 환경으로 설정합니다."
Write-Host ""
Write-Host "설치할 프로그램:"
Write-Host "  - Claude Code (AI 코딩 도우미)"
Write-Host "  - VS Code (코드 편집기)"
Write-Host "  - Tailscale (팀 VPN)"
Write-Host "  - Git (소스코드 관리)"
Write-Host "  - Node.js (JavaScript 실행 환경)"
Write-Host ""
Write-Host "예상 소요 시간: 약 15-20분"
Write-Host "관리자 권한이 필요합니다."
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
    Write-Host "관리자 터미널에서 다시 실행해주세요." -ForegroundColor Red
    exit 1
}

# --------------------------------------------------
# winget 확인
# --------------------------------------------------
function Test-Winget {
    if (-not (Get-Command "winget" -ErrorAction SilentlyContinue)) {
        Write-Host "winget(앱 설치 관리자)을 찾을 수 없습니다." -ForegroundColor Red
        Write-Host ""
        Write-Host "해결 방법:" -ForegroundColor Yellow
        Write-Host "  1. Windows 10을 최신 버전으로 업데이트하세요"
        Write-Host "  2. 또는 Microsoft Store에서 '앱 설치 관리자'를 검색하여 설치하세요"
        Write-Host "  3. 설치 후 터미널을 다시 열고 이 스크립트를 실행하세요"
        Write-Host ""
        Write-Host "Microsoft Store 링크:" -ForegroundColor Yellow
        Write-Host "  https://aka.ms/getwinget"
        Write-Host ""
        exit 1
    }
    Write-Host "[OK] winget 확인됨" -ForegroundColor Green
}

# --------------------------------------------------
# Step 1: 핵심 도구 설치 (winget 사용)
# --------------------------------------------------
function Install-CoreTools {
    Write-Host ""
    Write-Host "[1/6] 핵심 도구 설치 중..." -ForegroundColor Cyan

    $tools = @(
        @{ Id = "Anthropic.ClaudeCode"; Name = "Claude Code (AI 코딩 도우미)" },
        @{ Id = "Microsoft.VisualStudioCode"; Name = "VS Code (코드 편집기)" },
        @{ Id = "Tailscale.Tailscale"; Name = "Tailscale (팀 VPN)" },
        @{ Id = "Git.Git"; Name = "Git (소스코드 관리)" },
        @{ Id = "OpenJS.NodeJS.LTS"; Name = "Node.js 22 LTS (JavaScript 실행 환경)" }
    )

    foreach ($tool in $tools) {
        $installed = winget list --id $tool.Id 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [OK] $($tool.Name) - 이미 설치됨" -ForegroundColor Gray
        }
        else {
            Write-Host "  [설치] $($tool.Name)..." -ForegroundColor Yellow
            winget install --id $tool.Id --accept-source-agreements --accept-package-agreements
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  [OK] $($tool.Name) 설치 완료" -ForegroundColor Green
            }
            else {
                Write-Host "  [실패] $($tool.Name) 설치에 문제가 있습니다." -ForegroundColor Red
                Write-Host "         수동 설치가 필요할 수 있습니다." -ForegroundColor Yellow
            }
        }
    }
}

# --------------------------------------------------
# Step 2: SSH 키 생성
# --------------------------------------------------
function New-SshKey {
    Write-Host ""
    Write-Host "[2/6] SSH 키 설정 (원격 접속용)..." -ForegroundColor Cyan

    $sshDir = Join-Path $env:USERPROFILE ".ssh"
    $keyPath = Join-Path $sshDir "id_ed25519"

    if (-not (Test-Path $sshDir)) {
        New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
    }

    if (Test-Path $keyPath) {
        Write-Host "  [OK] SSH 키가 이미 존재합니다: $keyPath" -ForegroundColor Gray
    }
    else {
        Write-Host ""
        Write-Host "  SSH 키는 비밀번호 대신 사용하는 안전한 접속 수단입니다." -ForegroundColor White
        $email = Read-Host "  이메일 주소를 입력하세요 (SSH 키 식별용)"
        ssh-keygen -t ed25519 -C $email -f $keyPath -N ""
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [OK] SSH 키 생성 완료" -ForegroundColor Green
        }
        else {
            Write-Host "  [실패] SSH 키 생성에 실패했습니다." -ForegroundColor Red
            Write-Host "         ssh-keygen이 설치되어 있는지 확인하세요." -ForegroundColor Yellow
            Write-Host "         Git을 설치한 후 터미널을 재시작하면 사용 가능합니다." -ForegroundColor Yellow
            return
        }
    }

    # 공개키를 클립보드에 복사
    Write-Host ""
    Write-Host "  ======================================================" -ForegroundColor Yellow
    Write-Host "  아래 텍스트를 Mac 관리자에게 보내주세요:" -ForegroundColor Yellow
    Write-Host "  ======================================================" -ForegroundColor Yellow
    Write-Host ""
    $pubKeyContent = Get-Content "$keyPath.pub"
    Write-Host "  $pubKeyContent" -ForegroundColor White
    Write-Host ""

    try {
        Get-Content "$keyPath.pub" | Set-Clipboard
        Write-Host "  [OK] 클립보드에 복사되었습니다!" -ForegroundColor Green
        Write-Host "  카톡, 슬랙, 이메일 등으로 Mac 관리자에게 보내주세요." -ForegroundColor Cyan
    }
    catch {
        Write-Host "  [참고] 클립보드 복사에 실패했습니다. 위 텍스트를 직접 복사하세요." -ForegroundColor Yellow
    }
    Write-Host ""
}

# --------------------------------------------------
# Step 3: Mac 서버 SSH 접속 설정
# --------------------------------------------------
function Set-SshConfig {
    Write-Host "[3/6] Mac 서버 SSH 접속 설정..." -ForegroundColor Cyan

    if ([string]::IsNullOrEmpty($MacServer)) {
        Write-Host ""
        Write-Host "  Mac 서버 주소를 입력하세요." -ForegroundColor White
        Write-Host "  (Mac 관리자에게 'mac-mini.tailscale.com' 같은 주소를 받으세요)" -ForegroundColor Gray
        do {
            $MacServer = Read-Host "  Mac 서버 호스트명 (예: mac-mini.tailscale.com)"
            if ($MacServer -notmatch '^[a-zA-Z0-9._-]+$') {
                Write-Host "  잘못된 호스트명입니다. 영문, 숫자, 점(.), 하이픈(-)만 사용하세요." -ForegroundColor Red
                $MacServer = ""
            }
        } while ([string]::IsNullOrEmpty($MacServer))
    }
    if ([string]::IsNullOrEmpty($Username)) {
        Write-Host ""
        Write-Host "  Mac 서버 사용자 이름을 입력하세요." -ForegroundColor White
        Write-Host "  (Mac 관리자에게 확인하세요)" -ForegroundColor Gray
        do {
            $Username = Read-Host "  Mac 서버 사용자 이름"
            if ($Username -notmatch '^[a-zA-Z0-9._-]+$' -or $Username.Length -gt 32) {
                Write-Host "  잘못된 사용자 이름입니다 (영문, 숫자, 최대 32자)." -ForegroundColor Red
                $Username = ""
            }
        } while ([string]::IsNullOrEmpty($Username))
    }

    $sshConfigPath = Join-Path $env:USERPROFILE ".ssh" "config"
    $configBlock = @"

# Claude Code Mac Server (Mac 서버 접속 설정)
Host claude-mac
    HostName $MacServer
    User $Username
    IdentityFile ~/.ssh/id_ed25519
    ServerAliveInterval 60
    ServerAliveCountMax 3
    ForwardAgent yes
"@

    if (Test-Path $sshConfigPath) {
        $existing = Get-Content $sshConfigPath -Raw
        if ($existing -match "claude-mac") {
            Write-Host "  [OK] SSH 설정이 이미 존재합니다 (claude-mac)" -ForegroundColor Gray
            return
        }
    }

    Add-Content -Path $sshConfigPath -Value $configBlock
    Write-Host "  [OK] SSH 설정 추가 완료" -ForegroundColor Green
    Write-Host "  접속 명령어: ssh claude-mac" -ForegroundColor White
}

# --------------------------------------------------
# Step 4: VS Code 확장 설치
# --------------------------------------------------
function Install-VsCodeExtensions {
    Write-Host ""
    Write-Host "[4/6] VS Code 확장 설치..." -ForegroundColor Cyan

    $extensions = @(
        "ms-vscode-remote.remote-ssh",
        "ms-vscode-remote.remote-containers",
        "dbaeumer.vscode-eslint",
        "esbenp.prettier-vscode",
        "ms-vscode.vscode-typescript-next"
    )

    $codePath = Get-Command "code" -ErrorAction SilentlyContinue
    if (-not $codePath) {
        Write-Host "  [참고] VS Code CLI를 찾을 수 없습니다." -ForegroundColor Yellow
        Write-Host "         VS Code 설치 후 터미널을 재시작하면 자동으로 사용 가능합니다." -ForegroundColor Yellow
        Write-Host "         또는 VS Code에서 직접 확장을 설치하세요:" -ForegroundColor Yellow
        foreach ($ext in $extensions) {
            Write-Host "           - $ext" -ForegroundColor Gray
        }
        return
    }

    foreach ($ext in $extensions) {
        code --install-extension $ext --force 2>$null
        Write-Host "  [OK] $ext" -ForegroundColor Green
    }
}

# --------------------------------------------------
# Step 5: Claude Code 설정 파일 설치
# --------------------------------------------------
function Install-ClaudeConfig {
    Write-Host ""
    Write-Host "[5/6] Claude Code 설정 파일 설치..." -ForegroundColor Cyan

    $configDir = Join-Path $env:USERPROFILE "claude-code-config"

    if (Test-Path $configDir) {
        Write-Host "  [OK] 설정 저장소가 이미 존재합니다: $configDir" -ForegroundColor Gray
    }
    else {
        $repoUrl = Read-Host "  Git 저장소 URL을 입력하세요 (건너뛰려면 Enter)"
        if (-not [string]::IsNullOrEmpty($repoUrl)) {
            git clone $repoUrl $configDir
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  [OK] 설정 저장소 클론 완료" -ForegroundColor Green
            }
            else {
                Write-Host "  [실패] Git 클론에 실패했습니다." -ForegroundColor Red
                Write-Host "         URL을 확인하고 다시 시도하세요." -ForegroundColor Yellow
                return
            }
        }
        else {
            Write-Host "  [건너뜀] 저장소 URL 미입력" -ForegroundColor Gray
            return
        }
    }

    $installScript = Join-Path $configDir "install.ps1"
    if (Test-Path $installScript) {
        Write-Host "  install.ps1 실행 중..."
        & $installScript
    }
}

# --------------------------------------------------
# Step 6: 연결 테스트 및 계정 안내
# --------------------------------------------------
function Test-Connectivity {
    Write-Host ""
    Write-Host "[6/6] 연결 테스트 및 추가 설정 안내..." -ForegroundColor Cyan

    # Tailscale 계정 안내
    Write-Host ""
    Write-Host "  --- Tailscale (팀 VPN) 설정 ---" -ForegroundColor Yellow
    Write-Host "  Tailscale은 팀원끼리 안전하게 연결하는 VPN입니다."
    Write-Host "  1. https://login.tailscale.com 에서 회원가입"
    Write-Host "  2. Mac 관리자에게 초대 링크를 요청하세요"
    Write-Host "  3. Tailscale 앱 실행 -> 로그인"
    Write-Host ""

    # Anthropic 계정 / Claude Code 로그인 안내
    Write-Host "  --- Claude Code 로그인 ---" -ForegroundColor Yellow
    Write-Host "  Claude Code를 사용하려면 Anthropic 계정이 필요합니다."
    Write-Host "  1. https://console.anthropic.com 에서 회원가입"
    Write-Host "  2. 터미널에서 'claude' 실행"
    Write-Host "  3. 화면 안내에 따라 로그인"
    Write-Host ""

    # SSH 연결 테스트
    if ([string]::IsNullOrEmpty($MacServer)) {
        Write-Host "  [건너뜀] Mac 서버가 설정되지 않아 연결 테스트를 생략합니다." -ForegroundColor Gray
        return
    }

    Write-Host "  Mac 서버 SSH 연결 테스트 중..."
    $result = ssh -o ConnectTimeout=5 -o BatchMode=yes claude-mac "echo ok" 2>$null
    if ($result -eq "ok") {
        Write-Host "  [OK] SSH 연결 성공!" -ForegroundColor Green
    }
    else {
        Write-Host "  [실패] SSH 연결에 실패했습니다." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  확인사항:" -ForegroundColor Yellow
        Write-Host "    1. Tailscale이 양쪽(Windows, Mac) 모두 실행 중인가요?"
        Write-Host "    2. Mac 관리자에게 SSH 공개키를 전달했나요?"
        Write-Host "    3. Mac에서 원격 로그인(SSH)이 켜져 있나요?"
        Write-Host ""
        Write-Host "  문제가 지속되면 Mac 관리자에게 문의하세요."
    }

    # Claude Code CLI 확인
    Write-Host ""
    Write-Host "  Claude Code CLI 확인 중..."
    $claudePath = Get-Command "claude" -ErrorAction SilentlyContinue
    if ($claudePath) {
        Write-Host "  [OK] Claude Code CLI 확인됨" -ForegroundColor Green
    }
    else {
        Write-Host "  [참고] Claude Code가 PATH에 없습니다." -ForegroundColor Yellow
        Write-Host "         터미널을 재시작한 후 'claude'를 실행해보세요." -ForegroundColor Yellow
    }
}

# --------------------------------------------------
# Main
# --------------------------------------------------
function Main {
    Test-Winget
    Install-CoreTools
    New-SshKey
    Set-SshConfig
    Install-VsCodeExtensions
    Install-ClaudeConfig
    Test-Connectivity

    Write-Host ""
    Write-Host "설정이 완료되었습니다!" -ForegroundColor Green
    Write-Host ""
    Write-Host "다음 단계:" -ForegroundColor Cyan
    Write-Host "  1. 터미널을 재시작하세요"
    Write-Host "  2. 'tailscale up' 실행하여 VPN에 연결"
    Write-Host "  3. 'ssh claude-mac' 실행하여 Mac 서버에 접속"
    Write-Host "  4. 'claude' 실행하여 Claude Code 시작"
    Write-Host ""
    Write-Host "VS Code에서 원격 개발:" -ForegroundColor Cyan
    Write-Host "  VS Code -> Remote-SSH -> claude-mac"
    Write-Host ""
}

Main
