# OMC (oh-my-claudecode) 도입 현황

**현재 버전: v4.2.15 (2026-02-20 설치)**

> 설치 정보, 업데이트 프로세스, 롤백 방법, 위험 관리 상세: reference/omc-adoption-detail.md

## 활성화된 기능

| 기능 | 설명 | 기존 대응물 |
|------|------|------------|
| MCP 서버 "t" | LSP 12개 + AST 2개 + Python REPL + Notepad + State + ProjectMemory (32개 도구) | grep/glob (텍스트 기반) |
| 위임 강제기 | Task 호출 시 agent 정의의 model 자동 주입 | 없음 (수동 지정 or 기본값) |
| 모델 라우팅 | 작업 복잡도 분석 → Haiku/Sonnet/Opus 자동 배정 | performance-v2.md (수동 테이블) |
| 선제적 컴팩션 | 컨텍스트 70%/90% 도달 시 경고 | 없음 |
| Notepad | Priority Context + Working Memory 디스크 저장 | 없음 |
| Project Memory | 빌드/테스트 명령, 자주 쓰는 파일 자동 학습 | 없음 |
| 매직 키워드 | ultrawork, ultrathink, search, analyze 트리거 | 없음 |
| OMC 에이전트 30개 | 플러그인 내부에 독립 존재 | 기존 에이전트와 공존 |
| OMC 스킬 42개 | `oh-my-claudecode:*` 네임스페이스 | 기존 스킬과 공존 |
| OMC 훅 14개 | 플러그인 hooks.json으로 별도 실행 | 기존 훅과 공존 |

## 비활성화된 기능

| 기능 | 이유 |
|------|------|
| 외부 API 브릿지 | 코드가 외부로 유출될 위험. CLI 직접 실행만 허용 (사용자 동의 필수) |
| 자동 업데이트 | 플러그인 시스템이 수동 업데이트만 허용 |
| OMC HUD | CC CHIPS 상태바 유지 |

## 병합 에이전트 (7개)

OMC `<Agent_Prompt>` 구조를 채택하되 커스텀 도메인 지식을 보존한 에이전트:

| 에이전트 | OMC 대응물 | 모델 | 병합 내용 |
|---------|-----------|------|----------|
| **planner** | planner | opus | 인터뷰 워크플로우 + sequential-thinking MCP |
| **architect** | architect | opus | 읽기전용 분석 + 프로젝트 아키텍처 컨텍스트 |
| **code-reviewer** | code-reviewer | opus | 2단계 리뷰(스펙→품질) + 불변성/보안 규칙 |
| **security-reviewer** | security-reviewer | opus | OWASP 프레임워크 + 프로젝트별 보안 체크 |
| **tdd-guide** | test-engineer | opus | TDD Red-Green-Refactor + Mocking 패턴(외부 서비스) + 80% 커버리지 |
| **build-error-resolver** | build-fixer | sonnet | LSP 우선 진단 + 프로젝트별 기술 스택 패턴 |
| **verify-agent** | verifier | sonnet | fresh-context 검증 + 증거 기반 검증 원칙 |

구조: `<Role>`, `<Constraints>`, `<Investigation_Protocol>`, `<Failure_Modes_To_Avoid>`, `<Final_Checklist>`

## 에이전트 모델 감사 결과

opus가 불필요한 에이전트를 sonnet으로 다운그레이드:

| 에이전트 | 변경 전 | 변경 후 | 근거 |
|---------|--------|--------|------|
| doc-updater | opus | **sonnet** | 문서 작성은 기계적 작업 |
| refactor-cleaner | opus | **sonnet** | 코드 정리는 패턴 매칭 |
| e2e-runner | opus | **sonnet** | 테스트 실행은 표준 작업 |
| build-error-resolver | opus | **sonnet** | OMC build-fixer와 정렬, Agent_Prompt 병합 |

**유지(opus)**: planner, architect, code-reviewer, security-reviewer, tdd-guide

## 스킬 사용 가이드

OMC 스킬(`oh-my-claudecode:*`)과 커스텀 스킬이 유사한 기능을 제공하는 경우 우선순위:

| 기능 | 기본 (빠른 실행) | 상세 (전문가 모드) |
|------|-----------------|------------------|
| TDD | `/tdd` (OMC) | `/test-driven-development` (커스텀, 상세 워크플로우) |
| 코드 리뷰 | `/code-review` (OMC) | `/frontend-code-review` (커스텀, Blazor/.razor 지원) |
| 보안 리뷰 | `/security-review` (OMC) | `/security-pipeline` (커스텀, CWE+STRIDE) |
| 빌드 수정 | `/build-fix` (OMC) | `/fix` (커스텀, C#/Blazor 통합) |
| 플래닝 | `/plan` (OMC) | `/writing-plans` (커스텀, 상세 계획서) |
| Blazor 검증 | 없음 | `/verify-blazor` (커스텀, .razor 패턴 검증) |
| EF 마이그레이션 | 없음 | `/verify-ef-migration` (커스텀, 안전성 검증) |
| Clean Arch 검증 | 없음 | `/verify-clean-arch` (커스텀, 레이어 의존성 검증) |

**규칙**: OMC 스킬은 빠른 기본 실행, 커스텀 스킬은 도메인 특화 상세 실행. 삭제 없이 공존.

## 파일 소유권 매트릭스

### 안전 영역 (자유롭게 수정 가능)

| 파일/디렉토리 | 소유자 | 설명 |
|-------------|--------|------|
| `~/.claude/agents/*.md` | 커스텀 | 우리 에이전트 정의 |
| `~/.claude/rules/*.md` | 커스텀 | 우리 규칙 파일 |
| `~/.claude/skills/**/*.md` | 커스텀 | 우리 스킬 정의 |
| `~/.claude/scripts/*.sh` | 커스텀 | 우리 스크립트 |

### 감시 영역 (수정 시 주의)

| 파일/디렉토리 | 소유자 | 위험 |
|-------------|--------|------|
| `~/.claude/settings.json` | 공유 | OMC 설치 시 수정됨. 백업 필수 |
| `~/.claude/hooks.json` | 공유 | OMC 훅 + 커스텀 훅 공존 |

### 위험 영역 (절대 수정 금지)

| 파일/디렉토리 | 소유자 | 위험 |
|-------------|--------|------|
| `~/.claude/plugins/cache/omc/**` | OMC | 수정 시 업데이트에서 덮어씌워짐 |

## AST 도구 사용법

### ast_grep_search — 구조적 패턴 검색

**JavaScript/TypeScript:**
```
패턴: interface $NAME { $$$BODY }   → 모든 인터페이스를 본문 포함 검색
패턴: console.log($$$ARGS)          → 모든 console.log 호출 (문자열/주석 제외)
패턴: await $EXPR                   → 모든 await 표현식
```

**C# (.NET / Blazor):**
```
패턴: public class $NAME : $BASE { $$$BODY }  → 상속 클래스 탐색
패턴: Console.WriteLine($$$ARGS)             → 로그 누락 탐지
패턴: new $TYPE()                            → 직접 인스턴스 생성 (너무 많으면 DI 권짐)
패턴: Task $METHOD($$$PARAMS)                → 비동기 메서드 목록
패턴: [HttpGet($ROUTE)]                      → GET API 엔드포인트 목록
```

메타변수: `$NAME` (단일 노드), `$$$ARGS` (가변 인자)

### ast_grep_replace — 구조적 치환

```
패턴: console.error($$$ARGS) → 치환: logger.error($$$ARGS)
드라이런 먼저 실행 권장
```

단순 텍스트 검색은 기존 Grep이 더 빠름. 구조적 분석이 필요할 때 LSP/AST 사용.

## 매직 키워드

| 키워드 | 효과 |
|--------|------|
| ultrawork | 지속 실행 모드 (중단 없이 끝까지) |
| ultrathink | 심층 사고 모드 |
| search / deepsearch | 코드베이스 탐색 모드 |
| analyze | 분석 모드 |
