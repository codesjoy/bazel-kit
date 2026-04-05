#!/usr/bin/env bash
set -euo pipefail

launcher="$1"
workspace="${TEST_SRCDIR}/_main"
outdir="$(mktemp -d "${TEST_TMPDIR}/render.XXXXXX")"

BUILD_WORKSPACE_DIRECTORY="$workspace" "$launcher" \
  --environment preview \
  --output-dir "$outdir" \
  --namespace preview-api \
  --host api.preview.example.test \
  --image-repository ghcr.io/acme/api \
  --image-digest sha256:deadbeef \
  --preview-id pr-42 \
  --baseline-environment itest-baseline \
  --runtime-dependency web=https://web.itest.example.test

manifest="$outdir/manifest.yaml"
metadata="$outdir/metadata.json"

grep -Fq 'release: api' "$manifest"
grep -Fq 'namespace: preview-api' "$manifest"
grep -Fq '"repository": "ghcr.io/acme/api"' "$manifest"
grep -Fq '"digest": "sha256:deadbeef"' "$manifest"
grep -Fq '"previewId": "pr-42"' "$manifest"
grep -Fq '"baselineEnvironment": "itest-baseline"' "$manifest"
grep -Fq 'previewEnabled: true' "$manifest"
grep -Fq 'api.preview.example.test' "$manifest"
grep -Fq '"web": "https://web.itest.example.test"' "$manifest"

python3 - "$metadata" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], "r", encoding="utf-8"))
assert payload["service"] == "api", payload
assert payload["environment"] == "preview", payload
assert payload["namespace"] == "preview-api", payload
PY
