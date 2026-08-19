# Quick Rules — single-pass cleanup cheat sheet (한 콜 윤문용 룰북)

A compressed rulebook for this skill's single-pass cleanup: the S1/S2 patterns
from `reference/ai-tell-taxonomy.md` (the full ~50-pattern reference), reduced
to one line each — definition + prescription, no examples. IDs match the full
taxonomy 1:1, so cross-reference by ID when you need the worked example.

**Principle**: one line of definition, one line of prescription. No worked
examples here — those live in the full taxonomy.

**Do-NOT (never touch, in detection or rewrite)**: proper nouns, product/model/
institution names, numbers, dates, units, direct quotes in double quotes, legal
statute text, math/chemistry/statistics notation, industry-standard English
abbreviations (LLM, GPU, MCP, API, etc.).

**Over-polish guard**: a change rate above 30% is a warning sign; above 50%,
stop and reconsider the pass — you're likely rewriting, not cleaning up.

이 스킬의 단일 패스 윤문에 쓰는 압축 룰북이다. `reference/ai-tell-taxonomy.md`
(전체 ~50패턴 본진)에서 S1·S2 핵심 패턴만 추려 정의+처방 한 줄로 압축했다. ID는
본진과 1:1로 매칭되므로, 예문이 필요하면 해당 ID로 본진을 참조한다.

---

## A. Translation-ese (번역투)

| ID | Pattern | Severity | Prescription |
|---|---|---|---|
| A-1 | "~에 대해(서)" overuse | S1 | Connect with an object particle directly ("X에 대해 논의" → "X를 논의") |
| A-2 | "~를 통해/통하여" overuse | S1 | Spread across "~로", "~해서", "~함으로써" |
| A-3 | "~에 있어(서)" | S1 | "~에서", "~을 볼 때" |
| A-4 | "~라는 점에서" 3+ times | S2 | "~서", "~라는 이유로" |
| A-5 | "~와 관련하여/관련된" | S2 | "~에", "~의" |
| A-6 | "~에 기반하여/바탕으로" overuse | S2 | "~로", "~을 보고" |
| A-7 | "가지고 있다" / literal have·make·take·give + noun | S1 | Reduce to adjective/verb, or a double-subject construction ("회의를 가지다" → "회의를 했다"; "강한 경쟁력을 가지고 있다" → "경쟁력이 강하다") |
| A-8 | Double passive "~되어진다" | S1 | Active voice, or a single passive ("판단되어진다" → "판단된다") |
| A-9 | "~에 의해" passive | S2 | Restore the agent as subject ("AI에 의해 생성" → "AI가 만든") |
| A-10 | "~할 수 있다" overuse | S2 | State it plainly ("높일 수 있다" → "높인다") |
| A-11 | "~을 위해" purpose-clause overuse | S2 | "~려고", "~위한" |
| A-15 | Abstract subject + generic verb / causative·cognition verbs | S2 | Reduce to a concrete subject; causatives become "X 때문에/덕분에/로 인해" adverbial clauses; cognition verbs (suggest/show/indicate/reveal) become "~에 따르면 ~이다" / "~으로 ~이 드러났다" |
| A-16 | "그/그녀/그것/그들" ≥3 times per paragraph (literal English pronoun) | S1 | 50%+ should be dropped (zero pronoun) or replaced with a name/title |
| A-18 | ≥3-word modifier clause stacked left of a noun (relative-clause literalism) | S2 | Split the sentence, or use a postposed apposition ("X를 만났는데, 그 X는 …") |
| A-19 | Double particle "~에서의/~에로의/~으로의/~에의/~으로부터의" | S2 | Unpack into a clause/phrase. Plain "~의" alone is not in scope |

## B. English quoting/terminology overuse

| ID | Pattern | Severity | Prescription |
|---|---|---|---|
| B-1 | Korean term + parenthetical English every time (e.g. "~(Sovereign AI)") | S2 | Pair once on first mention, Korean only after that |
| B-2 | English word left untranslated when a Korean equivalent exists | S2 | Translate, but keep industry-standard terms as-is |

## C. Structural AI patterns

| ID | Pattern | Severity | Prescription |
|---|---|---|---|
| C-5 | Emoji overuse | S1 | Remove entirely in essay/report genres |
| C-7 | "먼저·반면·결국" 3-step formula | S2 | Cut to 1-2 connectors, or dissolve into prose |
| C-8 | "A인가·B인가" parallel-question repetition | S2 | Keep one instance, flatten the rest to declaratives |
| C-9 | Numbered-parenthetical indexing "(1)·(2)·(3)" | S2 | Dissolve into prose or a simple line break |
| C-10 | Colon-subtitle heading "X: Y" repeated | S1 | Shorten the heading or make it a plain declarative |
| C-11 | Comma right after a connective ending (-고/-며/-지만/-면서/-아서/-어서) | S1 | Remove the comma. 6+ occurrences is a strong signal |

## D. AI signature phrases

| ID | Pattern | Severity | Prescription |
|---|---|---|---|
| D-1 | Summary-pivot lexicon "결론적으로/따라서/이를 통해/그러므로/요약하면/정리하면" | S1 | Above 3 occurrences, replace 1-2 with a different closer and delete the rest |
| D-2 | "시사하는 바가 크다/주목할 만하다" | S1 | Delete or replace with a concrete conclusion |
| D-3 | "본질적으로/핵심적으로" | S1 | Delete |
| D-4 | Hype words (파격적·압도적·강력한·획기적·치명적) 3+ times | S1 | Reduce to concrete numbers/facts |
| D-5 | Personified abstract subject ("기술이 묻는다·시대가 부른다") | S1 | Use a person/organization as subject |
| D-6 | Formulaic closer "~할 때다/~해야 한다/~지금이야말로" | S1 | Close plainly, or delete |
| D-7 | Transformation formula "X에서 Y로" repeated | S2 | Keep one instance, generalize the rest |
| D-8 | Win/lose personification ("X가 Y를 이긴다/이깁니다") | S2 | State the priority directly ("구체적인 규칙이 일반 규칙보다 우선한다") |
| D-9 | Abstract structural-noun overuse ("축·갈래·결·레이어") | S2 | Replace with a concrete noun ("기준·조건·경우·종류·단계") |

## E. Rhythm / sentence endings

| ID | Pattern | Severity | Prescription |
|---|---|---|---|
| E-1 | Uniform sentence length (low variance) | S2 | Deliberately insert 1-2 short sentences and 1 long sentence per paragraph |
| E-2 | Same ending "~다" 4+ sentences in a row / auto-mapped progressive "~고 있다" | S2 | Vary endings ("~었다·~ㄴ다·~는다·~기 마련이다·~ㄹ 것이다" etc.); collapse "~고 있다" to a simple tense where it reads the same ("읽고 있다" → "읽는다") |
| E-7 | Inconsistent register across 해라/하게/하오/해요/합쇼 in dialogue/spoken text | S2 | Pick one register per passage and keep it consistent |

## F. Over-modification / redundancy

| ID | Pattern | Severity | Prescription |
|---|---|---|---|
| F-4 | Nominalization suffixes (한자어 -성/-적/-화, English -tion/-ment/-ness/-ity) stacked 12+ times | S2 | Reduce to a verb/adjective root ("the implementation of the policy" → "정책 시행" or "정책을 시행하기") |
| F-5 | "~적 N" abstract-noun chain ("전략적 함의·실천적 기반") | S2 | Compound noun or unpack ("전략 함의·실천의 기반") |

## G. Hedging

| ID | Pattern | Severity | Prescription |
|---|---|---|---|
| G-1 | "~것이다/~할 것이다" future-tense overuse | S2 | Present/declarative tense |
| G-2 | "~로 보인다/~인 듯하다" speculative overuse | S2 | State plainly where you can |
| G-3 | Safe-balance lexicon "양쪽 모두/두 가지 모두/장점도 있지만/신중하게/균형" | S2 | Above 4 occurrences, replace 1-2 with an actual position |

## H. Conjunction overuse

| ID | Pattern | Severity | Prescription |
|---|---|---|---|
| H-1 | Sentence-initial conjunctions "또한·따라서·즉·나아가·아울러·게다가·더욱이" 5+ times | S1 | Cut most of them. Let the sentence carry its own flow |
| H-3 | Meta-entry phrases "이는·이 점에서·이 관점에서·이 말은" 3+ times | S1 | Dissolve into the surrounding prose or delete |
| H-4 | "즉" overuse | S2 | Limit to one use |

## I. Formal/dependent-noun overuse

| ID | Pattern | Severity | Prescription |
|---|---|---|---|
| I-1 | "~인 것이다/~한 것이다" closer | S1 | Plain declarative |
| I-2 | "X은 ~라는 점에 있다" | S2 | Direct "X는 ~다" statement |
| I-3 | "~다는 뜻이다/~다는 의미다" closer | S2 | Unpack into the sentence itself |
| I-4 | Recommendation closer "~해야 한다·~합니다" repeated | S2 | Declarative/assertive |

## J. Visual-decoration overuse

| ID | Pattern | Severity | Prescription |
|---|---|---|---|
| J-1 | Markdown `**bold**` overuse in headings | S2 | Remove almost all of it in essay/report genres |
| J-2 | Quotation-mark emphasis 5+ times | S1 | Keep one or two on the most important terms, plain text elsewhere |
| J-3 | Bullet lists (in essay/report genres) | S2 | Merge into paragraph prose |

---

## Self-check (right after the rewrite pass)

Check the following within the same pass. If any item fails, roll back that edit.

1. **100% preserved**: proper nouns, numbers, dates, quotes — not a single character different from the source in those spans.
2. **Change rate**: 30% or under (above 50% means stop the pass).
3. **No genre drift**: a column hasn't turned into an essay; a report hasn't slid into blog voice.
4. **Register preserved**: formal stays formal, plain register isn't introduced.
5. **Zero remaining S1 patterns**: check D-1~D-7, A-7, A-8, A-16, C-5, C-10, C-11, H-1, I-1, J-2 in particular.
6. **No invented flourish**: no metaphor or rhetorical device was added that wasn't in the source.

## Grading (self-score)

- **A**: 0 remaining S1, 2 or fewer S2, 10-25% change rate, all 6 self-check items pass.
- **B**: 0 remaining S1, 4 or fewer S2, 5+ self-check items pass.
- **C**: 1-2 remaining S1, or 4 or fewer self-check items pass — recommend a second, more careful pass.
- **D**: 3+ remaining S1, or change rate over 50% — recommend stopping and flagging to the user instead of shipping the rewrite.
