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

assert_contains "$defs_file" 'def web_init('
assert_contains "$defs_file" 'def web_install('
assert_contains "$defs_file" 'def web_typecheck('
assert_contains "$defs_file" 'def web_browser_install('
assert_contains "$defs_file" 'def web_e2e('
assert_contains "$extensions_file" 'web_tools = module_extension('
assert_contains "$extensions_file" 'duplicate web tool override'
assert_contains "$launcher_file" 'PLAYWRIGHT_BROWSERS_PATH'
assert_contains "$launcher_file" '--store-dir'
assert_contains "$launcher_file" 'pnpm-lock.yaml'
assert_contains "$launcher_file" 'playwright install'
assert_contains "$launcher_file" 'web_runner = rule('
assert_contains "$versions_file" '"web_tool_node"'
assert_contains "$versions_file" '"web_tool_pnpm"'
assert_contains "$versions_file" '"package/dist/pnpm.cjs"'
