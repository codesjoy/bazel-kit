#!/usr/bin/env bash
set -euo pipefail

launcher="$1"
source_root="${TEST_SRCDIR}/_main"
workspace="$(mktemp -d "${TEST_TMPDIR}/plan-workspace.XXXXXX")"
tmpdir="$(mktemp -d "${TEST_TMPDIR}/plan.XXXXXX")"

mkdir -p "$workspace/rules"
cp "$source_root/BUILD.bazel" "$workspace/BUILD.bazel"
cp "$source_root/MODULE.bazel" "$workspace/MODULE.bazel"
cp "$source_root/MODULE.bazel.lock" "$workspace/MODULE.bazel.lock"
cp -R "$source_root/rules/pipeline" "$workspace/rules/pipeline"
export PIPELINE_BAZEL_BIN="$source_root/rules/pipeline/private/testdata/fake_bazel.sh"

run_plan() {
  local changed_file="$1"
  local output="$2"
  BUILD_WORKSPACE_DIRECTORY="$workspace" "$launcher" \
    --changed-files "$changed_file" \
    --baseline-environment staging \
    --output "$output"
}

run_plan "rules/pipeline/private/testdata/shared/contracts/schema.json" "$tmpdir/shared.json"
python3 - "$tmpdir/shared.json" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], "r", encoding="utf-8"))
assert payload["affected_service_names"] == ["api", "web"], payload
assert payload["baseline_environment"] == "staging", payload
assert payload["service_matrix"]["include"][0]["service"] == "api", payload
assert payload["service_matrix"]["include"][1]["service"] == "web", payload
assert [item["target"] for item in payload["lint_matrix"]["include"]] == [
    "//rules/pipeline/private:api_lint",
    "//rules/pipeline/private:web_lint",
], payload
assert payload["render_matrix"]["include"][0]["target"] == "//rules/pipeline/private:api_render", payload
assert payload["render_matrix"]["include"][1]["target"] == "//rules/pipeline/private:web_render", payload
PY

run_plan "rules/pipeline/private/testdata/services/web/src/main.ts" "$tmpdir/web.json"
python3 - "$tmpdir/web.json" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], "r", encoding="utf-8"))
assert payload["affected_service_names"] == ["web"], payload
assert payload["service_matrix"]["include"][0]["runtime_deps_csv"] == "api", payload
PY

BUILD_WORKSPACE_DIRECTORY="$workspace" "$launcher" --output "$tmpdir/empty.json"
python3 - "$tmpdir/empty.json" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], "r", encoding="utf-8"))
assert payload["empty"] is True, payload
assert payload["affected_service_names"] == [], payload
PY
