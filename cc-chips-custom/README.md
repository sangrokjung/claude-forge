# CC CHIPS Custom Overlay

CC CHIPS 서브모듈 위에 덮어쓰는 커스텀 패치입니다.
`install.sh` 실행 시 자동 적용됩니다.

## 변경 내용

### engine.sh

| 항목 | 설명 |
|------|------|
| 모델 감지 | Opus 4.6, Sonnet 4.5, Haiku 4.5 패턴 추가 |
| 세션 ID | Chip 3에 키 아이콘 + 세션 ID 앞 8자 표시 |
| 캐시 히트율 | Chip 4 추가 - `cache_read / 전체 입력 토큰 × 100` |
| API 응답시간 | Chip 4 추가 - `total_api_duration_ms`를 초 단위로 표시 |

### themes/claude.sh

Stats 칩 색상 추가 (초록색 `#2E7D32`)

## Chip 레이아웃

```
[Chip 1: 폴더] [Chip 2: Git] [Chip 3: 모델+컨텍스트+비용+세션ID] [Chip 4: 캐시+API시간]
```

## 필요 폰트

Nerd Font 필수 (JetBrainsMono Nerd Font 권장)

### iTerm2 설정
Preferences > Profiles > Text > Font > `JetBrainsMono Nerd Font`

### Ghostty 설정
```
font-family = JetBrainsMono Nerd Font
```
