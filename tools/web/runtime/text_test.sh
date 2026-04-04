#!/usr/bin/env bash
set -euo pipefail

repositories_file="$1"
versions_file="$2"

grep -Fq 'web_tool_node' "$versions_file"
grep -Fq 'web_tool_pnpm' "$versions_file"
grep -Fq 'package/dist/pnpm.cjs' "$versions_file"
grep -Fq 'windows_arm64' "$versions_file"
grep -Fq 'web_node_repository' "$repositories_file"
grep -Fq 'web_pnpm_repository' "$repositories_file"
