---
name: agent-router
description: "전문 에이전트 자동 라우팅. 법률, 재무, 특허, SEO, 마케팅, 기획, 코드리뷰, 아키텍처, 견적, CRM, 리서치, 제1원칙 사고 등 34 도메인"
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
| 아키텍처, 설계 판단, 기술 부채, architecture | architect |
| TDD, 테스트 먼저, 테스트 작성, test first | tdd-guide |
| 빌드 에러, 빌드 실패, 타입 에러, build error | build-error-resolver |
| 보안 검토, 보안 리뷰, 취약점, security review | security-reviewer |
| DB 리뷰, SQL 쿼리, 마이그레이션, 인덱스 | database-reviewer |
| 데드 코드, 리팩토링, 미사용 코드, cleanup | refactor-cleaner |
| 문서 업데이트, 코드맵, 문서 동기화 | doc-updater |
| 계약, 계약서, NDA, 법률, 법령, 판례, contract, 위약금, 손해배상, MOU, 약관 | contract-legal |
| 세금, 세무, 회계, 재무, 부가세, 절세, tax, 재무제표, 경비 처리, 현금흐름, 장부 | financial-accountant |
| 특허, 발명, 명세서, 청구항, 상표, patent, IP, 선행기술, OA, PCT, 지식재산 | patent-attorney |
| SEO, 검색 최적화, GEO, AEO, 검색 노출, AI 검색, 검색 순위, SERP, 백링크 | seo-geo-aeo-strategist |
| 기획, 제품 전략, 사업 전략, 로드맵, BMC, 전략 수립, 시장 분석, 경쟁 분석, 포지셔닝, MVP | product-strategist |
| 카피, 헤드라인, CTA, 광고 문구, copywriting | copywriting |
| 견적, 견적서, estimate, quote, 가격 제안 | quotation |
| 정부지원, 보조금, 지원사업, 공고, 사업계획서, 지원금, TIPS, K-Startup, 정부과제 | gov-support-strategist |
| 광고 최적화, 광고 성과, ROAS, ad optimization | ad-optimizer-team |
| 마케팅 전략, 성장 전략, growth marketing | performance-growth-marketer |
| 콘텐츠 기획, 유튜브 기획, 콘텐츠 캘린더 | qjc-content |
| 자동화 컨설팅, 교육 설계, VOD, 운영 | qjc-operations |
| 영업, 세일즈, 리드, CRM, 파이프라인, 팔로업 | crm-manager |
| UI, UX, 디자인, 랜딩페이지, 대시보드, design | web-designer |
| 영상 제작, Remotion, 인트로, 아웃트로 | remotion-creator |
| 조사해줘, 리서치, 시장 조사, 동향 분석, research | researcher |
| E2E 테스트, Playwright, 유저 여정 | e2e-runner |
| 검증, 빌드 확인, 테스트 확인, verify | verify-agent |
| AI 연구, 논문 분석, 실험 설계, SOTA, ablation, auto research | ai-researcher |
| Codex 리뷰, 크로스모델 리뷰, GPT 리뷰, second opinion | codex-reviewer |
| Gemini 리뷰, 프론트엔드 리뷰, React 리뷰, accessibility | gemini-reviewer |
| QJC 사업 전략, 영업 전략, 고객 분석, 제안서, proposal | qjc-business |
| 심층 리서치, 시장 분석, 정책 연구, 비즈니스 리서치, 산업 분석 | research-pi |
| 스토리텔링, 브랜드 스토리, 고객 사례, 내러티브, 피치덱 스토리 | storyteller |
| 제1원칙, first principles, 근본 분석, 비용 분해, 정말 필요한가, 삭제할 것, 단순화, 머스크 알고리즘, 처음부터 다시, 10배 혁신 | first-principles-thinker |

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
