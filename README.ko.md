<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/banner.jpg">
  <source media="(prefers-color-scheme: light)" srcset="docs/banner-light.jpg">
  <img src="docs/banner.jpg" alt="Claude Forge" width="100%">
</picture>

<p align="center">
  <strong>Claude Code를 위한 프로덕션 수준 설정 프레임워크</strong>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/LICENSE-MIT-blue?style=for-the-badge" alt="MIT License"></a>
  <a href="https://claude.com/claude-code"><img src="https://img.shields.io/badge/CLAUDE_CODE-%E2%89%A51.0-blueviolet?style=for-the-badge" alt="Claude Code"></a>
  <a href="https://github.com/sangrokjung/claude-forge/stargazers"><img src="https://img.shields.io/github/stars/sangrokjung/claude-forge?style=for-the-badge&color=yellow" alt="Stars"></a>
  <a href="https://github.com/sangrokjung/claude-forge/network/members"><img src="https://img.shields.io/github/forks/sangrokjung/claude-forge?style=for-the-badge&color=orange" alt="Forks"></a>
  <a href="https://github.com/sangrokjung/claude-forge/graphs/contributors"><img src="https://img.shields.io/github/contributors/sangrokjung/claude-forge?style=for-the-badge&color=green" alt="Contributors"></a>
  <a href="https://github.com/sangrokjung/claude-forge/commits/main"><img src="https://img.shields.io/github/last-commit/sangrokjung/claude-forge?style=for-the-badge" alt="Last Commit"></a>
</p>

<p align="center">
  <a href="#-빠른-시작">빠른 시작</a> &bull;
  <a href="#-개발-워크플로우">개발 워크플로우</a> &bull;
  <a href="#-구성-요소">구성 요소</a> &bull;
  <a href="#-설치-가이드">설치 가이드</a> &bull;
  <a href="#-아키텍처">아키텍처</a> &bull;
  <a href="README.md">English</a>
</p>

---

## Claude Forge란?

Claude Forge는 **Claude Code**를 기본 CLI에서 **완전한 개발 환경**으로 변환합니다. 설치 한 번으로 **11개 전문 에이전트**(Opus 6 + Sonnet 5), **40개 슬래시 커맨드**, **15개 스킬 워크플로우**, **15개 자동화 훅**(보안 6 + 유틸리티 9), **9개 규칙 파일**, **6개 MCP 서버**가 모두 연결되어 즉시 사용 가능합니다.

> oh-my-zsh가 터미널을 강화하듯, Claude Forge는 AI 코딩 어시스턴트를 **파워 유저 도구**로 업그레이드합니다.

---

## ⚡ 빠른 시작

```bash
# 1. 클론
git clone --recurse-submodules https://github.com/sangrokjung/claude-forge.git
cd claude-forge

# 2. 설치 (~/.claude에 심볼릭 링크 생성)
./install.sh

# 3. Claude Code 실행
claude
```

이것으로 끝. 모든 에이전트, 커맨드, 훅, 규칙이 즉시 사용 가능합니다.

### v2.1 업데이트

| 변경 | 설명 |
|:-----|:-----|
| **검증 규칙 추가** | 새 `verification.md` 규칙이 증거 기반 완료를 강제합니다 -- 테스트/빌드 실행 결과 없이 완료 선언 금지. |
| **에이전트 자기 진화** | 핵심 5개 에이전트(planner, architect, code-reviewer, security-reviewer, tdd-guide)가 작업 후 `~/.claude/agent-memory/`에 학습 내용을 기록합니다. |
| **훅 동기화** | `forge-update-check.sh` (세션 시작 시 업데이트 알림)와 `observe.sh` (지속 학습 관찰) 추가. |

### 처음이신가요?

개발이 처음이거나 Claude Code가 낯설다면, 여기서 시작하세요:

| 단계 | 할 일 |
|:----:|:------|
| 1 | 설치 후 `/guide` 실행 -- 3분 인터랙티브 투어 |
| 2 | [첫 사용자 가이드](docs/FIRST-STEPS.md) 읽기 -- 용어 사전 + TOP 6 커맨드 |
| 3 | [상황별 레시피](docs/WORKFLOW-RECIPES.md) 보기 -- 복사해서 쓰는 5가지 시나리오 |

또는 `/auto 로그인 페이지 만들기`를 입력하면, 계획부터 PR까지 알아서 진행합니다.

---

## 🔄 개발 워크플로우

<p align="center">
  <img src="docs/workflow-pipeline.jpg" alt="개발 워크플로우 파이프라인" width="720">
</p>

### 새 기능 개발

계획 수립부터 PR 생성까지 한 번에 진행합니다.

```
/plan → /tdd → /code-review → /handoff-verify → /commit-push-pr → /sync
```

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

| 단계 | 커맨드 | 설명 |
|:----:|:-------|:-----|
| 1 | `/plan` | planner 에이전트가 구현 계획, 의존성, 리스크를 분석 |
| 2 | `/tdd` | tdd-guide 에이전트가 RED→GREEN→IMPROVE 사이클 진행 |
| 3 | `/code-review` | code-reviewer 에이전트가 CRITICAL/HIGH/MEDIUM 이슈 분류 |
| 4 | `/handoff-verify` | verify-agent가 새 컨텍스트에서 빌드·테스트·린트 검증 |
| 5 | `/commit-push-pr` | 커밋 메시지 작성, 푸시, PR 생성까지 자동화 |
| 6 | `/sync` | 프로젝트 문서 동기화 (prompt_plan.md, spec.md, CLAUDE.md, rules) |

### 버그 수정

```
/explore → /tdd → /verify-loop → /quick-commit → /sync
```

| 단계 | 커맨드 | 설명 |
|:----:|:-------|:-----|
| 1 | `/explore` | 코드베이스를 탐색하여 원인 파악 |
| 2 | `/tdd` | 실패 테스트 작성 → 최소 수정 → 통과 확인 |
| 3 | `/verify-loop` | 빌드·테스트를 반복 검증하며 사이드 이펙트 확인 |
| 4 | `/quick-commit` | 빠른 커밋 & 푸시 |
| 5 | `/sync` | 커밋 후 프로젝트 문서 동기화 |

### 보안 감사

```
/security-review → /stride-analysis-patterns → /security-compliance
```

| 단계 | 커맨드 | 설명 |
|:----:|:-------|:-----|
| 1 | `/security-review` | security-reviewer 에이전트가 OWASP Top 10 기반 분석 |
| 2 | `/stride-analysis-patterns` | STRIDE 위협 모델링 수행 |
| 3 | `/security-compliance` | SOC2, GDPR 등 컴플라이언스 검증 |

### 팀 협업

<p align="center">
  <img src="docs/agent-teams.jpg" alt="Agent Teams Hub-and-Spoke" width="600">
</p>

```
/orchestrate
```

`/orchestrate` 커맨드로 Agent Teams를 구성하여 병렬 작업을 수행합니다.

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

- **Hub-and-spoke** 통신 (리더가 조율)
- **파일 소유권** 분리 (머지 충돌 없음)
- **페이즈 기반** 팀 교체
- 결정 사항은 `decisions.md`로 외부화

---

## 📦 구성 요소

<p align="center">
  <img src="docs/features-grid.jpg" alt="Claude Forge 구성 요소" width="720">
</p>

| 카테고리 | 수량 | 주요 항목 |
|:--------:|:----:|:----------|
| **에이전트** | 11 | `planner` `architect` `code-reviewer` `security-reviewer` `tdd-guide` `database-reviewer` (Opus) / `build-error-resolver` `e2e-runner` `refactor-cleaner` `doc-updater` `verify-agent` (Sonnet) |
| **커맨드** | 40 | `/commit-push-pr` `/handoff-verify` `/explore` `/tdd` `/plan` `/orchestrate` `/security-review` ... |
| **스킬** | 15 | `build-system` `security-pipeline` `eval-harness` `team-orchestrator` `session-wrap` ... |
| **훅** | 15 | 보안 방어 6개 + 유틸리티 9개 |
| **규칙** | 9 | `coding-style` `security` `git-workflow` `golden-principles` `agents-v2` `verification` ... |
| **MCP 서버** | 6 | `context7` `memory` `exa` `github` `fetch` `jina-reader` |

---

## 📥 설치 가이드

### 사전 요구사항

| 도구 | 용도 |
|:-----|:-----|
| **Node.js** | MCP 서버 실행 (npx) |
| **jq** | JSON 파싱 (설치 스크립트) |
| **Git** | 클론, 서브모듈 |
| **Claude Code CLI** | `claude` 명령어 |

### macOS / Linux

```bash
# 클론 (서브모듈 포함)
git clone --recurse-submodules https://github.com/sangrokjung/claude-forge.git
cd claude-forge

# 설치 (심볼릭 링크 생성)
./install.sh
```

설치 스크립트가 수행하는 작업:

1. 의존성 확인 (node, jq, git)
2. Git 서브모듈 초기화 (CC CHIPS)
3. 기존 `~/.claude/` 백업 (선택)
4. `~/.claude/`에 심볼릭 링크 생성
5. CC CHIPS 커스텀 오버레이 적용
6. MCP 서버 설치 (선택)
7. 외부 스킬 설치 (선택)
8. 셸 별칭 설정 (`cc`, `ccr`)

### Windows (WSL)

WSL에서 Windows 파일시스템(`/mnt/c/...`)에 클론한 경우 심볼릭 링크 대신 **복사**로 설치됩니다.

```bash
# WSL 네이티브 경로에 클론하면 심볼릭 링크 사용 가능
cd ~ && git clone --recurse-submodules https://github.com/sangrokjung/claude-forge.git
cd claude-forge && ./install.sh
```

### Windows (PowerShell)

```powershell
.\install.ps1
```

### MCP 서버 설정

설치 시 자동으로 구성됩니다. API 키가 필요한 서버는 별도 설정이 필요합니다.

| 서버 | API 키 필요 | 설명 |
|:-----|:----------:|:-----|
| **context7** | - | 실시간 라이브러리 문서 조회 |
| **memory** | - | 영속적 지식 그래프 |
| **fetch** | - | 웹 콘텐츠 가져오기 |
| **jina-reader** | - | URL → 마크다운 변환 |
| **github** | `GITHUB_PERSONAL_ACCESS_TOKEN` | 리포/PR/이슈 관리 |
| **exa** | 인증 필요 | AI 기반 웹 검색 |

### 커스터마이징

추적되는 파일을 수정하지 않고 설정을 오버라이드할 수 있습니다:

```bash
# 로컬 오버라이드 파일 생성 (git-ignored)
cp setup/settings.local.template.json ~/.claude/settings.local.json

# 시크릿/환경설정 편집
vim ~/.claude/settings.local.json
```

`settings.local.json`은 Claude Code가 `settings.json` 위에 병합합니다.

---

## 🏗 아키텍처

<p align="center">
  <img src="docs/architecture.jpg" alt="심볼릭 링크 아키텍처" width="720">
</p>

```mermaid
graph TB
    subgraph REPO["claude-forge (git 리포)"]
        A["agents/ (11)"]
        C["commands/ (40)"]
        S["skills/ (15)"]
        H["hooks/ (15)"]
        R["rules/ (9)"]
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

설치 스크립트가 리포에서 `~/.claude/`로 **심볼릭 링크**를 생성하므로, `git pull` 한 번으로 즉시 업데이트됩니다.

<details>
<summary><strong>전체 디렉토리 구조</strong></summary>

```
claude-forge/
  ├── .claude-plugin/       플러그인 매니페스트
  ├── .github/workflows/    CI 검증
  ├── agents/               에이전트 정의 (.md)
  ├── cc-chips/             상태바 서브모듈
  ├── cc-chips-custom/      커스텀 상태바 오버레이
  ├── commands/             슬래시 커맨드 (.md + 디렉토리)
  ├── docs/                 스크린샷, 다이어그램
  ├── hooks/                이벤트 기반 스크립트 (15개)
  ├── knowledge/            지식 베이스
  ├── reference/            참조 문서
  ├── rules/                자동 로드 규칙 파일 (9개)
  ├── scripts/              유틸리티 스크립트
  ├── setup/                설치 가이드 + 템플릿
  ├── skills/               다단계 스킬 워크플로우
  ├── install.sh            macOS/Linux 설치 스크립트
  ├── install.ps1           Windows 설치 스크립트
  ├── mcp-servers.json      MCP 서버 설정
  ├── settings.json         Claude Code 설정
  ├── CONTRIBUTING.md       기여 가이드
  ├── SECURITY.md           보안 정책
  └── LICENSE               MIT 라이선스
```

</details>

---

## 🛡 자동화 훅

### 보안 훅

<p align="center">
  <img src="docs/security-layers.jpg" alt="보안 방어 훅" width="480">
</p>

모든 작업이 계층형 보안 훅을 통과합니다:

| 단계 | 훅 | 방어 대상 |
|:----:|:---|:----------|
| 1 | `output-secret-filter.sh` | 출력에 노출된 API 키, 토큰 |
| 2 | `remote-command-guard.sh` | 안전하지 않은 원격 명령 |
| 3 | `db-guard.sh` | 파괴적 SQL (DROP, TRUNCATE) |
| 4 | `security-auto-trigger.sh` | 코드 변경 시 취약점 자동 탐지 |
| 5 | `rate-limiter.sh` | API 호출 속도 제한 |
| 6 | `expensive-mcp-warning.sh` | 고비용 MCP 호출 경고 |

### 유틸리티 훅

| 훅 | 기능 |
|:---|:-----|
| `code-quality-reminder.sh` | 코드 품질 체크리스트 알림 |
| `context-sync-suggest.sh` | 컨텍스트 동기화 제안 |
| `forge-update-check.sh` | 세션 시작 시 프레임워크 업데이트 확인 |
| `mcp-usage-tracker.sh` | MCP 사용량 추적 |
| `session-wrap-suggest.sh` | 세션 종료 시 정리 제안 |
| `task-completed.sh` | 작업 완료 알림 |
| `work-tracker-prompt.sh` | 작업 추적 프롬프트 |
| `work-tracker-stop.sh` | 작업 추적 종료 |
| `work-tracker-tool.sh` | 작업 추적 도구 |

---

## 🤖 에이전트

각 에이전트는 UI에서 역할별 **색상**으로 구분됩니다:

### Opus (고성능 추론)

| 에이전트 | 색상 | 역할 |
|:---------|:----:|:-----|
| `planner` | blue | 복잡한 기능의 구현 계획 수립, 의존성/리스크 분석 |
| `architect` | blue | 시스템 설계, 확장성, 기술 의사결정 |
| `code-reviewer` | blue | CRITICAL/HIGH/MEDIUM 이슈 분류 코드 리뷰 |
| `security-reviewer` | red | OWASP Top 10 기반 보안 분석 |
| `tdd-guide` | cyan | RED → GREEN → IMPROVE 테스트 주도 개발 |
| `database-reviewer` | blue | PostgreSQL/Supabase 스키마, 쿼리 최적화 |

### Sonnet (빠른 실행)

| 에이전트 | 색상 | 역할 |
|:---------|:----:|:-----|
| `build-error-resolver` | cyan | 빌드/TypeScript 오류 즉시 수정 |
| `e2e-runner` | cyan | E2E 테스트 생성, 실행, 관리 |
| `refactor-cleaner` | yellow | 데드 코드 제거, 중복 코드 정리 |
| `doc-updater` | yellow | 문서/코드맵 자동 업데이트 |
| `verify-agent` | cyan | 새 컨텍스트에서 빌드·테스트·린트 검증 |

### 색상 체계

| 색상 | 의미 |
|:-----|:-----|
| **blue** | 분석/리뷰 |
| **cyan** | 테스트/검증 |
| **yellow** | 유지보수/데이터 |
| **red** | 보안/경고 |
| **magenta** | 크리에이티브/리서치 |
| **green** | 비즈니스/성공 |

---

<details>
<summary><strong>📋 전체 커맨드 목록 (40개)</strong></summary>

| 커맨드 | 설명 |
|:-------|:-----|
| `/build-fix` | 빌드 오류 자동 수정 |
| `/checkpoint` | 현재 상태 체크포인트 저장 |
| `/code-review` | 방금 작성한 코드를 보안+품질 검사 |
| `/commit-push-pr` | 커밋, 푸시, PR 생성 자동화 |
| `/debugging-strategies` | 디버깅 전략 가이드 |
| `/dependency-upgrade` | 의존성 업그레이드 관리 |
| `/e2e` | E2E 테스트 실행 |
| `/eval` | 코드 모델 평가 |
| `/evaluating-code-models` | 코드 모델 벤치마크 |
| `/evaluating-llms-harness` | LLM 하네스 평가 |
| `/explore` | 코드베이스를 탐색하여 구조를 파악 |
| `/extract-errors` | 오류 추출 및 분석 |
| `/forge-update` | Claude Forge 프레임워크를 최신 버전으로 업데이트 |
| `/handoff-verify` | 빌드/테스트/린트 한 번에 자동 검증 |
| `/init-project` | 프로젝트 초기 설정 |
| `/learn` | 학습 및 지식 축적 |
| `/next-task` | 다음 작업 할당 |
| `/orchestrate` | Agent Teams 멀티 에이전트 구성 |
| `/plan` | AI가 구현 계획을 세워줍니다 |
| `/pull` | 원격 변경사항 가져오기 |
| `/quick-commit` | 빠른 커밋 & 푸시 |
| `/refactor-clean` | 리팩토링 및 코드 정리 |
| `/security-compliance` | 보안 컴플라이언스 검증 |
| `/security-review` | 보안 리뷰 실행 |
| `/stride-analysis-patterns` | STRIDE 위협 모델링 |
| `/suggest-automation` | 자동화 기회 제안 |
| `/summarize` | 코드/문서 요약 |
| `/sync-docs` | 문서 동기화 |
| `/sync` | 최신 변경사항 풀 + 프로젝트 문서 동기화 (prompt_plan.md, spec.md, CLAUDE.md, rules). 워크플로우 완료 후 또는 세션 시작 시 사용. |
| `/tdd` | 테스트 먼저 만들고 코드 작성 |
| `/test-coverage` | 테스트 커버리지 분석 |
| `/update-codemaps` | 코드맵 업데이트 |
| `/update-docs` | 문서 업데이트 |
| `/verify-loop` | 빌드·테스트 반복 검증 |
| `/web-checklist` | 웹 체크리스트 검사 |
| `/worktree-cleanup` | 워크트리 정리 |
| `/worktree-start` | 워크트리 시작 |
| `/auto` | 계획부터 PR까지 원버튼 자동 실행 |
| `/guide` | 처음 사용자를 위한 3분 인터랙티브 가이드 |
| `/show-setup` | 설치 상태와 프로젝트 정보 보기 |

</details>

<details>
<summary><strong>🎯 전체 스킬 목록 (15개)</strong></summary>

| 스킬 | 설명 |
|:-----|:-----|
| `build-system` | 빌드 시스템 구성 및 관리 |
| `cache-components` | 캐시 컴포넌트 패턴 |
| `cc-dev-agent` | Claude Code 개발 에이전트 워크플로우 |
| `continuous-learning-v2` | 지속적 학습 및 진화 시스템 |
| `eval-harness` | LLM 평가 하네스 |
| `frontend-code-review` | 프론트엔드 코드 리뷰 |
| `manage-skills` | 스킬 관리 도구 |
| `prompts-chat` | 프롬프트 채팅 |
| `security-pipeline` | 보안 파이프라인 |
| `session-wrap` | 세션 정리 및 래핑 |
| `skill-factory` | 스킬 생성 팩토리 |
| `strategic-compact` | 전략적 컴팩트 |
| `team-orchestrator` | 팀 오케스트레이터 |
| `verification-engine` | 검증 엔진 |
| `verify-implementation` | 구현 검증 |

</details>

---

## 🔌 MCP 서버

`mcp-servers.json`에 사전 구성 -- `./install.sh` 또는 `claude mcp add`로 설치:

| 서버 | 용도 |
|:-----|:-----|
| **context7** | 실시간 라이브러리 문서 조회 |
| **memory** | 영속적 지식 그래프 |
| **exa** | AI 기반 웹 검색 |
| **github** | 리포/PR/이슈 관리 |
| **fetch** | 웹 콘텐츠 가져오기 |
| **jina-reader** | URL → 마크다운 변환 |

---

## 🎨 커스터마이징

<details>
<summary><strong>에이전트 추가하기</strong></summary>

`agents/` 디렉토리에 YAML frontmatter가 포함된 마크다운 파일을 생성하세요:

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

## Output Format
[출력 형식]
```

지원 frontmatter 필드: `name` (필수), `description` (필수), `model`, `color`, `tools`, `memory`, `maxTurns`, `isolation`.

상세 필드 설명과 알려진 제한사항은 [reference/agents-config-ref.md](reference/agents-config-ref.md) 참조.

</details>

<details>
<summary><strong>슬래시 커맨드 추가하기</strong></summary>

`commands/` 디렉토리에 마크다운 파일을 생성하세요:

```markdown
# my-command.md

/my-command 실행 시 수행할 작업을 기술합니다.
```

</details>

<details>
<summary><strong>보안 훅 추가하기</strong></summary>

`hooks/` 디렉토리에 쉘 스크립트를 생성하고 `settings.json`에 등록하세요:

```bash
#!/bin/bash
# hooks/my-guard.sh
# 특정 도구 이벤트(PreToolUse, PostToolUse 등)에서 실행됩니다.
```

</details>

---

## 자주 묻는 질문

<details>
<summary><strong>/sync는 무엇을 하나요?</strong></summary>

`/sync`는 프로젝트 메모리와 문서를 동기화합니다. 원격 저장소에서 최신 변경사항을 풀한 뒤, 프로젝트 문서(`prompt_plan.md`, `spec.md`, `CLAUDE.md`, 규칙 파일)를 모두 동기화합니다. 워크플로우(기능 개발, 버그 수정, 리팩토링) 완료 후 또는 새 세션 시작 시 실행하면 Claude가 최신 컨텍스트를 유지합니다.

</details>

<details>
<summary><strong>Claude Forge는 세션 간 메모리를 어떻게 관리하나요?</strong></summary>

Claude Forge는 4계층 메모리 시스템을 사용합니다:

1. **프로젝트 문서** (`CLAUDE.md`, `prompt_plan.md`, `spec.md`) -- 저장소에 영속하는 프로젝트 수준 지침과 계획. `/sync`로 최신 상태를 유지합니다.
2. **규칙 파일** (`rules/`) -- 코딩 스타일, 보안, 워크플로우 규칙이 매 세션마다 자동 로드됩니다.
3. **MCP 메모리 서버** -- 세션 간 영속하는 지식 그래프로 엔티티와 관계를 저장합니다.
4. **에이전트 메모리** (`~/.claude/agent-memory/`) -- 핵심 에이전트가 작업 후 학습 내용을 기록하여 시간이 지남에 따라 추천 품질이 향상됩니다 (Self-Evolution).

세션 시작 시 `/sync`를 실행하면 1, 2 계층이 최신 상태가 됩니다. MCP 메모리 서버(3계층)와 에이전트 메모리(4계층)는 자동으로 영속합니다.

</details>

---

## 🤝 기여

에이전트, 커맨드, 스킬, 훅 추가 방법은 [CONTRIBUTING.md](CONTRIBUTING.md)를 참조하세요.

---

---

## Claude Forge를 사용하시나요? 배지를 달아주세요!

```markdown
[![Built with Claude Forge](https://img.shields.io/badge/Built_with-Claude_Forge-orange?style=flat-square)](https://github.com/sangrokjung/claude-forge)
```

이 배지를 프로젝트 README에 추가하여 Claude Forge 사용을 알려주세요.

---

## Contributors

<a href="https://github.com/sangrokjung/claude-forge/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=sangrokjung/claude-forge" />
</a>

---

## 📄 라이선스

[MIT](LICENSE) -- 자유롭게 사용, 포크, 확장하세요.

---

<p align="center">
  <sub>Made with ❤️ by <a href="https://github.com/sangrokjung">QJC (Quantum Jump Club)</a></sub>
</p>
