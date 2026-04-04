#!/usr/bin/env bash
set -euo pipefail

repositories_file="$1"
versions_file="$2"

grep -Fq 'quality_tool_biome' "$versions_file"
grep -Fq 'windows_arm64' "$versions_file"
grep -Fq 'quality_web_binary_tool_repository' "$repositories_file"
