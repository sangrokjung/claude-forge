---
name: dualsub
description: |
  영상·오디오·유튜브 URL에서 이중자막(영문+한글)을 생성한다.
  Groq whisper-large-v3로 전사하고 Groq LLM으로 한글 번역해
  EN/KO/이중 VTT·SRT·TXT를 출력한다.
  트리거: "자막 만들어", "이중자막", "영한 자막", "transcribe", "subtitle", "dualsub".
aliases:
  - dualsub
  - 이중자막
  - 영한자막
  - 자막생성
---

# dualsub — 이중자막(영문+한글) 생성 스킬

로컬 영상/오디오 파일 또는 유튜브 URL을 받아 **영문+한글 이중자막**을 만든다.
전사(Whisper)와 번역(LLM)을 모두 Groq API 하나로 처리하며, 청크별 증분 저장으로 중단돼도 재개된다.

## 언제 쓰나
- 유튜브 자동자막이 없거나(ASR 실패) 품질이 나쁠 때 직접 전사.
- 영어 영상에 한글 자막을 붙이고 싶을 때(강의·인터뷰·데모).
- `.vtt`/`.srt`(플레이어용) + 타임스탬프 `.txt`(분석/CCG용)가 동시에 필요할 때.

## 요구사항
- `ffmpeg`, `yt-dlp`(URL 입력 시), `python3`.
- **Groq API 키**: `GROQ_API_KEY` 환경변수 또는 `~/.config/watch/.env`의 `GROQ_API_KEY=` 라인.
  - 키 발급/확인: https://console.groq.com/keys · 유효성: `curl -s https://api.groq.com/openai/v1/models -H "Authorization: Bearer $KEY"` → HTTP 200.

## 실행

```bash
python3 "${SKILL_DIR}/scripts/dualsub.py" <입력> [옵션]
```

- `<입력>`: 로컬 영상/오디오 경로 **또는** 유튜브 URL.
- 옵션:
  - `--outdir DIR` 출력 폴더(기본 현재 디렉토리)
  - `--name NAME` 출력 파일 접두사(기본: 파일명/`video`)
  - `--to ko` 번역 대상 언어(기본 한글). `--no-translate` 면 영문만.
  - `--model whisper-large-v3` 전사 모델(빠른: `whisper-large-v3-turbo`)
  - `--llm openai/gpt-oss-120b` 번역 LLM
  - `--chunk-sec 3000` 청크 길이(초). 청크당 <24MB(Groq 업로드 한도) 유지용.

예:
```bash
# 로컬 영상 → 이중자막
python3 "${SKILL_DIR}/scripts/dualsub.py" "./lecture.mp4" --outdir ./subs

# 유튜브 → 이중자막(빠른 모델)
python3 "${SKILL_DIR}/scripts/dualsub.py" "https://youtu.be/XXXX" --model whisper-large-v3-turbo

# 전사만(번역 생략)
python3 "${SKILL_DIR}/scripts/dualsub.py" "./clip.mp4" --no-translate
```

## 산출물
`<outdir>/<name>.*`
- `.en.vtt` 영문 자막 · `.ko.vtt` 한글 자막
- `.dual.vtt` / `.dual.srt` **이중자막**(한 큐에 영문 위·한글 아래)
- `.en.txt` 타임스탬프 트랜스크립트(분석·CCG 입력용)

증분 캐시: `<outdir>/.dualsub/<name>/`(청크 오디오·청크별 전사 JSON·번역 JSON). 재실행 시 완료분은 건너뛴다.

## Groq 무료 티어 주의
- whisper는 **시간당 오디오 7,200초(2시간)** 한도. 긴 영상은 rate limit 리셋을 기다리며 자동 재개(청크당 최대 40회 `retry-after` 준수) → 10시간 영상은 약 5.5시간.
- 빠르게 하려면 Groq Dev 티어 업그레이드 또는 짧은 구간만 처리.

## 워크플로 팁
- 전사 결과 `.en.txt`는 `/ccg` 영상 분석의 입력으로 바로 쓸 수 있다(자막 없는 영상의 CCG 재분석).
- 플레이어(IINA/VLC/YouTube)에는 `.dual.srt` 또는 `.dual.vtt`를 얹으면 영한 동시 표시.

## 대안 스킬명(참고)
`dualsub`(채택) · `jamaker`(자막+maker) · `bisub` · `subtwin`.
