# modelgen

`modelgen` provides Bazel-managed access to `codesjoy-modelgen` from `github.com/codesjoy/pkg/tools/codesjoy-modelgen`.

The capability is intentionally separate from `protobuf`: this tool is a database-backed source generator, not a protoc or Buf plugin. It is exposed as a runnable Bazel rule so callers can keep the tool version pinned in Bazel while still running generation against the live workspace.

## Overview

- Public entrypoint: `@codesjoy_bazel_kit//rules/modelgen:defs.bzl`
- Managed tool extension: `modelgen_tools`
- Managed repo: `modelgen_tool_codesjoy_modelgen`
- Pinned source baseline: `github.com/codesjoy/pkg@9bfa697c14eeb20cfd5b7193e459525459e08406`
- Example workspace: [`examples/modelgen`](../examples/modelgen)

## Design And Rationale

### Why This Is A Separate Capability

`codesjoy-modelgen` is not a protobuf plugin and does not fit the `protobuf` capability boundary. Its operational model is:

- connect to a live MySQL or PostgreSQL database
- inspect table metadata
- write Go model source files into the workspace
- optionally emit `aipsql` metadata helpers

That workflow is database-driven, source-tree-writing, and independent from Buf or protoc generation.

### Why The Tool Is Built From A Pinned `codesjoy/pkg` Commit

The upstream repository currently does not provide a tagged binary release stream for these tools. To keep Bazel integration reproducible, `bazel-kit` pins the source archive to:

```text
9bfa697c14eeb20cfd5b7193e459525459e08406
```

The rule builds the tool from source in a repository rule rather than expecting the caller to preinstall it.

## Managed Tools And Prerequisites

### Bzlmod Setup

```starlark
modelgen_tools = use_extension("@codesjoy_bazel_kit//rules/modelgen:extensions.bzl", "modelgen_tools")
modelgen_tools.install()

use_repo(
    modelgen_tools,
    "modelgen_tool_codesjoy_modelgen",
)
```

Optional explicit pin:

```starlark
modelgen_tools.pkg_override(commit = "9bfa697c14eeb20cfd5b7193e459525459e08406")
```

### Host Prerequisites

- No host `codesjoy-modelgen` install is required.
- Running the rule still requires access to the target database.
- Any required network path, credentials, or local Docker setup are the caller's responsibility.

## Public API

Load from:

```starlark
load("@codesjoy_bazel_kit//rules/modelgen:defs.bzl", "codesjoy_modelgen")
```

### Rule Reference

```starlark
codesjoy_modelgen(
    name = "generate_models",
    dsn = "...",
    out_dir = "internal/model",
    schema = "public",
    tables = ["users"],
    override = ":override.yaml",
    gen_aipsql = True,
    timestamp_mode = "unix_sec",
    dry_run = False,
    force = False,
    package_name = "model",
)
```

| Attr | Required | Meaning |
| --- | --- | --- |
| `dsn` | yes | Database connection string |
| `out_dir` | yes | Output directory written relative to `BUILD_WORKSPACE_DIRECTORY` |
| `schema` | no | Database schema name |
| `tables` | no | Table allow-list; passed as a comma-separated flag |
| `override` | no | YAML override file |
| `gen_aipsql` | no | Whether to emit AIP SQL helpers |
| `timestamp_mode` | no | `unix_sec`, `unix_milli`, or `unix_nano` |
| `dry_run` | no | Preview mode without writing files |
| `force` | no | Allow overwriting protected outputs |
| `package_name` | no | Explicit generated package name |

## Common Workflows

### Minimal Usage

```starlark
load("@codesjoy_bazel_kit//rules/modelgen:defs.bzl", "codesjoy_modelgen")

codesjoy_modelgen(
    name = "generate_models",
    dsn = "postgres://user:pass@127.0.0.1:5432/demo?sslmode=disable",
    schema = "public",
    tables = ["users"],
    out_dir = "internal/model",
)
```

### Example With Override File

```starlark
codesjoy_modelgen(
    name = "generate_models",
    dsn = "postgres://modelgen:modelgen@127.0.0.1:5432/modelgen_it?sslmode=disable",
    schema = "public",
    tables = ["users"],
    out_dir = "examples/modelgen/output",
    override = ":override.yaml",
    gen_aipsql = True,
    timestamp_mode = "unix_nano",
    package_name = "output",
)
```

## Example Mapping

Reference files:

- BUILD target: [`examples/modelgen/BUILD.bazel`](../examples/modelgen/BUILD.bazel)
- override file: [`examples/modelgen/override.yaml`](../examples/modelgen/override.yaml)
- example notes: [`examples/modelgen/README.md`](../examples/modelgen/README.md)

Reference target:

- `//examples/modelgen:generate_models`

The example is intentionally not executed in CI because it requires a live database.

## Limits And Troubleshooting

- This capability does not provision a database.
- CI only validates the launcher shape, not a real generation run.
- DSN correctness, network reachability, schema existence, and credential validity remain caller-owned.
- The pinned `codesjoy/pkg` commit is intentionally strict; unknown commits are rejected by the extension.
