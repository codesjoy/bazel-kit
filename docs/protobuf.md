# protobuf

`protobuf` provides Buf-managed protobuf workflow helpers.

The capability is intentionally narrow: it owns protobuf workflow operations such as formatting, linting, breaking checks, code generation, and dependency lock maintenance. It does not try to replace Bazel's `proto_library` graph or invent a second protobuf configuration model on top of Buf.

## Overview

- Public entrypoint: `@codesjoy_bazel_kit//rules/protobuf:buf.bzl`
- Managed tool extension: `protobuf_tools`
- Managed repo: `protobuf_tool_buf`
- Current pinned Buf version: `v1.67.0`
- Example workspace: [`examples/protobuf`](../examples/protobuf)

All protobuf rules execute from `BUILD_WORKSPACE_DIRECTORY`, not from the runfiles tree. The `config` attribute points to a v2 `buf.yaml`; the directory containing that file becomes the input root for Buf commands.

## Design And Rationale

### Why Buf Is The Control Plane

The repo uses Buf as the protobuf control plane because the workflows this capability cares about are already Buf-native:

- formatting and format checks
- linting against a Buf config
- breaking checks against an explicit or Git-derived baseline
- code generation through `buf.gen.yaml`
- dependency lock maintenance through `buf dep update`

Keeping Buf as the control plane means callers keep using standard `buf.yaml`, `buf.gen.yaml`, and `buf.lock` files instead of learning a second repository-specific schema.

### Why This Is Not A `proto_library` Wrapper

This capability is deliberately not a Bazel protobuf graph abstraction. It does not define:

- `proto_library` wrappers
- language-specific `*_proto_library` graph helpers
- BSR publish flows
- registry authentication helpers

Those concerns are orthogonal to the workflow surface here. The goal is to make Buf-based protobuf maintenance reproducible inside Bazel, not to subsume Bazel's protobuf build graph.

### Operational Model

- The Buf binary is managed through Bzlmod, so callers do not need host `buf`.
- Rules are runnable workflows, not analysis-only helpers.
- Some rules are source-tree-writing by design:
  - `buf_format`
  - `buf_generate`
  - `buf_dep_update`
- `buf_breaking` has two modes:
  - explicit `against`, passed straight to Buf
  - default Git baseline against `origin/main`, scoped to the directory of `buf.yaml`

## Managed Tools And Prerequisites

### Bzlmod Setup

```starlark
protobuf_tools = use_extension("@codesjoy_bazel_kit//rules/protobuf:extensions.bzl", "protobuf_tools")
protobuf_tools.install()

use_repo(
    protobuf_tools,
    "protobuf_tool_buf",
)
```

`protobuf_tools.install()` is required. Unlike `quality_tools`, the protobuf extension does not provision anything unless an install tag is present.

### Version Overrides

```starlark
protobuf_tools.override(version = "v1.67.0")
```

The override is validated against the versions committed in [`tools/protobuf/versions.bzl`](../tools/protobuf/versions.bzl). This is a curated override, not an arbitrary tag passthrough.

### Host Prerequisites

- No host `buf` install is required.
- `git` is required only when `buf_breaking` uses the default Git baseline mode.
- Plugins referenced by `buf.gen.yaml` are the caller's responsibility:
  - local plugins must exist and be executable on the host
  - remote plugins follow Buf's own resolution behavior

## Public API

Load the public rules from:

```starlark
load("@codesjoy_bazel_kit//rules/protobuf:buf.bzl", "buf_breaking", "buf_dep_update", "buf_format", "buf_format_check", "buf_generate", "buf_lint")
```

### Rule Reference

| Rule | Required attrs | Optional attrs | Writes source tree? | Notes |
| --- | --- | --- | --- | --- |
| `buf_format` | `config` | `files` | yes | Formats either explicit files or the full config root in place |
| `buf_format_check` | `config` | `files` | no | Runs Buf's diff/exit-code check mode |
| `buf_lint` | `config` | none | no | Lints the config root directly |
| `buf_breaking` | `config` | `against`, `against_git_remote`, `against_git_branch` | no | Uses explicit `against` when set; otherwise builds a Git baseline against `origin/main` by default |
| `buf_generate` | `config`, `template` | none | yes | Runs `buf generate --template <buf.gen.yaml>` against the config root |
| `buf_dep_update` | `config` | none | yes, when Buf updates lock state | Runs `buf dep update` for the config root |

### Attribute Semantics

#### `config`

`config` must point to a v2 `buf.yaml`. The directory containing that file is treated as the Buf input root.

If `config` is `//examples/protobuf:buf.yaml`, the effective input root is `examples/protobuf`.

#### `files`

`files` is only used by `buf_format` and `buf_format_check`.

- If provided, each file is passed to Buf explicitly.
- If omitted, the rule runs against the config root and lets Buf recurse from there.

#### `template`

`template` is required by `buf_generate` and is passed to Buf exactly as a workspace-relative path. In practice this should be a `buf.gen.yaml` or compatible variant.

#### `against`

`against` is a literal Buf `--against` value. When it is present, `buf_breaking` does not require Git and does not derive any baseline automatically.

#### `against_git_remote` And `against_git_branch`

These attrs only matter when `against` is omitted. The default launcher constructs:

```text
.git#branch=<branch>,ref=refs/remotes/<remote>/<branch>,subdir=<config-dir>
```

For the example workspace, the default mode effectively compares the current `examples/protobuf` tree against `refs/remotes/origin/main`.

## Common Workflows

### Minimal BUILD Usage

```starlark
load("@codesjoy_bazel_kit//rules/protobuf:buf.bzl", "buf_breaking", "buf_dep_update", "buf_format", "buf_format_check", "buf_generate", "buf_lint")

buf_format(
    name = "format",
    config = ":buf.yaml",
)

buf_format_check(
    name = "format_check",
    config = ":buf.yaml",
)

buf_lint(
    name = "lint",
    config = ":buf.yaml",
)

buf_breaking(
    name = "breaking",
    config = ":buf.yaml",
)

buf_generate(
    name = "generate",
    config = ":buf.yaml",
    template = ":buf.gen.yaml",
)

buf_dep_update(
    name = "dep_update",
    config = ":buf.yaml",
)
```

### Restrict Formatting To Specific Files

```starlark
buf_format(
    name = "format_one_file",
    config = ":buf.yaml",
    files = ["proto/acme/weather/v1/weather.proto"],
)
```

### Explicit Breaking Baseline

```starlark
buf_breaking(
    name = "breaking_explicit",
    config = ":buf.yaml",
    against = ".git#branch=main,subdir=examples/protobuf",
)
```

Use explicit mode when your calling environment already knows the correct Buf baseline string or when you do not want the rule to rely on Git remotes.

### Generate With A Local Template

The example workspace uses:

```yaml
version: v2
plugins:
  - local: examples/protobuf/plugins/protoc-gen-example
    out: examples/protobuf/gen/example
```

That template keeps the example and tests self-contained. Additional template presets live under [`examples/protobuf/templates`](../examples/protobuf/templates):

- [`buf.gen.go.yaml`](../examples/protobuf/templates/buf.gen.go.yaml)
- [`buf.gen.ts.yaml`](../examples/protobuf/templates/buf.gen.ts.yaml)
- [`buf.gen.java.yaml`](../examples/protobuf/templates/buf.gen.java.yaml)

These presets are examples only. `buf_generate` always consumes the caller's own template file.

### Dependency Lock Maintenance

```starlark
buf_dep_update(
    name = "dep_update",
    config = ":buf.yaml",
)
```

Run this when your `buf.yaml` dependencies change. If the module has no external dependencies, the command may effectively no-op.

## Example Mapping

The protobuf example workspace is the reference usage:

- BUILD target definitions: [`examples/protobuf/BUILD.bazel`](../examples/protobuf/BUILD.bazel)
- Buf config: [`examples/protobuf/buf.yaml`](../examples/protobuf/buf.yaml)
- Default generation template: [`examples/protobuf/buf.gen.yaml`](../examples/protobuf/buf.gen.yaml)
- Schema: [`examples/protobuf/proto/acme/weather/v1/weather.proto`](../examples/protobuf/proto/acme/weather/v1/weather.proto)

Example targets:

- `//examples/protobuf:format`
- `//examples/protobuf:format_check`
- `//examples/protobuf:lint`
- `//examples/protobuf:breaking`
- `//examples/protobuf:breaking_explicit`
- `//examples/protobuf:generate`
- `//examples/protobuf:dep_update`

## Limits And Non-Goals

- Only v2 Buf config files are in scope:
  - `buf.yaml`
  - `buf.gen.yaml`
  - `buf.lock`
- This capability does not provide `proto_library` integration or language-specific Bazel protobuf graph helpers.
- It does not provide BSR publish flows or registry authentication helpers.
- `buf_generate` and `buf_dep_update` are intentionally source-tree-writing operations.
- Plugin execution policy belongs to the caller. The capability only wires Buf itself.

## Troubleshooting

### `buf_breaking` fails because `git` is missing

That only affects the default baseline mode. Either install `git` on the host or provide an explicit `against` value.

### `buf_generate` cannot find a plugin

The template is passed through to Buf as-is. Verify the plugin path or remote plugin reference in your `buf.gen.yaml`.

### `buf_dep_update` does not create a lockfile

If your module declares no external dependencies, Buf may leave no `buf.lock` behind. That is normal.

### Formatting or linting runs against the wrong directory

The rule derives its input root from the directory that contains `config`. Point `config` at the `buf.yaml` you actually want Buf to treat as the root.

### Windows and local plugins

The example local plugin is a shell stub used for offline tests. Real local plugins must be executable for the target host environment.
