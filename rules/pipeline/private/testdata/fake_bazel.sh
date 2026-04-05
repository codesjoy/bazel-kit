#!/usr/bin/env bash
set -euo pipefail

if [[ "$1" != "query" ]]; then
  printf 'unexpected bazel subcommand: %s\n' "$1" >&2
  exit 1
fi

query="${@: -1}"

if [[ "$query" == *"shared/contracts/schema.json"* ]]; then
  printf '//rules/pipeline/private:api_service\n'
  printf '//rules/pipeline/private:web_service\n'
  exit 0
fi

if [[ "$query" == *"services/web/src/main.ts"* ]]; then
  printf '//rules/pipeline/private:web_service\n'
  exit 0
fi

exit 0
