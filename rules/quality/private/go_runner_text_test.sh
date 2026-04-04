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

assert_contains "$defs_file" 'def go_fmt('
assert_contains "$defs_file" 'def go_fmt_check('
assert_contains "$defs_file" 'def go_lint('
assert_contains "$extensions_file" 'quality_tools = module_extension('
assert_contains "$extensions_file" '"domain": attr.string(mandatory = True)'
assert_contains "$extensions_file" 'duplicate quality tool override'
assert_contains "$launcher_file" 'local_prefix'
assert_contains "$launcher_file" 'tool_gofumpt'
assert_contains "$launcher_file" 'tool_golangci_lint'
assert_contains "$launcher_file" 'config'
assert_contains "$versions_file" '"golangci-lint"'
assert_contains "$launcher_file" 'quality_tool_gofumpt'
assert_contains "$launcher_file" 'quality_go_runner = rule('
assert_not_contains "$launcher_file" 'github.com/codesjoy/bazel-demo'
assert_not_contains "$launcher_file" 'require_tool "gofumpt"'
assert_not_contains "$launcher_file" 'require_tool "goimports"'
assert_not_contains "$launcher_file" 'require_tool "golines"'
assert_not_contains "$launcher_file" 'require_tool "golangci-lint"'
assert_not_contains "$launcher_file" 'go_devx'
