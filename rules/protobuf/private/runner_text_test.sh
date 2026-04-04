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

assert_contains "$defs_file" 'def buf_format('
assert_contains "$defs_file" 'def buf_breaking('
assert_contains "$defs_file" 'def buf_generate('
assert_contains "$extensions_file" 'protobuf_tools = module_extension('
assert_contains "$extensions_file" '"plugins": attr.string_list(default = [])'
assert_contains "$extensions_file" 'pkg_override'
assert_contains "$extensions_file" 'duplicate protobuf tool override for buf'
assert_contains "$extensions_file" 'unknown protobuf plugin'
assert_contains "$launcher_file" 'protobuf_buf_runner = rule('
assert_contains "$launcher_file" 'dep update'
assert_contains "$launcher_file" 'local_plugins'
assert_contains "$launcher_file" 'refs/remotes/'
assert_contains "$launcher_file" '@protobuf_tool_buf//:tool'
assert_contains "$versions_file" '"repo": "protobuf_tool_protoc_gen_codesjoy_event"'
assert_contains "$versions_file" '"repo": "protobuf_tool_buf"'
