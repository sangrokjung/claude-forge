# 출력 JSON 스키마 상세

## 공통 아이템 스키마

모든 subagent가 동일한 아이템 스키마를 따른다.

```json
{
  "items": [
    {
      "id": "string (필수, 고유 ID: source-NNN 형식)",
      "source": "string (필수, subagent 이름)",
      "title": "string (필수, 1줄 제목)",
      "description": "string (필수, 상세 설명 3줄 이내)",
      "category": "auto | user | info (필수)",
      "priority": "high | medium | low (필수)",
      "action": "string (선택, 실행할 구체적 작업)",
      "files": ["string[] (선택, 관련 파일 절대경로)"],
      "metadata": "object (선택, subagent별 추가 데이터)"
    }
  ]
}
```

## 카테고리 정의

| 카테고리 | 의미 | 실행 방식 | 예시 |
|---------|------|----------|------|
| auto | 자동 실행 가능 | Phase 4에서 무조건 실행 | 타임스탬프 갱신, 통계 기록 |
| user | 사용자 선택 필요 | Phase 3에서 선택지 제시 | 스킬 생성, 코드 수정, instinct 생성 |
| info | 정보 제공만 | Phase 5 리포트에 포함 | 학습 포인트, 세션 통계 |

## 우선순위 정의

| 우선순위 | 의미 | 정렬 순서 |
|---------|------|----------|
| high | 즉시 처리 권장 | 1 (최상위) |
| medium | 시간 여유 있음 | 2 |
| low | 참고용 | 3 (최하위) |

## ID 규칙

- 형식: `{source_prefix}-{NNN}` (3자리 숫자)
- source별 prefix:
  - doc-updater → `doc-`
  - automation-scout → `scout-`
  - learning-extractor → `learn-`
  - followup-suggester → `followup-`
- 예: `doc-001`, `scout-003`, `learn-002`, `followup-005`

## 병합 결과 스키마 (duplicate-checker 출력)

```json
{
  "total_before_dedup": "number (중복 제거 전 항목 수)",
  "total_after_dedup": "number (중복 제거 후 항목 수)",
  "duplicates_removed": "number (제거된 중복 수)",
  "by_category": {
    "auto": "number",
    "user": "number",
    "info": "number"
  },
  "items": [
    "... 공통 아이템 스키마와 동일"
  ]
}
```

## 파일 출력 위치

```
/tmp/session-wrap/
├── context.md                          # Phase 0: 컨텍스트 요약
├── git-changes.txt                     # Phase 0: git diff 통계
├── changed-files.txt                   # Phase 0: 변경 파일 목록
├── recent-commits.txt                  # Phase 0: 최근 커밋
├── recent-observations.jsonl           # Phase 0: 관찰 데이터
├── recent-buffer.jsonl                 # Phase 0: 버퍼 데이터
├── inventory.json                      # automation-scout: 스킬 인벤토리
├── results/
│   ├── doc-updates.json               # Phase 1: doc-updater
│   ├── automation-patterns.json       # Phase 1: automation-scout
│   ├── learning-points.json           # Phase 1: learning-extractor
│   ├── followup-tasks.json            # Phase 1: followup-suggester
│   └── merged-actions.json            # Phase 2: duplicate-checker
├── session-wrap-followups.md           # Phase 5: 후속 작업 목록
└── skill-candidates.md                 # Phase 4: 스킬 후보 (있으면)
```

## 리포트 출력 형식

Phase 5에서 터미널에 표시하는 리포트:

```
## Session Wrap 완료

### 실행 결과
- 문서 업데이트: {N}건 완료
- 스킬 후보 기록: {M}건
- Instinct 생성: {K}건
- 후속 작업 기록: {L}건

### 건너뛴 항목
- 사용자가 선택하지 않음: {X}건
- 중복 제거됨: {Y}건

### 후속 작업 파일
/tmp/session-wrap/session-wrap-followups.md

### 스킬 후보 파일 (있으면)
/tmp/session-wrap/skill-candidates.md

### 다음 세션에서
`/context-sync`로 외부 채널 동기화를 시작하세요.
```
