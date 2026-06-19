---
name: security-pipeline
description: Use when security verification is needed - pre-commit security checks, vulnerability scanning, STRIDE threat analysis. Integrates with /handoff-verify --security and /commit-push-pr. CWE Top 25 based.
version: 2.0.0
---

## Overview

보안 파이프라인 스킬은 코드 변경 시 자동으로 CWE Top 25 기반 보안 검증을 수행한다.
`/handoff-verify --security`, `/commit-push-pr` 실행 시 통합 동작한다.
보안 체크리스트 참조: `~/.claude/skills/_reference/security-checklist.md`

effort:max가 항상 강제 적용된다. 보안 검증은 축약하지 않는다.

---

## Trigger Conditions

### 파일 패턴 기반 자동 트리거

다음 패턴을 포함하는 파일이 변경되면 보안 파이프라인이 자동으로 실행된다:

| 패턴 | 트리거 수준 | 설명 |
|------|-------------|------|
| `**/auth/**` | Full Scan | 인증 관련 모듈 |
| `**/payment/**` | Full Scan | 결제 처리 모듈 |
| `**/api/**` | CWE Scan | API 엔드포인트 |
| `**/middleware/**` | CWE Scan | 미들웨어 |
| `**/session*` | CWE Scan | 세션 관리 |
| `**/token*` | CWE Scan | 토큰 처리 |
| `**/crypto*` | CWE Scan | 암호화 로직 |
| `**/admin/**` | Full + STRIDE | 관리자 기능 |
| `**/upload*` | CWE Scan | 파일 업로드 |
| `**/.env*` | Credential Scan | 환경변수 파일 |
| `**/config/secret*` | Credential Scan | 시크릿 설정 |

### 커밋 기반 자동 트리거

`/commit-push-pr` 실행 시 staged 파일 목록에서 위 패턴이 감지되면,
커밋 전 보안 파이프라인이 자동으로 실행된다.

---

## CWE Scanning Rules

### Critical (커밋 차단)

| CWE ID | Rule | Grep Pattern |
|--------|------|--------------|
| CWE-89 | SQL Injection | `query\(.*\$\{`, `query\(.*\+` |
| CWE-79 | XSS | `innerHTML`, `dangerouslySetInnerHTML`, `v-html` |
| CWE-78 | OS Command Injection | `exec\(.*\$\{`, `spawn\(.*req\.` |
| CWE-77 | Command Injection | Template string in shell command |
| CWE-798 | Hardcoded Credentials | `apiKey\s*=\s*['"]`, `secret\s*=\s*['"]` |

### High (경고, 커밋 허용)

| CWE ID | Rule | Grep Pattern |
|--------|------|--------------|
| CWE-22 | Path Traversal | `\.\.\/` with user input |
| CWE-352 | CSRF | POST handler without csrf check |
| CWE-287 | Improper Auth | Route without auth middleware |
| CWE-862 | Missing Authz | Handler without role/permission check |
| CWE-502 | Unsafe Deserialization | `eval\(`, `new Function\(` |
| CWE-918 | SSRF | `fetch\(.*req\.`, `axios.*req\.` |
| CWE-434 | Unrestricted Upload | Upload without validation |
| CWE-269 | Privilege Escalation | Role change without verification |

### Medium (정보 제공)

| CWE ID | Rule | Grep Pattern |
|--------|------|--------------|
| CWE-200 | Info Disclosure | `console\.log.*password\|token\|secret` |
| CWE-20 | Input Validation | Endpoint without schema validation |
| CWE-327 | Broken Crypto | `md5\(`, `sha1\(`, `Math\.random\(\)` |
| CWE-276 | Incorrect Perms | `origin:\s*['"]?\*`, `0o?777` |

---

## Auto-Fix Rules

자동 수정은 사용자 승인 후 적용한다. 신뢰도가 High인 항목만 자동 수정 대상이다.

### Parameterized Queries (CWE-89)

```
Before: db.query(`SELECT * FROM users WHERE id = '${id}'`)
After:  db.query('SELECT * FROM users WHERE id = $1', [id])
```

### Environment Variables (CWE-798)

```
Before: const apiKey = 'sk-proj-abc123'
After:  const apiKey = process.env.API_KEY
+ .env.example에 API_KEY= 추가
```

### Safe DOM Manipulation (CWE-79)

```
Before: element.innerHTML = userInput
After:  element.textContent = userInput
```

### Remove Sensitive Logs (CWE-200)

```
Before: console.log('Token:', token)
After:  // (line removed)
```

### Secure Hash (CWE-327)

```
Before: const hash = md5(data)
After:  const hash = crypto.createHash('sha256').update(data).digest('hex')
```

---

## Integration Points

### /handoff-verify (v6)

`/handoff-verify` 커맨드의 검증 단계에서 보안 검사가 포함된다.
verify-agent가 민감 파일 변경을 감지하면 이 스킬을 자동 호출한다.

### /commit-push-pr

커밋 전 자동 보안 게이트로 동작한다:
- Critical 발견 시: 커밋 차단 (BLOCKED)
- High 발견 시: 경고 표시 후 사용자 확인 (WARN)
- Medium 이하만 존재: 통과 (PASS)

### /security-review (통합됨)

이전 security-review 스킬의 OWASP 체크리스트는 `_reference/security-checklist.md`로 전환.
전체 보안 리뷰 시 이 스킬의 CWE Top 25 매핑 + STRIDE + 의존성 검사가 수행되며,
체크리스트 참조 파일을 함께 로드한다.

---

## effort:max Enforcement

이 스킬은 항상 effort:max로 실행된다.
보안 검증에서 분석 깊이를 줄이는 것은 허용하지 않는다.

적용 범위:
- CWE 패턴 매칭 시 false positive 최소화를 위한 컨텍스트 분석
- STRIDE 분류 시 전체 데이터 흐름 추적
- 자동 수정 제안 시 사이드 이펙트 검증
- 의존성 검사 시 transitive dependency 포함
