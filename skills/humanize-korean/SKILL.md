---
name: humanize-korean
description: "Clean up translation-ese and AI-writing tics in Korean prose so it reads like a person wrote it — content (facts, numbers, proper nouns, quotes) stays 100% unchanged, only style and rhythm are touched. Single-pass, done in this session. Triggers — AI 티 없애줘, 번역투 고쳐줘, 한글 자연스럽게 윤문해줘, sounds like a machine translation, remove AI tells from this Korean text, make this Korean read naturally. Not for: marketing copy generation (write it clean the first time — see rules/korean-writing-quality.md), English text, plain spell-check (see korean-spell-check), or book-length manuscripts."
---

# Humanize Korean — single-pass cleanup skill (한글 윤문 스킬)

> **Analogy.** A proofreading desk for text that reads like it just came out of a translator — the goal is to make it read like it was written in Korean from the start. It changes **not a single fact** (proper nouns, numbers, quotes stay 100% intact) — only the style and rhythm. This is *removing translation-ese and AI idioms to improve Korean prose quality*, not "evading an AI detector."
>
> 비유: 번역기를 갓 거친 듯 어색한 한글을 "원래 한국어로 쓴 글"처럼 다듬는 교정 데스크. **사실은 한 글자도 안 바꾸고**(고유명사·수치·인용 100% 보존) 문체·리듬·표현만 손본다. 이것은 *번역투·AI 구문 제거 = 한글 품질 개선*이지 "AI 탐지기 우회"가 아니다.

## 0. Before you start — scope and data-surface check

1. **Routing check.** If the input is marketing copy that hasn't been written yet, don't run this skill on it — write it clean the first time per `rules/korean-writing-quality.md` instead; this skill is for cleaning up existing text. If the input is a full book manuscript, treat this as a starting point only — long-form editorial judgment belongs to a human editor or a project-specific process.
2. **Sensitive-text check (see `rules/korean-writing-quality.md` §5).** If this session or your tooling routes the actual rewrite through a model surface outside this session (a different vendor's API, a hosted service), don't send text containing client names, deal amounts, PII, salary data, or secrets through that surface unless you've explicitly cleared it for that data. When in doubt, do the cleanup pass locally in this session, or redact first.

## 1. Single-pass workflow (in this session, one pass)

1. **Read the input.** If it's long (roughly 5,000+ Korean characters), consider splitting it into logical sections and running the pass per section — don't try to hold the whole self-check in your head for a very long piece at once.
2. **Detect.** Scan the text against `references/quick-rules.md` (compact ID + prescription table) and, for anything ambiguous or worth a worked example, `reference/ai-tell-taxonomy.md` (the full pattern reference this pack ships at the repo root).
3. **Rewrite.** Fix only the spans you detected — a surgical edit, not a rewrite of the whole piece. Keep every proper noun, number, date, unit, and direct quote byte-for-byte identical.
4. **Self-check.** Run the six-item checklist in `references/quick-rules.md` before returning the result. If change rate exceeds 50%, stop and tell the user instead of shipping the rewrite — that's not a cleanup pass anymore.
5. **Return.** The cleaned text, plus: (a) a one-line status (change rate estimate, rough grade A-D per `references/quick-rules.md`), and (b) 3-6 of the most significant before → after examples so the user can see what actually changed.

## 2. Iron rules (violate any of these → roll back)

1. **Meaning is invariant.** Facts, claims, numbers, dates, proper nouns, and quotes are preserved 100%.
2. **Evidence-grounded.** Only touch spans that map to a pattern in `references/quick-rules.md` or `reference/ai-tell-taxonomy.md`. Don't edit prose just because you'd have phrased it differently.
3. **Genre and register stay put.** A column doesn't become an essay. A report doesn't slide into blog voice. Formal register stays formal.
4. **No over-polish.** A change rate above 30% is a warning sign; above 50%, stop and reconsider — you're rewriting, not cleaning up.

## 3. Forbidden framing (CRITICAL)

Never describe this skill's purpose as "evading an AI detector," "detector bypass," or "hiding that this was AI-written." The actual purpose is *improving awkward, translation-ese Korean into natural Korean* — a legitimate prose-quality goal, independent of who or what wrote the draft.

## 4. Deeper cleanup (out of scope for this skill)

For long-form (8,000+ characters), high-stakes, or precision-critical text, a heavier multi-pass review (separate detection, rewrite, and independent fidelity/naturalness review stages) does a more thorough job than this single-pass skill. That's a project-specific setup this skill doesn't ship — if you need it, build a multi-stage review around `reference/ai-tell-taxonomy.md` as the shared pattern reference.

## 5. References

- Quality standard this cleanup targets: `rules/korean-writing-quality.md`
- Full pattern reference (10 categories A-J, severity tiers, before/after examples): `reference/ai-tell-taxonomy.md`
- Compact cheat sheet for this single pass: `references/quick-rules.md`
- Adjacent utility skills: `skills/korean-character-count` (deterministic character/byte counting), `skills/korean-spell-check` (rule-based spell/grammar check via a public checker)
