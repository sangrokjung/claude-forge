# Claude Forge

## 개요
Claude Code를 풀 개발 환경으로 변환하는 도구 프로젝트. 에이전트, 커맨드, 스킬, 훅, 규칙을 심링크로 `~/.claude/`에 연결하여 동작한다.

## 기술 스택
- Shell (Bash) - 설치 스크립트, 훅
- PowerShell - Windows 설치 스크립트
- Markdown - 에이전트/커맨드/스킬/규칙 정의
- JSON - 설정 파일 (settings.json, mcp-servers.json)

## 빌드 & 테스트
- 설치: `./install.sh` (macOS/Linux) 또는 `.\install.ps1` (Windows)
- 테스트: 수동 검증 (CLI 도구 프로젝트)
- 린트: ShellCheck (훅 스크립트)

## 디렉토리 구조
```
agents/          11개 에이전트 정의 (.md)
commands/        36개 슬래시 커맨드 (.md + SKILL 디렉토리)
skills/          15개 멀티스텝 스킬 워크플로우
hooks/           14개 이벤트 기반 셸 스크립트
rules/           8개 자동 로드 규칙 파일
reference/       참조 문서
knowledge/       지식 베이스
scripts/         유틸리티 스크립트
cc-chips/        상태 바 서브모듈
cc-chips-custom/ 커스텀 상태 바 오버레이
setup/           설치 가이드 + 템플릿
docs/            스크린샷, 다이어그램
```

## 핵심 워크플로우
1. 기능 개발: `/plan` -> `/tdd` -> `/code-review` -> `/handoff-verify` -> `/commit-push-pr`
2. 버그 수정: `/explore` -> `/tdd` -> `/verify-loop` -> `/quick-commit`
3. 보안 감사: `/security-review` -> `/stride-analysis-patterns` -> `/security-compliance`
4. 팀 협업: `/orchestrate` -> Agent Teams -> `/commit-push-pr`

## 코딩 컨벤션
- 코드 주석: 영어
- 커맨드/스킬 문서: 한국어 + 영어 혼용
- 훅 스크립트: POSIX 호환 셸 스크립트
- 새 커맨드 추가 시 commands/ 디렉토리에 .md 파일 생성
- 새 에이전트 추가 시 agents/ 디렉토리에 .md 파일 생성
