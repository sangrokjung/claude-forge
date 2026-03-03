# Windows Hooks 실행 환경 설정

Claude Forge의 모든 hook 파일(`.sh`)은 **bash** 기반으로 작성되어 있습니다.
Windows에서 정상 작동하려면 아래 중 하나가 필요합니다.

## 환경 확인

PowerShell에서 아래 명령 실행:

```powershell
where.exe bash
```

- **결과가 출력되면** → 정상. hooks가 작동합니다.
- **`InfoFile not found` 오류가 나오면** → 아래 설치 가이드를 따르세요.

---

## 옵션 A: Git for Windows (권장)

Git 설치 시 Git Bash가 함께 포함됩니다.

```powershell
winget install Git.Git
```

설치 후 터미널 재시작 → `where.exe bash`로 재확인.

---

## 옵션 B: WSL2 (고급)

```powershell
wsl --install
```

WSL2 설치 후 Ubuntu에서 Claude Code를 실행하면 `.sh` hooks가 네이티브로 작동합니다.

---

## 경고 없이 실패하는 경우

Claude Code는 hook 실패를 **침묵으로 무시**하고 작업을 계속 진행합니다.
bash가 없는 경우 다음 보안 기능이 **비활성화** 상태로 작동합니다:

| Hook 파일 | 역할 | 미작동 시 영향 |
|-----------|------|---------------|
| `remote-command-guard.sh` | 원격 세션 위험 명령 차단 | 차단 기능 없음 |
| `output-secret-filter.sh` | 출력에서 시크릿 마스킹 | 시크릿 노출 가능 |
| `rate-limiter.sh` | MCP 호출 속도 제한 | 제한 없음 |
| `mcp-usage-tracker.sh` | MCP 사용량 추적 | 추적 없음 |

> **결론**: 로컬 개발 환경(원격 세션 없음)이라면 즉각적 위험은 낮지만,
> Git Bash 설치는 강력히 권장됩니다.

---

## .NET 개발 관련 확인

hooks 작동 여부와 무관하게, **`dotnet` 명령어는 차단되지 않습니다**.

```powershell
# 모두 정상 작동
dotnet build
dotnet test
dotnet run
dotnet ef migrations add Init
```
