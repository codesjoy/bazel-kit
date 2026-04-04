# bazel-kit

`bazel-kit` is a shared repository for reusable Bazel capabilities used across codesjoy workspaces.

The repository is organized around capability-focused, runnable workflows rather than broad rule ecosystems. Each capability exposes a small public API, manages the external tools it owns through Bzlmod, and keeps its usage examples next to the implementation.

## What This Repo Provides

### `quality`

`quality` manages code-quality workflows for Go and shell. It installs formatter and linter binaries through `quality_tools`, exposes small runnable rules such as `go_fmt` and `shell_lint`, and keeps the build-facing API intentionally narrow. Read [docs/quality.md](docs/quality.md) and inspect [examples/quality/go](examples/quality/go) plus [examples/quality/shell](examples/quality/shell).

### `protobuf`

`protobuf` manages protobuf workflows with Buf as the control plane. It is intentionally workflow-oriented: formatting, linting, breaking checks, code generation, dependency lock updates, and Bazel-managed codesjoy protoc plugins. It does not try to wrap Bazel's `proto_library` graph in v1. Read [docs/protobuf.md](docs/protobuf.md) and inspect [examples/protobuf](examples/protobuf).

### `modelgen`

`modelgen` manages the `codesjoy-modelgen` binary from `github.com/codesjoy/pkg/tools` and exposes a runnable Bazel rule for database-driven GORM model generation. It is intentionally separate from `protobuf` because it is not a codegen plugin and requires a live database at execution time. Read [docs/modelgen.md](docs/modelgen.md) and inspect [examples/modelgen](examples/modelgen).

### `workspace`

`workspace` provides maintenance helpers for keeping a multi-module Go workspace in sync. Its current scope is `go.work` generation, optional `bazel mod tidy`, and optional execution of a follow-up runnable target such as Gazelle. Read [docs/workspace.md](docs/workspace.md) and inspect [examples/workspace](examples/workspace).

## Quick Start

```starlark
bazel_dep(name = "codesjoy_bazel_kit", version = "0.2.0")

quality_tools = use_extension("@codesjoy_bazel_kit//rules/quality:extensions.bzl", "quality_tools")
quality_tools.install(domains = ["go", "shell"])

protobuf_tools = use_extension("@codesjoy_bazel_kit//rules/protobuf:extensions.bzl", "protobuf_tools")
protobuf_tools.install(
    plugins = [
        "codesjoy_event",
        "codesjoy_reason",
        "google_aip",
    ],
)

modelgen_tools = use_extension("@codesjoy_bazel_kit//rules/modelgen:extensions.bzl", "modelgen_tools")
modelgen_tools.install()

use_repo(
    quality_tools,
    "quality_tool_gofumpt",
    "quality_tool_goimports",
    "quality_tool_golangci_lint",
    "quality_tool_golines",
    "quality_tool_shellcheck",
    "quality_tool_shfmt",
)

use_repo(
    protobuf_tools,
    "protobuf_tool_buf",
    "protobuf_tool_protoc_gen_codesjoy_event",
    "protobuf_tool_protoc_gen_codesjoy_reason",
    "protobuf_tool_protoc_gen_google_aip",
)

use_repo(
    modelgen_tools,
    "modelgen_tool_codesjoy_modelgen",
)
```

From there, load the rule entrypoints you need:

- `@codesjoy_bazel_kit//rules/quality:go.bzl`
- `@codesjoy_bazel_kit//rules/quality:shell.bzl`
- `@codesjoy_bazel_kit//rules/protobuf:buf.bzl`
- `@codesjoy_bazel_kit//rules/modelgen:defs.bzl`
- `@codesjoy_bazel_kit//rules/workspace:defs.bzl`

## Capability Matrix

| Capability | Public entrypoints | Managed tools | Writes source tree? | Host prerequisites | Example targets |
| --- | --- | --- | --- | --- | --- |
| `quality` | `go_fmt`, `go_fmt_check`, `go_lint`, `shell_lint` | `gofumpt`, `goimports`, `golines`, `golangci-lint`, `shfmt`, optional `shellcheck` | `go_fmt` writes source files; the check and lint rules do not | No separate formatter/linter install is required | `//examples/quality/go:fmt`, `//examples/quality/go:fmt_check`, `//examples/quality/go:lint`, `//examples/quality/shell:lint` |
| `protobuf` | `buf_format`, `buf_format_check`, `buf_lint`, `buf_breaking`, `buf_generate`, `buf_dep_update` | `buf`, `protoc-gen-codesjoy-event`, `protoc-gen-codesjoy-reason`, `protoc-gen-google-aip` | `buf_format`, `buf_generate`, and `buf_dep_update` write the source workspace | `git` is required only for the default `buf_breaking` mode; plugin inputs and plugin-selected templates remain the caller's responsibility | `//examples/protobuf:generate_codesjoy_event`, `//examples/protobuf:generate_codesjoy_reason`, `//examples/protobuf:generate_google_aip` |
| `modelgen` | `codesjoy_modelgen` | `codesjoy-modelgen` | yes | a reachable database is required when the target is actually run | `//examples/modelgen:generate_models` |
| `workspace` | `workspace_sync` | none | yes; it rewrites `go.work` and may trigger follow-up commands that write files | `go`, `bazel`, and whatever the optional follow-up target requires | `//examples/workspace:sync` |

## Design Conventions

- A **capability** is a narrow, cohesive workflow surface such as `quality`, `protobuf`, or `workspace`.
- A **managed tool** is a binary installed through a module extension and imported into the repo with `use_repo`, rather than something users are expected to preinstall manually.
- A **source-tree-writing** rule is a runnable target that intentionally updates files in `BUILD_WORKSPACE_DIRECTORY`. `go_fmt`, `buf_generate`, and `workspace_sync` fall into this category.
- Public APIs stay small on purpose. If a workflow needs more policy, it should usually live in the caller's config files or surrounding BUILD logic rather than in a wide Bazel abstraction layer here.

## Documentation Map

- [docs/quality.md](docs/quality.md): design, Bzlmod wiring, rule reference, and operational guidance for Go and shell quality workflows
- [docs/protobuf.md](docs/protobuf.md): design rationale for Buf-managed protobuf workflows, rule reference, examples, and troubleshooting
- [docs/modelgen.md](docs/modelgen.md): design, tool pinning, rule reference, and operational notes for `codesjoy-modelgen`
- [docs/workspace.md](docs/workspace.md): design and operational guide for `workspace_sync`

## Example Map

- [examples/quality/go](examples/quality/go): `go_fmt`, `go_fmt_check`, and `go_lint`
- [examples/quality/shell](examples/quality/shell): `shell_lint`
- [examples/protobuf](examples/protobuf): Buf formatting, linting, breaking, generate, and dep update workflows
- [examples/modelgen](examples/modelgen): launcher wiring for `codesjoy-modelgen`
- [examples/workspace](examples/workspace): `workspace_sync` with a follow-up executable target
