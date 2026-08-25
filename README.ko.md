<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/banner.jpg">
  <source media="(prefers-color-scheme: light)" srcset="docs/banner-light.jpg">
  <img src="docs/banner.jpg" alt="Claude Forge" width="100%">
</picture>

<p align="center">
  <a href="https://sangrokjung.github.io/claude-forge/?lang=ko"><b>⚡ 처음이신가요? 60초 설치 가이드 →</b></a>
</p>

<p align="center">
  <a href="README.md">English</a> · <a href="README.ko.md"><b>한국어</b></a> · <a href="README.zh.md">中文</a>
</p>

<p align="center">
  <strong>Claude Code(AI 코딩 조수)에 전문 장비 풀세트를 한 번에 장착하는 프레임워크</strong>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/LICENSE-MIT-blue?style=for-the-badge" alt="MIT License"></a>
  <a href="https://claude.com/claude-code"><img src="https://img.shields.io/badge/CLAUDE_CODE-%E2%89%A52.1.110-blueviolet?style=for-the-badge" alt="Claude Code"></a>
  <a href="https://github.com/sangrokjung/claude-forge/stargazers"><img src="https://img.shields.io/github/stars/sangrokjung/claude-forge?style=for-the-badge&color=yellow" alt="Stars"></a>
  <a href="https://github.com/sangrokjung/claude-forge/network/members"><img src="https://img.shields.io/github/forks/sangrokjung/claude-forge?style=for-the-badge&color=orange" alt="Forks"></a>
  <a href="https://github.com/sangrokjung/claude-forge/graphs/contributors"><img src="https://img.shields.io/github/contributors/sangrokjung/claude-forge?style=for-the-badge&color=green" alt="Contributors"></a>
  <a href="https://github.com/sangrokjung/claude-forge/commits/main"><img src="https://img.shields.io/github/last-commit/sangrokjung/claude-forge?style=for-the-badge" alt="Last Commit"></a>
</p>

<p align="center">
  <a href="#-이게-뭔가요">이게 뭔가요?</a> &bull;
  <a href="#-어떻게-설치해요">설치</a> &bull;
  <a href="#-뭐가-들어있어요">구성 요소</a> &bull;
  <a href="#-어떻게-써요">사용법</a> &bull;
  <a href="#-v30-업데이트">v3.0 변경사항</a> &bull;
  <a href="README.md">English</a>
</p>

> 🛡️ **v4.0.0 (2026년 8월)**: 가장 큰 변화는 **적대적 검증 루프(adversarial verification loop)**예요. 코드를 바꿀 때마다, 그 코드를 짜지 않았고 짠 사람의 생각 흐름도 모르는 독립 리뷰어(`adversarial-reviewer`)가 따로 검증해요. "작성자와 검증자는 다른 사람이어야 한다"(maker≠checker)는 원칙이고, 검증자가 `APPROVE`를 낼 때까지 반복해요. 이론이 아니라 실제로 v4.0을 만드는 동안 이 루프가 대표 유지자 본인의 PR(#58, #61)에서 진짜 결함 3건을 잡아냈어요. 자기 자신의 회귀를 통과시키던 CI 검사 하나, 그 검사를 고친 수정본에 똑같은 구멍이 한 단계 더 숨어 있던 것 하나, 그리고 1년 전 릴리스에 조용히 묶여있던 의존성 상한 하나였죠. 실제 검증 기록은 [`docs/VERIFICATION-LOOP.md`](docs/VERIFICATION-LOOP.md)에 있어요. 그 외에 **신뢰성 패키지**도 넣었어요. API 오류가 나면 세션을 스스로 재개하는 무인 자동 복구, `/compact` 이후에도 이어지는 세션 릴레이, 같은 파일을 계속 고치는 걸 감지하는 무한루프 가드, 옵트인 pre-commit 시크릿 가드가 들어있고, 배선 가이드는 [`docs/RELIABILITY.md`](docs/RELIABILITY.md)에 있어요. **디버깅 에스컬레이션 체인**(`systematic-debugger` → `rca-debugger` → `escalation-fixer`), **작업 난이도 자동 분류**(`/workflow-classify`가 S/M/L/XL로 작업 크기를 매기고 문서화·검증 강도를 그에 맞춰요), **한국어 산문 품질 가드레일**(사후 윤문이 아니라 처음 쓸 때부터 번역투·AI 관용구를 피해요. 아래 별도 섹션 참고)도 함께 담았어요. 에이전트 16개, 커맨드 35개, 스킬 32개, 훅 21개, 규칙 14개. 상세: [MIGRATION.ko.md](MIGRATION.ko.md)
>
> 🔧 **v3.1.1 핫픽스 (2026년 8월)**: 플러그인 설치 시 아무것도 안 뜨던 문제를 고쳤어요(`Hook load failed: expected record, received undefined`). `/plugin install claude-forge` 후 `✘ failed to load`가 뜨고 스킬·에이전트·커맨드가 하나도 안 보였다면 3.1.1로 올리시면 됩니다. 윈도우 `install.ps1`이 statusLine과 `scripts/`를 복사하지 않던 문제도 함께 해결했어요. 관련: [#52](https://github.com/sangrokjung/claude-forge/issues/52) · [#57](https://github.com/sangrokjung/claude-forge/issues/57) · [#50](https://github.com/sangrokjung/claude-forge/issues/50)

> 🎉 **v3.1.0 공개 (2026년 6월)**: **loop-forge**(반복 작업을 재사용 가능한 자가검증 슬래시 명령으로 박제) 추가 + 이 README를 비개발자 눈높이로 전면 재작성(도표 3종 포함). v3.0.2(쉬운 설치 경로)·v3.0.1(Anthropic 2026 표준: 훅 21+ 이벤트 · 서브에이전트 v2 · 스킬/커맨드 하이브리드 · MCP 4개) 기반. 상세: [MIGRATION.ko.md](MIGRATION.ko.md)

> 🚀 **한 줄 설치** (전체 설치, 권장):
> ```bash
> curl -fsSL https://raw.githubusercontent.com/sangrokjung/claude-forge/main/install.sh | bash
> ```
> 또는 Claude Code 세션 안에서: `/plugin marketplace add sangrokjung/claude-forge` → `/plugin install claude-forge` (부분 지원).

---

## 이게 뭔가요?

**Claude Code**(AI 코딩 조수)를 혼자 쓰면 기본기만 할 줄 아는 신입 직원과 같아요. **Claude Forge**는 그 신입에게 장비 풀세트(전문 비서 16명, 단축버튼 35개, 안전장치 21개 등)를 한 번에 장착해 줘요.

> 마치 터미널(명령창)을 꾸며주는 oh-my-zsh처럼, Claude Forge는 AI 코딩 조수를 파워 유저 도구로 업그레이드해요.

한 번 설치하면 아래가 모두 자동 연결돼 바로 쓸 수 있어요:

| 구성 | 숫자 | 쉽게 말하면 |
|:-----|:----:|:------------|
| **에이전트**(agents) | 16개 | 분야별 전문 비서. 기획, 테스트, 보안검토, 아키텍처(시스템 설계), 적대적 검증 등 |
| **커맨드**(commands) | 35개 | 자주 쓰는 작업 단축버튼. `/plan`(계획), `/tdd`(테스트) 등 |
| **스킬**(skills) | 33개 | AI가 익혀둔 작업 절차. 루프 자동화, 팀 오케스트레이션, 적대적 검증 루프 등 |
| **훅**(hooks) | 21 + 예제 9개 | 자동 안전점검. 위험한 명령 차단, API 키 유출 방지, API 오류 자동 복구 등 |
| **규칙**(rules) | 14개 | AI가 따르는 행동 지침. 코딩 스타일, 보안, 깃 워크플로우, 검증 루프 발동 조건 등 |
| **MCP**(외부 도구 연결) | 4개 | 브라우저 자동화, 문서 검색, 웹 읽기, 크롬 개발자 도구 |

---

## 뭐가 좋아요?

### 계획부터 PR까지 자동으로 이어져요

`/plan` 하나로 AI가 구현 계획을 세우고, `/tdd`(테스트 주도 개발)로 테스트를 먼저 작성하고, `/code-review`로 코드를 검토하고, `/commit-push-pr`로 PR(코드 병합 요청)까지 만들어 줘요. 각 단계가 서로 자동으로 연결돼 있어요.

### 6겹 보안 안전망이 항상 켜져 있어요

코드를 짤 때마다 API 키 노출 방지 → 위험한 원격 명령 차단 → 파괴적 SQL(데이터베이스 삭제 명령) 차단 → 취약점 자동 탐지 → API 속도 제한 → 고비용 도구 경고가 자동으로 작동해요. 따로 신경 쓰지 않아도 돼요.

### 반복 작업을 슬래시 명령으로 박제할 수 있어요

`loop-forge`(루프 단조) 스킬로 자주 반복하는 작업 흐름을 한 줄짜리 `/명령어`로 만들어 두면 다음엔 그냥 입력만 하면 돼요.

### `git pull` 한 번이면 즉시 업데이트돼요

설치 방식이 심볼릭 링크(바로가기 연결) 기반이라, 새 버전이 나와도 `git pull` 한 줄로 끝이에요.

---

## 어떻게 설치해요?

![3단계 설치](assets/readme/install-steps.ko.png)

설치 방법은 두 가지예요. 전체 기능이 필요하면 **방법 B(권장)**를 선택하세요.

### 방법 A: Claude Code 플러그인 (명령·스킬 일부만, 빠른 시작)

Claude Code 세션 안에서 두 줄 입력:

```
/plugin marketplace add sangrokjung/claude-forge
/plugin install claude-forge
```

업데이트: `/plugin update claude-forge`

> ⚠️ **주의**: 이 방법은 커맨드(단축버튼)와 일부 스킬만 연결돼요. 전문 비서(에이전트), 안전점검(훅), 규칙, 외부 도구 연결(MCP)은 연결되지 않아요. Claude Code 로더의 현재 정책 때문이에요. 전체 기능을 원하면 방법 B를 쓰세요.

<details>
<summary>방법 A vs 방법 B 상세 비교</summary>

| 구성 요소 | 방법 A (`/plugin install`) | 방법 B (`./install.sh`) |
|--------|:--------------------------:|:------------------------:|
| 커맨드 (35개)          | ✅ | ✅ |
| 스킬 (33개)            | ⚠️ 일부만                  | ✅ |
| 에이전트 (16개)        | ❌ | ✅ |
| 훅 (21개 + 예제 9개)   | ❌ | ✅ |
| 규칙 (14개)             | ❌ | ✅ |
| MCP 서버 (4개)         | ❌ | ✅ |
| 상태바 (CC CHIPS)      | ❌ | ✅ (선택) |
| settings.json 환경변수 | ❌ | ✅ |

</details>

---

### 방법 B: `install.sh` 전체 설치 (권장)

```bash
# 1. 코드 가져오기 (서브모듈은 선택 — 상태바만 해당)
git clone --recurse-submodules https://github.com/sangrokjung/claude-forge.git
cd claude-forge

# 2. 설치 (~/.claude 폴더에 바로가기 연결 생성)
./install.sh

# 3. Claude Code 실행
claude
```

설치 스크립트가 자동으로 해주는 것들:
1. 필요한 도구 확인 (node.js, jq, git)
2. 바로가기(심볼릭 링크) 생성: `~/.claude/` 폴더에 전체 연결
3. 외부 도구(MCP 서버) 설치 선택
4. 셸 단축 명령 설정 (`cc`, `ccr`)

v2.1에서 올라오는 경우: `./install.sh --upgrade` (기존 설정 백업 후 안전하게 이전)

<details>
<summary>Windows 설치 방법</summary>

**WSL(Windows 리눅스 환경)**에서:
```bash
# WSL 네이티브 경로에 클론해야 바로가기 방식 가능
cd ~ && git clone --recurse-submodules https://github.com/sangrokjung/claude-forge.git
cd claude-forge && ./install.sh
```

**PowerShell**:
```powershell
.\install.ps1
```

</details>

<details>
<summary>사전 필요 도구</summary>

| 도구 | 용도 |
|:-----|:-----|
| **Node.js** | 외부 도구(MCP 서버) 실행 |
| **jq** | JSON(데이터 형식) 파싱 |
| **Git** | 코드 가져오기, 업데이트 |
| **Claude Code CLI** | `claude` 명령어 |

</details>

---

## 뭐가 들어있어요?

![구성 한눈에](assets/readme/whats-inside.ko.png)

### 에이전트(agents): 분야별 전문 비서 16명

| 이름 | 역할 |
|:-----|:-----|
| `planner` (기획자) | 복잡한 기능의 구현 계획 수립, 의존성·위험 분석 |
| `architect` (설계사) | 시스템 구조 설계, 확장성, 기술 의사결정 |
| `code-reviewer` (코드 검토자) | 코드를 보고 심각도별(CRITICAL/HIGH/MEDIUM) 이슈 분류 |
| `security-reviewer` (보안 검토자) | 보안 취약점 OWASP Top 10 기반 분석 |
| `tdd-guide` (테스트 가이드) | 테스트 먼저 작성 → 코드 구현 → 개선 사이클 안내 |
| `database-reviewer` (데이터베이스 검토자) | 데이터베이스 구조·쿼리 최적화 |
| `build-error-resolver` (빌드 오류 해결사) | 빌드 오류 즉시 수정 |
| `e2e-runner` (E2E 테스터) | 처음부터 끝까지 통합 테스트 생성·실행 |
| `refactor-cleaner` (코드 정리사) | 쓰지 않는 코드 제거, 중복 코드 정리 |
| `doc-updater` (문서 업데이터) | 문서·코드맵 자동 업데이트 |
| `verify-agent` (검증 에이전트) | 새 환경에서 빌드·테스트·린트를 독립 검증 |

**v4.0 신규: 검증·디버깅 에이전트 5명**

| 이름 | 역할 |
|:-----|:-----|
| `adversarial-reviewer` (적대적 리뷰어) | 코드를 짜지 않고 짠 사람 생각도 모르는 독립 검토자. 주장을 확인하는 대신 깨뜨려 보고 `APPROVE`·`REQUEST_CHANGES`·`UNVERIFIED`로 판정 |
| `skeptical-auditor` (회의적 감사자) | 가벼운 두 번째 독립 검토가 필요할 때 쓰는, 더 저렴한 기계적 재검증 |
| `systematic-debugger` (체계적 디버거) | 재현 → 이분탐색 → 가설 → 검증 4단계. 실패 테스트로 증명되지 않은 수정은 절대 안 함 |
| `rca-debugger` (근본원인 분석가) | systematic-debugger로 안 풀리는 다중 시스템 장애의 5-why + 피시본 분석 |
| `escalation-fixer` (최종 해결사) | build-error-resolver로도 안 닫히는 빌드 오류의 마지막 수단. 아키텍처 수준 변경까지 허용하고, 과거 실패 시도를 기록에서 확인해 반복하지 않음 |

<details>
<summary>에이전트 색상 체계 (UI 구분)</summary>

| 색상 | 의미 |
|:-----|:-----|
| **파란색(blue)** | 분석/리뷰 |
| **하늘색(cyan)** | 테스트/검증 |
| **노란색(yellow)** | 유지보수/데이터 |
| **빨간색(red)** | 보안/경고 |
| **자홍색(magenta)** | 크리에이티브/리서치 |
| **초록색(green)** | 비즈니스/성공 |

</details>

---

### 훅(hooks): 자동 안전점검 21개

항상 켜져 있는 보안 6겹:

| 순서 | 훅 이름 | 막아주는 것 |
|:----:|:--------|:-----------|
| 1 | `output-secret-filter.sh` | 출력에 API 키·토큰이 노출되는 것 |
| 2 | `remote-command-guard.sh` | 위험한 원격 명령 실행 |
| 3 | `db-guard.sh` | 데이터베이스 파괴 SQL(DROP, TRUNCATE 등) |
| 4 | `security-auto-trigger.sh` | 코드 변경 시 자동 취약점 탐지 |
| 5 | `rate-limiter.sh` | API 과도한 호출 |
| 6 | `expensive-mcp-warning.sh` | 고비용 외부 도구 호출 경고 |

**v4.0 신규: 신뢰성 훅 6개 (무인 세션 안전망)**

| 훅 | 언제 실행되나 | 하는 일 |
|:---|:------------|:-------|
| `api-error-auto-resume.sh` | 재시도 가능한 API 오류로 세션이 끝날 때(`StopFailure`) | 오류를 분류하고, 폭주 방지 상한 안에서 무인 자동 재개를 예약해요. 전체 계약은 [`rules/api-error-recovery.md`](rules/api-error-recovery.md) |
| `loop-detection.sh` | 같은 파일을 세션 안에서 5회/10회 이상 고칠 때 | 계속 맴도는 대신 다시 생각해보라고 넌지시 알려줘요 |
| `auto-verify-fix.sh` | `.ts`/`.tsx`/`.js`/`.jsx`/`.py` 파일을 수정한 직후 | 가벼운 타입·구문 검사를 돌려 고칠 수 있는 오류를 바로 보여줘요 |
| `pre-compact-snapshot.sh` | 컨텍스트 압축 직전(`PreCompact`) | `relay` 스킬이 만든 최신 배턴(baton)의 위치를 스냅샷으로 남겨요 |
| `post-compact-restore.sh` | `/compact` 직후(`SessionStart`, matcher `compact`) | 그 위치를 새 세션 컨텍스트에 한 번만 복원해요 |
| `emdash-slop-guard.sh` | 한국어 비중이 높은 `.md` 파일을 수정한 직후 | 줄표(—/–) 삽입구 같은 AI 티를 잡아내요. 상세: [`rules/korean-writing-quality.md`](rules/korean-writing-quality.md) |

배선 가이드 전문은 [`docs/RELIABILITY.md`](docs/RELIABILITY.md)에 있어요. 별도로 옵트인 pre-commit
시크릿 가드(`scripts/install-precommit.sh`)도 v4.0에 추가됐는데, 이건 위 훅들과 달리 여러분이
지정한 git 저장소의 커밋을 보호하는 독립 설치형 스크립트예요.

<details>
<summary>유틸리티 훅 9개 + Opt-in 예제 9개</summary>

**유틸리티 훅 (항상 켜짐)**:

| 훅 | 기능 |
|:---|:-----|
| `code-quality-reminder.sh` | 코드 품질 체크리스트 알림 |
| `context-sync-suggest.sh` | 컨텍스트(문맥 정보) 동기화 제안 |
| `forge-update-check.sh` | 세션 시작 시 프레임워크 업데이트 확인 |
| `mcp-usage-tracker.sh` | 외부 도구 사용량 추적 |
| `session-wrap-suggest.sh` | 세션 종료 시 정리 제안 |
| `task-completed.sh` | 작업 완료 알림 |
| `work-tracker-prompt.sh` | 작업 추적 프롬프트 |
| `work-tracker-stop.sh` | 작업 추적 종료 |
| `work-tracker-tool.sh` | 작업 추적 도구 |

**Opt-in 예제 (직접 활성화 가능)**:

`hooks/examples/`에 있는 `.example` 파일을 `.sh`로 바꾸고 `settings.json`에 등록하면 활성화돼요. 예제는 이벤트당 하나씩 9개입니다. PostCompact(컴팩트 후), PostToolUseFailure(도구 실패 후), PreCompact(컴팩트 전), StopFailure(종료 실패), SubagentStart/Stop(서브에이전트 시작/종료), TaskCreated(태스크 생성), WorktreeCreate/Remove(워크트리 생성/삭제). 하네스 전체가 다루는 라이프사이클 이벤트(작동 시점)는 21가지이고, Claude Code의 전체 27개 이벤트 카탈로그는 [`hooks/README.md`](hooks/README.md)에 있어요.

</details>

---

### MCP: 외부 도구 연결 4개 (기본)

| 도구 | 역할 |
|:-----|:-----|
| **playwright** | 브라우저(웹 창)를 코드로 자동 조작·테스트 |
| **context7** | 라이브러리·프레임워크 최신 문서를 실시간 조회 |
| **jina-reader** | URL(웹 주소)을 읽기 좋은 마크다운 텍스트로 변환 |
| **chrome-devtools** | Lighthouse 성능 측정, Core Web Vitals, 메모리 분석 (`@0.23.0`) |

<details>
<summary>선택 추가 가능한 도구들 (opt-in)</summary>

`mcp-servers.optional.json`에서 필요한 것만 골라 추가할 수 있어요:

| 서버 | API 키 필요 | 설명 |
|:-----|:----------:|:-----|
| **memory** | - | 세션 간 기억 유지 (Auto Memory로 대체 가능) |
| **fetch** | - | 웹 콘텐츠 가져오기 (`uvx` 필요) |
| **github** | ✅ | GitHub 리포/PR/이슈 관리 (`gh` CLI로 대체 가능) |
| **exa** | ✅ | AI 기반 웹 검색 (`WebSearch`로 대체 가능) |

</details>

---

## 어떻게 써요?

![개발 흐름](assets/readme/workflow.ko.png)

### 새 기능 개발: 계획부터 PR까지

```
/plan → /tdd → /code-review → /handoff-verify → /commit-push-pr → /sync
```

<p align="center">
  <img src="docs/workflow-pipeline.jpg" alt="개발 워크플로우 파이프라인" width="720">
</p>

```mermaid
graph LR
    P["/plan<br/><small>구현 계획</small>"] --> T["/tdd<br/><small>테스트 주도 개발</small>"]
    T --> CR["/code-review<br/><small>코드 리뷰</small>"]
    CR --> HV["/handoff-verify<br/><small>Fresh 검증</small>"]
    HV --> CPR["/commit-push-pr<br/><small>커밋 & PR</small>"]
    CPR --> S["/sync<br/><small>문서 동기화</small>"]

    style P fill:#e94560,stroke:#fff,color:#fff
    style T fill:#0f3460,stroke:#fff,color:#fff
    style CR fill:#0f3460,stroke:#fff,color:#fff
    style HV fill:#533483,stroke:#fff,color:#fff
    style CPR fill:#16213e,stroke:#fff,color:#fff
    style S fill:#1a1a2e,stroke:#fff,color:#fff
```

| 단계 | 커맨드 | 하는 일 |
|:----:|:-------|:--------|
| 1 | `/plan` | planner(기획) 에이전트가 구현 계획·의존성·위험을 분석해요 |
| 2 | `/tdd` | tdd-guide 에이전트가 테스트 먼저 → 코드 구현 → 개선 사이클을 안내해요 |
| 3 | `/code-review` | code-reviewer(코드 검토) 에이전트가 심각도별 이슈를 분류해요 |
| 4 | `/handoff-verify` | verify-agent(검증)가 새 환경에서 빌드·테스트·린트를 독립 검증해요 |
| 5 | `/commit-push-pr` | 커밋 메시지 작성, 원격 저장소 푸시, PR(병합 요청) 생성까지 자동화해요 |
| 6 | `/sync` | 프로젝트 문서(prompt_plan.md, spec.md, CLAUDE.md, rules)를 동기화해요 |

---

### 버그 수정

```
/explore → /tdd → /verify-loop → /quick-commit → /sync
```

| 단계 | 커맨드 | 하는 일 |
|:----:|:-------|:--------|
| 1 | `/explore` | 코드베이스(코드 전체)를 탐색해 원인을 파악해요 |
| 2 | `/tdd` | 실패 테스트를 먼저 작성하고 최소한의 수정으로 통과시켜요 |
| 3 | `/verify-loop` | 빌드·테스트를 반복 검증해 사이드 이펙트(의도치 않은 부작용)를 확인해요 |
| 4 | `/quick-commit` | 빠른 커밋(코드 저장) & 푸시(원격 반영) |
| 5 | `/sync` | 커밋 후 프로젝트 문서를 동기화해요 |

---

### 보안 감사

```
/security-review → /stride-analysis-patterns → /security-compliance
```

| 단계 | 커맨드 | 하는 일 |
|:----:|:-------|:--------|
| 1 | `/security-review` | security-reviewer(보안 검토) 에이전트가 OWASP Top 10 기반으로 분석해요 |
| 2 | `/stride-analysis-patterns` | STRIDE(위협 모델링 프레임워크)로 보안 위협을 분석해요 |
| 3 | `/security-compliance` | SOC2, GDPR 등 법적 보안 기준 준수 여부를 검증해요 |

---

### 팀 협업: 멀티 에이전트

```
/orchestrate
```

<p align="center">
  <img src="docs/agent-teams.jpg" alt="Agent Teams Hub-and-Spoke" width="600">
</p>

```mermaid
graph LR
    L["팀 리더"]
    A1["에이전트 1<br/><small>프론트엔드</small>"]
    A2["에이전트 2<br/><small>백엔드</small>"]
    A3["에이전트 3<br/><small>테스팅</small>"]

    L <-->|조율| A1
    L <-->|조율| A2
    L <-->|조율| A3

    style L fill:#e94560,stroke:#fff,color:#fff
    style A1 fill:#0f3460,stroke:#fff,color:#fff
    style A2 fill:#0f3460,stroke:#fff,color:#fff
    style A3 fill:#0f3460,stroke:#fff,color:#fff
```

- 리더가 중심이 되어 여러 에이전트를 조율하는 **허브 앤 스포크** 방식이에요
- 각 에이전트가 맡은 파일을 독립적으로 처리해 **머지 충돌이 없어요**
- 단계별로 팀을 교체하는 **페이즈 기반 운영**도 가능해요

---

### 처음이신가요?

| 단계 | 할 일 |
|:----:|:------|
| 1 | 설치 후 `/guide` 실행: 3분 인터랙티브 투어 |
| 2 | [첫 사용자 가이드](docs/FIRST-STEPS.md) 읽기: 용어 사전 + TOP 6 커맨드 |
| 3 | [상황별 레시피](docs/WORKFLOW-RECIPES.md) 보기: 복사해서 쓰는 5가지 시나리오 |

또는 `/auto 로그인 페이지 만들기`를 입력하면 계획부터 PR까지 알아서 진행해요.

---

## v4.0 업데이트

<details open>
<summary><strong>v4.0 주요 변경사항 접기</strong></summary>

| 변경 | 설명 |
|:-----|:-----|
| **적대적 검증 루프** | `adversarial-reviewer` + `skeptical-auditor` 에이전트, `review-loop` 스킬, `rules/adversarial-review.md`. 작성자와 검증자는 다른 사람이어야 한다는 원칙(maker≠checker)이고, 그 코드를 짜지 않은 독립 검증자가 주장을 읽는 대신 직접 재현해서 `APPROVE` / `REQUEST_CHANGES` / `UNVERIFIED`로 판정해요. 실제 이 릴리스의 PR로 검증한 기록: [`docs/VERIFICATION-LOOP.md`](docs/VERIFICATION-LOOP.md) |
| **신뢰성 패키지** | API 오류 발생 시 무인 자동 재개(`StopFailure`), `/compact` 이후에도 이어지는 세션 릴레이, 무한루프 감지 훅, 편집 직후 검증 훅, 옵트인 pre-commit 시크릿 가드, 그리고 이 도구들이 공유하는 `libs/hook-guard.sh`까지. 배선 가이드 전문: [`docs/RELIABILITY.md`](docs/RELIABILITY.md) |
| **디버깅 에스컬레이션 체인** | `systematic-debugger` → `rca-debugger` → `escalation-fixer`. 앞 단계가 못 풀 때만 다음 단계가 나서요 |
| **작업 난이도 자동 분류** | `/workflow-classify`가 작업을 S/M/L/XL로 매기고, 문서화 깊이와 검증 강도를 그 등급에 맞춰 라우팅해요(`rules/task-grade-routing.md`) |
| **한국어 산문 품질 가드레일** | 사후 윤문이 아니라 처음 쓸 때부터 번역투·AI 관용구를 피해요. 자세한 내용은 바로 아래 섹션에 |

인벤토리: 에이전트 11 → **16개**, 커맨드 34 → **35개**, 스킬 26 → **32개**, 훅 15 → **21개**,
규칙 10 → **14개**. 전체 업그레이드 가이드는 [MIGRATION.ko.md](MIGRATION.ko.md)에 있어요.

</details>

### 한국어 산문 품질 가드레일, 자세히

> 비유: 좋은 번역가는 원문의 뜻을 한 글자도 바꾸지 않으면서 "원래 한국어로 쓴 글"처럼 옮겨요. Claude Forge가 만드는 한국어 산문도 똑같아요. 사실·수치·격식은 그대로 두고, AI가 남기는 기계적 말투만 처음부터 걷어내요.

Claude Forge를 쓰는 사람이 한국어로 마케팅 카피, 블로그, 이메일, 보고서, 커밋 메시지가 아닌
사람이 읽을 산문을 쓰게 하면, v4.0부터는 다음 장치가 함께 움직여요.

| 구성 요소 | 하는 일 |
|:---------|:-------|
| `rules/korean-writing-quality.md` | 번역투("~를 통해" 남발), AI 관용구("결론적으로", "혁신적인"), 기계적 병렬("첫째 둘째 셋째")을 **글을 쓰는 시점**에 피하라는 규칙. 매번 사후 윤문을 강제하지 않고, 처음부터 자연스럽게 쓰는 게 기본값이에요 |
| `reference/ai-tell-taxonomy.md` | 어휘·관용구·피동·접속사·리듬·구조 등 10개 분류로 정리한 AI 티 목록. 판정 기준의 SSOT예요 |
| `hooks/emdash-slop-guard.sh` | 한국어 비중이 높은 `.md` 파일을 고칠 때마다 줄표(—/–) 삽입구를 자동으로 잡아줘요. 코드·로그·커밋 메시지·격식 계약 문구·직접 인용·고유명사·영어는 대상이 아니에요 |
| `skills/humanize-korean` | 이미 쓴 글에 번역투·AI 관용구가 남아있으면, 사실·수치·격식은 손대지 않고 그 부분만 걷어내는 사후 윤문 스킬 |
| `skills/korean-character-count`, `skills/korean-spell-check` | 글자 수 제한이 있는 카피의 길이 계산과 맞춤법·띄어쓰기 검사 |

핵심은 "AI 탐지기를 속이기"가 아니라 "어색한 번역투를 자연스러운 한국어로 고치기"예요. 격식이
필요한 글(계약서, 법률 문서)은 그 격식 자체를 AI 티로 보지 않고 그대로 존중해요.

## v3.1.0 업데이트 (역사)

<details>
<summary><strong>v3.1.0 주요 변경사항 펼치기</strong></summary>

| 변경 | 설명 |
|:-----|:-----|
| **loop-forge 추가** | 반복 작업 한 줄을 재사용 가능한 자가검증 슬래시 명령(`/loop-forge`)으로 박제하는 스킬+커맨드. 5개 루프 원형 + verifier·하드스톱 자동. 스킬 24 → 25개, 커맨드 33 → 34개 |
| **비개발자 친화 README** | 이 README를 비개발자 눈높이로 전면 재작성. 쉬운 비유, 전문용어 괄호 풀이, 도표 3종(구성 / 설치 / 개발 흐름) |

</details>

## v3.0 업데이트

<details>
<summary><strong>v3.0 주요 변경사항 펼치기</strong></summary>

| 변경 | 설명 |
|:-----|:-----|
| **훅 21 이벤트** | 자동 안전점검이 5개에서 21개 라이프사이클 이벤트로 확장됐어요. 샘플: [`hooks/examples/`](hooks/examples/), 전체 목록: [`hooks/README.md`](hooks/README.md) |
| **서브에이전트 Frontmatter v2** | 에이전트 설정에 10개 선택 필드 추가: `isolation`(격리), `background`(배경 실행), `memory`(메모리), `maxTurns`(최대 턴) 등. 스키마: [`reference/agent-schema.json`](reference/agent-schema.json) |
| **스킬/커맨드 하이브리드 정책** | 스킬(자동 호출)과 커맨드(사용자 직접 입력)의 역할 구분 명문화. [`docs/SKILLS-VS-COMMANDS.md`](docs/SKILLS-VS-COMMANDS.md) |
| **MCP 최소 구성 (v3.0.1, 4개)** | 기본 외부 도구 4개로 최적화. 레거시 전체 세트는 [`mcp-servers.optional.json`](mcp-servers.optional.json) 보존 |
| **CLAUDE.md 템플릿 + @import** | [`setup/CLAUDE.md.template`](setup/CLAUDE.md.template) 신규. 모듈형 프로젝트 지침 구성 지원 |
| **settings.json 2026 필드** | `tui`(깜박임 없는 렌더링), `disableSkillShellExecution`(샌드박싱), `enabledMcpjsonServers`(명시적 허용 목록) |
| **원커맨드 업그레이드** | `./install.sh --upgrade`: 기존 v2.1 설치를 백업 및 diff 미리보기와 함께 안전하게 이전 |

**v3.0.1 추가 패치**:

| 변경 | 설명 |
|:-----|:-----|
| **플러그인 매니페스트** | `/plugin marketplace add sangrokjung/claude-forge`로 커맨드·스킬 사용 가능. CI가 버전 불일치 자동 차단 |
| **Chrome DevTools 승격** | Lighthouse / Core Web Vitals / 메모리 스냅샷이 기본 4개에 합류 |
| **훅 타이밍 기록** | SessionEnd 훅 실행 시점을 `~/.claude/logs/hook-timing.jsonl`에 기록하는 래퍼 신규 |
| **CI 트리거 확장** | 전 PR + `main`/`feat/**`/`fix/**`/`chore/**`/`docs/**`/`ci/**` 푸시에서 검증 실행 (총 6개 job) |

**v3.0에서 달라진 것 (주의)**:

- **MCP 기본 축소**: `memory`, `exa`, `github`, `fetch`가 기본에서 빠졌어요. 필요하면 [`mcp-servers.optional.json`](mcp-servers.optional.json)에서 복원하세요.
- **커맨드 8개가 `skills/`로 이동**: 바로가기 호환은 **2027-04-01**까지 유지돼요.
- **settings.json allowlist 변경**: `mcp__memory`, `mcp__exa`, `mcp__github`, `mcp__fetch` 제거. `mcp__playwright` 추가.

</details>

---

## 자주 묻는 질문

<details>
<summary><strong>/sync는 무엇을 하나요?</strong></summary>

`/sync`는 프로젝트 메모리(AI가 기억하는 정보)와 문서를 최신 상태로 맞춰줘요. 원격 저장소에서 최신 변경사항을 가져온 뒤, `prompt_plan.md`·`spec.md`·`CLAUDE.md`·규칙 파일을 모두 동기화해요. 워크플로우 완료 후 또는 새 세션 시작 시 실행하면 AI가 최신 맥락을 유지해요.

</details>

<details>
<summary><strong>Claude Forge는 세션 간 기억을 어떻게 관리하나요?</strong></summary>

4계층 메모리(기억) 시스템을 써요:

1. **프로젝트 문서** (`CLAUDE.md`, `prompt_plan.md`, `spec.md`): 저장소에 영속하는 프로젝트 수준 지침과 계획. `/sync`로 최신 상태를 유지해요.
2. **규칙 파일** (`rules/`): 코딩 스타일, 보안, 워크플로우 규칙이 매 세션마다 자동 로드돼요.
3. **MCP 메모리 서버**: 세션 간 영속하는 지식 그래프로 엔티티(개체)와 관계를 저장해요.
4. **에이전트 메모리** (`~/.claude/agent-memory/`): 핵심 에이전트가 작업 후 학습 내용을 기록해 시간이 지날수록 추천 품질이 높아져요.

세션 시작 시 `/sync`를 실행하면 1·2계층이 최신 상태가 돼요. 3·4계층은 자동으로 유지돼요.

</details>

<details>
<summary><strong>에이전트를 직접 추가할 수 있나요?</strong></summary>

`agents/` 폴더에 YAML 앞머리(frontmatter)가 포함된 마크다운 파일을 만들면 돼요:

```markdown
---
name: my-agent
description: Use this agent when [트리거 조건]. Input: [입력]. Output: [출력].
tools: ["Read", "Grep", "Glob"]
model: sonnet
memory: project
color: blue
---

You are an expert [역할]. Your mission is to [목표].

## Process
1. [단계 1]
2. [단계 2]
```

지원 frontmatter 필드: `name`(필수), `description`(필수), `model`, `color`, `tools`, `memory`, `maxTurns`, `isolation`.
상세: [reference/agents-config-ref.md](reference/agents-config-ref.md)

</details>

<details>
<summary><strong>슬래시 커맨드(단축버튼)를 직접 추가할 수 있나요?</strong></summary>

`commands/` 폴더에 마크다운 파일을 만들기만 하면 돼요:

```markdown
# my-command.md

/my-command 실행 시 수행할 작업을 기술합니다.
```

</details>

<details>
<summary><strong>보안 훅(안전점검)을 직접 추가할 수 있나요?</strong></summary>

`hooks/` 폴더에 쉘 스크립트를 만들고 `settings.json`에 등록하면 돼요:

```bash
#!/bin/bash
# hooks/my-guard.sh
# PreToolUse, PostToolUse 등 특정 이벤트(작동 시점)에서 실행됩니다.
```

</details>

---

## 전체 목록 (개발자용 상세)

<details>
<summary><strong>전체 커맨드 목록 (35개)</strong></summary>

| 커맨드 | 설명 |
|:-------|:-----|
| `/agent-router` | 전문 에이전트 자동 라우팅 |
| `/auto` | 계획부터 PR까지 원버튼 자동 실행 |
| `/build-fix` | 빌드 오류 자동 수정 |
| `/checkpoint` | 현재 상태 체크포인트 저장 |
| `/code-review` | 방금 작성한 코드를 보안+품질 검사 |
| `/commit-push-pr` | 커밋, 푸시, PR 생성 자동화 |
| `/e2e` | E2E 테스트 실행 |
| `/eval` | 코드 모델 평가 |
| `/explore` | 코드베이스를 탐색하여 구조 파악 |
| `/forge-update` | Claude Forge 프레임워크를 최신 버전으로 업데이트 |
| `/guide` | 처음 사용자를 위한 3분 인터랙티브 가이드 |
| `/handoff-verify` | 빌드/테스트/린트 한 번에 자동 검증 |
| `/init-project` | 프로젝트 초기 설정 |
| `/learn` | 학습 및 지식 축적 |
| `/loop-forge` | 반복 작업을 재사용 가능한 자가검증 슬래시 명령으로 박제 |
| `/next-task` | 다음 작업 할당 |
| `/orchestrate` | Agent Teams 멀티 에이전트 구성 |
| `/plan` | AI가 구현 계획을 세워줍니다 |
| `/pull` | 원격 변경사항 가져오기 |
| `/quick-commit` | 빠른 커밋 & 푸시 |
| `/refactor-clean` | 리팩토링 및 코드 정리 |
| `/security-review` | 보안 리뷰 실행 |
| `/show-setup` | 설치 상태와 프로젝트 정보 보기 |
| `/suggest-automation` | 자동화 기회 제안 |
| `/sync` | 최신 변경사항 풀 + 프로젝트 문서 동기화 |
| `/sync-docs` | 문서 동기화 |
| `/tdd` | 테스트 먼저 만들고 코드 작성 |
| `/test-coverage` | 테스트 커버리지 분석 |
| `/update-codemaps` | 코드맵 업데이트 |
| `/update-docs` | 문서 업데이트 |
| `/verify-loop` | 빌드·테스트 반복 검증 |
| `/web-checklist` | 웹 체크리스트 검사 |
| `/workflow-classify` | 작업을 S/M/L/XL로 분류하고 문서화·검증 강도를 그에 맞게 라우팅 |
| `/worktree-cleanup` | 워크트리 정리 |
| `/worktree-start` | 워크트리 시작 |

</details>

<details>
<summary><strong>전체 스킬 목록 (33개)</strong></summary>

| 스킬 | 설명 |
|:-----|:-----|
| `blind-spot-pass` | 낯선 분야 작업 전, 무엇을 모르는지조차 모르는 것(맹점)을 짚고 프롬프트할 만큼만 먼저 가르치는 사전 학습 |
| `build-system` | 빌드 시스템 구성 및 관리 |
| `cache-components` | 캐시 컴포넌트 패턴 |
| `cc-dev-agent` | Claude Code 개발 에이전트 워크플로우 |
| `continuous-learning-v2` | 지속적 학습 및 진화 시스템 |
| `debugging-strategies` | 디버깅 전략 가이드 |
| `dependency-upgrade` | 의존성 업그레이드 관리 |
| `eval-harness` | LLM 평가 하네스 |
| `evaluating-code-models` | 코드 모델 벤치마크 |
| `evaluating-llms-harness` | LLM 하네스 평가 |
| `extract-errors` | 오류 추출 및 분석 |
| `frontend-code-review` | 프론트엔드 코드 리뷰 |
| `harness-diet` | 매 세션 자동 로드되는 컨텍스트(CLAUDE.md+rules)를 측정하고 예산 안으로 다이어트 — 서사는 reference로 이관, 결정론 보존 검사로 거버넌스 무손실 검증 |
| `humanize-korean` | 사실·수치·격식은 그대로 두고 한국어 산문에서 번역투·AI 관용구만 걷어냄 |
| `korean-character-count` | 글자 수 제한이 있는 카피(제목·문자·광고 문구)용 한글 글자/음절 카운트 |
| `korean-spell-check` | 한국어 맞춤법·띄어쓰기 검사. 외부 서비스 nara-speller.co.kr로 텍스트를 전송하니 고객 실명·개인정보는 넣지 마세요 |
| `loop-forge` | 반복 작업 한 줄을 재사용 가능한 자가검증 슬래시 명령으로 박제 (5개 루프 원형 + verifier·하드스톱 자동) |
| `manage-skills` | 스킬 관리 도구 |
| `prompts-chat` | 프롬프트 채팅 |
| `relay` | `/compact` 넘어가는 세션 인계. `/compact` 한 줄 명령 + git/plan/session-summary에서 그대로 뽑은 사실이 담긴 "배턴" 파일을 만듦 |
| `review-loop` | 적대적 검증 루프 절차. `adversarial-reviewer`를 부르고, `REQUEST_CHANGES`엔 반영하고, 지금 리비전에 대한 `APPROVE`가 나올 때만 멈춤 |
| `security-compliance` | 보안 컴플라이언스 검증 |
| `security-pipeline` | 보안 파이프라인 |
| `session-wrap` | 세션 정리 및 래핑 |
| `skill-factory` | 스킬 생성 팩토리 |
| `strategic-compact` | 전략적 컴팩트 |
| `stride-analysis-patterns` | STRIDE 위협 모델링 |
| `summarize` | 코드/문서 요약 |
| `systematic-debugging` | 재현·격리·가설·검증·수정·확인 6단계 구조화 디버깅 절차 |
| `team-orchestrator` | 팀 오케스트레이터 |
| `using-superpowers` | 스킬 발견 및 사용 가이드 |
| `verification-engine` | 검증 엔진 |
| `verify-implementation` | 구현 검증 |

</details>

<details>
<summary><strong>아키텍처: 심볼릭 링크(바로가기) 구조</strong></summary>

> **스킬 vs 커맨드**: `skills/`는 AI가 자동으로 찾아 쓰는 지식과 재사용 워크플로우예요. `commands/`는 사용자가 `/이름`을 직접 입력해 타이밍을 결정하는 명령이에요. 정책 상세: [docs/SKILLS-VS-COMMANDS.md](docs/SKILLS-VS-COMMANDS.md)

<p align="center">
  <img src="docs/architecture.jpg" alt="심볼릭 링크 아키텍처" width="720">
</p>

```mermaid
graph TB
    subgraph REPO["claude-forge (git 리포)"]
        A["agents/ (11)"]
        C["commands/ (34)"]
        S["skills/ (26)"]
        H["hooks/ (15)"]
        R["rules/ (10)"]
        SC["scripts/"]
        CC["cc-chips/"]
        K["knowledge/"]
        REF["reference/"]
        SET["settings.json"]
    end

    INSTALL["./install.sh"]
    REPO --> INSTALL

    subgraph HOME["~/.claude/ (심볼릭 링크)"]
        HA["agents/"]
        HC["commands/"]
        HS["skills/"]
        HH["hooks/"]
        HR["rules/"]
        HSC["scripts/"]
        HCC["cc-chips/"]
        HSET["settings.json"]
    end

    INSTALL -->|symlink| HOME

    CLAUDE["claude (CLI)"]
    HOME --> CLAUDE

    style REPO fill:#1a1a2e,stroke:#e94560,color:#fff
    style HOME fill:#0f3460,stroke:#16213e,color:#fff
    style INSTALL fill:#e94560,stroke:#fff,color:#fff
    style CLAUDE fill:#533483,stroke:#fff,color:#fff
```

**전체 디렉토리 구조**:

```
claude-forge/
  ├── .claude-plugin/            플러그인 매니페스트 (4.0.0)
  ├── .github/workflows/         CI 검증
  ├── agents/                    에이전트 정의 (16 .md, frontmatter v2)
  ├── cc-chips/                  상태바 서브모듈
  ├── cc-chips-custom/           커스텀 상태바 오버레이
  ├── commands/                  슬래시 커맨드 (35 .md, 8개는 skills/로 이동)
  ├── docs/                      스크린샷, 다이어그램, 정책 문서 (RELIABILITY.md·VERIFICATION-LOOP.md 포함)
  ├── hooks/                     이벤트 기반 스크립트 (21)
  │   └── examples/              21 lifecycle 이벤트 샘플 opt-in (9)
  ├── knowledge/                 지식 베이스
  ├── libs/                      훅이 공유하는 쉘 라이브러리 (hook-guard.sh)
  ├── reference/                 참조 문서 (+ agent-schema.json, ai-tell-taxonomy.md)
  ├── rules/                     자동 로드 규칙 파일 (14)
  ├── scripts/                   유틸리티 스크립트 (install-precommit.sh 포함)
  ├── setup/                     설치 가이드 + CLAUDE.md 템플릿
  ├── skills/                    다단계 스킬 워크플로우 (33, 하이브리드 정책)
  ├── install.sh                 macOS/Linux 설치 (--upgrade 지원)
  ├── install.ps1                Windows 설치 (--upgrade 지원)
  ├── mcp-servers.json           MCP 기본 설정 (4 minimal)
  ├── mcp-servers.optional.json  MCP 선택 서버
  ├── settings.json              Claude Code 설정 (2026 필드)
  ├── MIGRATION.md               v2.1 → v4.0 이전 가이드 (EN)
  ├── MIGRATION.ko.md            v2.1 → v4.0 이전 가이드 (KO)
  ├── CONTRIBUTING.md            기여 가이드
  ├── SECURITY.md                보안 정책
  └── LICENSE                    MIT 라이선스
```

</details>

<details>
<summary><strong>커스터마이징: 설정 오버라이드</strong></summary>

추적되는 파일을 수정하지 않고 개인 설정을 오버라이드(덮어쓰기)할 수 있어요:

```bash
# 로컬 오버라이드 파일 생성 (git-ignored, 개인 설정)
cp setup/settings.local.template.json ~/.claude/settings.local.json

# 개인 시크릿·환경설정 편집
vim ~/.claude/settings.local.json
```

`settings.local.json`은 Claude Code가 `settings.json` 위에 자동으로 합쳐줘요.

</details>

---

## 기여하기

에이전트, 커맨드, 스킬, 훅 추가 방법은 [CONTRIBUTING.md](CONTRIBUTING.md)를 참조하세요.

---

## Claude Forge를 사용하시나요? 배지를 달아주세요!

```markdown
[![Built with Claude Forge](https://img.shields.io/badge/Built_with-Claude_Forge-orange?style=flat-square)](https://github.com/sangrokjung/claude-forge)
```

이 배지를 프로젝트 README에 추가하면 Claude Forge 사용을 알릴 수 있어요.

---

## Contributors

<a href="https://github.com/sangrokjung/claude-forge/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=sangrokjung/claude-forge" />
</a>

---

## 라이선스

[MIT](LICENSE). 자유롭게 사용, 포크, 확장하세요.

---

<p align="center">
  <sub>Made with ❤️ by <a href="https://github.com/sangrokjung">QJC (Quantum Jump Club)</a></sub>
</p>
