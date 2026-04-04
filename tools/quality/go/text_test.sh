#!/usr/bin/env bash
set -euo pipefail

repositories_file="$1"
versions_file="$2"

grep -Fq 'quality_tool_gofumpt' "$versions_file"
grep -Fq 'quality_tool_golangci_lint' "$versions_file"
grep -Fq 'windows_amd64' "$versions_file"
grep -Fq 'quality_go_go_source_tool_repository' "$repositories_file"
grep -Fq 'quality_go_binary_tool_repository' "$repositories_file"
