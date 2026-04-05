#!/usr/bin/env bash
set -euo pipefail

gitops_dir="$1"
message="$2"

cd "$gitops_dir"
git add -A .
if git diff --cached --quiet; then
  printf 'INFO  no GitOps changes to commit\n' >&2
  exit 0
fi
git commit -m "$message"
git push origin HEAD
