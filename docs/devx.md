# devx

`devx` provides repo-level Bazel workflow entrypoints for common developer loops.

## Public API

Load from:

```starlark
load("@codesjoy_bazel_kit//rules/devx:defs.bzl", "devx_doctor", "devx_workflow", "hooks_clean", "hooks_install", "hooks_run", "hooks_run_all", "hooks_verify")
```

### Rules

- `devx_workflow`
  - attrs: `run_targets`, `test_targets`, `coverage_targets`, `coverage_threshold`, `coverage_output_dir`, `bazel_args`
  - behavior: runs `bazel run`, then `bazel test`, then `bazel coverage --combined_report=lcov`
- `devx_doctor`
  - attrs: `required_commands`, `verify_run_targets`, `verify_test_targets`, `require_git_repo`
  - behavior: checks host commands, verifies git repo presence, and runs `bazel build --nobuild` on declared targets
- `hooks_install`, `hooks_verify`, `hooks_run`, `hooks_run_all`, `hooks_clean`
  - behavior: wraps the official `pre-commit install/run/uninstall` flow against the workspace root `.pre-commit-config.yaml`

## Notes

- `devx` intentionally orchestrates Bazel targets; it does not replace `rules_go` or invent a new test abstraction.
- Hooks rely on a repo-owned `.pre-commit-config.yaml` in the workspace root.
- Coverage output is copied to `_output/coverage/lcov.info` by default.
