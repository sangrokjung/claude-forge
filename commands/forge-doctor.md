---
allowed-tools: Bash(bash:*), Bash(jq:*), Bash(cat:*), Bash(ls:*), Read
description: Claude Forge 설치 무결성 점검 (의존성, symlink, MCP, alias, 백업)
argument-hint: [--quiet] [--json]
---

# /forge-doctor — Claude Forge 헬스 체크

`scripts/forge-doctor.sh`를 실행해 현재 설치 상태를 점검한다.

## 검사 항목

| # | 영역 | 무엇을 보는가 |
|---|------|--------------|
| 1 | Dependencies | node, jq, git, claude CLI |
| 2 | Install state | `~/.claude` 디렉토리, `.forge-meta.json` 유효성 |
| 3 | Forge items | 9개 핵심 항목(agents/rules/commands/scripts/skills/hooks/cc-chips/cc-chips-custom/settings.json)의 symlink 무결성 |
| 4 | Repository | 저장소 경로 존재, git 브랜치/커밋, plugin.json 버전 일치 |
| 5 | MCP servers | `claude mcp list` 등록 개수 |
| 6 | Shell aliases | `cc`/`ccr` alias 설치 여부 |
| 7 | Backups | `~/.claude.backup.*` 개수 |

## 실행 절차

1. `~/.claude/.forge-meta.json`에서 `repo_path`를 읽는다
2. `${repo_path}/scripts/forge-doctor.sh $ARGUMENTS` 실행
3. exit code로 결과 판정:
   - `0` — 모두 정상
   - `1` — 경고 있음 (사용엔 지장 없음)
   - `2` — 치명적 오류 (재설치 필요)

## 인자

| 인자 | 설명 |
|------|------|
| (없음) | 전체 리포트를 사람이 읽기 좋게 출력 |
| `--quiet` | 결과 요약만 출력 |
| `--json` | machine-readable JSON 출력 (CI/스크립팅용) |

## 실행 예시

```bash
# 메타에서 repo 경로 읽기
REPO=$(jq -r '.repo_path' "$HOME/.claude/.forge-meta.json")

# 점검 실행
bash "$REPO/scripts/forge-doctor.sh" $ARGUMENTS
```

## 결과 해석

- **모두 ✓** → 사용 가능, 별도 조치 불필요
- **! warning** → 사용엔 문제없음. 메시지 따라 선택적으로 조치
- **✗ error** → `cd $REPO_PATH && ./install.sh` 재실행 권장. 그래도 안 되면 `./uninstall.sh && ./install.sh`

## 참고

- 업데이트가 필요하면 `/forge-update`
- 완전 제거가 필요하면 저장소 루트의 `./uninstall.sh`
- 설치 가이드: [docs/FIRST-STEPS.md](../docs/FIRST-STEPS.md)
