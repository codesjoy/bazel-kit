#!/usr/bin/env bash
set -euo pipefail

gitops_dir="$1"
path_to_remove="$2"
message="$3"

cd "$gitops_dir"
rm -rf "$path_to_remove"
git add -A .
if git diff --cached --quiet; then
  printf 'INFO  no GitOps cleanup changes to commit\n' >&2
  exit 0
fi
git commit -m "$message"
git push origin HEAD
