---
name: prompts-chat
description: Use when searching, installing, or improving AI skills and prompts via prompts.chat or skills.sh. Triggers on skill search, prompt lookup, install skill, improve prompt, prompts.chat.
---

# Prompts & Skills Lookup

prompts.chat MCP 서버를 통해 AI 스킬과 프롬프트를 검색, 조회, 설치, 개선하는 통합 스킬.

## When to Activate

- 스킬 검색/설치 요청 ("코드 리뷰 스킬 찾아줘", "스킬 설치해줘")
- 프롬프트 검색/조회 요청 ("글쓰기 프롬프트 찾아줘")
- 프롬프트 개선 요청 ("이 프롬프트 더 좋게 만들어줘")
- prompts.chat, skills.sh 언급 시

## MCP Tools (prompts.chat)

> prompts.chat MCP 서버가 설정되지 않은 경우 아래 CLI 방식을 사용한다.

### Skills 모드

| Tool | 용도 | 주요 파라미터 |
|------|------|-------------|
| `search_skills` | 키워드로 스킬 검색 | query, limit (max 50), category, tag |
| `get_skill` | ID로 스킬 조회 (파일 포함) | id |

### Prompts 모드

| Tool | 용도 | 주요 파라미터 |
|------|------|-------------|
| `search_prompts` | 키워드로 프롬프트 검색 | query, limit, type (TEXT/STRUCTURED/IMAGE/VIDEO/AUDIO), category, tag |
| `get_prompt` | ID로 프롬프트 조회 | id |
| `improve_prompt` | AI로 프롬프트 개선 | prompt, outputType, outputFormat |

## Skills 워크플로우

### 검색

`search_skills`로 검색 후 결과 표시:
- Title, Description
- Author
- 파일 목록 (SKILL.md, references, scripts)
- Category, Tags
- Link

### 설치

1. `get_skill`로 전체 파일 조회
2. `~/.claude/skills/{slug}/` 디렉토리 생성
3. 각 파일을 해당 위치에 저장
4. 설치 성공 확인

### CLI 방식 (MCP 미설정 시)

```bash
npx skills find [query]            # 키워드 검색
npx skills add <owner/repo@skill>  # GitHub에서 설치
npx skills add <package> -g -y     # 글로벌 설치
npx skills check                   # 업데이트 확인
npx skills update                  # 전체 업데이트
npx skills init <name>             # 새 스킬 생성
```

웹 브라우징: https://skills.sh/

## Prompts 워크플로우

### 검색

`search_prompts`로 검색 후 결과 표시:
- Title, Description
- Author
- Category, Tags
- Link

### 조회

`get_prompt`로 프롬프트 내용 조회.
변수가 포함된 경우 (`${variable}` 또는 `${variable:default}`):
- 기본값 없는 변수: 사용자에게 입력 요청
- 기본값 있는 변수: 선택적

### 개선

`improve_prompt`로 프롬프트 개선:
- outputType: text, image, video, sound
- outputFormat: text, structured_json, structured_yaml
- 개선 결과와 변경 사항 설명 제공

## Guidelines

- 사용자가 직접 만들기 전에 항상 먼저 검색
- 검색 결과를 읽기 쉬운 형식으로 표시
- 스킬 설치 시 성공 여부 확인
- 프롬프트 개선 시 변경 사항 설명
