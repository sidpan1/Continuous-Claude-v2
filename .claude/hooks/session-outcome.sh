#!/bin/bash
set -e

# Check workspace first, then global
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GLOBAL_DIR="$HOME/.claude/hooks"

if [ -f "$SCRIPT_DIR/dist/session-outcome.mjs" ]; then
  cd "$SCRIPT_DIR"
  cat | node dist/session-outcome.mjs
elif [ -f "$GLOBAL_DIR/dist/session-outcome.mjs" ]; then
  cd "$GLOBAL_DIR"
  cat | node dist/session-outcome.mjs
else
  echo '{"result":"continue"}'
fi
