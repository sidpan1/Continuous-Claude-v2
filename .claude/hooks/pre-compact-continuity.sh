#!/bin/bash
set -e

# Check workspace first, then global
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GLOBAL_DIR="$HOME/.claude/hooks"

if [ -f "$SCRIPT_DIR/dist/pre-compact-continuity.mjs" ]; then
  cd "$SCRIPT_DIR"
  cat | node dist/pre-compact-continuity.mjs
elif [ -f "$GLOBAL_DIR/dist/pre-compact-continuity.mjs" ]; then
  cd "$GLOBAL_DIR"
  cat | node dist/pre-compact-continuity.mjs
else
  echo '{"result":"continue"}'
fi
