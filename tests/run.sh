#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fails=0
for t in "$REPO_ROOT"/tests/test_*.sh; do
  echo "─── $(basename "$t") ───"
  if bash "$t"; then
    echo "  OK"
  else
    fails=$((fails + 1))
  fi
done
echo ""
echo "$fails test file(s) failed"
exit "$fails"
