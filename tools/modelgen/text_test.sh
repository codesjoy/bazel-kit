#!/usr/bin/env bash
set -euo pipefail

repositories_file="$1"
versions_file="$2"

grep -Fq 'codesjoy_modelgen_repository' "$repositories_file"
grep -Fq '"repo": "modelgen_tool_codesjoy_modelgen"' "$versions_file"
grep -Fq '"default_commit": "9bfa697c14eeb20cfd5b7193e459525459e08406"' "$versions_file"
