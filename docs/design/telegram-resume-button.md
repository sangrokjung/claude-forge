# Telegram "세션 이어서 작업" 버튼 설계

> **결론 먼저**: Telegram inline keyboard에 세션 목록을 표시하고, 사용자가 한 번의 탭으로 `claude --resume <UUID>`를 원격 머신에서 실행할 수 있게 한다. 핵심은 **(1) 보기 좋은 세션 카드 + (2) 안전한 콜백 라우팅 + (3) 즉시 재진입 경로** 세 가지.

비유: 식당 진동벨처럼, 카페에서 "주문 다시 부르기" 버튼을 누르면 매장 안 단말기가 주문을 재호출한다. 사용자는 어디서든 누르고, 실제 실행은 매장(=개발 머신)에서 일어난다.

---

## 1. UX — 사용자가 보는 화면

### 1.1 메인 화면 (세션 리스트)

```
┌─────────────────────────────────────────┐
│ 🤖 Claude Code · 세션 이어서 작업          │
│ ─────────────────────────────────────── │
│ 최근 활성 세션 3개를 찾았습니다.            │
│                                          │
│ [ ⚡ 가장 최근 세션 이어서 작업 ]            │
│                                          │
│ ─── 프로젝트별 ──────────────────────── │
│ [ 🐢 Darwin · feature/v1.1-walklab     │
│    2분 전 · 108턴 · "빌드해서 PC에 설치" ] │
│                                          │
│ [ ⚙️ claude-forge · main                │
│    1시간 전 · 24턴 · "MCP 마이그레이션" ]   │
│                                          │
│ [ 🎨 design-lab · feat/landing-v3      │
│    어제 · 51턴 · "랜딩 페이지 v3" ]        │
│                                          │
│ ─────────────────────────────────────── │
│ [ 📋 전체 세션 ]  [ 🔍 검색 ]  [ ⚙️ 설정 ] │
└─────────────────────────────────────────┘
```

각 세션 카드 버튼 = 한 줄 inline button. 카드 내부 3줄 표시는 button label에 `\n`이 안 되므로 **상위 메시지 본문**에 카드 정보를 미리 렌더링하고, 버튼은 해당 카드의 "재개" 액션만 담당한다.

### 1.2 실제 Telegram 메시지 구조 (2-layer)

```
[메시지 본문 — Markdown]
🤖 *Claude Code · 세션 이어서 작업*

최근 활성 세션 3개를 찾았습니다.

*1. 🐢 Darwin* · `feature/v1.1-walklab`
   2분 전 · 108턴 · _"빌드해서 PC에 설치"_

*2. ⚙️ claude-forge* · `main`
   1시간 전 · 24턴 · _"MCP 마이그레이션"_

*3. 🎨 design-lab* · `feat/landing-v3`
   어제 · 51턴 · _"랜딩 페이지 v3"_

[Inline keyboard]
┌──────────────────────────────────────┐
│        ⚡ 가장 최근 이어서 작업          │  ← row 1: full width primary
├──────────────────────────────────────┤
│ ▶ 1. Darwin                          │
│ ▶ 2. claude-forge                    │  ← row 2~4: per-session
│ ▶ 3. design-lab                      │
├──────────────────────────────────────┤
│ 📋 전체     🔍 검색     ⚙️ 설정         │  ← row 5: utilities (3-column)
└──────────────────────────────────────┘
```

### 1.3 세션 선택 후 — 확인 화면

```
┌─────────────────────────────────────────┐
│ ▶ Darwin · feature/v1.1-walklab 이어가기 │
│ ─────────────────────────────────────── │
│ 마지막 메시지:                            │
│ > 최종적으로 지금까지 구현한 내용이…      │
│                                          │
│ 실행 위치: my-mac (192.168.1.42)         │
│ 워크트리: /Users/.../Darwin               │
│                                          │
│ [ ✅ 이어서 작업 ]  [ ❌ 취소 ]            │
│ [ 🍴 새 세션으로 fork ]                   │
│ [ 🖥️ Remote Control로 열기 ]              │
└─────────────────────────────────────────┘
```

확인 단계는 **선택적**. 자주 쓰는 사용자에겐 1탭으로 바로 실행하도록 설정에서 끌 수 있어야 한다.

---

## 2. 버튼 스펙 (JSON)

### 2.1 메인 세션 리스트 inline keyboard

```json
{
  "inline_keyboard": [
    [
      {
        "text": "⚡ 가장 최근 이어서 작업",
        "callback_data": "cf:resume:latest"
      }
    ],
    [
      {
        "text": "▶ 1. 🐢 Darwin · walklab",
        "callback_data": "cf:resume:9e7b2f3a-1c4d-4f8e-b2a1-d3e5f7a9c1b3"
      }
    ],
    [
      {
        "text": "▶ 2. ⚙️ claude-forge · main",
        "callback_data": "cf:resume:a3c1d8e7-5b6f-4d2a-9e8c-1f3b5d7a9c2e"
      }
    ],
    [
      {
        "text": "▶ 3. 🎨 design-lab · landing-v3",
        "callback_data": "cf:resume:b8d2e4f6-3a1c-5e7f-9b4d-2c6a8e1f3b5d"
      }
    ],
    [
      { "text": "📋 전체",  "callback_data": "cf:list:all:page=1" },
      { "text": "🔍 검색",  "switch_inline_query_current_chat": "resume " },
      { "text": "⚙️ 설정",  "callback_data": "cf:settings" }
    ]
  ]
}
```

### 2.2 확인 화면 keyboard

```json
{
  "inline_keyboard": [
    [
      { "text": "✅ 이어서 작업",    "callback_data": "cf:resume:exec:9e7b2f3a..." },
      { "text": "❌ 취소",          "callback_data": "cf:resume:cancel" }
    ],
    [
      { "text": "🍴 새 세션으로 fork", "callback_data": "cf:resume:fork:9e7b2f3a..." }
    ],
    [
      { "text": "🖥️ Remote Control로 열기", "callback_data": "cf:resume:rc:9e7b2f3a..." }
    ]
  ]
}
```

### 2.3 빠른 알림 위에 붙는 1-button (Stop hook → push notification)

세션 종료 직후 알림에 함께 보내는 **inline button 1개** — 가장 자주 쓰일 진입점.

```json
{
  "inline_keyboard": [
    [
      {
        "text": "↩️ 이 세션 이어서 작업",
        "callback_data": "cf:resume:9e7b2f3a-1c4d-4f8e-b2a1-d3e5f7a9c1b3"
      }
    ]
  ]
}
```

비유: 카톡 답장처럼, 알림을 받자마자 답할 수 있는 가장 짧은 경로.

---

## 3. callback_data 라우팅 규약

Telegram은 callback_data를 **최대 64바이트**로 제한한다. UUID는 36자라 여유가 있다.

### 3.1 콜백 prefix 표

| Prefix              | 의미                          | 예시                                  |
|---------------------|------------------------------|--------------------------------------|
| `cf:resume:latest`  | 가장 최근 세션 즉시 이어가기      | `cf:resume:latest`                   |
| `cf:resume:<UUID>`  | 특정 세션 선택 → 확인 단계로     | `cf:resume:9e7b2f3a-…`               |
| `cf:resume:exec:<UUID>` | 확인 후 실제 실행 트리거    | `cf:resume:exec:9e7b2f3a-…`          |
| `cf:resume:fork:<UUID>` | `--fork-session`으로 분기   | `cf:resume:fork:9e7b2f3a-…`          |
| `cf:resume:rc:<UUID>`   | `--remote-control` 모드로   | `cf:resume:rc:9e7b2f3a-…`            |
| `cf:resume:cancel`  | 확인 취소                     | `cf:resume:cancel`                   |
| `cf:list:all:page=N`| 전체 세션 페이지네이션         | `cf:list:all:page=2`                 |
| `cf:settings`       | 사용자 설정                    | `cf:settings`                        |

`cf:` namespace는 claude-forge의 다른 봇과 충돌하지 않도록 항상 prefix를 붙인다.

### 3.2 보안 — replay/spoof 방지

- callback_data에는 UUID만 노출(랜덤 UUID는 추측 불가).
- 봇은 **chat_id allowlist**로 본인만 호출하도록 제한 (`AUTHORIZED_CHAT_IDS` env).
- 실행 단계(`exec:*`)는 ngrok/타임아웃 토큰을 함께 검증 — 30초 안에 confirm 안 되면 무효화.

---

## 4. 실행 흐름 — 버튼 누르면 어떻게 되나

```
[Telegram 앱]
   │ 사용자가 [▶ 1. Darwin] 탭
   ▼
[Telegram Bot API → 자체 호스팅 webhook]
   │ {"callback_query": {"data": "cf:resume:9e7b...", "from": {"id": 5.daonplace}}}
   ▼
[webhook (FastAPI/Express 등, 사용자 머신 or VPS)]
   │ 1) chat_id allowlist 확인
   │ 2) UUID로 세션 메타 조회 (~/.claude/projects/<slug>/<uuid>.jsonl)
   │ 3) 확인 메시지 + keyboard 응답
   ▼
[사용자가 ✅ 이어서 작업 탭]
   │ callback_data: "cf:resume:exec:9e7b..."
   ▼
[webhook]
   │ 1) 워크트리 경로 확인 (~/.claude/projects/<slug>/PROJECT-METADATA.json)
   │ 2) tmux 새 창에 `cd <worktree> && claude --resume <uuid>` 송출
   │    또는 `--remote-control`로 별도 RC 세션 시작
   ▼
[개발 머신 tmux/iTerm]
   │ Claude Code 세션이 직전 상태로 재개됨
```

핵심: webhook은 사용자의 개발 머신에서 돌거나, VPS에서 SSH로 머신에 진입한다. 어느 쪽이든 **Telegram → webhook → tmux send-keys** 체인.

---

## 5. 구현 스니펫

### 5.1 Telegram 봇 — keyboard 생성 (Python)

```python
from telegram import InlineKeyboardButton, InlineKeyboardMarkup

def build_resume_keyboard(sessions: list[dict]) -> InlineKeyboardMarkup:
    """sessions = [{'uuid': str, 'project': str, 'branch': str, 'icon': str}, ...]"""
    rows = [
        [InlineKeyboardButton("⚡ 가장 최근 이어서 작업", callback_data="cf:resume:latest")]
    ]
    for i, s in enumerate(sessions[:5], start=1):
        label = f"▶ {i}. {s['icon']} {s['project']} · {s['branch']}"
        rows.append([
            InlineKeyboardButton(label[:60], callback_data=f"cf:resume:{s['uuid']}")
        ])
    rows.append([
        InlineKeyboardButton("📋 전체", callback_data="cf:list:all:page=1"),
        InlineKeyboardButton("🔍 검색", switch_inline_query_current_chat="resume "),
        InlineKeyboardButton("⚙️ 설정", callback_data="cf:settings"),
    ])
    return InlineKeyboardMarkup(rows)
```

### 5.2 webhook — 실제 실행 (Bash)

```bash
# ~/.claude-forge/telegram/resume-exec.sh
set -euo pipefail

UUID="$1"
WORKTREE="$(jq -r ".sessions[\"$UUID\"].cwd" ~/.claude/sessions-index.json)"

if [[ -z "$WORKTREE" || "$WORKTREE" == "null" ]]; then
  echo "Session $UUID not found" >&2; exit 2
fi

# 기존 tmux session이 있으면 attach, 없으면 새로 만들기
TMUX_NAME="claude-${UUID:0:8}"
if tmux has-session -t "$TMUX_NAME" 2>/dev/null; then
  tmux send-keys -t "$TMUX_NAME" "claude --resume $UUID" C-m
else
  tmux new-session -d -s "$TMUX_NAME" -c "$WORKTREE" \
    "claude --resume $UUID"
fi
```

### 5.3 Stop hook — 종료 시 알림에 버튼 첨부

```bash
# hooks/stop-telegram-resume-button.sh
SESSION_UUID="$(jq -r '.session_id' <<<"$PAYLOAD")"
LAST_MSG="$(jq -r '.last_user_message' <<<"$PAYLOAD" | head -c 80)"
PROJECT="$(basename "$PWD")"

curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  -H "Content-Type: application/json" \
  -d @- <<JSON
{
  "chat_id": "${TELEGRAM_CHAT_ID}",
  "text": "✅ *${PROJECT}* 세션 종료\n_${LAST_MSG}_",
  "parse_mode": "Markdown",
  "reply_markup": {
    "inline_keyboard": [[
      {"text": "↩️ 이 세션 이어서 작업", "callback_data": "cf:resume:${SESSION_UUID}"}
    ]]
  }
}
JSON
```

---

## 6. 디자인 토큰 (스타일 일관성)

| 요소         | 값                                            |
|-------------|----------------------------------------------|
| Primary CTA | `⚡ ...` + 첫 row 단독 배치                    |
| Per-session | `▶ N. <icon> <project> · <branch>` (1줄)      |
| Utility row | 3-column, 이모지 + 짧은 단어                   |
| Status hint | 메시지 본문에 Markdown으로 (버튼 안에는 X)     |
| 길이 제한    | 버튼 label 60자, callback_data 64바이트 이내   |

이모지 매핑(고정):
- ⚡ = 즉시 / 빠른 액션
- ▶ = 재생 / 재개
- 📋 = 전체 보기
- 🔍 = 검색
- ⚙️ = 설정
- ↩️ = 알림 → 직접 재개 (single-button shortcut)
- 🍴 = fork
- 🖥️ = Remote Control

---

## 7. 다음 단계 — 무엇을 만들 수 있나

이 설계는 **(a) 봇 백엔드**, **(b) Stop hook**, **(c) 세션 인덱스 수집기** 세 컴포넌트로 구현된다. 사용자가 원하는 범위에 따라:

1. **MVP (1~2시간)**: Stop hook + 단일 버튼 알림 (`↩️ 이 세션 이어서 작업`).
2. **Standard (반나절)**: 메인 리스트 + 확인 화면 + fork/RC 분기.
3. **Full (1일+)**: 검색, 페이지네이션, 멀티 머신 라우팅, Web App UI.

각 단계는 독립적으로 출시 가능. MVP만 있어도 "Telegram에서 세션 이어서 작업" 약속은 이미 지켜진다.
