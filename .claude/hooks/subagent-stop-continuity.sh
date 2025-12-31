#!/bin/bash
set -e

# Check workspace first, then global
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GLOBAL_DIR="$HOME/.claude/hooks"

if [ -f "$SCRIPT_DIR/dist/subagent-stop-continuity.mjs" ]; then
  cd "$SCRIPT_DIR"
  cat | node dist/subagent-stop-continuity.mjs
elif [ -f "$GLOBAL_DIR/dist/subagent-stop-continuity.mjs" ]; then
  cd "$GLOBAL_DIR"
  cat | node dist/subagent-stop-continuity.mjs
else
  echo '{"result":"continue"}'
fi
