# workspace

`workspace_sync` provides workspace maintenance helpers for multi-module Go repositories.

The capability is intentionally small: it rewrites `go.work`, can optionally run `bazel mod tidy`, and can optionally invoke a follow-up executable target such as Gazelle. It exists as a runnable workflow rule because the job is inherently operational and source-tree-writing.

## Overview

- Public entrypoint: `@codesjoy_bazel_kit//rules/workspace:defs.bzl`
- Public rule: `workspace_sync`
- Managed tools: none
- Example workspace: [`examples/workspace`](../examples/workspace)

## Design And Rationale

### Why This Is A Runnable Rule

`workspace_sync` is not an analysis-only helper. Its primary responsibilities are:

- compute the module list that should appear in `go.work`
- rewrite `go.work`
- optionally run `bazel mod tidy`
- optionally run a follow-up executable target

Those are stateful maintenance operations, so the capability is expressed as a runnable rule that executes against `BUILD_WORKSPACE_DIRECTORY`.

### Operational Model

- The launcher runs from the source workspace, not from runfiles.
- It fully rewrites the target `go.work` file; it does not patch the file incrementally.
- If `modules` is omitted, it discovers `go.mod` files under the workspace.
- If enabled, `bazel mod tidy` runs after the `go.work` rewrite.
- If `gazelle_target` is set, `bazel run <target>` executes after the optional mod tidy step.

## Public API

Load the rule from:

```starlark
load("@codesjoy_bazel_kit//rules/workspace:defs.bzl", "workspace_sync")
```

### Attribute Reference

| Attr | Type | Default | Meaning |
| --- | --- | --- | --- |
| `modules` | label list of `go.mod` files | auto-discover | Module roots to include in `go.work` |
| `go_work` | single file label | `go.work` in the workspace root | Output file to rewrite |
| `gazelle_target` | executable label | unset | Optional runnable target to execute after sync |
| `run_bazel_mod_tidy` | bool | `True` | Whether to run `bazel mod tidy` after rewriting `go.work` |

### Discovery Behavior

When `modules` is omitted, discovery searches for `go.mod` files while excluding:

- `vendor/`
- `_output/`
- `.tmp/`
- `.git/`
- `bazel-*`

Discovered module paths are sorted before being written to `go.work`.

### Host Prerequisites

`workspace_sync` explicitly checks for:

- `go`
- `bazel`

If `gazelle_target` is supplied, any prerequisites of that target also become part of the workflow.

## Common Workflows

### Minimal Usage

```starlark
load("@codesjoy_bazel_kit//rules/workspace:defs.bzl", "workspace_sync")

workspace_sync(
    name = "sync",
    modules = [
        "//service_a:go.mod",
        "//service_b:go.mod",
    ],
)
```

This rewrites `go.work` and then runs `bazel mod tidy`.

### Let The Rule Discover Modules

```starlark
workspace_sync(
    name = "sync",
)
```

Use this when the repository layout matches the discovery rules and you want the launcher to gather all `go.mod` files automatically.

### Disable `bazel mod tidy`

```starlark
workspace_sync(
    name = "sync",
    modules = ["//examples/quality/go:go.mod"],
    run_bazel_mod_tidy = False,
)
```

### Run A Follow-Up Target

```starlark
workspace_sync(
    name = "sync",
    modules = ["//examples/quality/go:go.mod"],
    go_work = ":go.work",
    gazelle_target = ":noop_gazelle",
    run_bazel_mod_tidy = False,
)
```

This mirrors the checked-in example and is useful when you want sync plus a deterministic follow-up maintenance action.

## Example Mapping

Reference files:

- BUILD file: [`examples/workspace/BUILD.bazel`](../examples/workspace/BUILD.bazel)
- Example `go.work`: [`examples/workspace/go.work`](../examples/workspace/go.work)
- Example follow-up executable: [`examples/workspace/noop_gazelle.sh`](../examples/workspace/noop_gazelle.sh)

Reference target:

- `//examples/workspace:sync`

## Operational Notes

- The rule derives the Go version for `go.work` by preferring `go env GOVERSION` and falling back to `go version`.
- The emitted `go.work` is written from scratch every run.
- If `gazelle_target` is present, it runs after the sync and optional mod tidy steps.
- On Windows, the launcher writes the file through PowerShell with UTF-8 output and no BOM.

## Limits And Non-Goals

- `workspace_sync` only manages `go.work` and optional follow-up commands.
- It does not attempt to merge with hand-edited `go.work` content.
- It does not perform partial updates to the file.
- It does not infer anything about non-Go workspaces.
- It does not validate what the follow-up target does; that target may mutate additional files.

## Troubleshooting

### The rule fails because `go` or `bazel` is missing

Those are explicit host prerequisites. Install them or ensure they are on `PATH` before running the target.

### `go.work` includes the wrong modules

If you rely on discovery, remember that the launcher excludes transient directories and sorts the discovered modules. Pass `modules` explicitly if you need a tighter set.

### `go.work` formatting or ordering changed unexpectedly

That is expected. The file is rewritten from scratch every run based on the current module set and detected Go version.

### A follow-up target changed more files than expected

`workspace_sync` does not sandbox or constrain `gazelle_target`. Any side effects come from that target's own behavior.
