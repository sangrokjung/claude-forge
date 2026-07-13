---
allowed-tools: Read, Write, Grep, Glob, Bash(git:*)
description: 머지 후 웹 테스트 체크리스트 + 완료 추적 (v6)
argument-hint: "[--auto-from-handoff] [--detailed] [--save] [--status] [--complete ID]"
---

## Task

### 0단계: 컨텍스트 수집

```bash
git log --oneline -3
git diff HEAD~1 --name-only
git diff HEAD~1 --stat
git branch --show-current
```

다음 파일 읽기 (있는 것만):
- `.claude/handoff.md` - 개발 의도, 테스트 필요 사항
- `spec.md` - 기능 요구사항
- `prompt_plan.md` - Task 상세
- `.claude/web-checklist-state.json` - 기존 체크리스트 상태

---

### 0.5단계: 플래그 분기

**`--status` 플래그 → 상태 조회 모드:**

`.claude/web-checklist-state.json` 읽기:

**파일 있으면:**
```
════════════════════════════════════════════════════════════════
📋 Web Checklist Status (v6)
════════════════════════════════════════════════════════════════

📅 생성: [created timestamp]
📌 커밋: [commit hash]
🌿 브랜치: [branch name]

진행률: [completion]% ([done]/[total])

## 미완료 항목
- [ ] [ID: N] [category] [text]
- [ ] [ID: N] [category] [text]
...

## 완료 항목
- [x] [ID: N] [category] [text]
- [x] [ID: N] [category] [text]
...

완료 처리: /web-checklist --complete [ID]
════════════════════════════════════════════════════════════════
```
→ 종료

**파일 없으면:**
```
ℹ️ 저장된 체크리스트가 없습니다.

생성: /web-checklist --save
```
→ 종료

---

**`--complete ID` 플래그 → 항목 완료 모드:**

`.claude/web-checklist-state.json` 읽기:

**해당 ID 찾으면:**
- `items[ID].done` → `true` 로 변경
- `completion` 재계산
- 파일 저장

```
✅ 체크리스트 항목 완료

  [ID]: [text] → ✅ Done

진행률: [new completion]% ([done]/[total])

남은 항목: [remaining count]개
전체 완료 시: /sync-docs
```
→ 종료

**해당 ID 없으면:**
```
❌ ID [N]을 찾을 수 없습니다.

유효한 ID: [사용 가능한 ID 목록]
상태 확인: /web-checklist --status
```
→ 종료

---

### 1단계: 변경 영역 분석

**변경된 파일 카테고리별 분류:**
| 카테고리 | 파일 패턴 | 테스트 영역 |
|----------|-----------|-------------|
| UI/화면 | `*.tsx`, `*.jsx`, `components/*` | 화면 표시, 반응형, 인터랙션 |
| API/서버 | `api/*`, `server/*`, `*.ts` | 엔드포인트, 응답 |
| 인증 | `auth/*`, `login/*`, `session/*` | 로그인, 로그아웃, 권한 |
| 결제 | `payment/*`, `billing/*` | 결제 플로우, 금액 |
| 데이터 | `*.sql`, `supabase/*`, `db/*` | 데이터 정합성 |
| 스타일 | `*.css`, `*.scss`, `tailwind.*` | 레이아웃, 디자인 |

### 2단계: 테스트 체크리스트 생성

**handoff.md의 "테스트 필요 사항" 참조해서 구체화.**

**UI 변경 시:**
- [ ] 화면이 정상적으로 렌더링되는지
- [ ] 반응형 (모바일/태블릿/데스크톱) 확인
- [ ] 로딩 상태 표시 확인
- [ ] 에러 상태 표시 확인
- [ ] 빈 상태(empty state) 표시 확인

**인증 관련 변경 시:**
- [ ] 로그인 플로우 정상 동작
- [ ] 로그아웃 정상 동작
- [ ] 세션 만료 시 동작
- [ ] 권한별 접근 제어 확인

**결제 관련 변경 시:**
- [ ] 테스트 결제 진행 (sandbox)
- [ ] 결제 금액 정확성
- [ ] 결제 실패 케이스 처리
- [ ] 결제 완료 후 상태 업데이트

**API 변경 시:**
- [ ] 엔드포인트 호출 정상 동작
- [ ] 응답 데이터 형식 확인
- [ ] 에러 응답 처리 확인
- [ ] 권한 체크 동작

**데이터 변경 시:**
- [ ] 기존 데이터 정합성 유지
- [ ] 새 데이터 저장 정상
- [ ] 데이터 조회 정상

### 3단계: 환경별 체크리스트

**개발 환경 (localhost):**
- [ ] 기능 기본 동작 확인
- [ ] 콘솔 에러 없음

**스테이징 환경 (있으면):**
- [ ] 배포 후 기능 동작 확인
- [ ] 실제 데이터베이스 연동 확인

**프로덕션 환경:**
- [ ] 배포 완료 확인
- [ ] 크리티컬 기능 동작 확인
- [ ] 에러 모니터링 (Sentry 등) 확인

### 4단계: 출력

```
════════════════════════════════════════════════════════════════
📋 Web Checklist (v6)
════════════════════════════════════════════════════════════════

🔧 변경 영역: [카테고리 목록]

📝 테스트 항목:

## 기능 확인
- [ ] [ID:1] [handoff.md 기반 테스트 항목 1]
- [ ] [ID:2] [handoff.md 기반 테스트 항목 2]
- [ ] ...

## UI 확인
- [ ] [ID:N] [UI 관련 체크 항목]
- [ ] ...

## 환경별 확인

### localhost (http://localhost:3000)
- [ ] [ID:N] 기능 동작 확인
- [ ] [ID:N] 콘솔 에러 없음

### 프로덕션 ([프로덕션 URL])
- [ ] [ID:N] 배포 완료 확인
- [ ] [ID:N] 기능 동작 확인

────────────────────────────────────────────────────────────────
⚠️ 주의 사항:
- [handoff.md의 "주의사항" 내용]

💡 테스트 팁:
- 시크릿/프라이빗 모드에서 테스트 권장
- 여러 브라우저에서 확인 권장 (Chrome, Safari)
────────────────────────────────────────────────────────────────

완료 추적:
  • /web-checklist --complete [ID] - 항목 완료 처리
  • /web-checklist --status - 진행 상황 확인

다음 단계:
  • 모든 항목 확인 후: /sync-docs
  • 이슈 발견 시: 새 브랜치에서 수정 또는 /orchestrate --type bugfix
════════════════════════════════════════════════════════════════
```

### 5단계: 체크리스트 저장

**`--save` 옵션 있으면 (또는 기본 동작으로 항상 저장):**

`.claude/web-checklist-state.json` 생성/업데이트:

```json
{
  "version": "v6",
  "created": "[ISO 8601 timestamp]",
  "commit": "[HEAD commit hash]",
  "branch": "[branch name or merged-from branch]",
  "items": [
    {"id": 1, "category": "기능", "text": "[항목 텍스트]", "done": false},
    {"id": 2, "category": "UI", "text": "[항목 텍스트]", "done": false},
    {"id": 3, "category": "API", "text": "[항목 텍스트]", "done": false},
    {"id": 4, "category": "환경-localhost", "text": "[항목 텍스트]", "done": false},
    {"id": 5, "category": "환경-production", "text": "[항목 텍스트]", "done": false}
  ],
  "completion": "0%",
  "warnings": ["[handoff.md 주의사항]"]
}
```

```
💾 체크리스트 저장됨: .claude/web-checklist-state.json

항목 완료 처리: /web-checklist --complete [ID]
진행 상황 확인: /web-checklist --status
```

---

## 사용 예시

```bash
# 기본 사용 (머지 후)
/web-checklist

# handoff.md 기반 자동 생성
/web-checklist --auto-from-handoff

# 상세 체크리스트
/web-checklist --detailed

# 저장 (상태 파일 생성)
/web-checklist --save

# 진행 상황 확인
/web-checklist --status

# 특정 항목 완료 처리
/web-checklist --complete 3

# 상세 + 저장
/web-checklist --detailed --save
```

## 통합: /commit-push-pr 연동

`/commit-push-pr --merge` 완료 후 자동으로 다음 안내:

```
다음 단계:
  /web-checklist - 웹 테스트 체크리스트 확인
  /web-checklist --status - 진행 상황 확인
  /sync-docs - 문서 동기화
```

## 상태 파일 관리

### 파일 위치
`.claude/web-checklist-state.json`

### 자동 정리
- 새 체크리스트 생성 시 이전 상태 파일 덮어쓰기
- 새 체크리스트 생성 시 이전 상태 덮어쓰기
- 수동 삭제: `rm .claude/web-checklist-state.json`

### 환경 독립성
- 체크리스트 상태는 로컬 `.claude/` 디렉토리에만 저장
- git에 커밋되지 않음 (`.claude/` 는 보통 .gitignore에 포함)
- 워크트리별로 독립적 상태 유지
