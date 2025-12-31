#!/bin/bash
# Shared utilities for hook scripts
# Source this file: source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

# Resolve hook paths - workspace first, global fallback
# Usage: run_hook "hook-name" (without .mjs extension)
run_hook() {
  local hook_name="$1"
  local script_dir="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
  local global_dir="$HOME/.claude/hooks"

  if [ -f "$script_dir/dist/${hook_name}.mjs" ]; then
    cd "$script_dir"
    cat | node "dist/${hook_name}.mjs"
  elif [ -f "$global_dir/dist/${hook_name}.mjs" ]; then
    cd "$global_dir"
    cat | node "dist/${hook_name}.mjs"
  else
    echo '{"result":"continue"}'
  fi
}

# Same as run_hook but with TypeScript fallback for development
# Usage: run_hook_dev "hook-name"
run_hook_dev() {
  local hook_name="$1"
  local script_dir="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
  local global_dir="$HOME/.claude/hooks"

  if [ -f "$script_dir/dist/${hook_name}.mjs" ]; then
    cd "$script_dir"
    cat | node "dist/${hook_name}.mjs"
  elif [ -f "$global_dir/dist/${hook_name}.mjs" ]; then
    cd "$global_dir"
    cat | node "dist/${hook_name}.mjs"
  elif [ -f "$script_dir/src/${hook_name}.ts" ]; then
    cd "$script_dir"
    cat | npx tsx "src/${hook_name}.ts"
  else
    echo '{"result":"continue"}'
  fi
}
