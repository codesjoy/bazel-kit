#!/usr/bin/env bash
set -euo pipefail

repositories_file="$1"
versions_file="$2"

grep -Fq 'protobuf_buf_repository' "$repositories_file"
grep -Fq '"repo": "protobuf_tool_buf"' "$versions_file"
grep -Fq '"default_version": "v1.67.0"' "$versions_file"
grep -Fq 'buf-Windows-x86_64.exe' "$versions_file"
