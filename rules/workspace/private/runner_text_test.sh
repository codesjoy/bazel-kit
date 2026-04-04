#!/usr/bin/env bash
set -euo pipefail

defs_file="$1"
launcher_file="$2"

assert_contains() {
  local file="$1"
  local pattern="$2"
  if ! grep -Fq -- "$pattern" "$file"; then
    printf 'missing pattern in %s: %s\n' "$file" "$pattern" >&2
    exit 1
  fi
}

assert_contains "$defs_file" 'def workspace_sync('
assert_contains "$launcher_file" 'run_bazel_mod_tidy'
assert_contains "$launcher_file" 'gazelle_target'
assert_contains "$launcher_file" 'call :require_tool bazel'
assert_contains "$launcher_file" 'require_tool() {'
