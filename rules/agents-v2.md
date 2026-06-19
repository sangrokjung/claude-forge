---
name: agents-v2
load: always
audience: team
sensitivity: L1
category: agent-routing
critical: true
description: 에이전트 오케스트레이션/자동 라우팅 — 전문 에이전트 트리거 + 키워드 충돌 분기표
---
# Agent Orchestration

> 팀 운영 상세: ~/qjc-office/dotclaude/reference/agents-teams-ref.md
> MCP/설정 상세: ~/qjc-office/dotclaude/reference/agents-config-ref.md
> 에이전트 카탈로그: ~/qjc-office/dotclaude/reference/agent-catalog.md

## Built-in Skills

| Skill | When to Use |
|-------|-------------|
| /simplify | 기능 구현 후 코드 정리 (3 병렬 에이전트) |
| /batch | 동일 패턴 반복 변경 (5+ 파일) |
| /rc | 외출 시 원격 세션 접속 |
| /ralph-loop | 다중 턴 자율 반복 (`--max-iterations` 필수) |
| /email-action | 2-Phase 이메일 처리: 빈 입력→목록, 번호→매칭, 검색어→4-Opus 팀 (Phase 2만 에이전트 사용) |

## 에이전트 자동 라우팅 (CRITICAL)

`/agent-router` 스킬이 전문 도메인의 실질적 작업 요청을 자동 라우팅한다.
using-superpowers의 "1% 규칙"에 의해 매 턴 agent-router 체크가 강제된다.
단순 질문/정보 요청은 라우팅하지 않고 직접 답변한다.

> **Tier 1-2 외부 확장**: 글로벌 99 + Tier 1 76 + Tier 2 25 = **200 에이전트** (`msitarzewski/agency-agents` 통합). 신규 도메인 매핑(게임·XR·블록체인·학술·MCP builder·embedded 등)은 `commands/agent-router.md` 참조. ⚠️ **zk 함정 분리 (CRITICAL)** — "zk-SNARK/Zero-Knowledge/Groth16"은 `blockchain-security-auditor`(또는 `engineering-solidity-smart-contract-engineer`), "Zettelkasten/Luhmann/atomic notes"는 `zk-steward`. 단독 "zk"는 모호 → 사용자 명시 확인 의무.

주요 라우팅 대상 (전체 ~75 에이전트 / 트리거 표는 본 SSOT에 보존):
- 개발: planner, code-reviewer, architect, tdd-guide, build-error-resolver, verify-agent, e2e-runner, security-reviewer, database-reviewer, refactor-cleaner, doc-updater, qa-evaluator (/qa 스킬 경유만 호출, 직접 호출 금지)
- Dev Team: dev-brainstormer, systematic-debugger, performance-reviewer, a11y-reviewer, rca-debugger, impl-worker, dev-team-lead (Hub)
> **Dev Team (8-stage 파이프라인)**: "팀으로 개발", "풀사이클", "개발팀으로", "Dev Team", "브레인스토밍", "근본 원인", "5-why", "Core Web Vitals", "LCP", "Lighthouse", "WCAG", "a11y", "접근성", "CI만 실패", "간헐적 버그", "플래키", "멀티 컴포넌트 병렬" 등은 dev-team-lead가 Hub-and-Spoke 8-stage(brainstorm→architect→plan→TDD→5-way review→perf/a11y→verify+RCA→QA→finish) 오케스트레이션. Dual Mode: 단순=subagent 조합, 3파일+/풀사이클=Hub 승격. HARD-GATE 3개(brainstorm SELECTED / plan APPROVED / verify all-green). 상세: rules/dev-team.md
> **"계획"·"기획" 키워드 6방향 라우팅 (MOH-4)**:
> | 요청 패턴 | 라우팅 | 이유 |
> |---------|-------|------|
> | "뭘 만들지 모르겠다" / "옵션" / "아이디어" / "LLM vs 규칙" | dev-brainstormer | 발산 (3-5안, NEVER writes plan) |
> | "신제품 기획" / "서비스 설계" / "PRD" / "로드맵" / "PM 프레임워크" | product-strategist | 일반 PM 구루 (Cagan/Torres/Rumelt) |
> | "QJC 신규 서비스" / "QJC 브랜드·가격·GTM" | qjc-business | QJC 특화 맥락 |
> | "구현 계획" / "spec" / "3-6단계 로드맵" / "리팩토링 계획" | planner | 코드 구현 전용 (Never implements) |
> | "팀으로" / "풀사이클" / "3파일+ 멀티페이즈" | dev-team-lead | Hub-and-Spoke 오케스트레이션 |
> | "근본 재설계" / "제1원칙" / "Idiot Index" | first-principles-thinker | 가정 분해·삭제 중심 |
> **프로젝트 런칭**: "프로젝트 런칭", "PRD 작성", "새 프로젝트", "신규 프로젝트", "PRD 생성", "프로젝트 + PRD 통합", "spec.md 생성", "prompt_plan.md 생성", "CLAUDE.md 초기화", "프로젝트 부트스트랩", "프로젝트 시작", "PRD v" (버전 작성), "프로젝트 + 문서 + 깃헙" 등은 `/project-launch` 스킬이 Supabase + 로컬 + GitHub 3분할 동기화로 8 Phase(기본)/12 Phase(--full) 실행. `--minimal` 구버전 호환, `--no-docs/--no-github/--no-save-work` opt-out. 상세: commands/project-launch.md + reference/project-launch-ref.md

> **프로젝트 아키텍처**: "아키텍처 분석", "C4 모델", "ADR", "Fitness Function", "기술 부채", "모듈 설계", "마이크로서비스", "의존성 분석", "확장성", "진화적 아키텍처", "코드 구조", "순환 의존성", "결합도", "아키텍처 리포트", "Strangler Fig", "바운디드 컨텍스트" 등은 architect가 10구루 프레임워크로 C4 다이어그램→Fitness Function 측정→ADR 작성→기술 부채 스캔→거버넌스 자율 수행. 구현 계획은 planner, 코드 수정은 refactor-cleaner. 상세: rules/project-architect.md
- 비즈니스: product-strategist, quotation, crm-manager, lead-scorer, meeting-prep, qjc-business, qjc-operations (회사운영 오케스트레이터), bizmodel-architect (BM 설계 전담)
> **BM(Business Model) 설계**: "비즈니스 모델 캔버스", "BMC", "Lean Canvas", "린 캔버스", "JTBD", "Jobs to be Done", "Wardley Map", "Wardley Mapping", "Build vs Buy", "Blue Ocean", "블루오션", "ERRC", "수익 모델", "BM 피벗", "BM 설계", "신규 사업 BM", "사업 모델 설계", "Foundation Sprint" 등은 bizmodel-architect가 16구루 프레임워크로 5단계(Discovery→Research→Design→Validate(score 85%)→Render) 자율 수행. UserPromptSubmit hook(`bizmodel-trigger-detector.sh`) 자동 감지. 5 모드(bmc/lean/jtbd/wardley/blue-ocean/auto). QJC 자체 브랜드/포트폴리오는 qjc-business, 일반 PM PRD/OST는 product-strategist. 상세: rules/business-model-design.md
- 고객 피드백: feedback-analyst
> **피드백 분석**: "피드백 분석", "리뷰 분석", "감정 분석", "NPS", "이탈 분석", "토픽 분류", "고객 건강", "PMF", "VoC", "Language Mining", "유튜브 댓글 분석", "채널톡 분석" 등은 feedback-analyst가 10구루로 수집→감정분석→토픽분류→NPS산정→우선순위→리포트 자율 수행. 상세: rules/feedback-analysis.md
- 고객지원: cs-responder
> **고객 문의 응대**: "고객 문의", "CS 처리", "답변 초안", "불만 처리", "클레임", "환불 요청", "에스컬레이션", "CS 현황", "CS 템플릿", "FAQ 답변" 등은 cs-responder가 문의 자동 분류(8종)+긴급도(4단계)+감정 분석(4단계)+답변 초안+에스컬레이션 판단. Gmail(gws CLI) 완전 자동화, 채널톡/카카오 반자동화. 상세: rules/cs-responder.md
- 고객지식: faq-builder
> **FAQ/지식베이스**: "FAQ", "자주 묻는 질문", "지식베이스", "헬프 센터", "반복 문의", "셀프서비스", "아티클", "KB" 등은 faq-builder가 KCS v6 Double Loop로 FAQ 자율 생성/관리/발행. B2C 수강생 CS(반변경/환불/SMS)는 qjc-cs-ops 스킬. 상세: rules/faq-knowledge-management.md
- 회의록: meeting-secretary
> **미팅 준비**: "미팅 준비", "아젠다", "브리핑", "고객 미팅", "discovery call", "SPICED", "Challenger" 등은 meeting-prep이 customer-index.json + CRM + GWS Calendar + Notion 종합하여 브리핑 노트 자동 생성. 상세: rules/meeting-prep.md
> **회의록 작성**: "회의록", "녹음 분석", "STT", "화자 분리", "미팅 요약", "액션 아이템 추출", "미팅 이력" 등은 meeting-secretary가 ~/meeting-automation/ 파이프라인을 오케스트레이션하여 녹음→전사→분석→3분할 배포 자율 수행. meeting-prep(미팅 전)과 역할 분리. **음성 정본=프로젝트 `meetings/<날짜>/`(글로벌 금지), 멀티파일·5h+는 WORK_DIR=`$OUTPUT_DIR/work`에서 ffmpeg 병합+청크 STT** (data-policy "/미팅" 예외). 상세: commands/meeting.md + reference/meeting-secretary-ref.md
- 맥락 동기화: context-sync-lead (Hub-and-Spoke 오케스트레이터)
> **맥락 동기화**: "맥락 동기화", "팀 공유 갱신", "GitHub + Drive에 올려", "프로젝트 메타 정합성", "산출물 동기화", "오늘 한 일 다 올려" 등은 context-sync-lead가 /sync-docs + /sync-all + /project-status-snapshot + GDrive 미러를 hub-and-spoke로 오케스트레이션. dry-run default + 사용자 승인 게이트 + L3 자동 redact + L4 abort. 단일 스킬(/sync-docs만)이면 직접 호출, 본 에이전트는 2개+ 체이닝 또는 GDrive 통합 시. 상세: rules/context-sync-lead.md
- 고객 온보딩: onboarding-guide
> **고객 온보딩**: "신규 고객", "환영 메시지", "학습 경로", "진도 확인", "첫 성과", "이탈 위험", "온보딩 가이드" 등은 onboarding-guide가 EUREKA/Bowling Alley/TTFV로 고객 온보딩 자율 수행. "직원 온보딩"은 hr-manager. 상세: rules/onboarding.md
- 교육 설계: training-designer
> **교육 설계**: "커리큘럼", "학습 목표", "교안", "퀴즈 설계", "교육 효과", "VOD 강의 구조", "마이크로러닝", "Bloom", "ADDIE", "Kirkpatrick", "Gagné", "코호트 설계", "NotebookLM 교육", "PBL", "루브릭" 등은 training-designer가 14구루로 커리큘럼 설계→학습 목표→교안 생성→퀴즈 설계→효과 측정→NotebookLM 콘텐츠 자율 수행. 교육 "운영"은 qjc-operations, 고객 온보딩은 onboarding-guide. 상세: rules/training-designer.md
- 수강생 Q&A 봇 운영 (패스트캠퍼스)
> **패스트캠퍼스 캠코치 봇**: "패스트캠퍼스 Q&A", "캠코치", "수강생 봇", "FastCampusCampCoachBot", "Hermes Agent 배포", "Gemma 4 로컬", "~/.hermes-fastcampus", "수강생 슈퍼그룹", "강의 Q&A 자동화" 등은 `~/.claude/rules/fastcampus-qa-bot.md` 규칙에 따라 처리. 봇 **직접 응답**=Hermes Agent 자체 수행(에이전트 불필요), **설정 변경**=대표 수동 편집, **지식베이스 갱신**=`패스트캠퍼스/scripts/05-build-knowledge-base.py`(주 1회), **지표 분석**=feedback-analyst, **에스컬레이션 CS**=cs-responder, **커리큘럼 보강**=training-designer. 개인 Hermes(`~/.hermes/`)와 수강생 봇(`~/.hermes-fastcampus/`) **완전 격리** 필수. 플랜: `~/.claude/plans/bubbly-conjuring-mitten.md`
> **리드 스코어링**: "리드 점수", "리드 스코어", "ICP 매칭", "우선순위 매겨", "전환 예측", "Hot Lead", "Score Decay" 등은 lead-scorer가 6차원 모델(Fit+Engagement) 100점 만점 자동 산정. crm-manager는 관계 관리 실행. 상세: rules/lead-scoring.md
- 경비 처리: expense-processor
> **경비 처리**: "영수증", "경비 처리", "경비 정리", "비용 분류", "세금계산서 정리", "세금계산서 파싱", "경비 리포트", "비용 코드", "적격증빙", "매입세액 집계", "카드 내역 분류", "증빙 감사", "OPEX 현황" 등은 expense-processor가 12구루로 OCR→자동분류→Supabase기록→리포트 자율 수행. 세법 해석/세금 계산/신고는 financial-accountant. 상세: rules/expense-processing.md
- 매출 처리: revenue-processor
> **매출 처리**: "매출 발생", "매출 기록", "세금계산서 발행 후 기록", "수금", "수금 확인", "매출 리포트", "매출 원장", "매출 대사", "3종 원장", "revenue-processor", "/revenue", "매출매입 Notion 대사", "매출 artifact 승인", "NTS 매출 승인", "매출 백필" 등은 revenue-processor가 매출 발생 시 3종 원장(로컬 세금계산서 PDF + Supabase transactions type=inflow + Notion 매출매입 DB 구분=매출) 동시 저장. 4 모드(record/promote/report/reconcile). MVP는 수동 입력 주 경로. NTS 자동 감지는 artifact 저장 후 promote 승인. 세법 해석/부가세 신고는 financial-accountant. 상세: rules/revenue-processing.md + commands/revenue.md
- 홈택스 매출 동기화: hometax-processor
> **홈택스 매출 자동 동기화**: "홈택스 메일", "홈택스 발급 알림", "hometaxadmin", "NTS 보안메일", "보안메일 복호화", "세금계산서 동기화", "발급 메일 자동 처리", "/hometax-sync" 등은 hometax-processor가 발행 후 알림 메일(`from:hometaxadmin@hometax.go.kr`)을 폴링→Playwright 사업자번호 자동 입력 복호화→파싱(승인번호/line_items)→재무폴더 PDF/HTML 저장→고객폴더 fuzzy match 사본→revenue-processor record 위임(라인별 N회)→Gmail `qjc/nts/synced` 라벨까지 자동화. 09:07/15:13 launchd 폴링 + 8h 쿨다운. revenue-processor record(수동)와 분리된 발행 후 동기화 전담. 상세: rules/hometax-sync.md + commands/hometax-sync.md + agents/hometax-processor.md
- 컴플라이언스: compliance-checker
> **규정 준수 체크**: "개인정보보호법", "전자상거래법", "약관 검증", "컴플라이언스", "규정 준수", "정보통신망법", "GDPR", "ISO 27001", "법령 개정", "처리방침", "마케팅 동의", "유출 사고", "사전 점검" 등은 compliance-checker가 5대 영역(PIPA/전자상거래법/정보통신망법/GDPR/ISO27001) 종합 진단 자율 수행. contract-legal(약관 수정), labor-consultant(노무 규정), security-compliance(기술 보안)과 오케스트레이션. 상세: rules/compliance-checker.md
- 법무/재무/대출/예산: contract-legal, nda-generator, financial-accountant, budget-analyst, patent-attorney, gov-support-strategist, loan-advisor
> **계약서 초안 생성**: "NDA 만들어", "계약서 초안", "용역계약 작성", "강의계약", "파트너십 계약", "계약서 써줘", "비밀유지계약" 등 **생성/작성 요청**은 nda-generator가 Ken Adams 5범주 + Tina Stark 5대 이슈 + Proactive Law 기반 4대 유형(NDA/용역/강의/파트너십) 초안 자동 생성. **검토/분석/판단 요청**은 contract-legal. 상세: rules/contract-drafting.md
> **예산 분석**: "예산", "현금흐름", "캐시플로우", "runway", "손익계산서", "P/L", "재무 KPI", "재무 건전성", "이상 지출", "burn rate", "ROI 분석", "예산 대비", "마진 분석", "재무 예측" 등은 budget-analyst가 10구루로 예산수립→실적분석→이상감지→현금흐름예측→KPI대시보드→투자ROI 자율 수행. 세무/기장/절세는 financial-accountant. 상세: rules/budget-analysis.md
- HR/노무/채용: hr-manager, labor-consultant, musk-hiring-evaluator
> **채용 평가**: "면접 질문", "인재 평가", "프리랜서 평가", "Keeper Test", "채용 필요", "Red Flag" 등은 musk-hiring-evaluator가 머스크 방식 면접 설계/인재 검증. 채용 공고 수집/급여/보험은 hr-manager. 상세: rules/musk-hiring.md
> **회사운영 오케스트레이션**: "회사 운영", "노란우산", "창업 혜택", "운영 리포트", "월간 체크리스트", "자동화 컨설팅(Make.com/n8n)" 등은 qjc-operations가 엔트리로 전문 에이전트 조율. 내부 위임: 심층 세무 계산→financial-accountant, 채용 공고 수집→hr-manager, 지원사업 적합도→gov-support-strategist, 대출 전략→loan-advisor, 예산 분석→budget-analyst. qjc-operations는 "소규모 기업 COO"로 직접 수행(오케스트레이션·자동화)과 위임을 구분. 상세: rules/company-operations.md
- 법무/분쟁: mediation-negotiator, civil-law-advisor
> **조정/협상 (mediation-negotiator)**: "조정", "중재", "협상 전략", "BATNA", "ZOPA", "ADR", "대금 분쟁", "재협상", "위약금 협상", "교착 해결", "소송 전 해결", "파트너십 재협상", "3D 협상" 등은 mediation-negotiator가 12구루 기반 소송 전 분쟁 해결·B2B 협상·가격 재협상·조정 신청서 작성. 경계: contract-legal(법률 판단)·civil-law-advisor(민사 구제절차)와 분리. 상세: rules/mediation.md
> **민사 법률 (civil-law-advisor)**: "손해배상", "채권추심", "소액소송", "지급명령", "내용증명", "부당이득", "임대차 분쟁", "소비자 피해 구제", "민사조정", "소액사건" 등은 civil-law-advisor가 12구루로 민사 분쟁 구제절차 자율 수행. 경계: contract-legal=계약 체결·해석, civil-law-advisor=분쟁 발생 후 구제, mediation-negotiator=소송 전 협상·조정. 상세: rules/civil-law.md
- 마케팅/콘텐츠: seo-geo-aeo-strategist, copywriting, ad-optimizer-team, performance-growth-marketer, qjc-content, storyteller
- 크리에이티브: web-designer, remotion-creator, design-creator, detail-page-creator (상세페이지 10~15장 전담)
> **디자인 제작**: "배너", "카드뉴스", "SNS 이미지", "광고 크리에이티브", "인포그래픽", "썸네일", "상세페이지 디자인" 등 이미지 산출물 제작은 design-creator가 ckm-design/ckm-banner-design 스킬을 오케스트레이션하여 자율 제작. 웹 코드 구현은 web-designer. 상세: rules/design-creator.md
> - `/design-extract <url>` 스킬과 연계: URL 레퍼런스가 주어진 경우 실시간 DOM 샘플링으로 DESIGN.md 추출 후 아트 디렉션에 자동 반영
> - `/design-extract <url>` 스킬과 연계 (web-designer): 요구사항에 레퍼런스 URL 포함 시 Phase 2a에서 자동 추출
> **DESIGN.md 거버넌스 (CRITICAL)**: 프론트엔드/UI 프로젝트(`*.tsx`/`*.css`/`globals.css`/`tailwind.config` 작업)는 루트 `DESIGN.md`를 시각 SSOT로 둔다. UI 작업 전 DESIGN.md 먼저 확인 → 없으면 생성(URL이면 design-extract, 일반이면 web-designer Phase 2 또는 표준 템플릿) → 변경 시 같은 PR에서 동기화. `CLAUDE.md`=코드/운영 SSOT, `DESIGN.md`=색·폰트·간격·컴포넌트 SSOT. 신규 UI 프로젝트는 `/project-launch`가 DESIGN.md 스캐폴드. 적용 범위: React/Vue/Next·대시보드·랜딩·컴포넌트라이브러리 (백엔드 API·CLI·파이프라인 제외). 상세: rules/design-doc-governance.md + reference/design-md-template.md
> **상세페이지 자동 생성 (detail-page-creator)**: "상세페이지 만들어줘", "상세페이지 자동", "디테일페이지", "detail page", "상품 상세 15장", "쇼핑몰 상세 이미지", "헤더부터 CTA까지", "다국어 상세페이지", "강의 상세페이지", "롱스크롤 상세" 등은 detail-page-creator가 OpenAI gpt-image-2 (image-to-image edits) + 13개 언어 프리셋(KR/EN/JP/CN/ES/TH/VN/FR/DE/PT/ID/AR/RU)으로 헤더~CTA 15섹션을 native ratio(3:2/2:3/1:1)·패키지/로고 보존·10% padding 보장하에 일괄 생성. 단일 컷 포스터/카드뉴스/광고세트는 design-creator로 위임. 상세: rules/detail-page.md
- 리서치: researcher, ai-researcher, research-pi, google-trends-analyst, naver-intel, naver-ads-autopilot
> **구글 트렌드**: "구글 트렌드", "급상승 검색어", "검색 트렌드", "키워드 트렌드", "관심도 비교", "시즈널 키워드", "Breakout" 등은 google-trends-analyst(분석/리포트) 또는 `/google-trends` 스킬(단순 조회)이 trendspy 엔진(키 불필요)으로 수행. **역방향 연계 의무**: 유튜브 최적화(qjc-content — gprop=youtube)·구글 SEO(seo-geo-aeo-strategist 키워드/캘린더)·구글 광고(ad-optimizer-team/performance-growth-marketer 예산·입찰 조정 전 계절성 확인) 작업 시 본 스킬 활용. 한국 보정: Trends=구글 표본(모바일은 네이버 우위) — 커머스/로컬·키워드 검색량은 **naver-intel** 교차. 상세: rules/google-trends.md
> **네이버 데이터 인텔리전스 (naver-intel)**: "네이버 키워드"·"검색량"·"월간 검색량"·"연관키워드"·"데이터랩"·"검색어 트렌드"·"쇼핑인사이트"·"네이버 여론"·"네이버 뉴스/블로그/카페 모니터링"·"지역검색" 등은 naver-intel이 naver_api.py 엔진(`~/.claude/commands/naver/scripts/`)으로 검색량·트렌드·쇼핑수요·여론 데이터 수집·분석. 구글 트렌드 교차 판정 시 google-trends-analyst 병렬 호출. 공공데이터(KOSIS/ECOS/DART)는 data-analyst. 상세: rules/naver-marketing.md + agents/naver-intel.md
> **네이버 검색광고 (naver-ads-autopilot)**: "네이버 검색광고"·"파워링크"·"광고 성과"·"입찰가"·"StatReport"·"키워드 입찰"·"CPC/CTR/ROAS(네이버)" 등은 naver-ads-autopilot이 ads-stat·ads-bid-recommend 서브커맨드로 성과 수집·입찰 추천. **입찰 자율 변경 절대 금지** — 사람이 out-of-band HMAC 토큰(`naver_bid_approve.py`) 발급 후 위임 시에만 bid_apply() 실행. 구글/메타 광고는 ad-optimizer-team. 상세: rules/naver-marketing.md + agents/naver-ads-autopilot.md
- 데이터/인텔리전스: data-analyst, ci-bi-strategist
> **CI/BI 인텔리전스**: "경쟁사", "경쟁 분석", "배틀카드", "시장 인텔리전스", "KPI 대시보드", "벤치마킹" 등은 ci-bi-strategist가 기존 에이전트를 오케스트레이션. 상세: rules/ci-bi-intelligence.md
- 투자/실거주: stock-investment-advisor, real-estate-investor, real-estate-property, housing-strategist
> **내집마련 생애주기 로드맵(실거주)**: "내집마련", "언제 집 사야", "임대주택 자격", "행복주택 신청", "청약 전략", "디딤돌/버팀목/보금자리 자격", "생애최초", "신혼집 전략", "출산 후 집", "월세 탈출", "주거 로드맵", "주거 시나리오" 등은 housing-strategist가 `/housing-roadmap` 스킬로 상황 진단(소득·자산·무주택·청약통장) → 임대주택(통합공공임대·행복주택)·청약 특별공급(생애최초·신혼·신생아)·정책대출(디딤돌·버팀목·보금자리·신생아특례) 자격 판정 → DSR/LTV 시뮬 → 시기별 시나리오(공격/균형/안정 3안) + 차트4종+PDF 산출. 매수 단계는 real-estate-investor(지역)→real-estate-property(매물) 위임. **실거주 vs 투자 분리**: "나/내 상황/자격/임대/정책대출"은 housing-strategist, "시장/시세/단지/투자/수익률"은 investor/property. 상세: reference/housing-roadmap.md
- 명리학: saju-myeongri
> **사주명리학**: "사주", "사주팔자", "명리", "만세력", "오행", "용신", "궁합", "택일", "작명", "운세", "대운", "격국", "신살", "합충", "12운성", "십성", "유명인 비교", "적천수", "궁통보감" 등은 saju-myeongri가 10구루로 만세력 계산(calculator.py)→오행/용신/격국 분석→대운/세운 해석→유명인 비교(matcher.py)→PDF 리포트(report-gen.py) STEP 1-10 자율 수행. 산출물은 `QJC/02_제품서비스/사주분석/` 하위 유형별 폴더 저장. 상세: rules/saju-file-management.md
- 리뷰: codex-reviewer, gemini-reviewer
- 메타 사고: first-principles-thinker

상세 라우팅 테이블: `/agent-router` 스킬 참조.

## 키워드 충돌 분기표 (MOH-8~11 경계 명확화)

### "리포트" 키워드 4방향
| 요청 맥락 | 라우팅 |
|---------|-------|
| "운영 리포트 / 월간 체크리스트" | qjc-operations (회사운영 엔트리) |
| "경비 리포트 / 세금계산서 정리" | expense-processor |
| "매출 리포트 / 매출 원장 / 3종 원장 대사" | revenue-processor |
| "예산 리포트 / 현금흐름 / ROI" | budget-analyst |
| "컴플라이언스 리포트 / PIPA 진단" | compliance-checker |
| "공공데이터 리포트 / KPI 대시보드" | data-analyst |
| "CI/BI 인텔리전스 리포트 / 경쟁사 분석" | ci-bi-strategist |
| "피드백 VoC 리포트 / NPS" | feedback-analyst |

### "프리랜서" 키워드 3방향
| 요청 맥락 | 라우팅 |
|---------|-------|
| "프리랜서 계약서 작성" | nda-generator (초안 생성) |
| "프리랜서 역량 평가 / 3-Bullet 검증 / AIM 면접" | musk-hiring-evaluator |
| "프리랜서 관리 / 급여 / 근로자성 판단" | hr-manager (운영) + labor-consultant (법적 판단) |

### "경쟁사" 키워드 2방향
| 요청 맥락 | 라우팅 |
|---------|-------|
| "경쟁사 시장 인텔리전스 / 배틀카드 / KPI 벤치마크" | ci-bi-strategist |
| "경쟁사 특허 조사 / 선행기술 / IP 포트폴리오" | patent-attorney |

### "분석" 키워드 핵심 4방향 (키워드 16 에이전트 충돌 중 Top)
| 요청 맥락 | 라우팅 |
|---------|-------|
| "코드 구조 / 의존성 / 아키텍처 분석" | architect |
| "공공 API / Supabase / KPI 시계열 분석" | data-analyst |
| "시장 / 산업 / 경쟁 / 기술 동향 분석" | research-pi |
| "예산 / 재무 건전성 / 현금흐름 분석" | budget-analyst |
| "네이버 데이터랩·검색량·쇼핑인사이트·여론 분석" | naver-intel |
| 나머지 도메인 특화 분석은 해당 전문 에이전트 (feedback/compliance/saju 등) |

### "유튜브" 키워드 3방향
| 요청 맥락 | 라우팅 |
|---------|-------|
| "유튜브 스크립트 / 썸네일 기획 / 기획" | qjc-content |
| "유튜브 영상 제작 / Remotion 자막" | remotion-creator |
| "유튜브 댓글 감정 분석 / VoC" | feedback-analyst |

### "랜딩" 키워드 5방향 (product-brief vs review vs build-create vs revamp vs bench)
| 요청 맥락 | 라우팅 |
|---------|-------|
| "상품 기획안/기획서로 랜딩", "기획안 넣으면 랜딩", "4-템플릿으로 랜딩" (기획안 → 4-템플릿 문서체인 → 검증까지 완성) | `/product-landing` (7-Phase: 고객→상품→고객가치언어→20블럭→카피덱→빌드→검증) |
| "랜딩 검토/리뷰/진단/감사" (진단에서 종결, 코드 미수정) | `/landing-review` (6축 점수 + P0/P1/P2) |
| "랜딩 만들어/신규/제작" (그린필드, 4-템플릿 없음) | `/landing-build` create axis (7-stage) |
| "랜딩 개선/리뉴얼/리뱀프/더 좋게/고쳐/패캠처럼 바꿔" (기존 자산 + 적용까지) | `/landing-build` revamp axis (6-stage, 패캠 플레이북 기반) |
| "경쟁 랜딩 teardown/역설계/패턴 추출" | `/landing-bench` |
| (product-landing P6·P7은 landing-build의 빌드/검증 spoke를 *호출*만 — 재구현 금지. revamp Stage 1은 review 엔진 재사용 — 중복 호출 금지) |

### 자금조달 경계 (MOH-9)
| 요청 맥락 | 라우팅 |
|---------|-------|
| "보조금 / 무상지원 / 기업마당 / K-Startup / 보조금24" | gov-support-strategist |
| "대출 / 정책자금 / 보증부대출 / 중진공 / 신보 / 기보" | loan-advisor |
| "소상공인정책자금" (회색지대) | 상환 의무 있으면 loan-advisor, 창업·R&D 무상 지원이면 gov-support-strategist |

### 인사이트 경계 (MOH-8)
| 요청 맥락 | 라우팅 |
|---------|-------|
| "외부 시장·경쟁사 인텔리전스" | ci-bi-strategist |
| "내부 고객 VoC·NPS·피드백 인사이트" | feedback-analyst |
| (중첩 시) "시장 반응 + 고객 피드백 통합" → 두 에이전트 병렬 호출 후 메인 세션 통합 |

## Parallel Task Execution

독립 작업은 항상 병렬 실행. 순차 실행이 필요한 경우만 예외.

## Subagents vs Agent Teams

| | Subagents | Agent Teams |
|---|---|---|
| 통신 | 메인에게만 보고 | 리더 경유 (hub-and-spoke) |
| 최적 용도 | 결과만 중요한 집중 작업 | 논의/협업이 필요한 복잡한 작업 |
| 토큰 비용 | 낮음 | 높음 |

상세: agents-teams-ref.md, agents-config-ref.md 참조.

## Agent Memory

`~/.claude/agent-memory/{agent-name}/`. 상세: agents-config-ref.md 참조.

## Agent Pipeline / Parallel Agents

- 호출 순서: ~/qjc-office/dotclaude/reference/agent-pipeline.md
- 병렬 가이드: ~/qjc-office/dotclaude/reference/parallel-agents-guide.md
