#!/usr/bin/env bash
# Pre-commit hook installer.
# Installs a secret-scanning + safety guard into .git/hooks/pre-commit.
# Default: install into the git repo containing $PWD.
# --all <base-dir>: walk every git repo found under <base-dir> (maxdepth 3).

set -euo pipefail

HOOK_CONTENT='#!/bin/bash
# Pre-commit Security Guard v10 (auto-installed by install-precommit.sh)
# v10 (2026-08-18): Pin the interpreter and grep to system binaries - shebang
#                   /bin/bash (the homebrew bash 5.3.15 resolved via PATH
#                   deadlocks on herestrings under 64KB), and GREP=/usr/bin/grep
#                   (the ugrep resolved via PATH, which homebrew installs under
#                   the grep name, hangs indefinitely on multibyte bodies with
#                   {40,} range repeats - the same input completes in 0.01s
#                   under /usr/bin/grep). Same class of issue as the v7 note.
# v9 (2026-08-18): Exclude placeholder false positives in prefix key patterns
#                  (sk-/ghp_/sbp_/xoxb-/AKIA) - only tokens whose body is a
#                  single repeated character or contains EXAMPLE pass through.
# v8 (2026-08-14): Fix a self-match where the PuTTY pattern blocked this
#                  guard from committing its own source (last char as a
#                  character class).
# v7 (2026-08-14): Fix `grep -q` piping swallowing matches via SIGPIPE
#                  (switch to herestrings) + remove the file-level whitelist.
# v6 (2026-08-14): Exclude ssh public-key false positives (algorithm + AAAA
#                  body only) + explicitly block private keys (PEM/PuTTY).
# v5 (2026-07-21): Fix base64 catch-all false positives - exclude pure hex
#                  (git SHA/hash) and slash-containing strings (URL/path) +
#                  add an explicit sbp_ (Supabase PAT) pattern.
set -euo pipefail

# Pin the regex engine (v10): the "grep" resolved via PATH may be ugrep or
# another alternative implementation, so prefer the system grep. Present on
# both macOS (/usr/bin/grep=BSD) and Linux (/usr/bin/grep=GNU). Fall back to
# PATH if missing.
GREP=/usr/bin/grep
[ -x "$GREP" ] || GREP=$(command -v grep)

# 1. Secret scan - block commits containing API keys
PATTERNS=(
  "[A-Za-z0-9+/]{40,}"          # Long base64-like strings
  "sk-[a-zA-Z0-9]{20,}"          # OpenAI keys
  "xoxb-[0-9]+-[a-zA-Z0-9]+"    # Slack tokens
  "ghp_[a-zA-Z0-9]{36}"          # GitHub tokens
  "AKIA[0-9A-Z]{16}"             # AWS access keys
  "eyJ[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+" # JWT tokens
  "sbp_[a-zA-Z0-9]{20,}"         # Supabase PAT (hex tail - explicit because the base64 filter misses it)
  "BEGIN [A-Z ]*PRIVATE KEY"     # PEM private key (added 2026-08-14 - while adding the public-key exception, also explicitly block the real risk)
  "PuTTY-User-Key-Fil[e]"        # PuTTY private key - keep the last char as a character
                                 # class so this file does not match its own pattern (the
                                 # guard was blocking its own source file)
)

STAGED=$(git diff --cached --name-only --diff-filter=ACM)
if [ -z "$STAGED" ]; then exit 0; fi

for file in $STAGED; do
  # Skip binary files and known safe patterns
  if file "$file" | "$GREP" -q "binary" 2>/dev/null; then continue; fi
  if [[ "$file" == *.lock ]] || [[ "$file" == *.min.js ]]; then continue; fi

  content=$(git show ":$file" 2>/dev/null || true)
  if [ -z "$content" ]; then continue; fi

  for pattern in "${PATTERNS[@]}"; do
    # Never `echo "$X" | grep -q` (found 2026-08-14). `grep -q` exits on the
    #    first match and closes the pipe, so the upstream echo dies with
    #    SIGPIPE (141), and `set -o pipefail` turns that into a pipeline
    #    failure - **silently swallowing a real match as a non-match**. A
    #    real secret then passes through unnoticed (reproduced: a 3KB file
    #    with a ghp_ token passed with rc=141). A herestring reads from a
    #    temp file, not a pipe, so this race does not apply.
    if "$GREP" -qE "$pattern" <<< "$content" 2>/dev/null; then
      # File-level whitelist removed (2026-08-14). A `"${VAR}"` token
      # anywhere in a file used to bypass **every** pattern check for that
      # file, and under ugrep the pattern itself was a syntax error that
      # never even ran (dead code + risk). False positives are now handled
      # by the narrow filters below instead.
      # base64 catch-all false-positive guard: pure lowercase hex (git SHA-1
      # 40 chars / SHA-256 content hash 64 chars) and slash-containing
      # strings (URL/path) are not secrets and are excluded.
      # An ssh **public** key is not a secret (that is the point of a public
      # key - private keys are caught by the PATTERNS above). But the
      # catch-all matched key bodies as 40+ char blocks, and whether it
      # passed depended on whether a "/" happened to appear in the body - an
      # arbitrary judgment that let the same kind of key pass in one file
      # and block in another. Mask only tokens that start with an algorithm
      # name + AAAA (the fixed prefix of an ssh public-key body).
      # 2026-08-14: a CI worker ssh public key was blocked by this false
      # positive before the exclusion below was added.
      if [ "$pattern" = "[A-Za-z0-9+/]{40,}" ]; then
        scan=$(sed -E '\''s#(ssh-(rsa|dss|ed25519)(-sk)?|ecdsa-sha2-nistp[0-9]+)[[:space:]]+AAAA[A-Za-z0-9+/=]+#\1 SSH_PUBKEY#g'\'' <<< "$content")
        # Collect candidates without grep -q, to dodge the SIGPIPE trap above
        # and to be able to distinguish an empty result from no result.
        cand=$("$GREP" -oE '\''[A-Za-z0-9+/]{40,}'\'' <<< "$scan" || true)
        cand=$("$GREP" -vE '\''^[0-9a-f]+$'\'' <<< "$cand" || true)
        cand=$("$GREP" -v '\''/'\'' <<< "$cand" || true)
        if [ -z "$cand" ]; then continue; fi
      fi
      # Exclude placeholder false positives in prefix key patterns (v9,
      # 2026-08-18). Docs and CI configs legitimately contain placeholders
      # like `ghp_xxxx...x` or `AKIA...EXAMPLE`. Real incident: the
      # .github/workflows/validate.yml file in this very repo defines
      # `ghp_xxxx...x` (36 x characters) as the whitelist for its own secret
      # scanner, and this guard read that string as a real token, blocking
      # every commit that touched the file (risking --no-verify becoming
      # habitual, which defeats the guard). A real key is random, so the
      # odds of its body being a single repeated character or containing
      # EXAMPLE are effectively zero - only those two shapes are excluded.
      # Length and charset requirements, and detection sensitivity, are
      # unchanged.
      # Why the pattern is re-matched with a trailing [A-Za-z0-9_-]*: grep
      # -oE only extracts as many characters as the pattern itself, so
      # AKIA[0-9A-Z]{16} would truncate AKIAIOSFODNN7EXAMPLE right before
      # "EXAMPLE".
      case "$pattern" in
        sk-*|ghp_*|sbp_*|xoxb-*|AKIA*)
          real=""
          while IFS= read -r tok; do
            if [ -z "$tok" ]; then continue; fi
            case "$tok" in *EXAMPLE*|*example*) continue ;; esac
            body=$(sed -E '\''s/^(sk-|ghp_|sbp_|xoxb-|AKIA)//'\'' <<< "$tok")
            first=${body:0:1}
            if [ -n "$first" ] && [ -z "$(tr -d "$first" <<< "$body")" ]; then continue; fi
            real="$tok"
            break
          done <<< "$("$GREP" -oE "${pattern}[A-Za-z0-9_-]*" <<< "$content" || true)"
          if [ -z "$real" ]; then continue; fi
          ;;
      esac
      echo "PRE-COMMIT BLOCKED: Potential secret in $file (pattern: $pattern)"
      echo "Use git add -p to review, or git commit --no-verify to bypass"
      exit 1
    fi
  done
done

# 2. Block .env files
for file in $STAGED; do
  if [[ "$file" == .env* ]] && [[ "$file" != .env.example ]] && [[ "$file" != .env.template ]]; then
    echo "PRE-COMMIT BLOCKED: .env file should not be committed: $file"
    exit 1
  fi
done

# 3. Block large files (10MB+)
for file in $STAGED; do
  if [ -f "$file" ]; then
    size=$(wc -c < "$file" 2>/dev/null || echo 0)
    if [ "$size" -gt 10485760 ]; then
      echo "PRE-COMMIT BLOCKED: File too large ($(( size / 1048576 ))MB): $file"
      exit 1
    fi
  fi
done

exit 0

'

install_hook() {
  local gitdir="$1"
  local REPO_DIR HOOK_PATH
  REPO_DIR=$(dirname "$gitdir")
  HOOK_PATH="$gitdir/hooks/pre-commit"

  # Skip if hook already exists and has our CURRENT-version signature.
  # If you change the hook body, bump this string too - otherwise every
  # existing repo gets SKIPped and the fix never propagates (confirmed
  # when v6 landed, 2026-08-14).
  if [ -f "$HOOK_PATH" ] && grep -q "Pre-commit Security Guard v10" "$HOOK_PATH" 2>/dev/null; then
    echo "  [SKIP] $REPO_DIR (already installed v10)"
    SKIPPED=$((SKIPPED + 1))
    return
  fi

  # Backup existing hook if present
  if [ -f "$HOOK_PATH" ]; then
    cp "$HOOK_PATH" "${HOOK_PATH}.bak"
    echo "  [BACKUP] Existing hook backed up to ${HOOK_PATH}.bak"
  fi

  # Install
  echo "$HOOK_CONTENT" > "$HOOK_PATH"
  chmod +x "$HOOK_PATH"
  echo "  [INSTALLED] $REPO_DIR"
  INSTALLED=$((INSTALLED + 1))
}

INSTALLED=0
SKIPPED=0

if [ "${1:-}" = "--all" ]; then
  BASE_DIR="${2:-$HOME}"
  [ -d "$BASE_DIR" ] || { echo "error: --all target not found: $BASE_DIR" >&2; exit 1; }
  # Process substitution (not `find | while`) so INSTALLED/SKIPPED updates
  # made inside the loop survive outside it — a pipe would run the loop body
  # in a subshell and silently discard the counters.
  while IFS= read -r gitdir; do
    install_hook "$gitdir"
  done < <(find "$BASE_DIR" -maxdepth 3 -name ".git" -type d)
else
  GIT_DIR=$(git rev-parse --git-dir 2>/dev/null) || {
    echo "error: not inside a git repository (use --all <base-dir> to scan a tree)" >&2
    exit 1
  }
  # git rev-parse --git-dir can print a path relative to $PWD (e.g. ".git");
  # normalize to absolute so install_hook's dirname/path-join stay correct
  # regardless of the caller's working directory.
  case "$GIT_DIR" in
    /*) : ;;
    *) GIT_DIR="$(pwd)/$GIT_DIR" ;;
  esac
  install_hook "$GIT_DIR"
fi

echo ""
echo "Done. Installed: $INSTALLED, Skipped: $SKIPPED"
