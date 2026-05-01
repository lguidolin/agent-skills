#!/usr/bin/env bash
set -euo pipefail

LOCK_FILE=".claude-profile.lock"

usage() {
  echo "Usage: $(basename "$0") {acquire <profile_name>|release|check|current}" >&2
  exit 1
}

is_pid_alive() {
  kill -0 "$1" 2>/dev/null
}

read_lock() {
  if [[ ! -f "$LOCK_FILE" ]]; then
    return 1
  fi
  local pid profile
  pid=$(sed -n '1p' "$LOCK_FILE")
  profile=$(sed -n '2p' "$LOCK_FILE")
  if [[ -z "$pid" || -z "$profile" ]]; then
    rm -f "$LOCK_FILE"
    return 1
  fi
  LOCK_PID="$pid"
  LOCK_PROFILE="$profile"
  return 0
}

cmd_acquire() {
  local profile_name="${1:-}"
  if [[ -z "$profile_name" ]]; then
    echo "Error: profile name required" >&2
    usage
  fi

  if read_lock; then
    if is_pid_alive "$LOCK_PID"; then
      echo "Error: profile '$LOCK_PROFILE' is locked by PID $LOCK_PID" >&2
      exit 1
    else
      # Stale lock — clean up
      rm -f "$LOCK_FILE"
    fi
  fi

  printf '%s\n%s\n' "$PPID" "$profile_name" > "$LOCK_FILE"
}

cmd_release() {
  rm -f "$LOCK_FILE"
}

cmd_check() {
  if read_lock; then
    if is_pid_alive "$LOCK_PID"; then
      echo "$LOCK_PROFILE"
    else
      rm -f "$LOCK_FILE"
      echo "none"
    fi
  else
    echo "none"
  fi
}

case "${1:-}" in
  acquire) cmd_acquire "${2:-}" ;;
  release) cmd_release ;;
  check|current) cmd_check ;;
  *) usage ;;
esac
