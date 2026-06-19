# 사전 준비 체크리스트

설정을 시작하기 전에 아래 항목을 모두 준비해 주세요.
한 번에 다 하면 약 15분이면 충분합니다.

---

## 필요한 계정 (무료)

- [ ] **GitHub 계정** - 소스코드 저장소
  - 가입: https://github.com/signup
  - 이미 있다면 건너뛰세요

- [ ] **Anthropic 계정** - Claude Code 사용에 필요
  - 가입: https://console.anthropic.com/signup
  - Claude Pro ($20/월) 또는 Max ($100/월) 구독 필요
  - 또는 API 키 발급 (사용량 기반 과금)

- [ ] **Tailscale 계정** - 팀 VPN (팀원 간 안전한 연결)
  - 가입: https://login.tailscale.com/start
  - 개인 무료, 팀 $6/인/월
  - Mac 관리자가 먼저 가입한 후 팀원을 초대합니다

---

## 필요한 정보 (Mac 관리자에게 확인)

아래 정보는 Mac 관리자가 알려줍니다. 미리 받아두세요.

- [ ] Git 저장소 URL (예: `https://github.com/회사명/claude-code-config.git`)
- [ ] Mac 서버 호스트명 (예: `mac-mini.tail1234.ts.net`)
- [ ] Mac 서버 접속 사용자명 (예: `dev`)
- [ ] Tailscale 팀 초대 링크

> 아직 못 받았다면 Mac 관리자에게 "사전 준비 체크리스트 보고 있는데, 접속 정보 알려주세요"라고 말씀하세요.

---

## 하드웨어 요구사항

### Windows 팀원

- [ ] Windows 10 (버전 1809 이상) 또는 Windows 11
- [ ] 인터넷 연결 (유선 또는 Wi-Fi)
- [ ] 최소 8GB RAM
- [ ] 10GB 이상 여유 디스크 공간

### Mac 관리자 (서버용)

- [ ] macOS Ventura (13.0) 이상
- [ ] Apple Silicon (M1/M2/M3/M4) 또는 Intel Mac
- [ ] 최소 16GB RAM (24GB 이상 권장)
- [ ] 50GB 이상 여유 디스크 공간
- [ ] 관리자(admin) 비밀번호

> **내 macOS 버전 확인 방법**: 왼쪽 상단 Apple 메뉴 > 이 Mac에 관하여

---

## 소프트웨어 사전 설치 (선택)

설정 스크립트가 자동으로 설치해 주지만, 미리 설치해두면 더 빠릅니다.

### Windows 팀원

- [ ] **Git**: https://git-scm.com/download/win
  - 설치 중 모든 옵션은 기본값 그대로 "Next"를 눌러도 됩니다
- [ ] **VS Code**: https://code.visualstudio.com
  - 코드 편집기입니다. Mac 서버의 코드를 내 화면에서 편집할 수 있습니다

### Mac 관리자

- [ ] **Homebrew**: https://brew.sh
  - 터미널을 열고 홈페이지에 있는 설치 명령어를 복사해서 붙여넣기하면 됩니다
  - Mac용 개발 도구 설치 관리자입니다

---

## 네트워크 확인

회사 방화벽이 있는 경우, 아래 도메인에 접근이 가능한지 IT 담당자에게 확인하세요.

- [ ] `github.com` - 소스코드 저장소
- [ ] `npmjs.com` - 개발 패키지 다운로드
- [ ] `tailscale.com` - VPN 연결
- [ ] `anthropic.com` - Claude API

> **확인 방법**: 브라우저에서 위 주소를 하나씩 열어보세요. 페이지가 열리면 접근 가능합니다.

---

## 예상 소요 시간

| 역할 | 작업 | 소요 시간 |
|------|------|----------|
| Mac 관리자 | 서버 초기 설정 | 30~40분 |
| Mac 관리자 | 팀원 키 등록 (1인당) | 약 5분 |
| Windows 팀원 | 환경 설정 | 15~20분 |
| Windows 팀원 | 접속 테스트 | 약 5분 |

---

## 준비 완료!

위 항목을 모두 확인했다면 다음 단계로 이동하세요.

- **Mac 관리자**: [Mac 서버 설정 가이드](SETUP-GUIDE.md#part-1-mac-관리자가-할-일)로 이동
- **Windows 팀원**: [Windows 설정 가이드](SETUP-GUIDE.md#part-2-windows-팀원이-할-일)로 이동

> 막히는 부분이 있다면 [용어 사전](GLOSSARY.md)에서 낯선 단어를 찾아보세요.
