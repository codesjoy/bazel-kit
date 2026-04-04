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

assert_contains "$defs_file" 'def web_fmt('
assert_contains "$defs_file" 'def web_fmt_check('
assert_contains "$defs_file" 'def web_lint('
assert_contains "$extensions_file" '_VALID_DOMAINS = ["go", "shell", "web"]'
assert_contains "$extensions_file" '_DEFAULT_INSTALL_DOMAINS = ["go", "shell"]'
assert_contains "$extensions_file" 'quality_web_binary_tool_repository'
assert_contains "$launcher_file" 'tool_biome'
assert_contains "$launcher_file" 'discover_web_files()'
assert_contains "$launcher_file" "'.jsonc'"
assert_contains "$launcher_file" 'quality_tool_biome'
assert_contains "$launcher_file" 'quality_web_runner = rule('
assert_contains "$versions_file" '"quality_tool_biome"'
assert_not_contains "$launcher_file" '.vue'
assert_not_contains "$launcher_file" '.svelte'
assert_not_contains "$launcher_file" '.astro'
