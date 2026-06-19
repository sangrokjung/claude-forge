---
allowed-tools: Bash(git:*), Bash(command:*), Bash(python3:*), Read, Workflow, Skill(sync-docs), Skill(commit-push-pr)
description: 8 reviewer 병렬 검증 (Workflow tool 결정론 fan-out + CRITICAL/HIGH adversarial 재검증)
argument-hint: "[의도 텍스트]"
---

# /handoff-verify — Workflow Parallel Fan-out (8 reviewers + adversarial verify)

> 트리거 주체 (§12, 2026-06-12): 본 스킬은 이미 Skill이다 — §12 "스킬화"는 완료 상태다. 미해결이었던 것은 **트리거 주체**다. 비단순 코드 변경 완료 후 **에이전트가 자율 호출**한다(사람이 매번 `/handoff-verify`를 입력하는 것은 폴백). 근거: verification.md "자율 검증 §11".

**Workflow tool 기반** pre-merge 검증 게이트. v7의 "단일 메시지 8× `Task()` 수동 fan-out"을 Workflow tool `parallel()`로 전환 — 결정론적 동시 spawn(사일런트 spawn 실패 0) + `schema` 강제 구조화 회수 + CRITICAL/HIGH **적대적 재검증**(false positive 제거).

| Reviewer | 영역 | gating |
|----------|------|--------|
| code-reviewer | 정적 보안+품질 | always |
| verify-agent | typecheck/lint/build/test 실행 (수정 금지) | always |
| security-reviewer | OWASP+STRIDE | always |
| database-reviewer | RLS/EXPLAIN/N+1 | always |
| a11y-reviewer | WCAG 2.1 AA | always |
| performance-reviewer | Core Web Vitals | always |
| codex-reviewer | GPT-5.5 크로스모델 | `command -v codex` |
| gemini-reviewer | Gemini 프론트엔드 | `command -v gemini` |

워크플로우 SSOT: `~/.claude/skills/handoff-verify/handoff-verify.workflow.js`
reviewer 상세 체크리스트: `~/.claude/skills/handoff-verify/reviewer-prompts.md`

## v7 → v8 변경 (왜 Workflow인가)

| v7 (Task 수동 fan-out) | v8 (Workflow tool) |
|---|---|
| 단일 응답에서 8× `Task()` 발화 — 비결정적, 사일런트 spawn 실패 가능 | `parallel(8)` 결정론 fan-out — 모든 reviewer 회수 보장 |
| §3 "발화 검증 가드"(C3)로 7/8 누락 재시도 | 구조적 불필요 — barrier가 8/8 보장 |
| perl placeholder 치환 → 메인이 추출 → Task() | `args` 객체 1회 주입 |
| 결과 Severity 분류·dedup LLM 추론 | `schema` 강제 + 스크립트 결정론 집계·dedup |
| dedup 없음 (D5) | file_line+severity 키 dedup (reviewer 목록 보존) |
| 없음 | **CRITICAL/HIGH adversarial 재검증** — 오탐 제거 |

## 1단계: 환경 수집 + args 생성 (bash)

```bash
# 변경 없으면 abort
if [ -z "$(git status --short)" ]; then
    echo "변경사항 없음. git status 빈 결과. /handoff-verify 종료."
    exit 0
fi

# CLI 가용성 안내 (미설치 reviewer는 워크플로우가 자동 skip)
CODEX_OK=$(command -v codex >/dev/null 2>&1 && echo true || echo false)
GEMINI_OK=$(command -v gemini >/dev/null 2>&1 && echo true || echo false)
if [ "$CODEX_OK" = "false" ] || [ "$GEMINI_OK" = "false" ]; then
    echo "⚠️  크로스모델 가용성 — codex:$CODEX_OK gemini:$GEMINI_OK"
    echo "   미설치 reviewer는 자동 skip + 푸터 명시. 설치: Read ~/.claude/skills/handoff-verify/cli-setup.md"
fi

# args JSON 생성 (python3로 안전 인코딩 — diff 8KB·따옴표·줄바꿈 이스케이프)
python3 - "$ARGUMENTS" << 'PYEOF'
import json, os, subprocess, sys

def sh(cmd):
    try:
        return subprocess.run(cmd, shell=True, capture_output=True, text=True).stdout
    except Exception:
        return ""

def has(cmd):
    return subprocess.run(f"command -v {cmd}", shell=True,
                          capture_output=True).returncode == 0

def read(path, fallback="(없음)"):
    try:
        with open(path) as f:
            return f.read().strip() or fallback
    except Exception:
        return fallback

intent = sys.argv[1] if len(sys.argv) > 1 and sys.argv[1].strip() else "(없음)"
dod = sh("grep -E '^- \\[ \\] DoD-' .claude/sprint-contract.md 2>/dev/null").strip() or "(없음)"

payload = {
    "intent": intent,
    "changed_files": sh("git diff --name-only HEAD").strip() or "(없음)",
    "diff": sh("git diff HEAD")[:8000] or "(없음)",
    "handoff": read(".claude/handoff.md"),
    "dod": dod,
    "has_codex": has("codex"),
    "has_gemini": has("gemini"),
}
print(json.dumps(payload, ensure_ascii=False))
PYEOF

# 워크플로우 본체 경로 탐지 (.claude 우선 → dotclaude fallback. 멀티PC 견고 — 동기화 가정 제거)
WF_PATH=$(ls ~/.claude/skills/handoff-verify/handoff-verify.workflow.js 2>/dev/null \
  || ls ~/qjc-office/dotclaude/skills/handoff-verify/handoff-verify.workflow.js 2>/dev/null)
if [ -z "$WF_PATH" ] || [ ! -f "$WF_PATH" ]; then
  echo "❌ handoff-verify.workflow.js 미발견 — 동기화 필요 (/dc pull 또는 /company-sync)"; exit 1
fi
echo "WF_PATH=$WF_PATH"
```

위 bash 출력의 **마지막 JSON 줄**(payload)과 **`WF_PATH=` 줄**을 2단계에 사용한다.

## 2단계: Workflow 호출 (결정론 병렬 fan-out)

메인 세션은 `Workflow` tool을 **scriptPath + args**로 1회 호출:

```
Workflow({
  scriptPath: "<1단계 출력의 WF_PATH 값 (절대경로 — 하드코딩 금지)>",
  args: <1단계 payload JSON을 JSON.parse 한 실제 객체>
})
```

- `scriptPath`는 **1단계가 탐지·검증한 `WF_PATH`** 를 그대로 쓴다. 경로를 하드코딩하지 말 것 (멀티PC에서 .claude 미동기화 시 dotclaude로 자동 fallback됨).
- `args`는 JSON **문자열이 아니라 `JSON.parse`로 파싱한 객체**로 전달 (`{intent, changed_files, diff, handoff, dod, has_codex, has_gemini}`). ⚠️ 문자열 그대로 넘기면 워크플로우가 흡수는 하지만(방어 코드 존재), 명시적으로 파싱하여 넘기는 것이 표준.
- 워크플로우는 background 실행 → 완료 시 `<task-notification>` 도착 → 결과 JSON 회수.
- 진행 상황은 `/workflows`로 관찰 가능 (Review 8 → Verify N).
- **금지**: `Task()` 수동 fan-out으로 회귀하지 말 것. v8은 Workflow가 유일 fan-out 경로.

워크플로우 반환 형식:
```jsonc
{
  "verdict": "PASS | WARN | FAIL",
  "summary": { "critical": N, "high": N, "medium": N, "low": N, "refuted": N },
  "confirmed_findings": [ { "severity", "file_line", "issue", "reviewers": [...] } ],
  "refuted_findings":   [ { ..., "refute_reason" } ],   // adversarial로 제거된 오탐
  "reviews": [ { "reviewer", "applicable", "verdict", "evidence", "findings", "counts": { "critical": N, "high": N, "medium": N, "low": N } } ],
  "na_reviewers": [...], "error_reviewers": [...], "skipped_reviewers": [...]
}
```

## 3단계: 푸터 출력 (워크플로우 결과를 그대로 포맷 — 추가 추론 금지)

```
══════════════════════════════════════════════════════════════════
  /handoff-verify — Workflow Fan-out (8 reviewers + adversarial)
══════════════════════════════════════════════════════════════════
🔴 CRITICAL (N):
  • <reviewers>: <file:line> — <issue>
🟠 HIGH (N):
  ...
🟡 MEDIUM (N):
  ...
🟢 LOW (N):
  ...
🧪 Refuted (N): <file:line> — <refute_reason>   (adversarial 검증으로 제거된 오탐)
ℹ️ N/A: <na_reviewers> (영역 변경 없음)
⚠️ FAILED: <error_reviewers> / Skipped: <skipped_reviewers (CLI 미설치)>
─────────────────────────────────────────────────────────────────
요약: 🔴N / 🟠N / 🟡N / 🟢N  (refuted N)  |  Verdict: PASS / WARN / FAIL
══════════════════════════════════════════════════════════════════
```

Verdict 룰 (워크플로우가 결정론 산출, confirmed_findings 기준):
- `FAIL`: CRITICAL ≥ 1
- `WARN`: CRITICAL = 0 AND HIGH ≥ 1
- `PASS`: CRITICAL = 0 AND HIGH = 0

다음 단계:
- PASS → `/sync-docs` → `/commit-push-pr --merge` (머지 전 문서 동기화 의무 — commit-push-pr v7이 sync-docs 게이트를 내장하므로 둘 다 자동 진행)
- WARN → 사용자 판단 (HIGH 검토 후 진행 또는 fix)
- FAIL → Critical fix 후 재실행

## 4단계: evaluation-dataset.jsonl 1 entry 기록 (bash)

```bash
# 메인이 워크플로우 반환값을 환경변수로 주입 후 단일 entry append.
# ⚠️ 키 변형/추론 금지 — 워크플로우 반환을 "그대로" 넣는다:
#   EVAL_VERDICT   = 반환 verdict (PASS|WARN|FAIL)
#   EVAL_SUMMARY   = 반환 summary 객체 그대로 {critical,high,medium,low,refuted}
#   REVIEWERS_JSON = 반환 reviews 배열 그대로 (각 원소 {reviewer, applicable, verdict, evidence, findings, counts:{critical,high,medium,low}})
EVAL_VERDICT="<반환 verdict>" \
EVAL_SUMMARY='<반환 summary 객체>' \
REVIEWERS_JSON='<반환 reviews 배열>' \
python3 << 'PYEOF'
import json, os
from datetime import datetime
log_path = os.path.expanduser("~/.claude/evaluation-dataset.jsonl")
entry = {
    "ts": datetime.now().isoformat(),
    "project": os.path.basename(os.getcwd()),
    "command": "handoff-verify",
    "mode": "workflow-parallel-8",
    "result": os.environ["EVAL_VERDICT"],
    "summary": json.loads(os.environ.get("EVAL_SUMMARY", "{}")),
    "reviewers": json.loads(os.environ.get("REVIEWERS_JSON", "[]")),
}
with open(log_path, "a") as f:
    f.write(json.dumps(entry, ensure_ascii=False) + "\n")
PYEOF
```

meta-evaluator 호환: 1 entry = 1 호출. `reviewers` 배열로 reviewer별 합의/불일치, `summary.refuted`로 adversarial 효과 추적.

## 사용 예시

```bash
/handoff-verify                          # 변경사항 검증
/handoff-verify "결제 모듈 리팩토링"      # 의도 명시
```

## 주의

- 8 reviewer 모두 동시 spawn (1줄 fix에도). Workflow concurrency cap min(16, cores-2)이라 8개 동시 OK.
- codex/gemini 미설치 시 자동 skip → 6 reviewer. 보안 변경 시 설치 강력 권장 (cli-setup.md).
- **autofix 없음** — handoff-verify는 검증/보고만. 자동 수정은 `/verify-loop`.
- adversarial 재검증은 **보수적** — 확신 없으면 finding 유지 (게이트는 false negative가 더 위험).
- 옛 `/code-review`, `/verify-loop` v6 그대로 유지. 통합 안 함.
- 모드 옵션(--quick/--standard/--deep) 없음 (사용자 단순함 결정 — v7 계승).
