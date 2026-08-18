---
allowed-tools: Read, Grep, Glob, Bash(git:*)
description: 코드베이스를 탐색하여 구조를 파악합니다.
argument-hint: "[경로] [--deps]"
---

# /explore - 반복 정제 코드베이스 탐색 (v6)

---

## 0단계: 파라미터 파싱

| 인자 | 설명 | 기본값 |
|------|------|--------|
| 검색어 | 탐색할 키워드, 함수명, 패턴 (필수) | - |
| `--auto` | 자동 정제 모드 (3회 반복) | 꺼짐 |
| `--interactive` | 대화형 정제 모드 | 기본값 |
| `--depth N` | 최대 탐색 깊이 | 3 |
| `--scope 경로` | 탐색 범위 제한 | 프로젝트 루트 |
| `--deps` | 의존성 추적 포함 | 꺼짐 |

---

## 1단계: 키워드 확장

입력 키워드에서 관련 키워드를 자동 확장한다:

| 입력 | 확장 |
|------|------|
| auth | login, logout, session, jwt, token, authenticate |
| payment | checkout, order, cart, invoice, billing |
| database | query, model, schema, migration, connection |
| user | profile, account, member, customer |
| api | endpoint, route, handler, controller |

---

## 2단계: 초기 탐색 (넓은 범위)

### 2-1. 파일명 검색

```bash
find {scope} -type f -name "*{검색어}*" \
  -not -path "*/node_modules/*" \
  -not -path "*/.git/*" \
  -not -path "*/dist/*" \
  -not -path "*/.next/*"
```

### 2-2. 코드 내용 검색

Grep 도구를 사용하여 코드 내 패턴을 검색한다.

패턴: `{검색어}`
범위: `{scope}` 또는 프로젝트 루트
제외: node_modules, .git, dist, .next, build

### 2-3. Git 히스토리 검색

```bash
git log --all --oneline --grep="{검색어}" -10
```

### 2-4. 초기 결과 정리

결과를 카테고리별로 분류한다:
- **파일**: 파일명에 검색어가 포함된 파일
- **정의**: 함수/클래스/타입 정의
- **사용처**: import, 호출, 참조
- **커밋**: 관련 Git 히스토리

관련도 점수 계산:
- 파일명 매칭: +30점
- 내용 매칭 (키워드 수): +10점/키워드
- 디렉토리 매칭: +20점
- import/export 빈도: +5점/건

---

## 3단계: 1차 필터링 및 요약

상위 15개 파일을 선정한다:
1. 각 파일 첫 50줄 읽기
2. 구조 분석 (함수, 클래스, export)
3. 카테고리 분류

카테고리:
- core: 핵심 로직
- api: API 핸들러
- ui: 컴포넌트
- types: 타입 정의
- utils: 유틸리티
- test: 테스트

---

## 4단계: 정제 라운드 (반복)

### --interactive 모드 (기본)

초기 결과를 사용자에게 보여주고, 정제 방향을 질문한다:

```
탐색 결과 (라운드 1):
  파일 [N]개 | 정의 [N]개 | 사용처 [N]개 | 커밋 [N]개

  정제 옵션:
    1. 특정 파일 자세히 보기
    2. 범위 좁히기 (디렉토리/파일 타입)
    3. 관련 패턴 추가 탐색
    4. 의존성 트리 추적
    5. 탐색 종료
```

사용자 선택에 따라 다음 라운드를 실행한다.
최대 `--depth` 횟수만큼 반복한다.

### --auto 모드

자동으로 3회 정제를 수행한다:

**라운드 1**: 넓은 범위 탐색 (위 2단계)

**라운드 2**: 정의와 사용처 교차 분석
  - 정의된 파일에서 export 패턴 확인
  - 사용처에서 import 패턴 확인
  - 의존성 방향 파악

**라운드 3**: 핵심 파일 심층 분석
  - 가장 관련성 높은 파일 3개를 Read로 읽기
  - 함수 시그니처, 타입 정의, 주요 로직 추출
  - 관련 테스트 파일 확인

---

## 5단계: 의존성 추적 (--deps 또는 depth 2+)

검색어와 관련된 코드의 의존성을 추적한다.

### 상향 추적 (이 코드를 사용하는 곳)

```bash
grep -rl "import.*{검색어}" {scope} --include="*.ts" --include="*.tsx"
```

### 하향 추적 (이 코드가 의존하는 곳)

대상 파일의 import 문을 분석하여 의존성을 파악한다.

### 의존성 그래프

```
{검색어} 의존성:
  상향 (사용처):
    src/pages/login.tsx
    src/hooks/useAuth.ts
  하향 (의존성):
    src/lib/supabase.ts
    src/types/user.ts
```

---

## 6단계: 컨텍스트 구성

### 파일 관계도

```
  src/auth/index.ts
        |
  ------+------
  |     |     |
login session jwt
  |     |     |
  ------+------
        |
  authGuard.ts
```

### 핵심 함수/클래스 요약

```
src/auth/index.ts
  export class AuthService
    - login(email, password): Promise<Session>
    - logout(): void
    - refreshSession(): Promise<Session>
  호출: src/api/auth.ts, src/hooks/useAuth.ts
  의존: src/lib/supabase/auth.ts
```

---

## 7단계: 출력

### 탐색 완료 시

```
════════════════════════════════════════════════════════════════
  Explore v6 (코드베이스 탐색)
════════════════════════════════════════════════════════════════

  검색어: "{검색어}"
  모드: [auto / interactive]
  범위: {scope}
  라운드: {N}회

  -- 탐색 결과 -----------------------------------------------

  파일 ({N}개):
    src/auth/login.ts
    src/auth/register.ts
    src/hooks/useAuth.ts

  정의 ({N}개):
    login.ts:15    export async function loginUser(...)
    register.ts:8  export async function registerUser(...)

  사용처 ({N}개):
    pages/login.tsx:3    import { loginUser } from '@/auth/login'
    hooks/useAuth.ts:5   import { loginUser, registerUser } from '@/auth'

  의존성:
    상향: 2개 파일이 이 코드를 사용
    하향: 3개 모듈에 의존

  -- 핵심 요약 -----------------------------------------------

  [검색어]는 [N]개 파일에서 정의되며, [N]개 파일에서 사용됩니다.
  주요 진입점: [파일 경로]
  관련 테스트: [테스트 파일 경로 또는 "없음"]

  수정 영향 분석:
    [주요 파일] 수정 시:
      영향 파일: [N]개
      테스트 재실행: [N]개

════════════════════════════════════════════════════════════════
```

### --auto 모드 출력

```
════════════════════════════════════════════════════════════════
  Explore v6 (Auto): "{검색어}"
════════════════════════════════════════════════════════════════

  [Phase 1-3 자동 실행...]

  탐색 요약:
    검색 파일: [N]개
    필터링 후: [N]개
    로드됨: [N]개

  핵심 발견:
    1. [발견 1 요약]
    2. [발견 2 요약]
    3. [발견 3 요약]

  컨텍스트 로드됨

  추가 탐색 필요하면:
    /explore "{검색어}" --interactive

════════════════════════════════════════════════════════════════
```

### 결과 없을 때

```
════════════════════════════════════════════════════════════════
  Explore v6 (코드베이스 탐색)
════════════════════════════════════════════════════════════════

  검색어: "{검색어}"
  결과: 일치하는 항목 없음

  시도해볼 사항:
    - 검색어 변경 (오타 확인)
    - --scope 범위 확대
    - 관련 키워드로 재검색

════════════════════════════════════════════════════════════════
```

---

## 다음 단계

| 코드를 파악했으면 | 커맨드 |
|:----------------|:-------|
| 수정 계획 세우기 | `/plan` |
| 바로 수정 시작 | `/tdd` |
