#!/bin/bash
set -e

# Check workspace first, then global
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GLOBAL_DIR="$HOME/.claude/hooks"

# Pass PPID to Node so it can find the correct context file
export CLAUDE_PPID="$PPID"

if [ -f "$SCRIPT_DIR/dist/skill-activation-prompt.mjs" ]; then
  cd "$SCRIPT_DIR"
  cat | node dist/skill-activation-prompt.mjs
elif [ -f "$GLOBAL_DIR/dist/skill-activation-prompt.mjs" ]; then
  cd "$GLOBAL_DIR"
  cat | node dist/skill-activation-prompt.mjs
else
  echo '{"result":"continue"}'
fi
