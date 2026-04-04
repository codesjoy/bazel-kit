#!/usr/bin/env bash
set -euo pipefail

repositories_file="$1"
versions_file="$2"

grep -Fq 'quality_tool_shfmt' "$versions_file"
grep -Fq 'quality_tool_shellcheck' "$versions_file"
grep -Fq 'windows_amd64' "$versions_file"
grep -Fq 'shellcheck not configured, skipping shellcheck validation' "$repositories_file"
