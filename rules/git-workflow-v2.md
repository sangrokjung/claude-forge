---
name: git-workflow-v2
load: conditional
audience: team
sensitivity: L1
category: meta
critical: false
description: Git 커밋/PR/브랜치 워크플로우 표준
paths:
  - ".gitignore"
  - ".github/**"
---
# Git Workflow

## Commit Message Format

```
<type>: <description>
```

Types: feat, fix, refactor, docs, test, chore, perf, ci. Attribution disabled via ~/.claude/settings.json.

## PR Workflow

1. `git diff [base-branch]...HEAD`로 전체 변경 분석 (최신 커밋만 보지 말 것)
2. PR 요약 + 테스트 계획 포함. `-u` 플래그로 push

## Feature Implementation

Plan(planner) → TDD(tdd-guide) → Review(code-reviewer) → Commit

## GitHub Org

`qjc-office` org. 새 리포: `gh repo create qjc-office/<name> --private --source=. --push`

## 방향 전환

3회 패치 실패 → `git reset` 후 범위 축소 재시작. 패치의 패치는 기술 부채.
