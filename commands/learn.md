---
allowed-tools: Bash(git:*), Read, Edit, Write, Grep, Glob
description: 교훈 기록 + 자동화 제안 (v6 - suggest-automation 통합)
argument-hint: '["교훈 내용"] [--from-error] [--from-session] [--suggest] [--list] [--edit N] [--remove N]'
---

# /learn - 교훈 기록 + 자동화 제안 (v6)

---

## 0단계: 파라미터 파싱

인자를 분석하여 모드를 결정한다.

| 플래그 | 설명 |
|--------|------|
| (없음) | 직접 교훈 입력 |
| `--from-error` | 최근 에러에서 패턴 추출 |
| `--from-session` | 현재 세션에서 패턴 추출 |
| `--suggest` | git log 기반 자동화 제안 |
| `--list` | 기록된 학습 목록 조회 |
| `--edit N` | N번 항목 수정 |
| `--remove N` | N번 항목 삭제 |

파싱 규칙:
- `--list`, `--edit`, `--remove`는 단독 실행 (다른 플래그와 조합 불가)
- `--suggest`는 단독 또는 `--from-session`과 조합 가능
- 플래그 없이 텍스트만 있으면 직접 입력 모드

---

## 1단계: 학습 소스 분석

### 직접 입력 모드 (기본)

사용자가 제공한 텍스트를 교훈으로 기록한다.

```
/learn "Supabase RLS 정책 변경 시 반드시 마이그레이션 파일 생성 필요"
```

### --from-error 모드

1. 최근 터미널 출력에서 에러 메시지를 탐지한다.
2. 에러의 근본 원인을 분석한다.
3. 해결 방법을 교훈으로 정리한다.

```bash
# 최근 에러 컨텍스트 확인
git log --oneline -5
git diff HEAD~1
```

### --from-session 모드

1. 현재 세션에서 수행한 작업을 요약한다.
2. 반복된 패턴, 실수, 발견사항을 추출한다.
3. 각 항목을 교훈으로 정리한다.

### --list 모드

CLAUDE.md의 `# Lessons Learned` 섹션을 읽어 목록을 출력한다.

### --edit N 모드

N번 항목을 읽고 사용자에게 수정 내용을 확인한 뒤 반영한다.

### --remove N 모드

N번 항목을 삭제한다. 삭제 전 해당 내용을 표시하고 확인한다.

---

## 2단계: 패턴 분석

추출된 교훈을 다음 분류 체계에 따라 태깅한다.

```
패턴 분류:
  error-pattern:        반복 에러 패턴 (빌드 실패, 타입 에러, 런타임 에러)
  performance-pattern:  성능 관련 패턴 (쿼리 최적화, 번들 사이즈, 렌더링)
  security-pattern:     보안 관련 패턴 (인증, 권한, 입력 검증)
  automation-pattern:   자동화 기회 (--suggest 모드 전용)
```

분류 기준:
- 에러 메시지가 포함된 경우 -> `error-pattern`
- 속도, 크기, 메모리 관련 -> `performance-pattern`
- 인증, 토큰, 권한, XSS 관련 -> `security-pattern`
- 반복 작업, 수동 작업 관련 -> `automation-pattern`
- 복수 분류 가능 (쉼표 구분)

---

## 3단계: --suggest 모드 (자동화 제안)

### 3-1. Git 히스토리 분석

```bash
git log --oneline -50
```

최근 50개 커밋에서 반복 패턴을 식별한다.

### 3-2. 반복 커밋 패턴 식별

다음 패턴을 탐지한다:
- 동일한 접두사가 3회 이상 반복 (예: `fix: lint`, `fix: type error`)
- 동일 파일이 5회 이상 수정
- 동일한 키워드가 반복 등장 (예: `migration`, `config`, `env`)

### 3-3. 파일 변경 패턴 분석

```bash
git log --name-only --oneline -50
```

자주 함께 변경되는 파일 그룹을 식별한다.

### 3-4. 기존 자동화 확인

이미 자동화된 항목과 중복되지 않도록 기존 설정을 확인한다.

```bash
# 기존 커맨드 확인
ls .claude/commands/ 2>/dev/null

# 기존 에이전트 확인
ls .claude/agents/ 2>/dev/null

# 기존 스킬 확인
ls .claude/skills/ 2>/dev/null
```

### 3-5. 제안 생성

탐지된 패턴별로 자동화 제안을 생성한다:

| 패턴 유형 | 제안 형태 |
|-----------|----------|
| 반복 커밋 (단순 작업) | Custom Command (`.claude/commands/`) |
| 반복 커밋 (복합 작업) | Custom Skill (`.claude/skills/`) |
| 반복 에러 수정 | Agent (`.claude/agents/`) |
| 파일 그룹 변경 | Hook (PreToolUse/PostToolUse) |

출력 형식:
```
자동화 제안:
  1. [command] /fix-lint - lint 에러 자동 수정 (8회 반복 감지)
  2. [skill]  db-migrate - 마이그레이션 생성+적용 (5회 반복 감지)
  3. [hook]   config 변경 시 env 검증 (4회 동시 변경 감지)
```

### 3-6. 선택적 생성

사용자가 번호를 선택하면 해당 자동화 파일을 생성한다.
생성하지 않을 경우 교훈으로만 기록한다.

---

## 4단계: CLAUDE.md 업데이트

프로젝트 루트의 `CLAUDE.md` 파일에 교훈을 추가한다.

### 섹션 위치

`# Lessons Learned` 섹션이 없으면 파일 끝에 생성한다.

### 기록 형식

```markdown
# Lessons Learned

## [N]. [제목] - [패턴 분류]
- **날짜**: 2026-02-07
- **분류**: error-pattern
- **교훈**: [내용]
- **조치**: [취한 조치 또는 권장 사항]
```

### Agent Memory 연동

교훈이 특정 에이전트의 도메인에 해당하는 경우, 해당 에이전트의 memory에도 기록한다.

| 교훈 분류 | 관련 에이전트 | Memory 경로 |
|-----------|-------------|-------------|
| error-pattern (빌드) | build-error-resolver | `~/.claude/agent-memory/build-error-resolver/` |
| error-pattern (테스트) | tdd-guide | `~/.claude/agent-memory/tdd-guide/` |
| security-pattern | security-reviewer | `~/.claude/agent-memory/security-reviewer/` |
| performance-pattern | architect | `~/.claude/agent-memory/architect/` |
| automation-pattern | planner | `~/.claude/agent-memory/planner/` |

기록 형식 (agent-memory에 append):
```
## Learnings
- [날짜] [프로젝트] 발견: [교훈 내용 요약]
```

이렇게 하면 에이전트가 다음 작업 시 관련 교훈을 자동으로 참조할 수 있다.

### --suggest 결과 기록

자동화 제안이 채택된 경우:
```markdown
## [N]. [제목] - automation-pattern
- **날짜**: 2026-02-07
- **분류**: automation-pattern
- **교훈**: [반복 패턴 설명]
- **조치**: [생성된 자동화 파일 경로]
```

---

## 5단계: 출력

### 성공 시

```
════════════════════════════════════════════════════════════════
  Learn v6 (패턴 분류 + 자동화 제안)
════════════════════════════════════════════════════════════════

  모드: [직접입력 / from-error / from-session / suggest]
  패턴 분류: [error-pattern / performance-pattern / ...]

  기록된 교훈:
    [교훈 내용 요약]

  CLAUDE.md 업데이트: [완료 / 해당 없음]
  자동화 생성: [파일 경로 / 해당 없음]

  권장 조치:
    검증 실패 학습 → /handoff-verify (다음 작업 시 반영)

════════════════════════════════════════════════════════════════
```

### --suggest 모드 출력

```
════════════════════════════════════════════════════════════════
  Learn v6 --suggest (자동화 제안)
════════════════════════════════════════════════════════════════

  분석 범위: 최근 50개 커밋

  탐지된 반복 패턴:
    1. lint 수정 (8회) -> [command] /fix-lint
    2. DB 마이그레이션 (5회) -> [skill] db-migrate
    3. config+env 동시 변경 (4회) -> [hook] config-env-sync

  생성하려는 항목 번호를 입력하세요 (쉼표 구분, 0=건너뛰기):

════════════════════════════════════════════════════════════════
```

### --list 모드 출력

```
════════════════════════════════════════════════════════════════
  Learn v6 - 학습 목록
════════════════════════════════════════════════════════════════

  총 [N]개 교훈 기록됨

  [1] error-pattern    | RLS 정책 변경 시 마이그레이션 필수 (2026-02-05)
  [2] security-pattern | API 키 로테이션 후 캐시 무효화 (2026-02-07)

  수정: /learn --edit N | 삭제: /learn --remove N

════════════════════════════════════════════════════════════════
```
