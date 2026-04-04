#!/usr/bin/env bash
set -euo pipefail

defs_file="$1"
extensions_file="$2"
launcher_file="$3"
versions_file="$4"

assert_contains() {
  local file="$1"
  local pattern="$2"
  if ! grep -Fq -- "$pattern" "$file"; then
    printf 'missing pattern in %s: %s\n' "$file" "$pattern" >&2
    exit 1
  fi
}

assert_not_contains() {
  local file="$1"
  local pattern="$2"
  if grep -Fq -- "$pattern" "$file"; then
    printf 'unexpected pattern in %s: %s\n' "$file" "$pattern" >&2
    exit 1
  fi
}

assert_contains "$defs_file" 'def shell_lint('
assert_contains "$extensions_file" 'quality_tools = module_extension('
assert_contains "$extensions_file" 'attr.string_list(default = ["go", "shell"])'
assert_contains "$extensions_file" 'requires shell domain in install domains'
assert_contains "$launcher_file" 'tool_shfmt'
assert_contains "$launcher_file" 'tool_shellcheck'
assert_contains "$versions_file" '"shellcheck"'
assert_contains "$launcher_file" 'tool_shellcheck'
assert_contains "$launcher_file" 'Shell scripts linted successfully'
assert_contains "$launcher_file" 'quality_tool_shfmt'
assert_contains "$launcher_file" 'quality_shell_runner = rule('
assert_not_contains "$launcher_file" 'github.com/codesjoy/bazel-demo'
assert_not_contains "$launcher_file" 'shell_devx'
