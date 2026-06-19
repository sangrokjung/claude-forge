# Windows + Mac 하이브리드 환경 설정 가이드

## 이 가이드는 무엇인가요?

Mac 한 대를 개발 서버로 두고, Windows PC를 사용하는 팀원들이 원격으로 접속하여 Claude Code를 함께 사용할 수 있도록 환경을 구성하는 종합 가이드입니다. 터미널(명령 프롬프트)을 처음 사용하는 분도 따라할 수 있도록 모든 과정을 단계별로 설명합니다.

> 용어가 낯설다면 [GLOSSARY.md](GLOSSARY.md)를 먼저 읽어주세요.
> 필요한 프로그램 목록은 [PREREQUISITES.md](PREREQUISITES.md)를 확인하세요.

---

## 전체 구성도

```
+--------------------------+      +--------------------------+
|   Windows PC (팀원 A)     |      |   Windows PC (팀원 B)     |
|   - Claude Code 설치      |      |   - Claude Code 설치      |
|   - Tailscale 설치        |      |   - Tailscale 설치        |
|   - VS Code 설치          |      |   - VS Code 설치          |
+-----------+--------------+      +-----------+--------------+
            |                                 |
            |      Tailscale 보안 네트워크       |
            |   (인터넷 어디서든 안전하게 연결)     |
            v                                 v
       +----+----------------------------------+----+
       |          Mac 개발 서버 (Mac Mini 등)         |
       |  - Claude Code 실행                         |
       |  - 프로젝트 코드 저장                         |
       |  - MCP 서버 (AI 도구들)                      |
       |  - SSH로 원격 접속 허용                       |
       +---------------------------------------------+
```

**핵심 흐름**: Windows 팀원이 Tailscale(보안 VPN)을 통해 Mac 서버에 SSH로 접속하여 Claude Code를 사용합니다.

---

## 역할 구분

| 항목 | Mac 관리자 (1명) | Windows 팀원 (여러 명) |
|------|-----------------|---------------------|
| 하는 일 | Mac 서버 설정, 팀원 등록 | 자기 PC 설정, 서버 접속 |
| 필요한 것 | Mac 컴퓨터, 관리자 계정 | Windows PC, 인터넷 |
| 소요 시간 | 약 30분 | 약 15분 |
| 난이도 | 중간 | 쉬움 |

---

## Part 1: Mac 관리자가 할 일

> 이 섹션은 Mac 서버를 관리하는 사람만 따라하면 됩니다.

### 1단계: 사전 준비 확인

> 이 단계에서는: Mac에 필요한 프로그램이 설치되어 있는지 확인합니다.

자세한 사전 준비 사항은 [PREREQUISITES.md](PREREQUISITES.md)를 참고하세요.

기본 요구사항:
- macOS 13 (Ventura) 이상
- 관리자 계정으로 로그인
- 인터넷 연결

### 2단계: Mac 서버 설정 스크립트 실행

> 이 단계에서는: Mac을 원격 개발 서버로 설정합니다. (SSH 활성화, 보안 설정, 필수 도구 설치)

**터미널 열기**: Spotlight (Cmd + Space) 에서 "Terminal" 검색 후 실행

```bash
cd ~/claude-code-config/setup
./setup-mac-server.sh --hostname mac-mini
```

> `mac-mini` 부분은 원하는 이름으로 바꿀 수 있습니다. (예: `dev-server`, `team-mac`)

**성공 시 출력 예시:**
```
Mac Server Setup for Claude Code
=================================
[1/7] System configuration...
  Setting hostname to: mac-mini
  ✓ Hostname set
  ✓ Sleep disabled
  ✓ Auto-restart enabled
[2/7] Configuring SSH...
  ✓ Host key exists
  ✓ SSH hardened (password auth disabled)
  ...
[7/7] Installing Claude Code config...
  Running install.sh...

Mac server setup complete!
```

**실패 시 대처:**
- `Permission denied` 오류 → 스크립트 실행 권한 부여: `chmod +x setup-mac-server.sh` 후 다시 실행
- `brew: command not found` → Homebrew 미설치. 스크립트가 자동 설치를 시도하지만, 실패 시 수동 설치: `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`
- `setremotelogin: command not found` → 수동으로 SSH 활성화: **시스템 설정 > 일반 > 공유 > 원격 로그인** 켜기

### 3단계: Tailscale 설치 및 Mac 등록

> 이 단계에서는: Mac을 Tailscale 네트워크에 등록하여 외부에서도 안전하게 접속할 수 있게 합니다.

1. **Tailscale 계정 생성**: https://login.tailscale.com 에 접속하여 회원가입
   - Google, Microsoft, GitHub 계정으로 간편 가입 가능
2. **Tailscale 앱 실행**: 스크립트가 이미 설치했으므로, 터미널에서 실행:
   ```bash
   tailscale up
   ```
3. **브라우저 인증**: 위 명령 실행 시 브라우저가 열리면 로그인하여 인증 완료

**성공 확인:**
```bash
tailscale status
```
출력에 Mac의 이름과 IP 주소가 보이면 성공입니다.

**실패 시 대처:**
- `tailscale: command not found` → Tailscale 수동 설치: `brew install --cask tailscale` 또는 https://tailscale.com/download/mac 에서 다운로드
- 브라우저가 열리지 않음 → 터미널에 표시된 URL을 직접 복사하여 브라우저에 붙여넣기

### 4단계: 팀원 SSH 키 등록

> 이 단계에서는: 팀원이 Mac에 비밀번호 없이 안전하게 접속할 수 있도록 공개 키를 등록합니다.

팀원이 Windows 설정 완료 후 SSH 공개 키를 보내줍니다 (카카오톡, 슬랙 등으로). 키는 아래와 같은 형태입니다:

```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx user@email.com
```

**등록 방법:**

```bash
# 방법 1: 직접 파일 편집 (nano 에디터 사용)
nano ~/.ssh/authorized_keys
# 파일 맨 아래에 팀원의 키를 붙여넣고 Ctrl+O로 저장, Ctrl+X로 종료

# 방법 2: 명령어 한 줄로 추가 (키를 따옴표 안에 붙여넣기)
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIxxxxxx user@email.com" >> ~/.ssh/authorized_keys
```

**여러 팀원이 있는 경우**: 각 팀원의 키를 한 줄에 하나씩 추가합니다.

**확인:**
```bash
cat ~/.ssh/authorized_keys
```
등록한 키들이 줄 단위로 출력되면 성공입니다.

**실패 시 대처:**
- 파일이 없다면: `mkdir -p ~/.ssh && touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys`
- 권한 오류: `chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys`

### 5단계: 팀원 Tailscale 초대

> 이 단계에서는: 팀원을 Tailscale 네트워크에 초대하여 Mac에 접속할 수 있게 합니다.

1. https://login.tailscale.com/admin/users 접속
2. **"Invite users"** 클릭
3. 팀원의 이메일 주소 입력 후 초대 발송
4. 팀원이 이메일의 초대 링크를 클릭하면 같은 네트워크에 합류

**확인:**
```bash
tailscale status
```
팀원의 기기가 목록에 보이면 성공입니다.

---

## Part 2: Windows 팀원이 할 일

> 이 섹션은 Windows PC를 사용하는 팀원들이 따라하면 됩니다.

### 1단계: 사전 준비 확인

> 이 단계에서는: Windows PC가 요구사항을 충족하는지 확인합니다.

자세한 사전 준비 사항은 [PREREQUISITES.md](PREREQUISITES.md)를 참고하세요.

기본 요구사항:
- Windows 10 (버전 1809 이상) 또는 Windows 11
- 인터넷 연결
- PC 관리자 권한

### 2단계: PowerShell을 관리자 권한으로 열기

> 이 단계에서는: 프로그램 설치에 필요한 관리자 권한 터미널을 엽니다.

**Windows 11의 경우:**
1. 화면 하단 작업 표시줄에서 **시작 버튼**(Windows 로고)을 **마우스 오른쪽 클릭**
2. 메뉴에서 **"터미널(관리자)"** 클릭
3. "이 앱이 변경하도록 허용하시겠습니까?" 팝업에서 **"예"** 클릭

**Windows 10의 경우:**
1. 화면 하단 작업 표시줄에서 **시작 버튼**(Windows 로고)을 **마우스 오른쪽 클릭**
2. 메뉴에서 **"Windows PowerShell(관리자)"** 클릭
3. "이 앱이 변경하도록 허용하시겠습니까?" 팝업에서 **"예"** 클릭

**확인**: 터미널 상단에 "관리자:" 가 표시되면 성공입니다.

### 3단계: 설정 스크립트 다운로드 및 실행

> 이 단계에서는: 필요한 도구들을 자동으로 설치하고, SSH 키를 생성합니다.

**먼저 Git이 설치되어 있지 않다면 설치:**
```powershell
winget install --id Git.Git --accept-source-agreements --accept-package-agreements
```
설치 후 **PowerShell을 닫았다가 다시 관리자 권한으로** 여세요 (Git 명령어가 인식되려면 터미널을 새로 열어야 합니다).

**저장소 복제:**
```powershell
cd $env:USERPROFILE
git clone https://github.com/qjc-office/dotclaude.git
cd claude-code-config\setup
```

> SSH 키가 아직 없으므로 HTTPS 방식으로 복제합니다. 나중에 SSH 키 설정이 완료되면 SSH 방식으로 전환할 수 있습니다.

**스크립트 실행 정책 변경 (최초 1회):**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```
"실행 정책을 변경하시겠습니까?" 물음에 **Y** 입력 후 Enter

**스크립트 실행:**
```powershell
.\setup-windows.ps1 -MacServer "mac-mini" -Username "dev"
```

> - `mac-mini` 부분: Mac 관리자에게 받은 Mac 서버 이름으로 변경
> - `dev` 부분: Mac 관리자에게 받은 사용자 이름으로 변경

**성공 시 출력 예시:**
```
Windows Team Member Setup
=========================
[1/6] Installing core tools...
  [OK] Claude Code
  [OK] VS Code
  [OK] Tailscale
  [OK] Git
  [OK] Node.js 22 LTS
[2/6] Configuring SSH...
  [OK] SSH key generated

  Your public key (copy this to Mac server):
  ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIxxxxxxxxx your@email.com

[3/6] Configuring SSH for Mac server...
  [OK] SSH config added. Connect with: ssh claude-mac
  ...
Setup complete!
```

**실패 시 대처:**
- `winget: 명령을 찾을 수 없습니다` → Windows 10의 경우 Microsoft Store에서 "앱 설치 관리자" 업데이트 필요
- `스크립트 실행이 비활성화되어 있습니다` → 위의 `Set-ExecutionPolicy` 명령을 먼저 실행하세요
- `git: 명령을 찾을 수 없습니다` → Git 설치 후 PowerShell을 닫았다가 다시 열기

### 4단계: SSH 공개 키를 Mac 관리자에게 전달

> 이 단계에서는: Mac에 접속하기 위한 "디지털 신분증(공개 키)"을 관리자에게 보냅니다.

스크립트 실행 중 화면에 표시된 공개 키를 복사합니다. 다시 확인하려면:

```powershell
Get-Content $env:USERPROFILE\.ssh\id_ed25519.pub
```

출력 예시:
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx your@email.com
```

**이 전체 텍스트를 복사**하여 Mac 관리자에게 카카오톡, 슬랙, 이메일 등으로 전달합니다.

> 보안 안내: 이것은 "공개 키"로, 다른 사람에게 보여줘도 안전합니다. 반면 `id_ed25519` (확장자 없는 파일)는 **"비밀 키"**이므로 절대 공유하지 마세요.

### 5단계: Tailscale 가입 및 팀 네트워크 참여

> 이 단계에서는: Mac과 같은 보안 네트워크에 연결하여 어디서든 접속 가능하게 합니다.

1. **Tailscale 실행**: 시작 메뉴에서 "Tailscale" 검색 후 실행
   - 또는 작업 표시줄 우측 트레이 아이콘에서 Tailscale 클릭
2. **로그인**: Mac 관리자가 보내준 초대 이메일의 링크를 클릭하여 가입
   - 또는 https://login.tailscale.com 에서 직접 가입 후 관리자에게 알려주기
3. **네트워크 연결 확인**: Tailscale 아이콘이 활성 상태(파란색)이면 연결된 것입니다

**확인**: PowerShell에서 아래 명령 실행
```powershell
tailscale status
```
자기 PC와 Mac 서버가 목록에 보이면 성공입니다.

**실패 시 대처:**
- Tailscale이 설치되지 않은 경우: `winget install Tailscale.Tailscale` 실행 후 PC 재시작
- 로그인 후에도 Mac이 안 보임 → Mac 관리자에게 Tailscale 상태 확인 요청

### 6단계: Anthropic 계정 생성 및 Claude Code 로그인

> 이 단계에서는: Claude Code를 사용하기 위한 Anthropic 계정을 만들고 로그인합니다.

1. **Anthropic 계정 생성**: https://console.anthropic.com 에 접속하여 회원가입
2. **Claude Code 로그인**: PowerShell (일반 권한도 가능) 에서:
   ```powershell
   claude
   ```
3. 브라우저가 열리면 Anthropic 계정으로 로그인
4. 터미널로 돌아오면 Claude Code 사용 준비 완료

**실패 시 대처:**
- `claude: 명령을 찾을 수 없습니다` → PowerShell을 닫고 새로 열기. 여전히 안 되면: `npm install -g @anthropic-ai/claude-code`
- 브라우저가 열리지 않음 → 터미널에 표시된 URL을 직접 브라우저에 붙여넣기

### 7단계: Mac 서버 접속 테스트

> 이 단계에서는: 모든 설정이 올바른지 Mac 서버에 실제 접속하여 확인합니다.

```powershell
ssh claude-mac
```

**성공 시**: Mac의 터미널 프롬프트가 표시됩니다 (예: `dev@mac-mini ~ %`)

```
The authenticity of host 'mac-mini (100.x.x.x)' can't be established.
ED25519 key fingerprint is SHA256:xxxxxxx.
Are you sure you want to continue connecting (yes/no)?
```
위와 같은 메시지가 나오면 `yes` 입력 후 Enter (최초 접속 시 1회만 표시)

**실패 시 대처:**
- `Connection refused` → Mac 관리자에게 SSH(원격 로그인)가 활성화되어 있는지 확인 요청
- `Permission denied (publickey)` → SSH 공개 키가 Mac에 등록되었는지 Mac 관리자에게 확인 요청
- `Could not resolve hostname` → Tailscale이 양쪽 모두 실행 중인지 확인. `tailscale status`로 확인

접속 해제 방법: `exit` 입력 후 Enter

---

## SSH 키 전달 과정 (전체 흐름)

SSH 키는 Mac 서버에 안전하게 접속하기 위한 "디지털 신분증"입니다. 전체 과정을 정리하면:

```
[Windows 팀원]                        [Mac 관리자]
     |                                      |
     | 1. 스크립트가 SSH 키 쌍 자동 생성        |
     |    (공개 키 + 비밀 키)                  |
     |                                      |
     | 2. 공개 키 텍스트가 화면에 표시           |
     |                                      |
     | 3. 공개 키를 복사하여                    |
     | ---카톡/슬랙/이메일로 전송--->            |
     |                                      |
     |                          4. 받은 공개 키를
     |                             authorized_keys에 추가
     |                                      |
     | 5. ssh claude-mac 으로 접속 테스트       |
     | <-------- 접속 성공! -------->          |
```

### 상세 과정

**Windows 팀원 측:**
1. `setup-windows.ps1` 실행 시 자동으로 SSH 키 쌍이 생성됨
2. 화면에 공개 키가 표시됨 (ssh-ed25519 AAAA... 형태)
3. 이 텍스트를 전체 복사하여 Mac 관리자에게 전송

**Mac 관리자 측:**
4. 팀원에게 받은 공개 키를 등록:
```bash
# 받은 키를 authorized_keys에 추가
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBxxxxxx user@email.com" >> ~/.ssh/authorized_keys
```

**Windows 팀원 측:**
5. 등록 완료 알림을 받으면 접속 테스트:
```powershell
ssh claude-mac
```

---

## 접속 방법 3가지

설정 완료 후 Mac 서버에 접속하는 방법은 3가지입니다.

### 방법 1: SSH 직접 접속 (가장 기본)

**언제 사용**: 빠르게 명령어를 실행하거나 Claude Code를 터미널에서 사용할 때

**조작법:**
1. PowerShell 또는 Windows Terminal 열기
2. 명령어 입력:
   ```powershell
   ssh claude-mac
   ```
3. Mac 서버의 터미널이 표시됨
4. Claude Code 실행:
   ```bash
   # tmux 세션에 연결 (기존 세션 유지)
   tmux attach -t claude || tmux new -s claude
   # Claude Code 시작
   claude
   ```
5. 종료: `exit` 입력

### 방법 2: VS Code Remote SSH (추천)

**언제 사용**: 코드 편집, 파일 탐색, 터미널을 모두 GUI 환경에서 사용할 때 (가장 편리)

**조작법:**
1. VS Code 실행
2. 좌측 하단 **녹색 아이콘**(><) 클릭
3. **"Connect to Host... (Remote-SSH)"** 선택
4. **"claude-mac"** 선택
5. 새 VS Code 창이 열리며 Mac 서버에 연결됨
6. **파일 > 폴더 열기** 로 프로젝트 폴더 선택
7. 터미널(Ctrl+`)에서 Claude Code 실행 가능

### 방법 3: Windows에서 로컬 Claude Code 사용

**언제 사용**: Mac 서버 없이 독립적으로 작업할 때, 또는 Mac 서버에 접속할 수 없을 때

**조작법:**
1. PowerShell 또는 Windows Terminal 열기
2. 프로젝트 폴더로 이동:
   ```powershell
   cd C:\Users\사용자이름\프로젝트폴더
   ```
3. Claude Code 실행:
   ```powershell
   claude
   ```

---

## 문제 해결

### 1. SSH 접속이 거부됨 (Connection refused)

**원인**: Mac의 SSH 서비스가 꺼져 있음
**해결** (Mac 관리자):
```bash
# SSH 상태 확인
sudo systemsetup -getremotelogin
# SSH 활성화
sudo systemsetup -setremotelogin on
```
또는: **시스템 설정 > 일반 > 공유 > 원격 로그인** 켜기

### 2. 공개 키 인증 실패 (Permission denied publickey)

**원인**: SSH 키가 Mac에 등록되지 않았거나, 파일 권한이 잘못됨
**해결** (Mac 관리자):
```bash
# 권한 확인 및 수정
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys

# 키가 제대로 등록되었는지 확인
cat ~/.ssh/authorized_keys
```
**해결** (Windows 팀원):
```powershell
# 키 파일이 있는지 확인
Test-Path $env:USERPROFILE\.ssh\id_ed25519.pub
# 공개 키 다시 확인
Get-Content $env:USERPROFILE\.ssh\id_ed25519.pub
```

### 3. 호스트 이름을 찾을 수 없음 (Could not resolve hostname)

**원인**: Tailscale이 연결되지 않았거나, 양쪽 중 하나가 오프라인
**해결**:
```powershell
# Windows에서 Tailscale 상태 확인
tailscale status
```
```bash
# Mac에서 Tailscale 상태 확인
tailscale status
```
양쪽 모두 "connected" 상태인지 확인. 오프라인이면 Tailscale 앱을 재시작.

### 4. Tailscale이 연결되지 않음

**원인**: Tailscale 서비스가 중지됨
**해결** (Windows):
- 시작 메뉴에서 "Tailscale" 검색 후 실행
- 작업 표시줄 트레이에서 Tailscale 아이콘 확인 (파란색 = 연결됨)

**해결** (Mac):
```bash
# Tailscale 상태 확인
tailscale status
# 다시 연결
tailscale up
```

### 5. Claude Code 명령어가 인식되지 않음

**원인**: 설치 후 터미널을 새로 열지 않았거나, Node.js가 설치되지 않음
**해결** (Windows):
```powershell
# 터미널을 닫고 새로 열기 후:
claude --version

# 안 되면 수동 설치:
npm install -g @anthropic-ai/claude-code
```
**해결** (Mac):
```bash
# Node.js 확인
node --version
# Claude Code 설치
npm install -g @anthropic-ai/claude-code
```

### 6. winget 명령어가 인식되지 않음 (Windows)

**원인**: Windows 10에서 앱 설치 관리자가 업데이트되지 않음
**해결**:
1. Microsoft Store 열기
2. "앱 설치 관리자" 검색
3. 업데이트 버튼 클릭
4. PowerShell을 닫고 새로 열기

### 7. 스크립트 실행 정책 오류 (Windows)

**원인**: PowerShell 스크립트 실행이 기본적으로 차단됨
**해결**:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```
Y 입력 후 Enter

### 8. VS Code에서 Remote SSH 연결 실패

**원인**: Remote-SSH 확장이 없거나, SSH 설정이 잘못됨
**해결**:
1. VS Code에서 Ctrl+Shift+X (확장 마켓플레이스)
2. "Remote - SSH" 검색 후 설치
3. SSH 설정 확인:
```powershell
Get-Content $env:USERPROFILE\.ssh\config
```
"claude-mac" 항목이 있어야 합니다.

### 9. Mac이 절전 모드로 접속 불가

**원인**: Mac의 절전 모드가 해제되지 않음
**해결** (Mac 관리자):
```bash
# 절전 모드 설정 확인
pmset -g
# 절전 비활성화
sudo pmset -a sleep 0
sudo pmset -a displaysleep 0
```
또는: **시스템 설정 > 에너지 절약** 에서 절전 해제

### 10. SSH 접속 시 비밀번호를 물어봄

**원인**: 공개 키 인증이 실패하여 비밀번호 인증으로 넘어감
**해결**:
1. (Mac 관리자) authorized_keys에 키가 올바르게 등록되었는지 확인
2. (Mac 관리자) 파일 권한 확인: `chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys`
3. (Windows 팀원) SSH 키 파일 경로가 올바른지 확인:
```powershell
ssh -v claude-mac
```
출력에서 `Offering public key` 줄을 찾아 올바른 키 파일을 사용하고 있는지 확인

### 11. tmux 세션이 없다고 나옴

**원인**: Mac이 재부팅되었거나 tmux 세션이 종료됨
**해결**:
```bash
# 새 세션 생성
tmux new -s claude
# 또는 기존 세션 확인
tmux list-sessions
```

### 12. Git clone 시 인증 오류

**원인**: SSH 키가 GitHub에 등록되지 않았거나 HTTPS를 사용해야 함
**해결**: 초기 설정 시에는 HTTPS 방식으로 clone:
```powershell
git clone https://github.com/qjc-office/dotclaude.git
```
SSH 방식은 GitHub에 SSH 키를 등록한 후 사용 가능합니다.

---

## 용어가 낯설다면

이 가이드에서 사용된 기술 용어가 낯설다면 [GLOSSARY.md](GLOSSARY.md)를 참고하세요. SSH, Tailscale, tmux 등 주요 용어에 대한 쉬운 설명이 있습니다.

---

## 다음 단계

설정이 모두 완료되었다면:

1. **Mac 관리자**: 팀원들에게 접속 정보(서버 이름, 사용자 이름)를 공유하세요
2. **Windows 팀원**: `ssh claude-mac` 으로 접속 후 `claude` 명령으로 Claude Code를 시작하세요
3. **모든 구성원**: [README.md](../README.md)에서 프로젝트 구성과 사용 가능한 명령어를 확인하세요
