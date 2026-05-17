# Telegram Resume + Bridge Bot

> 두 가지 모드 — **Resume**(세션을 새로 켜기) + **Bridge**(살아있는 세션을 폰으로 원격 조작)

**비유**:
- *Resume* = 카페 진동벨. 죽은 주문을 다시 부른다.
- *Bridge* = 사무실 PC 원격 데스크톱. PC는 안 끄고, 폰으로 키보드만 친다.

설계 근거:
- [`docs/design/telegram-resume-button.md`](../../docs/design/telegram-resume-button.md) — Resume 모드
- [`docs/design/telegram-bridge-mode.md`](../../docs/design/telegram-bridge-mode.md) — Bridge 모드 (이번 추가)

---

## Resume 모드

- `/sessions` — 최근 세션 리스트 + 프로젝트별 한 줄 버튼
- `/resume`   — 가장 최근 세션으로 바로 확인 화면
- Stop hook  — 세션 종료 시 `[ ↩️ 이 세션 이어서 작업 ]` 단일 버튼 알림
- 콜백 → `executor.sh` → tmux에 `claude --resume <uuid>` 송출
- Fork (`--fork-session`), Remote Control (`--remote-control`) 분기 지원

## Bridge 모드 (NEW)

**Mac에서 `/tg`를 치면** 그 순간부터 입출력이 Telegram으로 우회:

```
[Mac 터미널 / Claude Code 도중]
> /tg
↓ (UserPromptSubmit 훅이 가로챔)
🔌 Telegram bridge 활성화됨

[Telegram]
> 빌드 한번 돌려봐    ← 폰에서 입력
↓ (bot이 tmux send-keys로 주입)
[Mac tmux]
> 빌드 한번 돌려봐
↓ (Claude 응답 → jsonl 기록)
[bot이 jsonl tail에서 감지]
↓
[Telegram]
🤖 Claude: 빌드 시작합니다...
🔧 Bash: make build
✅ 빌드 성공

> /end  ← 종료 시
↓
🛑 Bridge 종료. Mac 터미널에서 계속하세요.
```

Claude 프로세스는 안 죽음 — MCP 서버·메모리 컨텍스트·tool 상태 그대로 유지.

---

## 빠른 시작 (5분)

### 1) 봇 생성

@BotFather에서 `/newbot` → 토큰 받기. 토큰을 봇과 채팅하면서 `/start`를 보내고:

```bash
curl "https://api.telegram.org/bot<TOKEN>/getUpdates" | jq '.result[0].message.chat.id'
```

본인의 chat_id가 출력됩니다.

### 2) 설치

```bash
cd scripts/telegram-resume
./install.sh
```

자동으로 처리되는 항목:
- `~/.claude-forge/telegram-resume/`에 봇 파일 복사
- Python venv 생성 + `requests` 설치
- `~/.claude/settings.json`의 Stop hook 등록
- macOS launchd 서비스 (`com.claudeforge.telegram-resume`) 등록

### 3) 토큰 설정

```bash
$EDITOR ~/.claude-forge/telegram-resume/.env
```

```ini
TELEGRAM_BOT_TOKEN=1234567890:ABCdef...
TELEGRAM_CHAT_IDS=987654321
```

### 4) 봇 재시작

```bash
launchctl kickstart -k "gui/$UID/com.claudeforge.telegram-resume"
tail -f ~/.claude-forge/telegram-resume/logs/bot.out.log
```

### 5) 동작 확인

Telegram에서 봇에게 `/sessions` 전송. 최근 세션 리스트가 보이면 성공.

---

## 옵션 — 수동 실행 (launchd 없이)

```bash
cd ~/.claude-forge/telegram-resume
set -a; . ./.env; set +a
./venv/bin/python bot.py
```

---

## 파일 구조

```
scripts/telegram-resume/
├── README.md                                # 이 문서
├── bot.py                                   # 메인 long-polling 봇 (Resume + Bridge 통합)
├── bridge.py                                # Bridge 상태머신 (jsonl tail + tmux inject)
├── keyboard.py                              # InlineKeyboard 빌더
├── sessions.py                              # 세션 메타 로더
├── executor.sh                              # Resume: tmux 송출
├── notify.sh                                # 재사용 가능 Telegram 알림 송신기
├── install.sh                               # 설치 자동화
├── requirements.txt                         # requests
├── .env.example                             # 환경변수 템플릿
└── systemd/
    └── com.claudeforge.telegram-resume.plist  # launchd 템플릿

hooks/
├── telegram-resume-notify.sh                # Stop hook (Resume 알림 + Bridge 자동 정리)
└── handoff-telegram.sh                      # UserPromptSubmit 훅 (/tg 트리거)
```

---

## 콜백 라우팅

| callback_data              | 동작                                  |
|----------------------------|--------------------------------------|
| `cf:resume:latest`         | 최근 세션 확인 화면                    |
| `cf:resume:<uuid>`         | 특정 세션 확인 화면                    |
| `cf:exec:r:<short>`        | `claude --resume <uuid>` (tmux)      |
| `cf:exec:f:<short>`        | `... --fork-session`                 |
| `cf:exec:rc:<short>`       | `... --remote-control`               |
| `cf:list:page=N`           | 페이지네이션                           |
| `cf:list:refresh`          | 리스트 새로고침                        |
| `cf:cancel`                | 확인 취소                              |
| `cf:settings`              | 설정 표시                              |

UUID 짧은 형태(`<short>` = 첫 8자)는 64-byte callback 한도 안에서 모드 + UUID + prefix를 한 번에 보내기 위한 것. 봇은 prefix로 full UUID를 다시 찾아 실행합니다.

## Bridge 모드 — 사용법

### 1) Mac에서 시작

Claude Code 세션 도중, **tmux 안에서** 다음 중 하나를 입력:

```
/tg
/handoff-tg
>>tg
```

UserPromptSubmit 훅이 가로채서:
- `~/.claude-forge/telegram-resume/state/bridge.json` 작성
- Telegram에 "🔌 Bridge 시작" 알림 발송
- exit 2 — 이 prompt는 Claude로 가지 않음

### 2) Telegram에서 작업

봇과의 채팅에서:
- **일반 텍스트** → Mac tmux로 `send-keys`로 주입 (= Claude 입력)
- `/bridge` → 현재 bridge 상태 표시
- `/end` → bridge 종료, Mac 터미널 사용 가능

### 3) 종료 조건

세 가지 자동 종료:
- Telegram에서 `/end`
- Mac 세션이 종료될 때 (Stop hook이 자동 정리)
- 90분 idle (`TELEGRAM_BRIDGE_MAX_IDLE_MIN`)

### Bridge 상태 파일 protocol

```json
{
  "active": true,
  "session_uuid": "9e85e278-...",
  "jsonl_path": "/Users/.../9e85e278-....jsonl",
  "tmux_target": "claude-9e85e278:0.0",
  "chat_id": "987654321",
  "project_name": "Darwin",
  "git_branch": "feature/v1.1",
  "started_at": "2026-05-17T05:30:00Z",
  "last_activity_at": "2026-05-17T05:32:11Z",
  "jsonl_size_at_start": 524288
}
```

봇은 매 polling 사이클마다 이 파일의 mtime을 확인하고, 변경되면 reload. 봇 재시작에도 자동 복구됩니다 (단, `jsonl_size_at_start`로 과거 응답 replay는 방지).

---

## 보안

- `TELEGRAM_CHAT_IDS` allowlist 외부에서 온 메시지는 즉시 거부
- 봇은 long-polling 방식 — 외부 webhook 노출 없음
- 토큰은 `~/.claude-forge/telegram-resume/.env`에만 저장 (Git에 커밋되지 않음)
- 모든 명령은 본인 머신의 `executor.sh`에서만 실행 — SSH/원격 진입 없음
- Stop hook은 토큰 미설정 시 silent no-op — 세션을 막지 않음

---

## 검증 — 수동 dry-run

봇을 실행하지 않고 컴포넌트만 점검:

```bash
# 1) 세션 인덱서 점검
python3 sessions.py

# 2) 키보드 렌더링 점검 (JSON 출력)
python3 keyboard.py

# 3) executor.sh 시뮬레이션 — 실제 tmux 실행 없음
DRY_RUN=1 ./executor.sh resume <session-uuid>

# 4) Stop hook 단독 점검 — 실제 메시지 발송 없음
echo '{"session_id":"...","cwd":"/tmp","transcript_path":"..."}' \
  | TELEGRAM_BOT_TOKEN= TELEGRAM_CHAT_IDS= \
    ../../hooks/telegram-resume-notify.sh
```

---

## 제거

```bash
./install.sh --uninstall
```

launchd 서비스가 unload되고 plist가 삭제됩니다. Stop hook 항목은 `~/.claude/settings.json`에서 수동으로 지워주세요.

---

## 알려진 한계

- macOS 전용 (launchd). Linux는 systemd unit을 직접 작성해야 합니다.
- 봇이 동작 중인 머신에서만 세션 재개가 가능 — 멀티 머신 라우팅은 미지원.
- iTerm2 native panes 대신 plain tmux 사용 — `claude --tmux` 호환성은 별도 작업.

설계 문서의 "Standard / Full" 단계를 참고해 확장할 수 있습니다.
