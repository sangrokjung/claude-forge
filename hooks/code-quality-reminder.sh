#!/bin/bash
# code-quality-reminder.sh - PostToolUse Hook (Edit/Write)
# 코드 수정 후 품질 체크 리마인더를 stderr로 출력
# Claude에게 셀프 체크를 유도하는 간결한 메시지
# exit 0 필수 (세션 방해 금지)

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_name', ''))
except:
    pass
" 2>/dev/null)

if [[ "$TOOL_NAME" != "Edit" && "$TOOL_NAME" != "Write" ]]; then
    exit 0
fi

FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    inp = d.get('tool_input', {})
    print(inp.get('file_path', ''))
except:
    pass
" 2>/dev/null)

# 코드 파일만 대상 (md, txt, json, yaml 등 제외)
case "$FILE_PATH" in
    *.ts|*.tsx|*.js|*.jsx|*.py|*.go|*.rs|*.java|*.rb|*.php|*.swift|*.kt|*.sh|*.cs|*.razor|*.cshtml)
        ;;
    *)
        exit 0
        ;;
esac

echo "[code-quality] 수정된 파일의 에러 핸들링, 불변성 패턴, 입력 검증을 확인하세요." >&2

exit 0
