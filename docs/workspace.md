# workspace

`workspace` provides workspace maintenance helpers for multi-module Go repositories.

It now covers both `go.work` sync and the common repo-wide module maintenance actions that previously lived in `deps.mk`.

## Public API

Load from:

```starlark
load("@codesjoy_bazel_kit//rules/workspace:defs.bzl", "go_clean", "go_mod_download", "go_mod_tidy", "go_mod_verify", "workspace_drift_check", "workspace_modules_print", "workspace_sync")
```

### Rules

- `workspace_sync`
  - attrs: `modules`, `go_work`, `gazelle_target`, `run_bazel_mod_tidy`
  - behavior: discovers or accepts module roots, rewrites `go.work`, optionally runs `bazel mod tidy`, optionally runs a follow-up executable target
- `go_mod_tidy`
  - attrs: `modules`
  - behavior: loops over selected modules and runs `GOWORK=off go mod tidy`
- `go_mod_download`
  - attrs: `modules`
  - behavior: loops over selected modules and runs `GOWORK=off go mod download`
- `go_mod_verify`
  - attrs: `modules`
  - behavior: loops over selected modules and runs `GOWORK=off go mod verify`
- `workspace_drift_check`
  - attrs: `modules`, `go_work`
  - behavior: regenerates the expected `go.work` content in a temp file and diffs it against the live file
- `workspace_modules_print`
  - attrs: `modules`
  - behavior: prints discovered modules and selected modules
- `go_clean`
  - attrs: `modules`, `output_dir`
  - behavior: removes `_output` by default and runs `GOWORK=off go clean -cache -testcache` per selected module

## Discovery Behavior

When `modules` is omitted, discovery searches for `go.mod` files while excluding:

- `vendor/`
- `_output/`
- `.tmp/`
- `.git/`
- `bazel-*`

Discovered module paths are sorted before use.

## Host Prerequisites

- `workspace_sync` requires `go` and `bazel`
- `go_mod_*`, `workspace_drift_check`, `workspace_modules_print`, and `go_clean` require `go`
- any supplied `gazelle_target` adds its own prerequisites

## Example

See [`examples/workspace`](../examples/workspace).

## Notes

- `workspace_sync` rewrites `go.work` from scratch every run.
- The launcher derives the Go version by preferring `go env GOVERSION` and falling back to `go version`.
- All workspace maintenance launchers use the same cross-platform helper path on Windows, macOS, and Linux.
