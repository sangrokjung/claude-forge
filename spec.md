# Claude Forge - 기능 명세

## Feature 1: 기업용 팀 설정 관리

### 요구사항
1. 팀별 `settings.json` 오버라이드 지원 (팀 설정 > 개인 설정 > 기본 설정)
2. 팀 관리자가 허용/차단 권한을 중앙에서 관리
3. 설정 상속 체인: `settings.json` → `settings.team.json` → `settings.local.json`

### 데이터 모델
```
settings.team.json:
  team_name: string
  permissions:
    allow: string[]       # 팀 레벨 허용 목록
    deny: string[]        # 팀 레벨 차단 목록 (개인이 해제 불가)
  enforced_rules: string[] # 팀 필수 룰 파일 목록
  mcp_servers: object      # 팀 공용 MCP 서버
```

### 비즈니스 로직
- 설정 병합 시 deny 목록은 union (합집합), allow 목록은 intersection (교집합)
- `enforced_rules`에 등록된 룰은 개인이 제거 불가
- `install.sh`가 팀 설정 파일을 감지하여 자동 적용

---

## Feature 2: RBAC (역할 기반 접근 제어)

### 요구사항
1. 역할 정의: admin, developer, reviewer, readonly
2. 역할별 커맨드/에이전트 접근 제한
3. 역할별 MCP 서버 접근 제한

### 데이터 모델
```
roles:
  admin:
    commands: ["*"]
    agents: ["*"]
    mcp: ["*"]
  developer:
    commands: ["*"]
    agents: ["planner", "tdd-guide", "code-reviewer", "build-error-resolver"]
    mcp: ["context7", "memory", "github", "fetch"]
  reviewer:
    commands: ["/code-review", "/security-review", "/explore"]
    agents: ["code-reviewer", "security-reviewer"]
    mcp: ["context7", "github"]
  readonly:
    commands: ["/explore", "/show-setup"]
    agents: []
    mcp: ["context7"]
```

### 비즈니스 로직
- `install.sh --role developer`로 역할 지정
- 역할에 따라 `settings.json`의 permissions를 자동 생성
- 커스텀 역할 정의 지원 (`roles/[name].json`)

---

## Feature 3: 감사 로그 강화

### 요구사항
1. 모든 커맨드 실행 기록 (who, what, when, where)
2. 보안 이벤트 별도 분류 (시크릿 감지, 권한 위반 등)
3. 로그 내보내기 (JSON, CSV)

### 데이터 모델
```
audit_log_entry:
  timestamp: ISO8601
  user: string
  action: string          # command/agent/hook
  target: string          # 실행 대상
  result: success|failure
  metadata:
    session_id: string
    branch: string
    files_changed: string[]
```

### 비즈니스 로직
- `work-tracker-*.sh` 훅을 확장하여 구조화된 로그 생성
- `.claude/audit/` 디렉토리에 일별 로그 파일 저장
- `/audit-report` 커맨드로 기간별 리포트 생성
- 보안 이벤트는 실시간 알림 (Slack/Teams MCP 연동)

---

## Feature 4: 프라이빗 스킬 레지스트리

### 요구사항
1. 기업 내부 스킬을 중앙 저장소에서 관리
2. `install.sh`가 레지스트리에서 스킬 자동 설치
3. 스킬 버전 관리 및 롤백

### 데이터 모델
```
registry:
  url: string             # 기업 내부 레지스트리 URL
  auth: token|ssh
  skills:
    - name: string
      version: semver
      required: boolean   # 필수 설치 여부
```

### 비즈니스 로직
- `/forge-update`에 레지스트리 동기화 추가
- 스킬 의존성 해결 (A 스킬이 B 스킬 필요 시 자동 설치)
- 스킬 서명 검증 (무결성 보장)

---

## Feature 5: 멀티 프로젝트 대시보드

### 요구사항
1. 여러 프로젝트의 상태를 한 눈에 파악
2. 프로젝트별 보안 점수, 테스트 커버리지, 최근 활동
3. CLI 기반 대시보드 (하단바 확장)

### 데이터 모델
```
project_status:
  name: string
  path: string
  last_activity: ISO8601
  security_score: number  # 0-100
  test_coverage: number   # 0-100
  open_issues: number
  pending_prs: number
```

### 비즈니스 로직
- `/dashboard` 커맨드로 전체 프로젝트 상태 표시
- cc-chips 확장으로 현재 프로젝트 점수 상시 표시
- 주기적 자동 스캔 (cron 또는 SessionStart 훅)
