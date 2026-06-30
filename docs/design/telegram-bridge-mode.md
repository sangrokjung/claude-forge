# Telegram Bridge Mode — 살아있는 세션 원격 조작

> **결론 먼저**: Mac에서 돌고 있는 Claude Code 세션을 그대로 둔 채, 입출력만 Telegram으로 우회한다. 사용자가 Mac에서 `/tg` 또는 `>>tg`를 치면 그 순간부터 (1) Claude의 모든 응답이 Telegram으로 푸시되고, (2) Telegram에 친 메시지는 Mac의 tmux pane에 자동 주입된다. Claude 프로세스·MCP 서버·메모리 상태 모두 그대로 유지된다.

비유: 사무실에 켜둔 PC에 폰으로 원격 데스크톱 접속하는 것과 같다. PC는 안 끄고, 입력 장치만 폰으로 옮긴다. resume 모드(=PC를 새로 켜기)와 본질적으로 다르다.

---

## 1. 핵심 차이 — resume vs bridge

| 측면 | Resume 모드 (이전 구현) | Bridge 모드 (이번 구현) |
|------|----------------------|------------------------|
| Claude 프로세스 | 종료됐다가 다시 시작 | 계속 살아있음 |
| 세션 컨텍스트 | jsonl에서 재구성 | 메모리에 그대로 |
| MCP 서버 상태 | 재시작 (느림, 연결 끊김) | 유지 |
| 토글 시점 | 세션 종료 후 | 대화 도중 즉시 |
| 입력 경로 | Telegram → executor → 새 tmux | Telegram → 기존 tmux pane |
| 출력 경로 | 다음 resume까지 캐시 안 됨 | jsonl tail → 실시간 push |

---

## 2. 사용자 경험

### 2.1 핸드오프 시나리오

```
[Mac 터미널 / Claude Code 세션 도중]
> 사용자: /tg

[훅이 가로채서]
🔌 Telegram bridge 시작됨.
   세션: 9e85e278 (Darwin · feature/v1.1)
   tmux: claude-9e85e278
   Telegram에서 계속 작업하세요. '/end' 로 종료.

[사용자가 Mac을 떠나서 Telegram 열기]
[Telegram]
🔌 *Bridge 모드 활성*
   세션: Darwin · feature/v1.1
   "이 세션의 응답이 여기로 push됩니다. 메시지 입력 = Mac으로 주입."

[사용자가 Telegram에서 입력]
> 사용자: 빌드 한번 돌려봐
   ↓ (bot이 tmux send-keys로 주입)
[Mac tmux pane]
> 빌드 한번 돌려봐
   ↓ (Claude가 응답 — jsonl에 기록됨)
[bot이 jsonl tail에서 새 assistant entry 감지]
   ↓
[Telegram]
🤖 *Claude*
빌드 시작합니다...
🔧 _Bash_: make build
✅ 빌드 성공 (0 errors)

[사용자가 Telegram에서 계속 작업...]
[작업 끝나면]
> 사용자: /end
[Telegram]
🛑 Bridge 종료. Mac 터미널에서 계속하세요.

[Mac 터미널에서 다시 입력 가능 — 세션은 그대로]
```

### 2.2 트리거 방식

**Mac → bridge 시작**:
| 트리거 | 동작 | 사용 시점 |
|-------|------|---------|
| `/tg` · `/handoff-tg` · `>>tg` | bridge 모드 진입 | PC에서 출발할 때 |

**Mac → bridge 종료 (NEW — PC 복귀 시 깔끔하게)**:
| 트리거 | 동작 |
|-------|------|
| `/tg-end` · `/end-tg` · `/handoff-end` | 상태 파일 삭제 + Telegram에 종료 알림 |

**Telegram → 종료**:
| 트리거 | 동작 |
|-------|------|
| `/end` · `/stop` · `/handoff-end` | bot이 직접 처리 |

`>>tg <메시지>` 형태로 보내도 메시지 내용은 현재 버려짐 (후속 작업 후보).

---

## 3. 아키텍처

```
┌──────────────────────────────────────────────────────────────────┐
│                          Mac                                       │
│                                                                    │
│  ┌────────────────┐         ┌──────────────────────────────────┐ │
│  │  tmux pane     │◄──────► │     Claude Code (running)         │ │
│  │  'claude-xxx'  │ send-   │  ~/.claude/projects/.../uuid.jsonl │ │
│  └────────┬───────┘  keys   └──────────┬───────────────────────┘ │
│           │                            │ append-only writes        │
│           │                            ▼                            │
│           │                  ┌──────────────────────┐              │
│           │                  │   bridge.py (in bot) │              │
│           │                  │  - jsonl tail        │              │
│           │                  │  - tmux send-keys    │              │
│           │                  │  - state machine     │              │
│           └◄─────────────────┤  - Telegram I/O      │              │
│                              └──────────┬───────────┘              │
│                                         │ getUpdates / sendMessage │
└─────────────────────────────────────────┼──────────────────────────┘
                                          │
                                          ▼
                              ┌────────────────────────┐
                              │   api.telegram.org     │
                              └────────────────────────┘
                                          ▲
                                          │
                              ┌────────────────────────┐
                              │   사용자 폰 / Telegram   │
                              └────────────────────────┘
```

핵심 트릭:
- **출력 캡처**: tmux 화면을 파싱하지 않고 **jsonl 파일을 tail** 한다 — ANSI 코드/스피너 없이 구조화된 데이터.
- **입력 주입**: tmux의 `send-keys`로 Claude의 입력 prompt에 직접 친다 — 단순/안정적.
- **상태**: `~/.claude-forge/telegram-resume/state/bridge.json`에 저장 — 봇 재시작 시 자동 복구.

---

## 4. 핸드오프 protocol

### 4.1 Mac → bridge 시작

UserPromptSubmit 훅이 `/tg`를 가로채면:

1. 현재 세션의 `session_id`, `cwd`, `tmux $TMUX` 환경에서 target 추출
2. `~/.claude-forge/telegram-resume/state/bridge.json` 작성:
   ```json
   {
     "active": true,
     "session_uuid": "9e85e278-...",
     "jsonl_path": "/Users/.../9e85e278-....jsonl",
     "tmux_target": "claude-9e85e278",
     "chat_id": "987654321",
     "started_at": "2026-05-17T05:30:00Z",
     "jsonl_size_at_start": 524288
   }
   ```
3. Telegram에 시작 알림 메시지 전송
4. 훅이 exit 2 — Claude는 이 prompt를 받지 않음

### 4.2 bot.py — bridge tick

매 폴링 사이클마다 (`poll_loop` 안):

```python
def bridge_tick():
    bridge.load_state_if_changed()
    if not bridge.is_active(): return
    new_lines = bridge.tail_jsonl()
    for line in new_lines:
        entry = json.loads(line)
        if entry.get("type") == "assistant":
            text = format_assistant(entry)
            send_message(bridge.chat_id, text)
```

### 4.3 Telegram → tmux 주입

bot.py가 텍스트 메시지를 받았을 때:

```python
def handle_text(chat_id, text):
    if text.startswith("/"):
        return handle_command(chat_id, text)
    if bridge.is_active():
        return bridge.inject(text)
    # else: 기본 세션 리스트
```

inject 구현:
```python
def inject(self, text):
    subprocess.run([
        "tmux", "send-keys",
        "-t", self.tmux_target,
        text, "Enter",
    ])
```

### 4.4 bridge 종료

세 가지 종료 경로:
- **Telegram에서 `/end`**: bot.py가 상태 파일 삭제 + 종료 알림
- **Mac 터미널에서 `/tg-end`**: 별도 훅 또는 사용자가 직접 상태 파일 삭제
- **세션 종료** (Claude exit): Stop 훅이 상태 파일 자동 정리

---

## 5. Edge cases

| 케이스 | 처리                                                    |
|-------|--------------------------------------------------------|
| tmux 없는 터미널 (Terminal.app, iTerm2 단독) | 훅이 친절한 에러 메시지, bridge 거부 |
| jsonl 파일 회전·삭제 | 상태 파일에 `jsonl_size_at_start` 기록; 줄어들면 reset |
| 봇 재시작 (launchd kickstart) | 상태 파일에서 복구, jsonl 위치는 현재 size로 reset |
| 두 chat에서 동시 `/tg` | 마지막 호출자만 활성 — 이전 chat에 "다른 곳에서 인계됨" 알림 |
| 메시지가 너무 길어 4096자 초과 | 4000자씩 split, "(1/3) ..." 헤더 |
| 어시스턴트 응답에 코드 블록 | Markdown 그대로 — Telegram이 ``` 렌더링 |
| Tool 사용 | `🔧 _tool_name_` 한 줄 요약 (전체 호출은 noisy) |
| 사용자가 Mac 터미널에서도 친 메시지 | jsonl에 type=user로 기록 — bridge는 무시 (피드백 루프 방지) |
| 토큰 미설정 | 훅은 silent no-op, bot은 죽음 |

---

## 6. 보안 모델

| 항목 | 처리                                                |
|------|----------------------------------------------------|
| 누가 inject할 수 있나 | `TELEGRAM_CHAT_IDS` allowlist에 있는 chat만 |
| 토큰 노출 | `.env` 파일 only, git ignore |
| jsonl 읽기 권한 | 사용자 본인의 `~/.claude` 디렉토리만 |
| tmux 주입 권한 | 봇이 사용자 권한으로 실행 — 본인 머신만 |
| 종료 보장 | Stop 훅이 자동 정리, 무한 활성 방지 |

추가 보호: bridge가 90분 idle이면 자동 종료 (`BRIDGE_MAX_IDLE_MIN`).

---

## 7. 이번 구현 범위

- `bridge.py` 모듈 (jsonl tail + tmux inject + state)
- `bot.py` 통합 (poll 루프에 bridge_tick, 텍스트 라우팅)
- `handoff-telegram.sh` UserPromptSubmit 훅
- `/end`, `/bridge-status` 명령
- 상태 파일 protocol
- Stop 훅이 bridge 자동 정리

다음 라운드 후보 (이번 안 함):
- macOS 단축키 → `/tg` 자동 입력
- 음성 입력 (Telegram voice → STT → inject)
- 멀티 세션 동시 bridge
- iOS Shortcut 통합
