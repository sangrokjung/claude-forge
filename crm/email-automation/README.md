# CRM Email Automation CLI

CSV 고객 데이터를 읽어 세그먼트별 맞춤 안내메일 텍스트 파일을 자동 생성합니다.

## 설치

```bash
cd crm/email-automation
uv sync
```

## 사용법

```bash
# 기본 실행 (data/customers.csv → out/emails/)
uv run python -m email_automation.cli

# 파일 경로 지정
uv run python -m email_automation.cli -i data/customers.csv -o out/emails

# 특정 세그먼트만 필터링
uv run python -m email_automation.cli -s enterprise

# 미리보기 (파일 생성 없이)
uv run python -m email_automation.cli --dry-run
```

## CLI 옵션

| 옵션 | 단축 | 설명 | 기본값 |
|------|------|------|--------|
| `--input` | `-i` | CSV 파일 경로 | `data/customers.csv` |
| `--output` | `-o` | 출력 디렉토리 | `out/emails` |
| `--segment` | `-s` | 세그먼트 필터 (`enterprise`/`startup`/`individual`) | 전체 |
| `--dry-run` | | 실제 파일 생성 없이 미리보기 | - |

## CSV 형식

필수 컬럼: `company`, `contact`, `email`, `segment`, `phone`, `position`

```csv
company,contact,email,segment,phone,position
삼성전자,김철수,cs.kim@samsung.com,enterprise,02-1234-5678,CTO
넥스트유니콘,정하나,hana@nextunicorn.kr,startup,010-1111-2222,CEO
김지원,김지원,jiwon.kim@gmail.com,individual,010-5555-6666,프리랜서
```

### 세그먼트별 메일 톤

- **enterprise**: 격식체, 맞춤 솔루션 + 전담 매니저 강조
- **startup**: 성장 지원, 스케일링 + 인프라 크레딧 강조
- **individual**: 친근한 톤, 1:1 맞춤 + 무료 체험 강조

## 테스트

```bash
uv run pytest -v
```
