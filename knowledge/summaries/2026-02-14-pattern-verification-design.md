# 패턴 검증 시스템 설계 문서

> 2026-02-14 | 출처: kimoring/ai-skills 패턴 적용

## 한 줄 요약

기존에 자동으로 잡던 "오타(빌드/타입 오류)"에 더해서, "우리 팀 글쓰기 스타일(코딩 규칙/패턴)"도 자동으로 잡아주는 시스템을 옆에 하나 더 놓은 것.

---

## 1. 무엇이 추가되었나

| 파일 | 역할 | 비유 |
|------|------|------|
| `skills/manage-skills/SKILL.md` | 검사 항목을 자동으로 만들어주는 스킬 | 메뉴판을 만드는 사람 |
| `skills/verify-implementation/SKILL.md` | 검사 항목을 실행하는 스킬 | 메뉴판 보고 요리하는 사람 |

기존 파일은 하나도 변경하지 않았다. 새 파일 2개만 추가.

---

## 2. 기존 시스템과의 관계

```
verification-engine (기존)     verify-implementation (신규)
----------------------------   ----------------------------
빌드 오류                      코딩 패턴 위반
타입 오류                      아키텍처 규약 위반
린트 오류                      프로젝트 관례 위반
테스트 실패                    네이밍/구조 규칙 위반

"컴파일러가 잡는 것"            "사람이 리뷰에서 잡던 것"
```

비유: verification-engine은 **맞춤법 검사기**, verify-implementation은 **회사 글쓰기 스타일 검사기**.

---

## 3. 설계 결정과 이유

### 3-1. 왜 스킬 2개로 나눴나

```
/manage-skills          -> 검사 항목을 만드는 역할
/verify-implementation  -> 검사를 실행하는 역할
```

식당에서 메뉴판 만드는 사람과 요리하는 사람이 같으면 둘 다 엉망이 된다.
나눠야 각자 맡은 일에 집중할 수 있다.

### 3-2. 왜 기존 verification-engine을 안 고치고 새로 만들었나

기존 집(verification-engine)에 방을 증축하면 공사 중에 살기 불편하다.
옆에 별채를 짓는 게(새 스킬 추가) 기존 생활에 영향이 없다.

- 기존 시스템이 깨질 위험 제로
- 새 시스템이 마음에 안 들면 파일 2개만 삭제하면 원복
- 두 시스템이 서로 모르기 때문에 하나가 고장 나도 다른 하나는 정상 작동

### 3-3. 왜 에이전트 중복 감지를 넣었나

우리 시스템에는 이미 53개 전문 에이전트가 있다.

```
security-reviewer    -> 보안 검증 담당
database-reviewer    -> DB 검증 담당
code-reviewer        -> 코드 품질 담당
```

여기서 `/manage-skills`가 "verify-security" 같은 걸 또 만들면 같은 일을 두 곳에서 하게 된다. 결과가 다르면 혼란, 같으면 낭비.

그래서 "이 도메인은 이미 전문가가 있으니 스킬 안 만든다"는 로직을 넣었다.

### 3-4. 왜 3-way 동기화를 하나

스킬이 새로 생기면 3곳에 기록해야 한다:

```
manage-skills/SKILL.md         -> "이런 스킬이 있다" (등록부)
verify-implementation/SKILL.md -> "이 스킬을 실행해야 한다" (실행 목록)
프로젝트 CLAUDE.md              -> "이 프로젝트에서 쓸 수 있다" (사용 안내)
```

비유: 신입사원이 들어오면 인사팀 명부에 등록하고(manage-skills), 업무 배분표에 추가하고(verify-implementation), 회사 소개 페이지에 반영해야(CLAUDE.md) 한다. 한 곳이라도 빠지면 혼란이 생긴다.

### 3-5. 왜 적응형 실행(5개/6개 기준)을 넣었나

```
스킬 5개 이하 -> 순차 실행 (하나씩 차례로)
스킬 6개 이상 -> 병렬 실행 (동시에 여러 개)
```

비유: 세탁물 5벌이면 손세탁이 빠르다(세탁기 돌리는 시간이 더 걸림). 세탁물 20벌이면 세탁기가 빠르다(손세탁은 하루 종일).

기술적 이유:
- 병렬 실행은 서브에이전트를 따로 만드는데, 이게 토큰(비용)을 더 쓴다
- 스킬이 적으면 순차로 하는 게 비용 대비 효율적
- 스킬이 많아지면 순차로 하면 너무 느리니까 병렬이 필수

### 3-6. 왜 심각도(CRITICAL/HIGH/MEDIUM/LOW)를 나눴나

모든 이슈를 동등하게 취급하면 급한 걸 놓친다.

```
"하드코딩된 비밀번호" (CRITICAL) <- 즉시 고쳐야
"변수명이 좀 길다" (LOW)         <- 나중에 해도 됨
```

`--severity HIGH` 플래그로 "급한 것만 보여줘"가 가능해진다.

### 3-7. 왜 프로젝트별로 verify-* 스킬을 만들게 했나

```
글로벌 스킬 (모든 프로젝트 공통):
  manage-skills, verify-implementation

프로젝트별 스킬 (프로젝트마다 다름):
  verify-api, verify-auth, verify-naming...
```

비유: 회사 공통 규칙("출근 시간은 9시")은 글로벌, 부서별 규칙("마케팅팀은 보고서를 이 양식으로")은 프로젝트별. 프론트엔드 프로젝트와 백엔드 프로젝트의 규칙이 다르니까 검증 스킬도 각 프로젝트에 맞게 따로 만들어야 한다.

### 3-8. 왜 --fix와 --report-only를 나눴나

```
--fix          -> 문제 찾으면 바로 고쳐줘
--report-only  -> 문제만 알려주고 손대지 마
```

비유: 건강검진 결과만 받기(report-only) vs 건강검진 + 즉시 처방(fix).

- 코드 리뷰 중 -> 보고서만 필요 (내가 직접 고칠 거니까)
- 커밋 직전 -> 자동 수정 원함 (빨리 끝내고 싶으니까)

---

## 4. 사용 방법

### 기본 사용

```bash
# 1. 코드 작성 후, 변경사항에 맞는 검증 스킬 생성
/manage-skills

# 2. 생성된 모든 verify-* 스킬을 통합 실행
/verify-implementation
```

### 옵션

```bash
/verify-implementation --fix              # 이슈 자동 수정
/verify-implementation --report-only      # 보고서만 (수정 없음)
/verify-implementation --severity HIGH    # HIGH 이상만 보고
/verify-implementation --category api     # verify-api 스킬만 실행
```

### 전체 워크플로우

```
코드 작성
  -> /manage-skills          (verify-* 스킬 생성/업데이트)
  -> /verify-implementation  (패턴 검증)
  -> /handoff-verify         (기술 검증 - 기존)
  -> /commit-push-pr         (커밋)
```

---

## 5. 전체 구조 한눈에

```
코드를 짰다
    |
    v
/manage-skills (자동으로 검사 항목 생성)
    |
    v
verify-api, verify-naming... (프로젝트별 검사 항목들)
    |
    v
/verify-implementation (검사 항목 전부 실행 -> 보고서)
    |
    v
"패턴 규칙은 다 지켰다"
    |
    v
/handoff-verify (빌드/타입/린트/테스트 - 기존)
    |
    v
"기술적으로도 문제없다"
    |
    v
커밋
```

---

## 6. 출처

[kimoring/ai-skills](https://github.com/kimoring/ai-skills)의 manage-skills + verify-implementation 패턴을 글로벌 스킬로 적용.

주요 변경점 (원본 대비):
- 프로젝트 레벨 -> 글로벌 레벨
- 에이전트 중복 감지 로직 추가
- 3-way 동기화 (manage-skills, verify-implementation, CLAUDE.md)
- 적응형 실행 전략 (순차/병렬)
- 심각도 분류 및 실행 플래그
