#!/usr/bin/env bash
set -euo pipefail

workspace_name="${TEST_WORKSPACE:-_main}"
runfiles_root="${TEST_SRCDIR}/${workspace_name}"
if [[ ! -d "${runfiles_root}/examples/modelgen" && -d "${TEST_SRCDIR}/_main/examples/modelgen" ]]; then
  runfiles_root="${TEST_SRCDIR}/_main"
fi

launcher="${runfiles_root}/$1"
test -f "${launcher}"
test -x "${launcher}"
