#!/bin/bash
# DB Guard - PreToolUse Hook
# Blocks dangerous SQL patterns: DROP, TRUNCATE, DELETE without WHERE, ALTER DROP
#
# Hook trigger: PreToolUse, matcher: mcp__(supabase|supabase-db)__execute_sql, mcp__(supabase|supabase-db)__apply_migration
# Exit codes: 0 = allow, 2 = block

# Read tool call JSON from stdin
INPUT=$(cat)

QUERY=$(echo "$INPUT" | python3 -c "
import sys, json
data = json.load(sys.stdin)
ti = data.get('tool_input', {})
# execute_sql uses 'query', apply_migration uses 'sql' or 'statements'
print(ti.get('query', ti.get('sql', ti.get('statements', ''))))
" 2>/dev/null)

if [[ -z "$QUERY" ]]; then
    # No query found, allow (might be a different tool input format)
    exit 0
fi

# Python 기반 SQL 패턴 검사 (CWE-78 방지: grep 파이프라인 대신 Python 사용)
export _DB_GUARD_QUERY="$QUERY"
python3 << 'DB_GUARD_SCRIPT'
import os
import sys
import re

query = os.environ.get("_DB_GUARD_QUERY", "")
if not query:
    sys.exit(0)

query_upper = query.upper()
safe_preview = query[:200]

# Block DROP TABLE/DATABASE/SCHEMA
if re.search(r'\bDROP\s+(TABLE|DATABASE|SCHEMA)\b', query_upper):
    print("BLOCKED: DROP statement detected", file=sys.stderr)
    print(f"Query: {safe_preview}", file=sys.stderr)
    sys.exit(2)

# Block TRUNCATE — statement 형태만 (DDL). GRANT/REVOKE의 권한 키워드 TRUNCATE는 허용.
# DDL: 'TRUNCATE TABLE foo' / 'TRUNCATE foo' / 'TRUNCATE foo, bar'
# 권한: 'REVOKE INSERT, UPDATE, DELETE, TRUNCATE, ... ON foo FROM ...'
# 정규식: TRUNCATE 다음에 (TABLE|식별자) 형태의 DDL만 매칭. 콤마 또는 ON이 따라오면 권한 키워드.
_truncate_ddl = re.search(r'\bTRUNCATE\s+(TABLE\s+|ONLY\s+|[A-Z_][A-Z0-9_]*\s*[(,;]|[A-Z_][A-Z0-9_]*\s*$)', query_upper)
if _truncate_ddl:
    print("BLOCKED: TRUNCATE statement detected", file=sys.stderr)
    print(f"Query: {safe_preview}", file=sys.stderr)
    sys.exit(2)

# Block DELETE without WHERE
if re.search(r'\bDELETE\s+FROM\b', query_upper) and not re.search(r'\bWHERE\b', query_upper):
    print("BLOCKED: DELETE without WHERE clause", file=sys.stderr)
    print(f"Query: {safe_preview}", file=sys.stderr)
    sys.exit(2)

# Block ALTER TABLE ... DROP COLUMN (destructive schema change)
# DROP CONSTRAINT/INDEX는 허용 (중복 인덱스 제거 등)
if re.search(r'\bALTER\s+TABLE\b.*\bDROP\s+COLUMN\b', query_upper):
    print("BLOCKED: ALTER TABLE DROP COLUMN detected", file=sys.stderr)
    print(f"Query: {safe_preview}", file=sys.stderr)
    sys.exit(2)

# Safe query - allow
sys.exit(0)
DB_GUARD_SCRIPT
