#!/usr/bin/env bash
set -euo pipefail

install_launcher="$1"
typecheck_launcher="$2"
test_launcher="$3"
build_launcher="$4"
browser_install_launcher="$5"
e2e_launcher="$6"

workspace="$(mktemp -d "${TEST_TMPDIR}/web-smoke.XXXXXX")"
project_dir="$workspace/apps/demo"
mkdir -p "$project_dir"

cat > "$project_dir/package.json" <<'EOF'
{
  "name": "demo-app",
  "private": true
}
EOF

cat > "$project_dir/tsconfig.json" <<'EOF'
{
  "compilerOptions": {
    "noEmit": true
  }
}
EOF

cat > "$project_dir/vitest.config.ts" <<'EOF'
export default {};
EOF

cat > "$project_dir/playwright.config.ts" <<'EOF'
export default {};
EOF

cat > "$project_dir/pnpm-lock.yaml" <<'EOF'
lockfileVersion: '9.0'
EOF

export WEB_SMOKE_LOG="$workspace/web-smoke.log"

BUILD_WORKSPACE_DIRECTORY="$workspace" "$install_launcher"
BUILD_WORKSPACE_DIRECTORY="$workspace" "$typecheck_launcher"
BUILD_WORKSPACE_DIRECTORY="$workspace" "$test_launcher"
BUILD_WORKSPACE_DIRECTORY="$workspace" "$build_launcher"
BUILD_WORKSPACE_DIRECTORY="$workspace" "$browser_install_launcher"
BUILD_WORKSPACE_DIRECTORY="$workspace" "$e2e_launcher"

grep -Fq "ARG=--dir" "$WEB_SMOKE_LOG"
grep -Fq "ARG=$workspace/apps/demo" "$WEB_SMOKE_LOG"
grep -Fq "ARG=--store-dir" "$WEB_SMOKE_LOG"
grep -Fq "ARG=$workspace/.pnpm-store" "$WEB_SMOKE_LOG"
grep -Fq "ARG=install" "$WEB_SMOKE_LOG"
grep -Fq "ARG=--frozen-lockfile" "$WEB_SMOKE_LOG"
grep -Fq "ARG=tsc" "$WEB_SMOKE_LOG"
grep -Fq "ARG=--noEmit" "$WEB_SMOKE_LOG"
grep -Fq "ARG=vitest" "$WEB_SMOKE_LOG"
grep -Fq "ARG=run" "$WEB_SMOKE_LOG"
grep -Fq "ARG=vite" "$WEB_SMOKE_LOG"
grep -Fq "ARG=build" "$WEB_SMOKE_LOG"
grep -Fq "ARG=playwright" "$WEB_SMOKE_LOG"
grep -Fq "ARG=test" "$WEB_SMOKE_LOG"
grep -Fq "PLAYWRIGHT_BROWSERS_PATH=$workspace/.playwright-browsers" "$WEB_SMOKE_LOG"
test -d "$workspace/.playwright-browsers/chromium-stub"
