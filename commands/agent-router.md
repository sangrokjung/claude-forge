---
name: agent-router
description: "전문 에이전트 자동 라우팅. 법률, 재무, 특허, SEO, 마케팅, 기획, BM 설계(BMC/Lean/JTBD/Wardley/Blue Ocean/Lightning Sprint), 코드리뷰, 아키텍처, 견적, CRM, HR/인사, 노무(노동법/해고/산재/취업규칙), 리서치, 데이터 분석, 제1원칙 사고, 주식 투자, 부동산 투자, 명리학, 회사운영(노란우산/창업혜택/고용지원/세무일정), 디자인 제작(배너/카드뉴스/SNS/광고/인포그래픽), FAQ/지식베이스(KCS/셀프서비스/아티클), 고객지원(CS응답/에스컬레이션) 등 50+ 에이전트"
---

<SUBAGENT-STOP>
서브에이전트로 실행 중이면 이 스킬을 건너뛴다. 재귀 스폰 방지.
</SUBAGENT-STOP>

# Agent Router

> 비유: 병원 접수 데스크. 환자가 "배가 아파요"라고 하면 내과로, "뼈가 부러졌어요"라면 정형외과로 배정한다. 접수 데스크가 직접 진료하지 않는다.

## 규칙 (CRITICAL)

1. 아래 라우팅 테이블에서 매칭되는 에이전트가 있으면 → **반드시 Agent tool로 스폰**
2. 매칭이 없으면 → 이 스킬을 무시하고 직접 처리
3. 사용자가 "직접 해" 또는 "에이전트 없이"라고 하면 → 라우팅 스킵
4. 여러 에이전트가 매칭되면 → 가장 구체적인 것 선택
5. 에이전트 스폰 시 사용자의 원본 요청을 그대로 전달 (요약/변형 금지)

## 라우팅 테이블

| 키워드 (하나라도 포함 시) | 에이전트 |
|------------------------|---------|
| 구현 계획, 복잡한 기능, 설계, implementation plan | planner |
| 코드 리뷰, 코드 검토, code review, 리뷰해줘 | code-reviewer |
| 아키텍처, 설계 판단, 기술 부채, architecture, C4 모델, ADR, Fitness Function, 모듈 설계, 순환 의존성, 결합도, 아키텍처 리포트, 진화적 아키텍처, 마이크로서비스 설계, 바운디드 컨텍스트, Strangler Fig, 의존성 분석, 코드 구조 분석 | architect |
| TDD, 테스트 먼저, 테스트 작성, test first | tdd-guide |
| 빌드 에러, 빌드 실패, 타입 에러, build error | build-error-resolver |
| 보안 검토, 보안 리뷰, 취약점, security review | security-reviewer |
| DB 리뷰, SQL 쿼리, 마이그레이션, 인덱스 | database-reviewer |
| 데드 코드, 리팩토링, 미사용 코드, cleanup | refactor-cleaner |
| 문서 업데이트, 코드맵, 문서 동기화 | doc-updater |
| 계약, 계약서, NDA, 법률, 법령, 판례, contract, 위약금, 손해배상, MOU, 약관 | contract-legal |
| 영수증, 영수증 처리, 경비 정리, 경비 분류, 비용 분류, 비용 코드, 세금계산서 정리, 세금계산서 파싱, 세금계산서 PDF, 경비 리포트, 비용 리포트, 월간 경비, 적격증빙, 증빙 확인, 매입세액 집계, 카드 내역 분류, 증빙 감사, OPEX 현황, 비용 코드 매칭, 경비 입력, 경비 기록, receipt, expense report, cost code | expense-processor |
| 세금, 세무, 회계, 부가세, 절세, tax, 재무제표 작성, 기장, 장부, 세금 계산, 소득세, 원천세, 세금 신고, 세법 판단, 경비 인정 가능한가 | financial-accountant |
| 예산, 예산 분석, 예산 수립, 예산 계획, 예산 대비, BvA, budget, budgeting, 현금흐름, 현금흐름 예측, 캐시플로우, cash flow, runway, 런웨이, 몇 개월 버틸, burn rate, 번레이트, 손익계산서, P/L, PnL, 월별 손익, 분기 손익, 재무 건전성, 재무 건강, 재무 KPI, 재무 지표, Financial Health, 이상 지출, 비정상 지출, 이상 감지, anomaly, 비용 급증, 중복 결제, 구독 정리, ROI 분석, 투자 수익률, 회수 기간, NPV, IRR, 매출 예측, 비용 예측, 재무 예측, 시나리오 분석, 마진, 마진율, 이익률, Throughput Accounting, LER, Core Capital, Beyond Budgeting, ZBB, Rolling Forecast, Variance Analysis | budget-analyst |
| 특허, 발명, 명세서, 청구항, 상표, patent, IP, 선행기술, OA, PCT, 지식재산 | patent-attorney |
| SEO, 검색 최적화, GEO, AEO, 검색 노출, AI 검색, 검색 순위, SERP, 백링크 | seo-geo-aeo-strategist |
| 기획, 제품 전략, 사업 전략, 로드맵, 전략 수립, 시장 분석, 경쟁 분석, 포지셔닝, MVP | product-strategist |
| **BM 설계**, 비즈니스 모델 캔버스, BMC, 9블록, Lean Canvas, 린 캔버스, JTBD, Jobs to be Done, 고용 이론, Wardley, Wardley Map, Wardley Mapping, Build vs Buy, 가치 사슬 진화, Blue Ocean, 블루오션, ERRC, Strategy Canvas, 수익 모델, BM 피벗, Lightning Sprint, 3일 검증, Foundation Sprint, Osterwalder, Maurya, Christensen JTBD, Eric Ries Lean Startup, Steve Blank Customer Development, 신규 사업 BM, business model canvas, lean canvas, jobs to be done, blue ocean, revenue model, bm pivot, lightning sprint | bizmodel-architect |
| 카피, 헤드라인, CTA, 광고 문구, copywriting | copywriting |
| 견적, 견적서, estimate, quote, 가격 제안 | quotation |
| 정부지원, 보조금, 지원사업, 공고, 사업계획서, 지원금, TIPS, K-Startup, 정부과제 | gov-support-strategist |
| 광고 최적화, 광고 성과, ROAS, ad optimization | ad-optimizer-team |
| 마케팅 전략, 성장 전략, growth marketing | performance-growth-marketer |
| 콘텐츠 기획, 유튜브 기획, 콘텐츠 캘린더 | qjc-content |
| 자동화 컨설팅, 교육 설계, VOD, 회사 운영, 회사 관리, 경영 관리, 사업 관리, 사업자 관리, 운영 자동화, COO, 노란우산, 노란우산공제, 소기업공제, 자금 조달, 운영 자금, 사업 자금, 긴급 자금, 정책 자금, 소상공인 대출, 세금 일정, 세무 캘린더, 신고 일정, 납부 일정, 부가세 일정, 종소세 일정, 원천세 일정, 청년창업, 세액감면, 창업세액감면, 청년창업세액, 창업 지원, 창업 혜택, 소규모 창업, 고용지원금, 고용장려금, 청년일자리, 일자리도약, 첫 채용, 고용 창출, 인건비 지원, 사업자등록, 사업자 변경, 업종 변경, 사업장 이전, 대표자 변경, 중소기업 확인서, 법인 설립, 법인전환, 법인 관리, 정관 변경, 등기 변경, 주주총회, 운영 현황, 회사 현황, 운영 리포트, 운영 보고, 월간 리포트, 경영 리포트, 인허가, 신고 의무, 법정 의무, 통신판매업, 정보보호, 퇴직공제, company operations | qjc-operations |
| 리드 스코어, 리드 점수, 리드 스코어링, lead score, lead scoring, ICP 매칭, ICP 분석, ICP 정의, ICP 재정의, 리드 우선순위, 전환 예측, 전환 가능성, Hot Lead, 핫리드, Score Decay, 리드 자격, MQL, SQL, 적격 리드, 파이프라인 스코어, Predictive Scoring, 스코어 매겨, 점수 매겨, 우선순위 매겨, 누구에게 먼저, 전환율 예측 | lead-scorer |
| 영업, 세일즈, 리드 등록, 리드 관리, CRM, 파이프라인, 팔로업, 딜 관리, 고객 건강 | crm-manager |
| 회의록, 회의록 작성, 미팅 노트, meeting minutes, 미팅 기록, 미팅 정리, 녹음 파일, 녹음 분석, 미팅 녹음, 오디오 분석, STT, 음성 인식, 전사, transcription, 화자 분리, speaker diarization, 미팅 요약, 회의 요약, 미팅 분석, 액션 아이템, action item, 미팅 할 일, 후속 조치, 결정 사항, 미팅 이력, 지난 미팅, 과거 미팅, 미팅 검색, 회의록 배포, Otter, Fireflies, WhisperX, VITO, Grain, Read.ai, GTD 액션 | meeting-secretary |
| FAQ, 자주 묻는 질문, 지식베이스, knowledge base, 헬프 센터, help center, 반복 문의, 반복 질문, 셀프서비스, self-service, 아티클 작성, FAQ 만들어, FAQ 작성, FAQ 수정, FAQ 검색, FAQ 발행, FAQ 성과, FAQ 분석, Deflection Rate, Content Standard, KCS, 75단어 룰, Cynefin, SECI, FAQ 갭, FAQ 매칭, FAQ 블로그, FAQ SEO, 답변 템플릿, 자동 답변, FAQ 봇, 도움말, 매뉴얼, 가이드 문서, 콘텐츠 건강, Reuse is Review | faq-builder |
| UI, UX, 랜딩페이지, 랜딩페이지 코드, 랜딩 페이지, 홈페이지, 웹사이트, 웹페이지, 페이지 디자인, 웹 디자인, 사이트 만들기, 사이트 디자인, 대시보드, 대시보드 UI, 어드민 페이지, 관리자 페이지, 컴포넌트 라이브러리, 디자인 시스템, 반응형 웹, 모바일 웹, 프론트엔드 디자인, UI 만들기, UI 컴포넌트, landing page, homepage, website, dashboard, web design, frontend, responsive web | web-designer (단일 UI 구현만 — 풀 팀 제작·장문 랜딩은 /landing-build create, 기존 랜딩 개선/리뉴얼/고쳐는 /landing-build revamp. 발화에 "리뉴얼·개선·고쳐"가 들어오면 web-designer 아닌 /landing-build revamp로 보낸다) |
| 랜딩 섹션 구성, 스토리라인 설계, 랜딩 구조 짜줘, 오퍼 설계, 가격 앵커링 설계 (B2C 랜딩/강의 커머스 한정 — B2B 견적·가격 산정은 quotation), 섹션 시퀀스, section architecture | landing-conversion-architect |
| 랜딩 벤치마크, 랜딩 teardown, 랜딩 역설계, 경쟁사 랜딩 분석, landing teardown | /landing-bench 스킬 |
| 기존 랜딩 개선/리뉴얼/수정/리뱀프/더 좋게/고쳐/패캠처럼 바꿔 (자산 동반 — 진단+개선 적용까지), revamp landing | /landing-build (revamp axis) |

> **landing 4-way 경계**: 진단만(점수+백로그)=`/landing-review` · 신규 제작=`/landing-build` create · 기존 개선 적용=`/landing-build` revamp · 경쟁 teardown=`/landing-bench`. "개선/리뉴얼/더 좋게/고쳐"(자산 동반)는 review가 아니라 revamp(적용까지). "검토/리뷰/진단/감사"는 review(진단 종결).
| 배너, 배너 디자인, 배너 제작, 커버 이미지, 헤더 이미지, 히어로 이미지, 카드뉴스, 카드 뉴스, 정보 카드, SNS 이미지, SNS 그래픽, 인스타 이미지, 소셜 미디어 이미지, 광고 이미지, 광고 크리에이티브, 광고 배너, GDN 배너, 메타 광고 이미지, 디스플레이 광고, 인포그래픽, 정보 그래픽, 썸네일, 유튜브 썸네일, 디자인 제작, 그래픽 만들어, 이미지 제작, 비주얼 제작, 디자인해줘, 이벤트 이미지, 프로모션 이미지, 상세페이지 디자인, ad creative, banner design, card news, social media image, graphic design, create design | design-creator |
| 프로필 사진, 프로필 이미지, 프로필 제작, 프로필 만들어, 프로필 N장, 헤드샷, headshot, 링크드인 프로필, linkedin 프로필, 증명사진, 정장 프로필, 비즈니스 프로필, 프로필 변주, OO처럼 프로필, ~처럼 프로필 사진, 유명인처럼 프로필, 얼굴 고정 프로필, professional portrait, profile photo, profile picture | profile-portrait SKILL |
| 영상 제작, Remotion, 인트로, 아웃트로 | remotion-creator |
| 프리미어, Premiere, Premiere Pro, 영상 편집, 컷 편집, 타임라인, 시퀀스, 자막 작업, SRT, VTT, 캡션, 내보내기, 인코딩, 렌더링, Export, H.264, FFmpeg, 프록시, 코덱, 비트레이트, 라우드니스, LUFS, 영상 리뷰, 영상 검수, 편집 체크리스트, video editing, premiere pro, video export, video review | premiere-editor |
| 조사해줘, 리서치, 시장 조사, 동향 분석, research | researcher |
| E2E 테스트, Playwright, 유저 여정 | e2e-runner |
| 검증, 빌드 확인, 테스트 확인, verify | verify-agent |
| AI 연구, 논문 분석, 실험 설계, SOTA, ablation, auto research | ai-researcher |
| Codex 리뷰, 크로스모델 리뷰, GPT 리뷰, second opinion | codex-reviewer |
| Gemini 리뷰, 프론트엔드 리뷰, React 리뷰, accessibility | gemini-reviewer |
| QJC 사업 전략, 영업 전략, 고객 분석, 제안서, proposal | qjc-business |
| 심층 리서치, 시장 분석, 정책 연구, 비즈니스 리서치, 산업 분석 | research-pi |
| 스토리텔링, 브랜드 스토리, 고객 사례, 내러티브, 피치덱 스토리 | storyteller |
| 데이터 수집, 데이터 분석, 데이터 시각화, 차트, 그래프, KOSIS, ECOS, 통계청, 한국은행, 공공데이터 분석, KPI 설계, 지표 분석, 데이터 리포트, 데이터 파이프라인, 자동 수집, 데이터 대시보드 | data-analyst |
| 경쟁사, 경쟁 분석, 경쟁사 분석, 경쟁 동향, 경쟁 현황, 경쟁 모니터링, 경쟁 경보, 경쟁사 모니터링, 배틀카드, 시장 인텔리전스, 인텔리전스, CI/BI, 벤치마킹, 경쟁 벤치마크, 포지셔닝 맵, 전략 그룹, 경쟁 지도, competitive intelligence, business intelligence, competitive landscape, battlecard, Five Forces, SWOT 분석, Blue Ocean, ERRC, War Gaming, 경쟁사 비교, 경쟁사 재무, 경쟁사 채용, 경쟁사 뉴스, 패스트캠퍼스 분석, 인프런 분석, 클래스101 분석, 경쟁 조기 경보, Gilad, Fuld, Fleisher, 경쟁 우위, 경쟁 대응, 경쟁 전략, competitor profile, market intelligence, KPI 대시보드, BI 대시보드, 성과 벤치마크 | ci-bi-strategist |
| 제1원칙, first principles, 근본, 본질, 근본 분석, 왜 하는 거지, 비용 분해, 비용 줄이기, 비용 구조, 비용 비효율, 구독 정리, 지출 분석, 원가 분석, 정말 필요한가, 진짜 필요해, 삭제할 것, 프로세스 단순화, 업무 간소화, 프로세스 개선, 비효율, 워크플로우 정리, 자동화 우선순위, 자동화 순서, 머스크, 머스크 알고리즘, 5단계 알고리즘, 처음부터 다시, 리셋, 재설계, 10배, 문샷, 10x, moonshot, idiot index, 원가 비율, 원자재 대비, 하드코어, hardcore, 80% 삭제, 극한 효율, 다 없앤다면, 시너지, 수렴, convergence, DOGE, 정부 효율, via negativa, Day 1, Zero to One, 안티프래질, 멘탈 모델, 레버리지, 비용 비율, 사이클 타임, 병목, 전략 검증, 이거 해야 해, 뭐가 중요한지 | first-principles-thinker |
| 주식, 종목 분석, 시장 분석, KOSPI, KOSDAQ, 코스피, 코스닥, 증시, PER, PBR, ROE, 밸류에이션, 적정주가, DCF, 기술적 분석, 차트 분석, 포트폴리오, 섹터 로테이션, 투자 전략, 공시 분석, DART 공시, 전자공시, 수급 동향, 외국인 매매, 스크리닝, 종목 추천, 재무제표 분석, 버핏, 그레이엄, 린치, 달리오, 막스, 그린블라트, 오닐, 미너비니, 와인스타인, 박세익, 김정환, 이채원, 홍진채, CAN SLIM, Magic Formula, VCP, SEPA, 금리 영향, 환율 영향, 연준, 경기 사이클, 인플레이션, 지정학, 전쟁 영향, 무역 분쟁, Fear Greed, GPR 지수, stock analysis | stock-investment-advisor |
| 부동산 시장, 부동산 동향, 부동산 전망, 집값 전망, 시장 분석, 가격지수, 매매지수, 부동산 투자, 투자 지역, 투자 전략, 부동산 정책, 부동산 규제, 거시경제 부동산, 기준금리 부동산, 금리 인하 집값, 유동성 부동산, M2 부동산, 인플레이션 부동산, 환율 부동산, 전쟁 부동산, 지정학 부동산, 한반도 리스크, 중국 부동산 위기, 인구 감소 부동산, 수도권 집중, 빅사이클, 진자이론, 부채사이클, real estate market | real-estate-investor |
| 매물, 매물 찾아줘, 매물 검색, 매물 조회, 매물 분석, 매물 비교, 급매, 급매물, 신규 매물, 호가, 현재 호가, 매물 가격, 네이버부동산, KB시세, 임장, 임장 체크리스트, 디지털 임장, 비교평가, 단지 비교, 아파트 비교, 관심 매물, 매물 모니터링, 워치리스트, 매물 추적, 가격 알림, 건축물대장, 관리비 확인, K-apt, 학군 확인, 학구도, 경매 물건, 경매 매물, 낙찰 예상가, 권리분석, 전세가율 높은, GAP 작은, 갭투자 매물, 소액 갭투자, 방미, 월천대사, 렘군, 너바나, 매물탐방, 임장 방법, 매물 선별법, 저평가 아파트, 이 매물 어때, 이 아파트 어때, 이 단지 어때, property listing, property analysis | real-estate-property |
| 신규 고객, 새 고객, 신규 가입, 새 가입자, 신규 수강생, 새 수강생, 환영 메시지, welcome, 환영 이메일, 가입 환영, 웰컴, 고객 온보딩, 수강생 온보딩, 온보딩 가이드, 온보딩 진행, 온보딩 체크, customer onboarding, 학습 경로, 수강 가이드, 커리큘럼 추천, 어떻게 시작, 시작 가이드, 학습 진도, 진도 확인, 수강 현황, 학습 현황, 첫 성과, 마일스톤, 첫 자동화, TTFV, 이탈 위험, 미완료 고객, 장기 미접속, 재참여, 넛지, 온보딩 미완료, 온보딩 퍼널, 온보딩 전환율, activation rate, Desired Outcome, Bowling Alley, EUREKA, Story of User, Hook Model, Fogg Model, PLG 온보딩 | onboarding-guide |
| 사주, 사주팔자, 명리, 명리학, 만세력, 오행, 용신, 궁합, 택일, 작명, 운세, 대운, 세운, 천간, 지지, 간지, 격국, 신살, 역마살, 도화살, 적천수, 궁통보감, 자평진전, 합충, 12운성, 십성, 통변성, 사주 분석, 사주 봐줘, 올해 운세, 궁합 봐줘, 이름 지어줘, 좋은 날, 길일, saju, myeongri, four pillars | saju-myeongri |
| 채용, 구인, 구직, 인재, 면접, JD, 직무기술서, 채용공고, 급여, 월급, 연봉, 임금, 수당, 인센티브, 보상, salary, 급여 계산, 4대보험 계산, 4대보험 산출, 국민연금 계산, 건강보험 산출, 고용보험, 근태, 출퇴근, 직원 온보딩, 입사 온보딩, 입사, 인사평가, 성과평가, OKR, 조직문화, 팀 빌딩, 인력 계획, headcount, 직원 교육, HRD, 프리랜서 관리, 외주 관리, Bersin, Ulrich, Laszlo Bock, Lencioni, Radical Candor, Keeper Test, Netflix 문화, Superworker, HR SaaS, 비즈포인, flex HR, 연말정산, payslip, 급여명세서 | hr-manager |
| 노동법, 근로기준법 해석, 노무 자문, 노무사, 공인노무사, 해고, 부당해고, 정리해고, 권고사직, 해고예고, 징계, 징계위원회, 취업규칙, 인사규정, 급여규정, 복무규정, 근로자성 판단, 프리랜서 vs 근로자, 특수고용, 플랫폼 노동자, 퇴직금 산정, 퇴직금 분쟁, 퇴직연금, 근로시간, 연장근로, 야간근로, 휴일근로, 주52시간, 포괄임금제, 통상임금, 평균임금, 최저임금 위반, 임금체불, 산재, 산업재해, 산재 신청, 산재 처리, 장해등급, 노동위원회, 구제신청, 부당노동행위, 노동조합, 단체교섭, 단체협약, 근로감독, 시정지시, 과태료, 중대재해, 중대재해처벌법, 안전보건관리, 직장 내 괴롭힘, 직장 내 성희롱, 비정규직, 기간제법, 파견법, 연차유급휴가, 연차수당, 출산휴가, 육아휴직, 위장도급, 외국인 근로자, 고용허가제, E-9 비자, labor law, labor consultant, 노무 컴플라이언스 | labor-consultant |
| 고객 문의, 문의 처리, CS 처리, 문의 답변, 고객 응대, 문의 확인, CS 답변, 답변 초안, 답변 작성, 회신 작성, 답변 보내줘, 답변해줘, 불만, 클레임, 컴플레인, 환불 요청, 항의, 불만 처리, 고객 불만, CS 현황, CS 리포트, CS 통계, 티켓 현황, 미처리 문의, CSAT, 고객 만족도, CS 템플릿, 답변 템플릿, 표준 답변, 에스컬레이션, 긴급 문의, 긴급 CS, 채널톡 답변, 카카오 답변, 이메일 답변, CS 이메일, 고객 이메일, Hug Your Haters, Amazement, 예측적 서비스, Uplifting Service, 감정 매핑, 서비스 레벨, SLA, 응답 시간, 처리 시간, CS 자동화, 문의 자동 분류, 자동 답변, CS 봇, customer inquiry, support ticket, complaint, escalation, customer service | cs-responder |

### (정리됨 2026-06-11) 외부 Tier 1/2 에이전트 101개 아카이브

> msitarzewski/agency-agents 임포트 101개(Tier1 76 + Tier2 25)는 도입 후 22일간 호출 0회로 `archive/agents-external-20260611/`에 아카이브됨. 해당 도메인(게임/XR/블록체인 등) 요청 시 general-purpose로 직접 처리하거나 필요 시 복원.

### Lazyweb MCP (신규 2026-05-05)

| 키워드 | 라우팅 |
|--------|--------|
| "레퍼런스 수집", "비슷한 화면", "디자인 영감" | `/lazyweb:lazyweb-quick-references` |
| "competitive design analysis", "경쟁사 디자인 분석" | `/lazyweb:lazyweb-design-research` |
| "디자인 비교", "유사 디자인 찾아", "visual similarity" | `/lazyweb:lazyweb-design-improve` |
| "다른 카테고리 영감", "cross-pollination", "novel pattern" | `/lazyweb:lazyweb-design-brainstorm` |
| "Mobbin/Savee/Dribbble/Behance 연결" | `/lazyweb:lazyweb-add-inspo-source` |
| "영감 소스 제거", "Mobbin/Savee 연결 해제" | `/lazyweb:lazyweb-remove-inspo-source` |

상세: `~/.claude/rules/lazyweb-mcp.md`

## 팀 하위 에이전트 (직접 라우팅 불필요)

다음 에이전트는 상위 팀이 자동 관리하므로 직접 호출하지 않는다:
- ad-compass, ad-scout-google, ad-scout-meta → **ad-optimizer-team**이 관리
- action-architect, folder-hunter, mail-scout → **email-action-team**이 관리 (/email-action 스킬 경유)
- auto-experimenter → **ai-researcher** 또는 **research-pi**가 관리

## 예외 (라우팅 스킵)

- 단순 질문/정보 요청 → 직접 답변
- 한 줄 수정/오타 → 직접 처리
- 이미 에이전트가 실행 중 → 중복 스폰 방지
- 사용자가 명시적으로 "에이전트 없이" 요청 → 직접 처리
- 서브에이전트 내부에서 실행 중 → 스킵 (재귀 방지)
