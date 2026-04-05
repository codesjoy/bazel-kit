# wire

`wire` provides Bazel-managed access to the archived but still widely used `google/wire` CLI for source-tree DI generation workflows.

## Bzlmod Setup

```starlark
wire_tools = use_extension("@codesjoy_bazel_kit//rules/wire:extensions.bzl", "wire_tools")
wire_tools.install()

use_repo(
    wire_tools,
    "wire_tool_wire",
)
```

## Public API

```starlark
load("@codesjoy_bazel_kit//rules/wire:defs.bzl", "wire_check", "wire_diff", "wire_gen")
```

- `wire_gen`
- `wire_diff`
- `wire_check`

Common attrs:

- `modules`: optional `go.mod` labels; if omitted, the launcher discovers all modules under the workspace
- `target_pkgs`: packages passed to `wire`, default `["./cmd/server"]`
- `gocache_dir`: Go build cache directory, default `_output/wire-go-build-cache`

## Example

See [`examples/wire`](../examples/wire).
