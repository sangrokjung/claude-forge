#!/bin/bash
# Continuous Learning v2 - Observer Agent Launcher
#
# 수정 (2026-03-30): shlock 기반 싱글턴 + pgrep 이중 확인
# 원인: PID 파일 레이스 컨디션으로 64+ 프로세스 누적 버그
#
# Usage:
#   start-observer.sh        # Start observer in background
#   start-observer.sh stop   # Stop running observer
#   start-observer.sh status # Check if observer is running

set -e

CONFIG_DIR="${HOME}/.claude/homunculus"
PID_FILE="${CONFIG_DIR}/.observer.pid"
LOCK_FILE="${CONFIG_DIR}/.observer-start.lock"
LOG_FILE="${CONFIG_DIR}/observer.log"
OBSERVATIONS_FILE="${CONFIG_DIR}/observations.jsonl"

mkdir -p "$CONFIG_DIR"

case "${1:-start}" in
  stop)
    # 모든 observer 프로세스 정리 (PID 파일 + pgrep)
    if [ -f "$PID_FILE" ]; then
      pid=$(cat "$PID_FILE")
      if kill -0 "$pid" 2>/dev/null; then
        echo "Stopping observer (PID: $pid)..."
        kill "$pid"
      fi
      rm -f "$PID_FILE"
    fi
    # PID 파일에 없는 고아 프로세스도 정리
    pgrep -f 'start-observer.sh' 2>/dev/null | grep -v "$$" | while read orphan_pid; do
      kill "$orphan_pid" 2>/dev/null && echo "Killed orphan observer: $orphan_pid"
    done
    rm -f "$LOCK_FILE"
    echo "Observer stopped."
    exit 0
    ;;

  status)
    if [ -f "$PID_FILE" ]; then
      pid=$(cat "$PID_FILE")
      if kill -0 "$pid" 2>/dev/null; then
        echo "Observer is running (PID: $pid)"
        echo "Log: $LOG_FILE"
        echo "Observations: $(wc -l < "$OBSERVATIONS_FILE" 2>/dev/null || echo 0) lines"
        # 고아 프로세스 경고
        orphan_count=$(pgrep -f 'start-observer.sh' 2>/dev/null | grep -v "$pid" | grep -v "$$" | wc -l | tr -d ' ')
        if [ "$orphan_count" -gt 0 ]; then
          echo "WARNING: $orphan_count orphan observer processes detected. Run 'stop' to clean up."
        fi
        exit 0
      else
        echo "Observer not running (stale PID file)"
        rm -f "$PID_FILE"
        exit 1
      fi
    else
      echo "Observer not running"
      exit 1
    fi
    ;;

  start)
    # shlock 기반 싱글턴 보장 (macOS)
    if ! /usr/bin/shlock -f "$LOCK_FILE" -p $$ 2>/dev/null; then
      echo "Another start-observer.sh is already running (lock held)"
      exit 0
    fi
    trap 'rm -f "$LOCK_FILE"' EXIT

    # PID 파일 기반 확인
    if [ -f "$PID_FILE" ]; then
      pid=$(cat "$PID_FILE")
      if kill -0 "$pid" 2>/dev/null; then
        echo "Observer already running (PID: $pid)"
        exit 0
      fi
      rm -f "$PID_FILE"
    fi

    # pgrep 이중 확인: 이미 observer 서브셸이 실행 중인지
    existing=$(pgrep -f 'sleep 300' 2>/dev/null | head -1)
    if [ -n "$existing" ]; then
      # sleep 300이 observer의 것인지 확인
      parent_cmd=$(ps -o command= -p "$(ps -o ppid= -p "$existing" 2>/dev/null | tr -d ' ')" 2>/dev/null)
      if echo "$parent_cmd" | grep -q 'start-observer'; then
        echo "Observer subshell already running (sleep PID: $existing)"
        exit 0
      fi
    fi

    echo "Starting observer agent..."

    # The observer loop
    (
      trap 'rm -f "$PID_FILE"; exit 0' TERM INT

      analyze_observations() {
        # Only analyze if we have enough observations
        obs_count=$(wc -l < "$OBSERVATIONS_FILE" 2>/dev/null || echo 0)
        if [ "$obs_count" -lt 10 ]; then
          return
        fi

        echo "[$(date)] Analyzing $obs_count observations..." >> "$LOG_FILE"

        # Use Claude Code with Haiku to analyze observations
        if command -v claude &> /dev/null; then
          claude --model haiku --max-turns 3 --print \
            "Read $OBSERVATIONS_FILE and identify patterns. If you find 3+ occurrences of the same pattern, create an instinct file in $CONFIG_DIR/instincts/personal/ following the format in the observer agent spec. Be conservative - only create instincts for clear patterns." \
            >> "$LOG_FILE" 2>&1 || true
        fi

        # Archive processed observations
        if [ -f "$OBSERVATIONS_FILE" ]; then
          archive_dir="${CONFIG_DIR}/observations.archive"
          mkdir -p "$archive_dir"
          mv "$OBSERVATIONS_FILE" "$archive_dir/processed-$(date +%Y%m%d-%H%M%S).jsonl"
          touch "$OBSERVATIONS_FILE"
        fi
      }

      # Handle SIGUSR1 for on-demand analysis
      trap 'analyze_observations' USR1

      echo "$$" > "$PID_FILE"
      echo "[$(date)] Observer started (PID: $$)" >> "$LOG_FILE"

      while true; do
        # Check every 5 minutes
        sleep 300

        analyze_observations
      done
    ) &

    disown

    # Wait a moment for PID file
    sleep 1

    if [ -f "$PID_FILE" ]; then
      echo "Observer started (PID: $(cat "$PID_FILE"))"
      echo "Log: $LOG_FILE"
    else
      echo "Failed to start observer"
      exit 1
    fi
    ;;

  *)
    echo "Usage: $0 {start|stop|status}"
    exit 1
    ;;
esac
