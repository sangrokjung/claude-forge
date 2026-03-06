# Mobility RFP Monitor

K-Startup 공고 및 나라장터(입찰/사전규격) OpenAPI를 조회하여
모빌리티·MaaS 관련 항목만 필터링하고, 신규 항목을 Slack으로 알림하는 CLI 도구.

## 설치

```bash
cd gov-monitoring/mobility-rfp-monitor
uv sync
```

## 환경변수

| 변수 | 용도 | 필수 |
|------|------|------|
| `DATA_GO_KR_API_KEY` | [공공데이터포털](https://www.data.go.kr/) 서비스키 | O |
| `SLACK_WEBHOOK_URL` | [Slack Incoming Webhook](https://api.slack.com/messaging/webhooks) URL | `--dry-run` 아닐 때 |

### API 키 발급

1. [공공데이터포털](https://www.data.go.kr/) 회원가입
2. 아래 API 활용 신청:
   - K-Startup 공고정보 서비스
   - 나라장터 입찰공고 조회 서비스
   - 나라장터 사전규격 조회 서비스
3. 발급받은 서비스키를 `DATA_GO_KR_API_KEY`로 설정

### Slack Webhook 설정

1. [Slack API](https://api.slack.com/apps) → Create New App
2. Incoming Webhooks 활성화 → Add New Webhook to Workspace
3. 발급된 URL을 `SLACK_WEBHOOK_URL`로 설정

## 사용법

```bash
# 기본 실행 (24시간 이내, 전체 소스, Slack 알림)
uv run python -m mobility_rfp_monitor

# Slack 없이 결과만 확인
uv run python -m mobility_rfp_monitor --dry-run

# K-Startup만 조회
uv run python -m mobility_rfp_monitor --source kstartup --dry-run

# 나라장터만 48시간 범위로 조회
uv run python -m mobility_rfp_monitor --source g2b --since-hours 48 --dry-run
```

## CLI 옵션

| 옵션 | 기본값 | 설명 |
|------|--------|------|
| `--since-hours` | `24` | 조회 범위 (시간) |
| `--source` | `all` | 조회 소스: `kstartup`, `g2b`, `all` |
| `--dry-run` | `false` | Slack 알림 없이 매칭 결과만 출력 |
| `--state-file` | `.state.json` | 중복 방지 상태 파일 경로 |

## 자동 스케줄링 (cron)

```bash
# 6시간마다 실행
0 */6 * * * cd /path/to/mobility-rfp-monitor && DATA_GO_KR_API_KEY=xxx SLACK_WEBHOOK_URL=xxx uv run python -m mobility_rfp_monitor
```

## 테스트

```bash
uv run pytest -v
```

## 아키텍처

```
cli.py          # argparse CLI 진입점
  → client.py   # httpx 기반 API 클라이언트 (K-Startup, 나라장터)
  → filter.py   # 키워드 필터링 (keywords.py의 60+ 키워드)
  → state.py    # .state.json 기반 중복 방지 (불변 State)
  → notifier.py # Slack Block Kit 알림
```

흐름: **fetch → filter keywords → filter unseen → notify → save state**
