# 현재 세션용 프롬프트

Claude Code 워크플로우용 복사-붙여넣기 프롬프트.

> ⚠️ 커스텀 명령어가 로드되지 않은 세션에서 복사-붙여넣기로 사용

---

## 워크플로우 순서

```
1. ORCHESTRATE (선택) → 2. 개발 → 3. HANDOFF → 4. /clear → 5. VERIFY → 6. SYNC-DOCS → 7. COMMIT-PUSH-PR
```

> **SYNC-DOCS가 COMMIT-PUSH-PR(머지)보다 먼저다** — 문서 동기화 변경분이 머지 커밋에 포함되어야 한다 (머지 전 의무 게이트, v7).

---

## 핵심 워크플로우 프롬프트

### ORCHESTRATE (선택)

```
Agent Teams로 병렬 개발을 시작해줘.

**타입**: feature / bugfix / refactor
**작업 설명**: [구현할 내용]

전제조건: CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 설정 필요
```

### HANDOFF

```
개발 세션 핸드오프 문서를 작성해줘.

1. git status로 변경사항 확인
2. .claude/handoff.md 생성:
   - 완료한 작업 (왜 이렇게 구현했는지)
   - 변경 파일 요약
   - 테스트 필요 사항
   - 알려진 이슈
   - 주의사항
3. 완료 후 "/clear 후 /verify 하세요" 안내
```

### VERIFY

```
개발 완료 후 검증을 진행해줘. think hard로 철저하게.

1. git status, git diff 확인
2. .claude/handoff.md, CLAUDE.md, spec.md 읽기
3. 코드 리뷰 (think hard):
   - 의도대로 구현됐는지
   - 로직 오류, 엣지 케이스
   - 보안 취약점
4. 빌드 & 테스트 & 린트 실행
5. 결과: Critical / Warning / Info 분류
6. 통과 시 handoff.md 삭제, "SYNC-DOCS → /commit-push-pr --merge" 안내
```

### SYNC-DOCS (머지 전 의무)

```
개발 문서를 동기화해줘. (커밋/머지 전에 실행 — 문서 변경분이 머지 커밋에 포함되도록)

1. git log --oneline -5로 최근 커밋 확인
2. prompt_plan.md: 완료 Task [ ] → [x]
3. spec.md: 변경된 스펙 반영
4. CLAUDE.md: 배운 규칙 추가
```

### COMMIT-PUSH-PR

```
검증 통과 후 커밋 & PR & 머지를 진행해줘.

**옵션**: --merge / --squash / --rebase / --draft / --no-verify / --skip-sync-docs(긴급 전용)

1. git status, branch 확인
2. main 브랜치면 경고
3. 빌드/테스트 검증 (--no-verify 없으면)
4. 문서 동기화 게이트: SYNC-DOCS 미실행 상태면 지금 실행 (머지 전 의무 — --skip-sync-docs 시에만 경고 후 스킵)
5. git add -A && git commit (Conventional Commits — 문서 동기화 변경분 포함)
6. git push
7. gh pr create
8. 옵션에 따라 gh pr merge
```

---

## Phase별 프롬프트

### Phase 1: 초기화

```
현재 프로젝트에 CLAUDE.md를 생성해줘.

포함: 개요, 기술 스택, 핵심 명령어 (dev/test/lint),
규칙 (TDD 필수, 주석 한국어), 금지 사항 (any, 하드코딩)
```

### Phase 2: 기획

**아이디어 구체화**:
```
나는 [서비스명]을 만들고 싶어.
스펙 문서를 위해 한 번에 하나씩 질문해줘.
파고들 항목: 핵심 기능, 데이터 모델, API, 예외 처리
```

**spec.md 생성**:
```
지금까지 논의를 바탕으로 spec.md 작성해줘.
포함: 목표, 핵심 기능(P0/P1), 데이터 모델, API 엔드포인트
```

**prompt_plan.md 생성**:
```
spec.md 기반으로 prompt_plan.md 만들어줘.
원칙: TDD, 1-2시간 단위 Task, Milestone 그룹화
```

### Phase 3: 구현 (TDD Loop)

**작업 시작**:
```
/clear
@spec.md @prompt_plan.md 읽어줘. Task [번호] 시작.
```

**테스트 작성 (Red)**:
```
구현 전에 요구사항 검증 테스트 작성해줘.
성공/예외/경계값 케이스 포함. 테스트 실패 확인해줘.
```

**기능 구현 (Green)**:
```
테스트 실패했어. 최소한의 코드로 통과시켜줘.
```

**리팩토링 & 커밋**:
```
테스트 통과. 품질 개선 리팩토링 후 'feat: [기능명]'으로 커밋해줘.
```

### Phase 4: 검증

**스펙 대조 감사**:
```
/clear
spec.md, prompt_plan.md와 소스 코드를 ultrathink로 재검토해.
완료 항목이 실제 구현됐는지, 스펙과 일치하는지 확인.
수정하지 말고 리포트만.
```

**코드 리뷰**:
```
/clear
시니어 개발자로서 코드 리뷰해줘.
검토: 보안, 성능, 가독성, spec.md 일치 여부
이슈를 Critical/Major/Minor로 분류.
```

### Phase 5: 배포

```
/security-review
배포 전 최종 점검: 전체 테스트, 린트, 타입 체크, README 최신화
```

---

## Think 키워드

### think (단순 에러)
```
/clear
이 에러의 원인을 think 해서 찾아줘:
[에러 로그]
```

### think hard (복잡한 에러)
```
/clear
이 에러를 think hard 해서 분석해줘:
[에러 로그]

바로 수정하지 말고 근본 원인 분석 → 재현 테스트 → 수정
```

### ultrathink (아키텍처)
```
/clear
이 시스템 설계를 ultrathink 해서 검토해줘.
구조적 결함, 확장성, 성능 병목 분석. 수정하지 말고 리포트만.
```

---

## Sub-agents

### Explore 에이전트
```
Launch explore agent with Sonnet 4.5
```

### 병렬 코드베이스 검색
```
10개의 병렬 sub-agents로 repo를 검색해서 포괄적인 문서 생성해줘.
```

---

## Playwright 테스트

### 테스트 계획 (Planner)
```
@playwright-test-planner
[페이지 URL]에 대한 테스트 시나리오를 작성해줘.
포함: 핵심 기능 검증, 에러 상태, 반응형 레이아웃
specs/ 폴더에 마크다운으로 저장.
```

### 의존성 그룹화
```
specs/[파일명].md의 시나리오를 분석해서
의존성이 겹치지 않는 그룹으로 나눠줘.
```

### 테스트 생성 (병렬)
```
그룹별로 병렬로 에이전트를 띄워서 테스트 코드를 작성해줘.
최대 10개까지 병렬 실행. seed.spec.ts의 fixture 활용.
```

### 실패 테스트 수정 (Healer)
```
npx playwright test 실패한 테스트들을 확인해줘.
실패한 파일별로 힐러 에이전트를 병렬로 띄워서 수정 + 검증해줘.
```
