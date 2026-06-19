---
name: verification
description: Verification Before Completion
load: conditional
audience: team
sensitivity: L1
category: coding
critical: true
paths:
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.js"
  - "**/*.py"
  - "**/*.go"
---

# Verification Before Completion (CRITICAL)

> Superpowers verification-before-completion 패턴 이식 + QJC verification-engine 연동

완료를 주장하려면 이번 메시지에서 검증 명령어를 실행한 증거가 있어야 한다. 증거 없는 완료 주장은 거짓이다.

비유: 법정에서 "아마 무죄일 겁니다"가 통하지 않듯, 코드에서도 "아마 작동할 겁니다"는 통하지 않는다. **증거 먼저, 주장 나중.**

## Gate Function

주장 전 5단계: (1) 증명할 명령어 식별 (2) 새로 완전히 실행 (3) 출력 읽고 exit code·실패 수 확인 (4) 출력이 주장을 확인하는지 판단 — 아니면 실제 상태 보고 (5) 그 다음에만 주장. 한 단계라도 건너뛰면 검증이 아니라 거짓말.

## 검증 체크리스트

| 주장 | 필요한 증거 |
|------|-----------|
| 테스트 통과 | 테스트 명령어 출력: 0 failures |
| 빌드 성공 | 빌드 명령어: exit 0 |
| 버그 수정 | 원래 증상 재현 -> 수정 후 통과 |
| 에이전트 완료 | VCS diff에서 변경 확인 |
| 요구사항 충족 | 줄별 체크리스트 대조 |
| 산출물 빌드 (PPTX/PDF/HTML/이미지) | **고객 발송·완성 문서는 내가 직접 전 페이지를 열어 검토**(1-2 샘플 금지 — 샘플은 결함 슬라이드를 놓친다). 점검 항목: 텍스트 잘림·오버플로·한글 줄바꿈(keep-all)·**이미지/그라디언트 배경 위 텍스트 대비(워시아웃)**·stale 잔재·숫자 정합. "완료" 선언 전에 검토를 사용자에게 떠넘기지 말 것. (빌더 score 100은 스키마 통과만 보장 — 본문 누락·대비 불량 못 잡음) |

**금지 표현**: "아마", "확신한다", "이전에 실행했으니", "간단한 변경이라", "Great!/Done!" — 확률 표현(should, probably, seems to)은 증거가 아니다.

## 검증 패턴

- **테스트/빌드**: 명령어 실행 → 출력에서 0 failures/exit 0 확인 → 그 다음 주장
- **회귀 테스트**: 통과 → 되돌리기 → 실패 확인 → 복원 → 통과 (Red-Green)
- **요구사항**: 계획 재읽기 → 항목별 검증 → 갭 또는 완료 보고
- **에이전트 위임**: 보고 신뢰 금지 → VCS diff로 독립 검증

## verification-engine 연동

이 규칙(인지적 강제)과 verification-engine 스킬(`/handoff-verify`, 시스템적 검증)은 상호보완. 둘 다 필요.

## 검증 도구 진입점

| 목적 | 도구 | 사용법 |
|------|------|--------|
| 빌드/테스트/린트 확인 | `/handoff-verify` | 커밋 전 기본 검증 |
| 자동 재시도 (최대 3회) | `/verify-loop` | handoff-verify 실패 시 |
| 패턴 검증 보고서 | verification-engine 스킬 | 아키텍처/설계 검증 |
| fresh-context 검증 | verify-agent | 에이전트 위임 후 독립 검증 |

## 적용 시점

**항상:** 완료 주장, 만족 표현, 커밋/PR/태스크 완료, 다음 태스크 이동, 에이전트 위임 전에. 검증에 지름길은 없다.

**비례 적용:** 변경 범위에 비례한 증거면 충분하다. 단순 텍스트/설정 수정 → diff 확인. 코드 변경 → 테스트/빌드. 버그 수정 → 재현→통과.

## 자율 검증 (Autonomous Verify, §11 — 2026-06-12)

> 비유: 숙련된 정비공은 사장이 "점검했냐"고 물어볼 때까지 기다리지 않는다. 정비를 끝내면 시동을 걸어보고 결과를 보고한다. 모델이 좋아진 지금, 검증도 그래야 한다.

비단순 코드 변경을 끝냈으면 **사람의 `/handoff-verify` 호출을 기다리지 말고 에이전트가 자율로** verify-agent 또는 `/handoff-verify` 스킬을 실행한 뒤 완료를 주장한다 (work-agreements.md §11·§12). 위임은 검증을 *없애는* 게 아니라 "사람이 매번 호출하는 수고"만 없앤다 — **Gate Function(증거 없는 완료 주장 금지)은 그대로이며, 에이전트가 그 게이트를 자율로 충족**한다.

**불변식 바닥(invariant floor)** — 자율 룰이 세션 오염에 흔들려도 다음 결정론 backstop이 검증을 떠받친다:
- `auto-verify-fix.sh` (PostToolUse Edit/Write) — 경량 typecheck/구문 검증 자동
- Dev Team Hub 모드 HARD-GATE 3 (`verify.json` all-green) — `dev-team.md`
- `/auto` 임베딩 — feature/bugfix 파이프라인이 handoff-verify를 강제 호출

**검증 3층의 무게·발동 경계 (2026-06-19)** — 검증은 무게에 비례해 발동을 분리한다: `auto-verify-fix`(경량 ~300ms, PostToolUse 매 편집·타입/구문) → `verify-agent`(중간 >30s, §11 에이전트 자율 — **단독 코드편집 케이스를 받음**) → `handoff-verify`(무거움 8-reviewer >120s, `/auto` 강제 + 커밋·머지 전 자율 + 사용자 명시). **handoff-verify에는 sync-docs식 "편집마다 신호 훅"(`meta-doc-sync-suggest.sh`류)을 의도적으로 두지 않는다** — 8-reviewer는 무거워 매 편집 신호 시 토큰 폭주 + verify-agent와 중복이기 때문. 단독 코드편집의 검증은 verify-agent가, 커밋·머지 전 무거운 검증은 `/auto` 강제가 받는다. sync-docs(가벼움)는 단독편집 신호 훅이 적합했으나 handoff-verify는 무게 때문에 이 **비대칭이 올바르다** — "일관성"을 이유로 handoff-verify용 편집-신호 훅을 추가하지 말 것.

**비례 적용은 유지**: 단순 텍스트/설정 변경은 자율 verify 대상이 아니다(diff 확인으로 충분). "자율"이 "과잉 검증"이 되지 않게 — 비단순 코드 변경에만.
