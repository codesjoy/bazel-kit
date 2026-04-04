# quality

`quality` provides public code-quality helpers for Go and shell.

The capability is deliberately scoped to formatting and linting workflows. It manages the tool binaries through Bzlmod, exposes a small runnable rule surface, and leaves project-specific policy in the caller's config files and module layout.

## Overview

- Public entrypoints:
  - `@codesjoy_bazel_kit//rules/quality:go.bzl`
  - `@codesjoy_bazel_kit//rules/quality:shell.bzl`
- Managed tool extension: `quality_tools`
- Example workspaces:
  - [`examples/quality/go`](../examples/quality/go)
  - [`examples/quality/shell`](../examples/quality/shell)

## Design And Rationale

### Why This Is A Capability Instead Of A Generic Tool Wrapper

The goal is not to expose every flag of every formatter and linter. The goal is to give workspaces a reproducible, minimal quality workflow surface that:

- installs the exact tool binaries through Bazel
- runs those tools from `BUILD_WORKSPACE_DIRECTORY`
- encodes the expected high-level workflow (`fmt`, `fmt_check`, `lint`)
- keeps project-specific details in BUILD attrs and checked-in config files

That is why the public API is intentionally small and capability-centered.

### Operational Model

- Managed tools are installed through `quality_tools`.
- Launchers execute from the source workspace, not from runfiles.
- `go_fmt` is source-tree-writing by design.
- `go_fmt_check`, `go_lint`, and `shell_lint` validate the current workspace state without rewriting files.
- Go file and module discovery is implemented in the launcher and excludes common generated and transient directories.

## Managed Tools And Prerequisites

### Bzlmod Setup

```starlark
quality_tools = use_extension("@codesjoy_bazel_kit//rules/quality:extensions.bzl", "quality_tools")
quality_tools.install(domains = ["go", "shell"])

use_repo(
    quality_tools,
    "quality_tool_gofumpt",
    "quality_tool_goimports",
    "quality_tool_golangci_lint",
    "quality_tool_golines",
    "quality_tool_shellcheck",
    "quality_tool_shfmt",
)
```

If you omit `quality_tools.install(...)`, the extension currently defaults to provisioning both `go` and `shell`. Explicit install calls are still recommended because they make intent clear and let you opt out of domains deliberately.

### Domain Model

`quality_tools.install` accepts:

- `domains`, default `["go", "shell"]`
- `shellcheck`, default `False`

If `shellcheck = True`, the `shell` domain must be enabled.

### Version Overrides

```starlark
quality_tools.override(domain = "go", name = "gofumpt", version = "v0.9.2")
quality_tools.override(domain = "shell", name = "shfmt", version = "v3.13.0")
```

Overrides are validated against the versions committed in:

- [`tools/quality/go/versions.bzl`](../tools/quality/go/versions.bzl)
- [`tools/quality/shell/versions.bzl`](../tools/quality/shell/versions.bzl)

They are curated overrides, not arbitrary upstream version passthrough.

### Default Managed Tools

| Domain | Tool | Default version | Notes |
| --- | --- | --- | --- |
| `go` | `gofumpt` | `v0.9.2` | built from source |
| `go` | `goimports` | `v0.43.0` | built from source |
| `go` | `golines` | `v0.13.0` | built from source |
| `go` | `golangci-lint` | `v2.11.4` | prebuilt archive |
| `shell` | `shfmt` | `v3.13.0` | always installed when the shell domain is enabled |
| `shell` | `shellcheck` | `v0.11.0` | optional; defaults to a warning wrapper unless explicitly enabled |

### Host Expectations

No separate formatter or linter installation is required. The launchers invoke managed binaries from Bazel runfiles.

The rules still operate against the live workspace checked out in `BUILD_WORKSPACE_DIRECTORY`, so failures reflect the state of your source tree, configs, and modules.

## Public API

### Go Rules

Load from:

```starlark
load("@codesjoy_bazel_kit//rules/quality:go.bzl", "go_fmt", "go_fmt_check", "go_lint")
```

| Rule | Required attrs | Optional attrs | Writes source tree? | Behavior |
| --- | --- | --- | --- | --- |
| `go_fmt` | `local_prefix` | `files` | yes | Runs `gofumpt`, then `goimports`, then `golines` |
| `go_fmt_check` | `local_prefix` | `files` | no | Fails if any of the three tools would rewrite files |
| `go_lint` | `config` | `modules` | no | Runs `golangci-lint` with `GOWORK=off` per module |

#### `go_fmt`

- If `files` is provided, only those files are formatted.
- If `files` is omitted, the launcher discovers `*.go` files under the workspace.
- Discovery excludes:
  - `vendor/`
  - `_output/`
  - `.tmp/`
  - `.git/`
  - `bazel-*`
  - common generated file names such as `*.pb.go`, `*.gen.go`, `*_generated.go`, and `zz_generated*.go`

`local_prefix` is passed to `goimports -local` and is required explicitly so the rule does not guess import grouping policy.

#### `go_fmt_check`

`go_fmt_check` uses the same discovery and tool ordering as `go_fmt`, but runs each tool in check mode:

- `gofumpt -l`
- `goimports -l -local ...`
- `golines -l --dry-run`

The rule fails if any tool reports drift.

#### `go_lint`

- `config` is required and should point to a `golangci-lint` config file.
- If `modules` is provided, lint runs only in those module directories.
- If `modules` is omitted, the launcher discovers all `go.mod` files under the workspace with the same transient-directory exclusions used elsewhere.
- Lint runs with:
  - `GOWORK=off`
  - temporary Go build cache
  - temporary golangci-lint cache

### Shell Rule

Load from:

```starlark
load("@codesjoy_bazel_kit//rules/quality:shell.bzl", "shell_lint")
```

| Rule | Required attrs | Optional attrs | Writes source tree? | Behavior |
| --- | --- | --- | --- | --- |
| `shell_lint` | `scripts` | none | no | Runs `shfmt -d` followed by `shellcheck -x` |

`shell_lint` does not auto-discover files. Callers pass the scripts explicitly.

When `shellcheck` is not enabled in `quality_tools.install(shellcheck = True)`, the managed `shellcheck` repo becomes a warning wrapper that exits successfully with a message. This keeps `shfmt` active by default without forcing every workspace to adopt shellcheck immediately.

## Common Workflows

### Minimal Go Setup

```starlark
load("@codesjoy_bazel_kit//rules/quality:go.bzl", "go_fmt", "go_fmt_check", "go_lint")

go_fmt(
    name = "fmt",
    files = ["main.go"],
    local_prefix = "github.com/acme/project",
)

go_fmt_check(
    name = "fmt_check",
    files = ["main.go"],
    local_prefix = "github.com/acme/project",
)

go_lint(
    name = "lint",
    modules = ["go.mod"],
    config = ":.golangci.yaml",
)
```

### Minimal Shell Setup

```starlark
load("@codesjoy_bazel_kit//rules/quality:shell.bzl", "shell_lint")

shell_lint(
    name = "lint",
    scripts = ["demo.sh"],
)
```

### Example Mapping

The checked-in examples are the reference usage:

- Go example BUILD file: [`examples/quality/go/BUILD.bazel`](../examples/quality/go/BUILD.bazel)
- Shell example BUILD file: [`examples/quality/shell/BUILD.bazel`](../examples/quality/shell/BUILD.bazel)

Example targets:

- `//examples/quality/go:fmt`
- `//examples/quality/go:fmt_check`
- `//examples/quality/go:lint`
- `//examples/quality/shell:lint`

## Operational Notes

- All launchers run from `BUILD_WORKSPACE_DIRECTORY`.
- `go_fmt` mutates files in place; check and lint rules do not.
- `go_lint` is module-scoped, not package-scoped.
- `shell_lint` is intentionally explicit about which scripts it receives.
- The capability does not attempt to manage generated-file ownership beyond excluding common generated Go file patterns from automatic discovery.

## Limits And Non-Goals

- `quality` is not a build/test abstraction. It only covers formatting and linting workflows.
- It does not auto-discover shell scripts.
- It does not infer `local_prefix` or lint config paths.
- It does not attempt to wrap every upstream tool flag.
- `shellcheck` is intentionally opt-in by default.

## Troubleshooting

### `go_fmt` or `go_fmt_check` says `local_prefix` is required

That is intentional. Pass the import prefix you want `goimports` to treat as local.

### `go_lint` says `config` is required

The rule never guesses a golangci-lint config path. Provide it explicitly.

### A file was not formatted automatically

If you omitted `files`, automatic discovery excludes common generated files and transient directories. Pass the file explicitly if you want to override that behavior.

### `shell_lint` prints a shellcheck warning but still passes

That means `shellcheck` is not enabled in `quality_tools.install(...)`. Enable it with:

```starlark
quality_tools.install(domains = ["shell"], shellcheck = True)
```

or include `shell` alongside any other enabled domains.
