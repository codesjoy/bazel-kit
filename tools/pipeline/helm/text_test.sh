#!/usr/bin/env bash
set -euo pipefail

repositories_file="$1"
versions_file="$2"

grep -Fq 'pipeline_tool_helm' "$versions_file"
grep -Fq 'helm-v3.20.1-linux-amd64.tar.gz' "$versions_file"
grep -Fq 'windows_arm64' "$versions_file"
grep -Fq 'pipeline_helm_repository' "$repositories_file"
