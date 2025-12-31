#!/bin/bash
set -e
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

# Pass PPID to Node so it can find the correct context file
export CLAUDE_PPID="$PPID"

run_hook "skill-activation-prompt"
