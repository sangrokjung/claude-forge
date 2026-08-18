#!/bin/bash
# auto-verify-fix.sh - PostToolUse Hook (Edit/Write)
# Lightweight type/syntax verification after a code file edit → surface fixable errors.
# exit 0 required (PostToolUse cannot block).

INPUT=$(cat)

echo "$INPUT" | python3 -c "
import sys, json, os, subprocess, hashlib, re

try:
    d = json.load(sys.stdin)
except:
    sys.exit(0)

tool = d.get('tool_name', '')
if tool not in ('Edit', 'Write'):
    sys.exit(0)

inp = d.get('tool_input', {})
file_path = inp.get('file_path', '')
if not file_path or not os.path.isfile(file_path):
    sys.exit(0)

# Extension filter: only .ts, .tsx, .js, .jsx, .py
ext = os.path.splitext(file_path)[1].lower()
if ext not in ('.ts', '.tsx', '.js', '.jsx', '.py'):
    sys.exit(0)

# Walk up to find the project root (tsconfig.json or package.json)
search_dir = os.path.dirname(os.path.abspath(file_path))
project_root = search_dir
for _ in range(10):
    if os.path.exists(os.path.join(project_root, 'tsconfig.json')) or \
       os.path.exists(os.path.join(project_root, 'package.json')):
        break
    parent = os.path.dirname(project_root)
    if parent == project_root:
        project_root = search_dir
        break
    project_root = parent

# Detect project type + run the matching verification command
is_python = (ext == '.py')
has_tsconfig = os.path.exists(os.path.join(project_root, 'tsconfig.json'))

if is_python:
    try:
        r = subprocess.run(
            ['python3', '-m', 'py_compile', file_path],
            capture_output=True, text=True, timeout=8
        )
    except:
        sys.exit(0)
elif has_tsconfig:
    try:
        r = subprocess.run(
            ['bash', '-c', 'npx tsc --noEmit --pretty \"' + file_path + '\" 2>&1 | head -30'],
            capture_output=True, text=True, timeout=8,
            cwd=project_root
        )
    except:
        sys.exit(0)
else:
    # JS without tsconfig, or no recognized project type — no-op
    sys.exit(0)

output = (r.stdout + r.stderr).strip()
if r.returncode == 0 or not output:
    sys.exit(0)

# --- repeat-suppression marker ---
sid = os.environ.get('SESSION_ID', 'unknown')
path_hash = hashlib.md5(file_path.encode()).hexdigest()
marker = f'/tmp/auto-verify-fix-{sid}-{path_hash}'

count = 0
if os.path.exists(marker):
    try:
        count = int(open(marker).read().strip())
    except:
        count = 0
count += 1
try:
    open(marker, 'w').write(str(count))
except:
    pass

basename = os.path.basename(file_path)
if count > 3:
    # Same error repeating: go quiet, stop nagging.
    sys.exit(0)

# --- error classification ---
FIXABLE = [
    r'Cannot find name',
    r'is declared but',
    r'React Hook.*cannot be called',
    r'Module.*not found',
    r'Cannot find module',
    r'has no exported member',
]

messages = []
seen = set()
for line in output.split('\n')[:30]:
    line = line.strip()
    if not line or line in seen:
        continue
    has_err = 'error' in line.lower() or 'SyntaxError' in line
    if not has_err:
        continue
    seen.add(line)
    if any(re.search(p, line) for p in FIXABLE):
        messages.append(f'[auto-fix] {line} -> fix this file.')
    else:
        messages.append(f'[verify-warn] {line} -> needs manual check.')

# Nothing meaningful found: go quiet.
if not messages:
    sys.exit(0)

# PostToolUse: plain stdout/stderr is NOT injected into Claude's context.
# Must use hookSpecificOutput.additionalContext (JSON on stdout) instead.
ctx = (
    f'[verify hook — auto-verify-fix] Verification errors found in the file you just edited ({basename}):\n'
    + '\n'.join(messages[:10])
    + '\nNon-blocking signal — review and fix the errors above.'
)
out = {'hookSpecificOutput': {'hookEventName': 'PostToolUse', 'additionalContext': ctx}}
print(json.dumps(out, ensure_ascii=False))
" 2>/dev/null

exit 0
