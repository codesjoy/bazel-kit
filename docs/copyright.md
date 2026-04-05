# copyright

`copyright` wraps the open-source `addlicense` CLI as a Bazel-managed runnable workflow for add/check operations.

## Bzlmod Setup

```starlark
copyright_tools = use_extension("@codesjoy_bazel_kit//rules/copyright:extensions.bzl", "copyright_tools")
copyright_tools.install()

use_repo(
    copyright_tools,
    "copyright_tool_addlicense",
)
```

## Public API

```starlark
load("@codesjoy_bazel_kit//rules/copyright:defs.bzl", "copyright_add", "copyright_verify")
```

- `copyright_add`
- `copyright_verify`

Common attrs:

- `boilerplate`
- `roots`
- `patterns`
- `year`

File discovery excludes `vendor/`, `_output/`, `.tmp/`, `.git/`, and `bazel-*` directories by default.

## Example

See [`examples/copyright`](../examples/copyright).
