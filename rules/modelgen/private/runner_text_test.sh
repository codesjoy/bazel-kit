#!/usr/bin/env bash
set -euo pipefail

defs_file="$1"
extensions_file="$2"
launcher_file="$3"
versions_file="$4"

grep -Fq 'def codesjoy_modelgen(' "$defs_file"
grep -Fq 'modelgen_tools = module_extension(' "$extensions_file"
grep -Fq '"default_commit": "9bfa697c14eeb20cfd5b7193e459525459e08406"' "$versions_file"
grep -Fq 'codesjoy-modelgen complete' "$launcher_file"
grep -Fq '@modelgen_tool_codesjoy_modelgen//:tool' "$launcher_file"
