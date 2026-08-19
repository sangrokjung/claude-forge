---
name: korean-writing-quality
description: Korean prose output quality — avoid translation-ese, AI idioms, and mechanical patterns from the moment of generation, not just in a post-hoc cleanup pass. Applies to any Korean prose a human will read. 한국어 산문 출력 품질 — 번역투·AI 관용구·기계적 패턴을 생성 단계에서 회피.
load: conditional
paths:
  - "**/content/**"
  - "**/blog/**"
  - "**/drafts/**"
  - "**/marketing/**"
  - "**/newsletter/**"
  - "**/proposals/**"
  - "**/reports/**"
  - "**/manuscript/**"
  - "**/landing/**"
  - "**/checkout/**"
  - "**/pricing/**"
  - "**/payment/**"
  - "**/*.ko.md"
audience: team
sensitivity: L1
category: content
critical: false
---

# Korean Writing Quality Standard (한국어 글쓰기 출력 품질 기준)

> **Analogy.** A good translator carries the meaning of a source text across a language boundary without changing a single fact, so the result reads as if it had been written in the target language from the start. The same idea applies here: keep the facts, the argument, and the register untouched, and by default, strip only the mechanical tics that AI writing leaves behind.
>
> **비유.** 좋은 번역가는 원문의 뜻을 한 글자도 바꾸지 않으면서 "원래 한국어로 쓴 글"처럼 옮긴다. 우리 글도 같다. 사실·논지·격식은 그대로 두고, AI가 남긴 기계적 말투(번역투·상투구)만 걷어낸 자연스러운 한국어가 디폴트다.

## 0. One-line rule (한 줄 원칙)

When generating Korean prose a human will read, avoid translation-ese, AI idioms, and mechanical patterns **at generation time** — write naturally the first time, rather than treating a cleanup pass as mandatory for everything. Run a cleanup pass (`skills/humanize-korean`, shipped alongside this rule) only on output that still falls short after generation.

어느 실행 환경에서도, **사람이 읽을 한국어 산문을 생성할 때 번역투·AI 관용구·기계 패턴을 생성 단계에서 회피**한다. 매번 사후 윤문을 강제하는 게 아니라 처음부터 자연스럽게 쓴다(pre-gen). 미달 산출물만 `humanize-korean` 스킬로 보정한다(post-gen).

## 1. Scope (적용 대상)

Marketing copy, landing pages, SNS posts, blog posts, newsletters, customer/team email, report prose, proposal prose, educational content, video scripts, customer-support replies, brand stories, meeting-summary prose — **any Korean prose or message a human will read.**

**Korean UI copy inside code files (`.tsx`/`.jsx`/`.html`, etc.) counts as prose too.** Headlines, subcopy, button labels, notices, FAQ text, and pricing/checkout copy don't get a pass just because the file extension is code. Even when a request is framed purely as "edit the checkout page," touching the Korean copy on it still falls under this rule.

마케팅 카피·랜딩·SNS·블로그·뉴스레터·고객/팀 이메일·보고서 산문·제안서 산문·교육 콘텐츠·유튜브 스크립트·CS 답변·브랜드 스토리·회의록 요약 산문 등 **사람이 읽을 한국어 산문·메시지**. **코드 파일(tsx/jsx/html 등) 안의 사용자 노출 한국어 문자열도 산문이다.** 헤드라인·서브카피·버튼·안내문·FAQ·가격/결제 문구는 파일이 코드라는 이유로 아래 §2의 "코드" 제외를 적용받지 않는다.

## 2. Exclusions (제외)

- Code, comments, commit messages, logs, CLI output, structured data (JSON/YAML/table cells) — except user-facing Korean UI copy strings *inside* code files, which fall under §1, not this exclusion.
- Legal/contract boilerplate (precision and register take priority — formal legal register is not an AI tell).
- Direct quotes, proper nouns, personal/product names, numbers, dates, units.
- Intentional visual copy (a large headline, bold keywords meant to hook the reader — don't let cleanup weaken the hook). This exclusion means "don't let cleanup kill an intentional hook," not "headlines are AI-tell-exempt": em-dash interjections, translation-ese ("~를 통해" overuse), and mechanical parallelism should still be avoided in headlines and CTA badges.
- English output.
- Cases where the user has explicitly asked for a machine/AI-sounding style.

- 법률 조문·계약서 정형 문구 (register·정확성 우선, 격식체는 AI 티가 아니다)
- 직접 인용·고유명사·인명·제품명·수치·날짜·단위
- 의도적 시각 카피 (빅 헤드라인·키워드 굵게 등, 후킹 약화 금지). 이 제외는 "윤문이 훅을 죽이지 말라"는 뜻이지 헤드라인의 AI-tell 면제가 아니다. 줄표(—) 삽입구·번역투·기계 병렬은 헤드라인·CTA 배지에서도 회피한다.
- 사용자가 AI/기계 스타일을 명시 요청한 경우

## 3. Principles (원칙)

1. **Pre-gen first.** Write clean at generation time; don't force a cleanup pass on every piece of writing (cost, over-editing, and unnecessary data movement if the cleanup tool runs elsewhere).
2. **Remove only the AI mechanics, keep everything else.** Register, expertise, genre, argument, and facts stay 100% intact. **AI-tell is not the same thing as formality.**
3. **Don't over-edit.** Don't introduce metaphor or rhetoric that wasn't in the source. Don't dull an intentional tone or hook.
4. **Fix on shortfall.** If a piece still falls short of the bar after generation, clean it up with the `humanize-korean` skill (post-gen, optional). See §5 before sending sensitive text through any cleanup pass.
5. **Model/tool choice is out of scope for this rule.** Which model or tool writes and polishes the prose is a project decision this rule doesn't make; this rule sets the *quality bar*, not the routing.

1. **pre-gen 우선**: 생성 단계에서 깨끗하게. 사후 윤문 패스를 모든 글에 강제하지 않는다.
2. **AI 기계성만 제거, 나머지 보존**: 격식·전문성·register·장르·논지·사실은 100% 유지. **AI-tell ≠ 격식.**
3. **과윤문 금지**: 원문에 없던 비유·수사를 임의로 추가하지 않는다. 의도된 톤·후킹을 해치지 않는다.
4. **미달 시 보정**: 품질 바 미달이면 `humanize-korean` 스킬로 윤문(post-gen, 선택). 사후 윤문 시 §5를 준수한다.
5. **모델 선택은 본 룰의 소관이 아니다**: 어떤 모델·도구로 문구를 쓰고 다듬을지는 프로젝트마다 다른 결정이다. 본 룰은 *품질 기준*이지 라우팅 룰이 아니다.

## 4. The quality bar (품질 바)

Core patterns confirmed, across before/after cleanup passes on real Korean prose, as defaults to avoid from the moment of generation:

- **Translation-ese**: "~에 대해" overuse, "~를 통해" overuse, "가지고 있다" (literal "have/possess"), double passive ("~되어진다"), "~에 의해" passive, "~할 수 있다" overuse.
- **AI idioms**: "결론적으로/요약하면" (in conclusion / to summarize), "시사하는 바가 크다/주목할 만하다" (has significant implications / noteworthy), hype words "혁신적/획기적/압도적" (revolutionary/groundbreaking/overwhelming), "~이야말로 적기/~할 때다" (now is truly the time).
- **Structure**: "첫째 둘째 셋째" mechanical parallelism, emoji overuse, sentence-initial conjunction ("또한/따라서/즉") overuse, stacked hedging, formal-noun overuse ("것이다/점/수/바").
- **Confirmed via real-world publishing feedback**: em-dash interjections (—…—), win/lose personification ("X beats/wins over Y"), abstract structural-noun overuse ("축/갈래/결/레이어" — axis/branch/texture/layer).

The full pattern reference (10 categories A–J, severity tiers S1/S2/S3, academic grounding, before/after examples) lives in `reference/ai-tell-taxonomy.md`.

> **External-editor validation.** A professional book-publishing editorial team, reviewing draft manuscript chapters, flagged em-dash interjections and win/lose personification ("beats"/"wins over") as common enough across recent AI-assisted submissions to raise suspicion of AI authorship on their own — even though neither pattern is technically incorrect Korean. Two different authors' independent drafts produced the identical phrasing ("이깁니다") in the same spot in their argument. The lesson generalizes: even a grammatically correct pattern is worth avoiding once it becomes a recognizable AI signature. Formal or for-publication writing (a submission, a pitch, a contribution) should run a deterministic style gate before it goes out — the shipped `hooks/emdash-slop-guard.sh` in this pack covers the em-dash half of that gate.
>
> 외부 출판사 편집부가 단행본 원고 초고 검토에서 줄표(—) 삽입구와 "이긴다/이깁니다" 류 표현을 "요즘 집필 제안 원고들에 공통적으로 나온다. 잘못된 표현은 아니지만 불필요한 의심(AI 생성 의심)을 살 수 있다"며 명시 지적했다. 서로 다른 저자의 원고 2건에서 같은 자리에 같은 "이깁니다"가 발견되기도 했다. 잘못된 표현이 아니어도 의심을 유발하면 회피 대상이다.

## 5. Sending Korean prose through a third-party model surface (제3자 모델 표면으로 전송할 때)

If a cleanup or rewrite pass routes Korean text through a model surface outside this session — a different vendor's API, a separate tool, a hosted service — treat that the same as any other outbound data transfer: don't send sensitive text (client names, deal amounts, PII, salary data, secrets) to a surface you haven't explicitly cleared for that kind of data. When in doubt, keep the cleanup pass local to this session, or redact the sensitive spans first.

윤문·재작성 패스가 이 세션 밖의 모델 표면(다른 벤더 API·별도 도구·호스팅 서비스)을 거친다면, 다른 외부 발송과 똑같이 취급한다. 그 표면에 보내도 된다고 명시적으로 확인하지 않은 민감 텍스트(고객 실명·거래 금액·PII·급여·시크릿)는 보내지 않는다. 애매하면 윤문을 이 세션 안에서만 하거나, 민감 구간을 먼저 가린다.

## 6. Verification (검증)

- **Self-check**: after writing prose, scan once for the §4 patterns still lingering.
- **Deterministic gate**: this pack ships `hooks/emdash-slop-guard.sh` (registered under `settings.json`'s `PostToolUse` `Edit|Write` group), which fires on written/edited `.md` files whose content is substantially Korean and flags em-dash interjections and heading separators via `scripts/emdash_slop_check.py`. It's advisory (exit 0, non-blocking) — treat its warning as a to-do, not noise. English documents don't trigger it (see the hook's own Hangul-ratio scoping gate).
- If your project already has a pre-publish review step, fold a translation-ese/AI-tell scan into it as one more gate before anything goes out.

- **자가 점검**: 산문 작성 후 §4 핵심 패턴이 남아있지 않은지 1회 스캔.
- **결정론 게이트**: 본 팩이 함께 배포하는 `hooks/emdash-slop-guard.sh`(`settings.json`의 `PostToolUse` `Edit|Write` 그룹에 등록)가, 편집·작성된 `.md` 파일 중 **한국어 비중이 충분히 높은 파일**에서만 줄표 삽입구·헤딩 구분자를 `scripts/emdash_slop_check.py`로 검사·경고한다. 비차단(exit 0)이며 영어 문서에는 발동하지 않는다(훅 자체의 한글 비율 스코핑 게이트).

## 7. Boundary with adjacent guidance (인접 규칙과의 경계)

| Adjacent guidance | Boundary |
|---|---|
| `rules/interaction.md` tone guidance | This rule is the *sentence-level implementation* of that tone (removing translation-ese and AI-tell). |
| A project's own copy-generation model routing (if any) | That's a *model* decision; this rule sets the *quality* bar regardless of which model writes. |
| `skills/humanize-korean` | That's the cleanup *tool* and its data-surface guard (§5); this rule is the *generation-time* quality standard (pre-gen). |

## 8. Related (관련 자산)

`rules/interaction.md` (tone) · `reference/ai-tell-taxonomy.md` (pattern reference, SSOT) · `skills/humanize-korean` (cleanup skill) · `hooks/emdash-slop-guard.sh` + `scripts/emdash_slop_check.py` (deterministic em-dash gate) · `skills/korean-character-count`, `skills/korean-spell-check` (adjacent Korean-text utility skills)
