#!/usr/bin/env bash
set -euo pipefail

launcher="$1"
workspace="$(mktemp -d "${TEST_TMPDIR}/web-init.XXXXXX")"

expect_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    printf 'missing file: %s\n' "$path" >&2
    find "$workspace" -maxdepth 6 -type f | sort >&2
    exit 1
  fi
}

BUILD_WORKSPACE_DIRECTORY="$workspace" "$launcher"

expect_file "$workspace/apps/demo/package.json"
expect_file "$workspace/apps/demo/biome.json"
expect_file "$workspace/apps/demo/tsconfig.json"
expect_file "$workspace/apps/demo/vite.config.ts"
expect_file "$workspace/apps/demo/vitest.config.ts"
expect_file "$workspace/apps/demo/playwright.config.ts"
expect_file "$workspace/apps/demo/index.html"
expect_file "$workspace/apps/demo/src/main.ts"
expect_file "$workspace/apps/demo/src/counter.ts"
expect_file "$workspace/apps/demo/src/style.css"
expect_file "$workspace/apps/demo/tests/counter.test.ts"
expect_file "$workspace/apps/demo/e2e/app.spec.ts"
expect_file "$workspace/pnpm-workspace.yaml"

grep -Fq '"name": "demo-app"' "$workspace/apps/demo/package.json"
grep -Fq "@playwright/test" "$workspace/apps/demo/package.json"
grep -Fq "packages:" "$workspace/pnpm-workspace.yaml"
grep -Fq "apps/demo" "$workspace/pnpm-workspace.yaml"
