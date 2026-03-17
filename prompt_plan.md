# Claude Forge - 구현 계획 (기업용 확장)

## Phase 1: 팀 설정 인프라

> 기업 환경의 기반이 되는 팀 설정 체계 구축

- [x] `settings.team.json` 스키마 정의
- [x] `install.sh`에 팀 설정 감지 및 병합 로직 추가
- [x] 설정 상속 체인 구현 (기본 → 팀 → 개인)
- [x] deny 목록 union 병합 로직 구현
- [x] `enforced_rules` 강제 적용 메커니즘 구현
- [x] 팀 설정 검증 커맨드 (`/show-setup` 확장)

## Phase 2: RBAC 시스템

> 역할별 권한 관리로 기업 보안 요구사항 충족

- [x] 역할 정의 파일 구조 설계 (`roles/*.json`)
- [x] 기본 역할 4종 생성 (admin, developer, reviewer, readonly)
- [x] `install.sh --role` 플래그 구현
- [x] 역할 기반 permissions 자동 생성 로직
- [x] 커스텀 역할 정의 지원
- [x] 역할 전환 커맨드 (`/switch-role`)

## Phase 3: 감사 로그

> 컴플라이언스 및 보안 감사를 위한 로깅 체계

- [x] 구조화된 감사 로그 포맷 정의 (JSON)
- [x] `work-tracker-*.sh` 훅 확장 (구조화된 출력)
- [x] `.claude/audit/` 디렉토리 자동 생성 및 관리
- [x] 보안 이벤트 분류 및 별도 로깅
- [x] `/audit-report` 커맨드 생성
- [x] 로그 내보내기 (JSON, CSV)
- [x] 로그 보존 정책 (cleanupPeriodDays 연동)

## Phase 4: 프라이빗 스킬 레지스트리

> 기업 내부 스킬 중앙 관리 및 배포

- [x] 레지스트리 스키마 정의 (`registry.json`)
- [x] `/forge-update`에 레지스트리 동기화 추가
- [x] 스킬 의존성 해결 엔진
- [x] 스킬 버전 관리 (설치/업데이트/롤백)
- [x] 스킬 서명 검증 메커니즘
- [x] `/skill-registry` 관리 커맨드

## Phase 5: 멀티 프로젝트 대시보드

> 여러 프로젝트를 통합 관리하는 대시보드

- [x] 프로젝트 상태 수집 스크립트
- [x] `/dashboard` 커맨드 생성
- [x] cc-chips 확장 (프로젝트 점수 표시)
- [x] 자동 스캔 훅 (SessionStart)
- [x] 프로젝트 간 보안 점수 비교

## 의존성

```
Phase 1 (팀 설정) ← 독립 실행 가능
Phase 2 (RBAC)    ← Phase 1 완료 후 (팀 설정 위에 역할 적용)
Phase 3 (감사 로그) ← Phase 1 완료 후 (팀 정보 로깅 필요)
Phase 4 (레지스트리) ← Phase 1 완료 후 (팀별 레지스트리 설정)
Phase 5 (대시보드)  ← Phase 3 완료 후 (로그 데이터 기반 점수 산출)
```

## 우선순위

| Phase | 영향도 | 난이도 | 권장 순서 |
|-------|--------|--------|-----------|
| 1. 팀 설정 | 높음 | 중간 | 1순위 |
| 2. RBAC | 높음 | 높음 | 2순위 |
| 3. 감사 로그 | 중간 | 중간 | 3순위 |
| 4. 레지스트리 | 중간 | 높음 | 4순위 |
| 5. 대시보드 | 낮음 | 중간 | 5순위 |
