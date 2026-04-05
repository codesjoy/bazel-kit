#!/usr/bin/env bash
set -euo pipefail

defs_file="$1"
extensions_file="$2"
launcher_file="$3"
plan_file="$4"
render_file="$5"
versions_file="$6"

assert_contains() {
  local file="$1"
  local pattern="$2"
  if ! grep -Fq -- "$pattern" "$file"; then
    printf 'missing pattern in %s: %s\n' "$file" "$pattern" >&2
    exit 1
  fi
}

assert_contains "$defs_file" 'def pipeline_service('
assert_contains "$defs_file" 'pipeline_helm_render = _pipeline_helm_render'
assert_contains "$extensions_file" 'pipeline_tools = module_extension('
assert_contains "$launcher_file" 'PipelineServiceInfo = provider('
assert_contains "$launcher_file" 'pipeline_plan = rule('
assert_contains "$launcher_file" 'pipeline_helm_render = rule('
assert_contains "$plan_file" 'def query_affected_service_labels('
assert_contains "$plan_file" '"baseline_environment"'
assert_contains "$render_file" 'def override_payload('
assert_contains "$render_file" 'runtimeDependencies'
assert_contains "$versions_file" '"pipeline_tool_helm"'
assert_contains "$versions_file" 'helm-v3.20.1-linux-amd64.tar.gz'
