#!/bin/bash
set -e

# Check workspace first, then global
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GLOBAL_DIR="$HOME/.claude/hooks"

if [ -f "$SCRIPT_DIR/dist/session-end-cleanup.mjs" ]; then
  cd "$SCRIPT_DIR"
  cat | node dist/session-end-cleanup.mjs
elif [ -f "$GLOBAL_DIR/dist/session-end-cleanup.mjs" ]; then
  cd "$GLOBAL_DIR"
  cat | node dist/session-end-cleanup.mjs
else
  echo '{"result":"continue"}'
fi
