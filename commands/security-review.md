---
allowed-tools: Bash(npm:*), Bash(npx:*), Bash(pip:*), Bash(cargo:*), Bash(grep:*), Bash(git:*), Read, Glob, Grep
description: CWE 기반 보안 검토 + STRIDE 위협 모델링 (v6 - effort:max 강제)
argument-hint: "[파일/디렉토리] [--auto] [--quick] [--cwe] [--stride] [--deps] [--report markdown|json]"
---

## Task

### 0단계: effort:max 강제

```
⚠️ Security Review는 항상 effort:max로 실행됩니다.
이는 보안 품질을 위해 타협할 수 없는 설정입니다.
모든 분석은 최대 깊이로 수행되며, 축약하지 않습니다.
```

effort:max를 내부적으로 강제 적용한다. 보안 검토는 속도보다 정확성이 우선이며,
shallow scan은 허용하지 않는다.

---

### 1단계: 스캔 대상 식별

**파라미터 파싱:**
- `[경로]`: 특정 파일 또는 디렉토리 지정
- `--auto`: git diff 기반 변경 파일만 스캔 (민감 패턴 감지 시 자동 트리거)
- `--quick`: 변경 파일 대상 빠른 스캔 (CWE 상위 10개만)
- `--cwe`: CWE Top 25 전체 매핑 상세 분석
- `--stride`: STRIDE 위협 모델링 추가 실행
- `--deps`: 의존성 취약점 검사
- `--report [형식]`: markdown 또는 json 리포트 파일 생성

**스캔 범위 결정:**

```bash
# --auto: git diff 변경 파일만
git diff --cached --name-only | grep -E '\.(ts|tsx|js|jsx|py|go|rs|java)$'
git diff --name-only | grep -E '\.(ts|tsx|js|jsx|py|go|rs|java)$'

# --quick: 변경 파일 빠른 스캔
git diff --name-only HEAD~1 | grep -E '\.(ts|tsx|js|jsx|py|go|rs|java)$'

# 기본 (플래그 없음): 전체 소스 파일
find src/ lib/ app/ -type f -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx'
```

**Auto-trigger 패턴 (--auto 모드에서 파일 경로/내용에 포함 시 자동 확대 스캔):**

| 패턴 | 위험 수준 | 설명 |
|------|-----------|------|
| `auth` | Critical | 인증 관련 코드 |
| `payment` | Critical | 결제 처리 코드 |
| `session` | High | 세션 관리 |
| `token` | High | 토큰 발급/검증 |
| `password` | Critical | 비밀번호 처리 |
| `secret` | Critical | 시크릿/키 관리 |
| `crypto` | High | 암호화 로직 |
| `jwt` | High | JWT 토큰 처리 |
| `admin` | High | 관리자 기능 |
| `upload` | Medium | 파일 업로드 |
| `download` | Medium | 파일 다운로드 |
| `redirect` | Medium | URL 리다이렉트 |

---

### 2단계: CWE Top 25 매핑

모든 소스 파일에 대해 CWE Top 25 기반 패턴 매칭을 수행한다.
각 발견 항목에는 반드시 CWE ID를 태깅한다.

```
┌─────────┬──────────────────────────────┬───────────────────────────────┬──────┐
│ CWE ID  │ Name                         │ Detection Pattern             │ Sev  │
├─────────┼──────────────────────────────┼───────────────────────────────┼──────┤
│ CWE-79  │ Cross-site Scripting (XSS)   │ innerHTML, dangerouslySet*,  │ Crit │
│         │                              │ v-html, [innerHTML]=         │      │
├─────────┼──────────────────────────────┼───────────────────────────────┼──────┤
│ CWE-89  │ SQL Injection                │ query( + string concat/      │ Crit │
│         │                              │ template literal with ${},   │      │
│         │                              │ .raw( + user input           │      │
├─────────┼──────────────────────────────┼───────────────────────────────┼──────┤
│ CWE-78  │ OS Command Injection         │ exec(, spawn(, execSync(     │ Crit │
│         │                              │ + user-controlled input      │      │
├─────────┼──────────────────────────────┼───────────────────────────────┼──────┤
│ CWE-22  │ Path Traversal               │ ../ in user-supplied paths,  │ High │
│         │                              │ path.join( + req.params      │      │
├─────────┼──────────────────────────────┼───────────────────────────────┼──────┤
│ CWE-352 │ Cross-Site Request Forgery   │ POST/PUT/DELETE without      │ High │
│         │                              │ CSRF token validation        │      │
├─────────┼──────────────────────────────┼───────────────────────────────┼──────┤
│ CWE-287 │ Improper Authentication      │ Missing auth middleware,     │ High │
│         │                              │ auth check bypass            │      │
├─────────┼──────────────────────────────┼───────────────────────────────┼──────┤
│ CWE-862 │ Missing Authorization        │ Route handler without authz, │ High │
│         │                              │ direct object reference      │      │
├─────────┼──────────────────────────────┼───────────────────────────────┼──────┤
│ CWE-798 │ Hardcoded Credentials        │ apiKey=", secret=", pass=",  │ Crit │
│         │                              │ token=", key=" (literals)    │      │
├─────────┼──────────────────────────────┼───────────────────────────────┼──────┤
│ CWE-200 │ Exposure of Sensitive Info   │ console.log + secret/token/  │ Med  │
│         │                              │ password, error stack trace  │      │
│         │                              │ in response                  │      │
├─────────┼──────────────────────────────┼───────────────────────────────┼──────┤
│ CWE-502 │ Deserialization of Untrusted │ JSON.parse(untrusted),       │ High │
│         │ Data                         │ eval(, new Function(         │      │
├─────────┼──────────────────────────────┼───────────────────────────────┼──────┤
│ CWE-306 │ Missing Authentication for   │ Critical endpoint without    │ High │
│         │ Critical Function            │ auth guard                   │      │
├─────────┼──────────────────────────────┼───────────────────────────────┼──────┤
│ CWE-20  │ Improper Input Validation    │ No schema validation (zod/   │ Med  │
│         │                              │ joi), missing sanitization   │      │
├─────────┼──────────────────────────────┼───────────────────────────────┼──────┤
│ CWE-269 │ Improper Privilege Mgmt      │ Role escalation, missing     │ High │
│         │                              │ role check                   │      │
├─────────┼──────────────────────────────┼───────────────────────────────┼──────┤
│ CWE-434 │ Unrestricted Upload          │ File upload without type/    │ High │
│         │                              │ size validation              │      │
├─────────┼──────────────────────────────┼───────────────────────────────┼──────┤
│ CWE-918 │ Server-Side Request Forgery  │ fetch/axios with user URL,   │ High │
│         │                              │ no URL allowlist             │      │
├─────────┼──────────────────────────────┼───────────────────────────────┼──────┤
│ CWE-611 │ XML External Entity (XXE)    │ XML parser without disabled  │ High │
│         │                              │ external entities            │      │
├─────────┼──────────────────────────────┼───────────────────────────────┼──────┤
│ CWE-77  │ Command Injection            │ Template strings in shell    │ Crit │
│         │                              │ commands                     │      │
├─────────┼──────────────────────────────┼───────────────────────────────┼──────┤
│ CWE-276 │ Incorrect Default Perms      │ 0777, world-writable files,  │ Med  │
│         │                              │ permissive CORS              │      │
├─────────┼──────────────────────────────┼───────────────────────────────┼──────┤
│ CWE-732 │ Incorrect Permission Assign  │ Public access to admin       │ High │
│         │                              │ resources                    │      │
├─────────┼──────────────────────────────┼───────────────────────────────┼──────┤
│ CWE-327 │ Use of Broken Crypto Algo    │ md5(, sha1(, DES, RC4,      │ Med  │
│         │                              │ Math.random() for security   │      │
└─────────┴──────────────────────────────┴───────────────────────────────┴──────┘
```

**Grep 스캔 실행 예시:**

```bash
# CWE-79: XSS
grep -rn 'innerHTML\|dangerouslySetInnerHTML\|v-html' src/

# CWE-89: SQL Injection
grep -rn 'query(`\|query(".*\${\|\.raw(' src/

# CWE-78/77: Command Injection
grep -rn 'exec(\|execSync(\|spawn(' src/ | grep -v node_modules

# CWE-798: Hardcoded Credentials
grep -rn 'apiKey.*=.*"\|secret.*=.*"\|password.*=.*"\|token.*=.*"' src/ --include='*.ts' --include='*.js'

# CWE-200: Sensitive Info Exposure
grep -rn 'console\.log.*\(password\|token\|secret\|key\|credential\)' src/

# CWE-327: Broken Crypto
grep -rn 'md5(\|sha1(\|Math\.random()' src/ --include='*.ts' --include='*.js'

# CWE-502: Unsafe Deserialization
grep -rn 'eval(\|new Function(\|JSON\.parse' src/ | grep -v 'JSON\.parse(JSON'

# CWE-918: SSRF
grep -rn 'fetch(\|axios\.\(get\|post\)' src/ | grep 'req\.\|params\.\|query\.'
```

---

### 3단계: STRIDE 위협 모델링 (--stride)

`--stride` 플래그가 있을 때 실행한다.
각 발견 항목을 STRIDE 카테고리로 추가 분류한다.

```
┌───┬─────────────────────────────┬─────────────────────────────────────────────┐
│   │ STRIDE Category             │ 검토 항목                                    │
├───┼─────────────────────────────┼─────────────────────────────────────────────┤
│ S │ Spoofing (인증 위조)         │ - 인증 토큰 위조 가능성                      │
│   │                             │ - 세션 하이재킹 취약점                        │
│   │                             │ - 사용자 신원 확인 누락                       │
│   │                             │ - 관련 CWE: 287, 306, 798                   │
├───┼─────────────────────────────┼─────────────────────────────────────────────┤
│ T │ Tampering (데이터 변조)      │ - 입력값 검증 부재 (CWE-20)                  │
│   │                             │ - SQL/Command Injection (CWE-89, 78)        │
│   │                             │ - 서명되지 않은 데이터 전송                    │
│   │                             │ - 클라이언트 측 검증만 존재                    │
├───┼─────────────────────────────┼─────────────────────────────────────────────┤
│ R │ Repudiation (부인)          │ - 감사 로그 부재                              │
│   │                             │ - 민감 작업 기록 누락                         │
│   │                             │ - 로그 무결성 미보장                          │
│   │                             │ - 트랜잭션 추적 불가                          │
├───┼─────────────────────────────┼─────────────────────────────────────────────┤
│ I │ Information Disclosure      │ - 에러 스택트레이스 노출 (CWE-200)            │
│   │ (정보 유출)                  │ - 민감 데이터 로깅 (CWE-200)                 │
│   │                             │ - API 응답에 과다 정보                        │
│   │                             │ - 소스맵/디버그 정보 노출                     │
├───┼─────────────────────────────┼─────────────────────────────────────────────┤
│ D │ Denial of Service           │ - Rate limiting 미적용                       │
│   │ (서비스 거부)                │ - 무제한 파일 업로드 (CWE-434)               │
│   │                             │ - ReDoS 가능 정규표현식                      │
│   │                             │ - 리소스 소진 취약점                          │
├───┼─────────────────────────────┼─────────────────────────────────────────────┤
│ E │ Elevation of Privilege      │ - 수평/수직 권한 상승 (CWE-269)              │
│   │ (권한 상승)                  │ - IDOR (CWE-862)                            │
│   │                             │ - 관리자 기능 접근 제어 미비                   │
│   │                             │ - JWT 클레임 조작 가능성                      │
└───┴─────────────────────────────┴─────────────────────────────────────────────┘
```

**STRIDE 분석 출력 형식:**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
STRIDE 위협 모델링 결과
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

┌───────────────────────────────────────────────────────┐
│ Category                │ Threats │ Critical │ Status │
├─────────────────────────┼─────────┼──────────┼────────┤
│ S - Spoofing            │    2    │    1     │  FAIL  │
│ T - Tampering           │    3    │    2     │  FAIL  │
│ R - Repudiation         │    1    │    0     │  WARN  │
│ I - Info Disclosure     │    2    │    0     │  WARN  │
│ D - Denial of Service   │    1    │    0     │  WARN  │
│ E - Elevation of Priv   │    2    │    1     │  FAIL  │
└───────────────────────────────────────────────────────┘

위협 점수: 45/100 (개선 필요)
```

---

### 4단계: 보안 Fixable 자동 수정

자동 수정 가능한 취약점은 사용자 승인 후 즉시 적용한다.
수정 전후 diff를 반드시 보여준다.

**자동 수정 규칙:**

| CWE | 취약 패턴 | 자동 수정 | 신뢰도 |
|-----|-----------|-----------|--------|
| CWE-89 | String concat SQL | Parameterized query ($1, ?) | High |
| CWE-798 | Hardcoded secret literal | process.env.VAR_NAME | High |
| CWE-79 | innerHTML = userInput | textContent = userInput | High |
| CWE-79 | dangerouslySetInnerHTML | DOMPurify.sanitize() | Med |
| CWE-200 | console.log(secret) | 라인 제거 또는 마스킹 | High |
| CWE-327 | md5(, sha1( | crypto.createHash('sha256') | Med |
| CWE-276 | CORS: origin: '*' | 명시적 origin 지정 | Med |
| CWE-352 | POST without CSRF | CSRF 토큰 검증 추가 | Low |

**자동 수정 흐름:**

```
[발견] CWE-798 Hardcoded Credential in src/config/auth.ts:12
  Before: jwtSecret: 'my-super-secret-key-12345',
  After:  jwtSecret: process.env.JWT_SECRET,
  + .env.example에 JWT_SECRET= 추가

적용하시겠습니까? (Y/n)
```

신뢰도 Low인 수정은 제안만 하고, High/Med만 자동 수정 대상으로 표시한다.

---

### 5단계: 의존성 취약점 (--deps)

`--deps` 플래그가 있을 때 실행한다.
프로젝트 루트에서 패키지 매니저를 자동 감지한다.

**Node.js (package.json 감지 시):**

```bash
npm audit --json 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
vulns = data.get('vulnerabilities', {})
for name, info in vulns.items():
    sev = info.get('severity', 'unknown')
    via = info.get('via', [])
    fix = info.get('fixAvailable', False)
    print(f'{sev.upper():8} {name:30} fix={fix}')
"
```

**Python (requirements.txt / pyproject.toml 감지 시):**

```bash
pip-audit --format json 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
for dep in data.get('dependencies', []):
    for vuln in dep.get('vulns', []):
        print(f\"{vuln['id']:15} {dep['name']:25} {dep['version']:10} fix={vuln.get('fix_versions', ['N/A'])}\")
"
```

**Rust (Cargo.toml 감지 시):**

```bash
cargo audit --json 2>/dev/null
```

**Go (go.mod 감지 시):**

```bash
govulncheck ./... 2>/dev/null
```

**출력 형식:**

```
════════════════════════════════════════════════════════════════
의존성 취약점 스캔 결과
════════════════════════════════════════════════════════════════

감지된 패키지 매니저: npm (package-lock.json)
스캔 대상: N개 패키지

┌──────────────────────────────────────────────────────────────┐
│ 심각도    패키지              버전      CVE           수정 버전 │
├──────────────────────────────────────────────────────────────┤
│ Critical  lodash              4.17.19   CVE-2021-xxx  4.17.21 │
│ High      minimist            1.2.5     CVE-2022-xxx  1.2.8   │
│ Medium    semver              7.3.7     CVE-2023-xxx  7.5.2   │
└──────────────────────────────────────────────────────────────┘

자동 수정 가능: npm audit fix
수동 수정 필요: npm audit fix --force (breaking changes 주의)
```

---

### 6단계: 출력

**v6 표준 헤더:**

```
════════════════════════════════════════════════════════════════
  Security Review v6 (effort: max, CWE Top 25)
════════════════════════════════════════════════════════════════
```

**요약 섹션:**

```
스캔 대상: N개 파일 | 모드: [auto|quick|full]
분석 깊이: effort:max | CWE 매핑: [10|25]개
STRIDE: [실행됨|미실행] | 의존성: [실행됨|미실행]

발견된 이슈: N개
  Critical: X개 | High: Y개 | Medium: Z개 | Low: W개
```

**개별 이슈 형식 (CWE + STRIDE 태깅):**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[Critical] CWE-89: SQL Injection | STRIDE: T (Tampering)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
위치: src/api/users.ts:34
CWE: https://cwe.mitre.org/data/definitions/89.html

코드:
> 34 |   const result = await db.query(`SELECT * FROM users WHERE id = '${id}'`);

위험: 사용자 입력이 SQL 쿼리에 직접 삽입됨
공격 예시: id = "'; DROP TABLE users; --"

수정 방법:
  const result = await db.query('SELECT * FROM users WHERE id = $1', [id]);

자동 수정 가능: Yes (신뢰도: High)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**커밋 권고 푸터:**

```
════════════════════════════════════════════════════════════════
커밋 권고
════════════════════════════════════════════════════════════════

Critical 이슈: X개 -> BLOCKED (커밋 전 반드시 수정)
High 이슈: Y개 -> 수정 강력 권장
Medium 이슈: Z개 -> 검토 후 수정 권장
Low 이슈: W개 -> 선택적 수정

상태: BLOCKED | WARN | PASS

BLOCKED: Critical 이슈가 1개 이상 존재하면 커밋을 차단합니다.
WARN: High 이슈만 존재하면 경고를 표시하고 커밋을 허용합니다.
PASS: Medium 이하만 존재하면 통과합니다.
════════════════════════════════════════════════════════════════
```

**--report markdown 출력 시:**
결과를 `security-report-YYYYMMDD-HHMMSS.md` 파일로 저장한다.

**--report json 출력 시:**
결과를 `security-report-YYYYMMDD-HHMMSS.json` 파일로 저장하며, 구조는 다음과 같다:

```json
{
  "version": "v6",
  "timestamp": "2026-02-07T12:00:00Z",
  "effort": "max",
  "scan": {
    "mode": "full",
    "files_scanned": 42,
    "cwe_rules": 20,
    "stride_enabled": true,
    "deps_enabled": true
  },
  "findings": [
    {
      "severity": "critical",
      "cwe_id": "CWE-89",
      "cwe_name": "SQL Injection",
      "stride_category": "T",
      "file": "src/api/users.ts",
      "line": 34,
      "code": "const result = await db.query(`SELECT * FROM users WHERE id = '${id}'`);",
      "description": "사용자 입력이 SQL 쿼리에 직접 삽입됨",
      "fix": "Parameterized query 사용",
      "auto_fixable": true,
      "confidence": "high"
    }
  ],
  "summary": {
    "critical": 1,
    "high": 2,
    "medium": 1,
    "low": 0,
    "total": 4,
    "recommendation": "BLOCKED"
  },
  "dependencies": {
    "package_manager": "npm",
    "total_packages": 120,
    "vulnerable": 3,
    "auto_fixable": 2
  }
}
```
