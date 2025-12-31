#!/bin/bash
# PostToolUse hook: Index handoffs and inject Braintrust IDs
# Matches: Write tool calls to thoughts/handoffs/**/*.md
set -e

# Check workspace first, then global
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GLOBAL_DIR="$HOME/.claude/hooks"

if [ -f "$SCRIPT_DIR/dist/handoff-index.mjs" ]; then
  cd "$SCRIPT_DIR"
  cat | node dist/handoff-index.mjs
elif [ -f "$GLOBAL_DIR/dist/handoff-index.mjs" ]; then
  cd "$GLOBAL_DIR"
  cat | node dist/handoff-index.mjs
elif [ -f "$SCRIPT_DIR/src/handoff-index.ts" ]; then
  cd "$SCRIPT_DIR"
  cat | npx tsx src/handoff-index.ts
else
  echo '{"result":"continue"}'
fi
