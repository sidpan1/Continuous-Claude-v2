#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
# Pass PPID to Node so it can find the correct context file
export CLAUDE_PPID="$PPID"
cat | node dist/skill-activation-prompt.mjs
