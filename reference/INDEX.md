# 규칙 파일 인덱스

`~/qjc-office/dotclaude/rules/` (자동 로드) 및 `~/qjc-office/dotclaude/reference/` (필요 시 Read) 파일 목록.

## 핵심 규칙 (rules/ - 매 세션 자동 로드)

| 파일 | 용도 | 크기 |
|------|------|------|
| ~/qjc-office/dotclaude/rules/coding-style.md | 불변성, 파일 구조, 에러 핸들링, 코드 품질 | 핵심 |
| ~/qjc-office/dotclaude/rules/interaction.md | 언어(한국어), 비유 설명, 결론 먼저, context7 사용 규칙 | 핵심 |
| ~/qjc-office/dotclaude/rules/security.md | 시크릿 관리, 보안 체크리스트, 보안 대응 프로토콜 | 핵심 |
| ~/qjc-office/dotclaude/rules/git-workflow-v2.md | 커밋 메시지 형식, PR 워크플로우, GitHub org 관리 | 핵심 |
| ~/qjc-office/dotclaude/rules/golden-principles.md | 핵심 원칙 12가지 + 합리화 방지 + 날짜 계산 | 핵심 |
| ~/qjc-office/dotclaude/rules/agents-v2.md | 에이전트 목록, 즉시 사용 규칙, 병렬 실행 패턴 | 핵심 |

## 도메인 규칙 (rules/ - 매 세션 자동 로드)

| 파일 | 용도 |
|------|------|
| ~/qjc-office/dotclaude/rules/supabase-mcp.md | Supabase MCP 사용 가이드 |
| ~/qjc-office/dotclaude/rules/email.md | 이메일 관련 규칙 |
| ~/qjc-office/dotclaude/rules/qjc-auto.md | QJC 자동화 관련 규칙 |
| ~/qjc-office/dotclaude/rules/personal-os.md | Personal OS 운영 규칙 (JSONL append-only, 모듈 접근 순서) |
| ~/qjc-office/dotclaude/rules/verification.md | 검증 완료 요구사항 (증거 기반 완료 강제) |
| ~/qjc-office/dotclaude/rules/session-recovery.md | 세션 복구 규칙 |
| ~/qjc-office/dotclaude/rules/session-summary.md | 세션 종료 시 작업 요약 기록 |
| ~/qjc-office/dotclaude/rules/document-production.md | 문서 제작 파이프라인 (MD→DOCX→PDF) |
| ~/qjc-office/dotclaude/rules/esign.md | 전자서명 CLI (quantum-sign) |
| ~/qjc-office/dotclaude/rules/image-generation.md | 이미지 생성 규칙 (Gemini, /generate-image) |
| ~/qjc-office/dotclaude/rules/remotion.md | Remotion 영상 제작 규칙 |
| ~/qjc-office/dotclaude/rules/video-production.md | 프리미어 프로 영상 편집 + FFmpeg + 자막 + 내보내기 거버넌스 |
| ~/qjc-office/dotclaude/rules/ralph-loop.md | 다중 턴 자율 작업 (Ralph Loop, /auto-loop) |
| ~/qjc-office/dotclaude/rules/receiving-review.md | 코드 리뷰 수신 프로토콜 |
| ~/qjc-office/dotclaude/rules/gws.md | Google Workspace CLI 트리거 + 인증 |
| ~/qjc-office/dotclaude/rules/scrapling.md | 웹 스크레이핑 에스컬레이션 + 트리거 |
| ~/qjc-office/dotclaude/rules/youtube-subtitle.md | 자막 추출 우선순위 + 트리거 |
| ~/qjc-office/dotclaude/rules/performance-marketing.md | 퍼포먼스 마케팅 트리거 + 도구 우선순위 |
| ~/qjc-office/dotclaude/rules/quotation.md | 견적서 트리거 + 에이전트 참조 |
| ~/qjc-office/dotclaude/rules/planning.md | 기획 에이전트 트리거 + 구루 12명 카탈로그 |
| ~/qjc-office/dotclaude/rules/patent-attorney.md | 변리사 에이전트 트리거 + 구루 10명 + AI 자동화 매트릭스 |
| ~/qjc-office/dotclaude/rules/contract-legal.md | 계약/법률 에이전트 트리거 + 구루 10명 + AI 자동화 매트릭스 |
| ~/qjc-office/dotclaude/rules/financial-accountant.md | 재무/회계 에이전트 트리거 + 구루 10명 + Profit First |
| ~/qjc-office/dotclaude/rules/storyteller.md | 스토리텔러 에이전트 트리거 + 구루 12명 + 연계 파이프라인 |
| ~/qjc-office/dotclaude/rules/research.md | 범용 연구 에이전트 트리거 + 라우팅 + 구루 5명 |
| ~/qjc-office/dotclaude/rules/google-trends.md | 구글 트렌드 조사 트리거 + google-trends-analyst/스킬 라우팅 + 429/해석 제약 |
| ~/qjc-office/dotclaude/rules/hr-manager.md | HR 에이전트 트리거 + 구루 10명 + 급여/노무 라우팅 |
| ~/qjc-office/dotclaude/rules/company-operations.md | **회사운영 오케스트레이션** 트리거 + 구루 10명 + 위임 매트릭스 + 세무일정/노란우산/창업혜택/고용지원 |
| ~/qjc-office/dotclaude/rules/answer-provenance.md | **답변 출처 추적** (Ouroboros §A10 채택) — 5종 prefix + Dialectic Rhythm Guard + Refine/Restate Gate |
| ~/qjc-office/dotclaude/rules/contract-engineering.md | **컨트랙트 엔지니어링** (Ouroboros §A2) — plan.md frontmatter YAML 표준 + AC verifier |
| ~/qjc-office/dotclaude/rules/memory-policy.md | **4계층 메모리 + 7일 decay** (Ouroboros §A6) — L1 영구 / L2 중기 / L3 단기 / L4 cache |
| ~/qjc-office/dotclaude/rules/pipeline-metrics.md | **brake 변수 시계열 측정** (Ouroboros §A4) — pipeline-metrics.jsonl 스키마 + rejection rate 분석 |

## 참조 문서 (reference/ - 필요 시 Read 도구로 접근)

| 파일 | 용도 | 참조 |
|------|------|------|
| [agents-teams-ref.md](./agents-teams-ref.md) | Agent Teams 상세: 전제조건, 규칙, 리더 규율, 팀원 관리 | agents-v2.md에서 분리 |
| [agents-config-ref.md](./agents-config-ref.md) | MCP 분배 패턴, Subagent 선택 가이드 | agents-v2.md에서 분리 |
| [agent-pipeline.md](./agent-pipeline.md) | 에이전트 호출 순서, 조건부 분기, 파이프라인 규칙 | agents-v2.md에서 참조 |
| [performance-marketing-ref.md](./performance-marketing-ref.md) | CLI 명령어, 구루 체크리스트, 의사결정 규칙, API 버전 | performance-marketing.md에서 분리 |
| [quotation-ref.md](./quotation-ref.md) | 견적서 필수 요소, 가격 산정, 할인 정책, 변환 절차 | quotation.md에서 분리 |
| [gws-ref.md](./gws-ref.md) | gws CLI 예시, 출력 형식, Workflow 헬퍼, 주의사항 | gws.md에서 분리 |
| [scrapling-ref.md](./scrapling-ref.md) | Scrapling CLI 옵션, 사용 패턴, Python 예시 | scrapling.md에서 분리 |
| [youtube-subtitle-ref.md](./youtube-subtitle-ref.md) | yt-dlp 명령어, 옵션, /youtube-search 연동 | youtube-subtitle.md에서 분리 |
| [planning-ref.md](./planning-ref.md) | 기획 구루 12명 프레임워크 상세, 의사결정 매트릭스 | planning.md에서 분리 |
| [patent-attorney-ref.md](./patent-attorney-ref.md) | 변리사 구루 10명 프레임워크, KIPRIS API, 청구항 기법 | patent-attorney.md에서 분리 |
| [contract-legal-ref.md](./contract-legal-ref.md) | 계약/법률 구루 10명 프레임워크, 법령/판례 API, 계약 템플릿 | contract-legal.md에서 분리 |
| [financial-accountant-ref.md](./financial-accountant-ref.md) | 재무/회계 구루 10명 프레임워크, 세무 캘린더, Profit First | financial-accountant.md에서 분리 |
| [storyteller-ref.md](./storyteller-ref.md) | 스토리텔링 구루 12명 프레임워크 상세, 감정 곡선, 자동화 매트릭스 | storyteller.md에서 분리 |
| [research-methodologies-ref.md](./research-methodologies-ref.md) | 범용 연구 구루 5명 프레임워크, API 소스, 방법론 상세 | research.md에서 분리 |
| [hr-manager-ref.md](./hr-manager-ref.md) | HR 구루 10명 프레임워크, 공공 API 명세, 급여 계산, 노무 체크리스트 | hr-manager.md에서 분리 |
| [company-operations-ref.md](./company-operations-ref.md) | **회사운영 구루 10명 프레임워크**, API 명세, 노란우산/창업혜택/고용지원 데이터, 자동화 파이프라인 | company-operations.md에서 분리 |
| [agent-catalog.md](./agent-catalog.md) | 에이전트 전체 카탈로그 | agents-v2.md에서 참조 |
| [parallel-agents-guide.md](./parallel-agents-guide.md) | 독립 작업 병렬 디스패치 가이드 | agents-v2.md에서 참조 |
| [testing-anti-patterns.md](./testing-anti-patterns.md) | 테스트 안티패턴 (mock 남용, test-only 메서드) | tdd-guide 에이전트에서 참조 |

## 파일 관계도

```
rules/ (자동 로드)
  agents-v2.md → reference/agents-teams-ref.md, agents-config-ref.md, agent-pipeline.md
  performance-marketing.md → reference/performance-marketing-ref.md
  quotation.md → reference/quotation-ref.md
  gws.md → reference/gws-ref.md
  scrapling.md → reference/scrapling-ref.md
  youtube-subtitle.md → reference/youtube-subtitle-ref.md
  planning.md → reference/planning-ref.md
  patent-attorney.md → reference/patent-attorney-ref.md
  contract-legal.md → reference/contract-legal-ref.md
  financial-accountant.md → reference/financial-accountant-ref.md
  storyteller.md → reference/storyteller-ref.md
  research.md → reference/research-methodologies-ref.md
  hr-manager.md → reference/hr-manager-ref.md
  company-operations.md → reference/company-operations-ref.md

reference/ (필요 시 Read)
```

## 스킬 활용 현황 (2026-02-22 기준)

### 활발 사용 (주 7회+)
commit-push-pr, dc, handoff-verify, worktree-start, sync-docs,
worktree-cleanup, web-checklist

### 간헐 사용 (주 1~6회)
learn, verify-loop, card-news, orchestrate, save-work, next-task

### 자동화 연결 대기
| 스킬 | 상태 | 차단 사유 |
|------|------|----------|
| continuous-learning-v2 | 훅 활성화 완료 (액션 1) | — |
| session-wrap | 연결됨 | session-end-suggest.sh (Stop 훅) |
| context-sync | 연결됨 | context-sync-suggest.sh (SessionStart 훅) |
| security-pipeline | 수동 호출 | handoff-verify --security로 간접 사용 |

### 수동 전용 (설계상 자동화 불가)
fix, security-review, frontend-code-review, codex-review, strategic-compact 등 30개

## 하네스 아키텍처 (v12, 2026-03-29)

| 문서 | 경로 | 역할 |
|------|------|------|
| **하네스 아키텍처** | `reference/harness-architecture.md` | 전체 시스템 구조 정의 (Anthropic 7대 원칙, PGE, /auto-ship, 셀프 임프루빙, 보안, 파이프라인 12개) |
| Anthropic 원전 분석 | `~/.claude/agent-memory/researcher/anthropic-harness-design-fulltext-2026.md` | 블로그 2편 완전판 분석 |
| 갭 분석 보고서 | `~/qjc-office/company-docs/reports/harness-deep-review-20260325.md` | Anthropic vs QJC 비교 |

## 수정 가이드

- 에이전트 목록 추가/변경 → `~/qjc-office/dotclaude/rules/agents-v2.md`
- 팀 운영 규칙 변경 → `~/qjc-office/dotclaude/reference/agents-teams-ref.md`
- MCP 패턴 변경 → `~/qjc-office/dotclaude/reference/agents-config-ref.md`

---

## 글로벌 스코프 자산 인벤토리 (자동 갱신)

> 비유: 도서관 카탈로그의 "총 장서 수" 패널. 책장(rules/agents/skills/hooks)이 늘 때마다 직원이 수동으로 숫자를 고치는 게 아니라, 야간에 자동으로 카운터만 갈아 끼우고 주변 안내문은 그대로 둔다. 마커 안만 자동, 마커 밖은 보존.

이 섹션은 `/sync-all --scope=global-index --apply`로 자동 갱신된다. 마커 블록 밖은 사용자가 자유 편집해도 보존된다.

<!-- sync-all:auto-start name="global-scope-inventory" -->
| 자산 유형 | 카운트 | 디렉토리 | 비고 |
|-----------|--------|----------|------|
| rules | 55 | `~/qjc-office/dotclaude/rules/` | 매 세션 자동 로드 |
| agents | 100 | `~/qjc-office/dotclaude/agents/` | 라우팅 대상 |
| commands (skills) | 101 | `~/qjc-office/dotclaude/commands/` | `/` 호출 |
| hooks | 102 | `~/.claude/hooks/` | SessionStart/PostToolUse 등 |
| reference | 113 | `~/qjc-office/dotclaude/reference/` | 필요 시 Read |
| scripts | 21 | `~/.claude/scripts/` | health, drift, scan |

마지막 갱신: 2026-05-17 15:41:50 KST
<!-- sync-all:auto-end -->

> **출처**: 마커 컨벤션은 [`~/qjc-office/dotclaude/rules/sync-all.md`](../rules/sync-all.md) Phase 16 "CLAUDE.md 마커 컨벤션"을 동일 적용. 자동 갱신 스크립트는 [`~/.claude/scripts/sync-all-update-global-index.sh`](../../.claude/scripts/sync-all-update-global-index.sh) (Phase 1 신규).
>
> **공식 spec 참조**: Skills의 `${CLAUDE_SKILL_DIR}` 변수와 `<!-- ... -->` HTML 주석 patterns은 [docs.anthropic.com/en/docs/claude-code/slash-commands](https://docs.anthropic.com/en/docs/claude-code/slash-commands) 에서 정의된 표준에 합치. 공식 문서: "Block-level HTML comments are stripped before content is injected into Claude's context" — 마커가 Claude 컨텍스트에 노이즈 추가하지 않음 (sync-all.md "공식 스펙과의 관계" 섹션 검증 완료, 2026-04-22).
