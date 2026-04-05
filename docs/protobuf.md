# protobuf

`protobuf` is no longer a repo-owned Bazel capability in `bazel-kit`.

This is an intentional breaking pivot: protobuf support now means "use upstream [`rules_buf`](https://github.com/bufbuild/rules_buf) and Gazelle directly", with this repo only keeping:

- migration guidance
- a copyable official example under [`examples/protobuf`](../examples/protobuf)

As of April 5, 2026, the latest `rules_buf` release is `v0.5.2` (published on August 22, 2025), and that is what the example in this repo is pinned to. Source: [rules_buf latest release](https://github.com/bufbuild/rules_buf/releases/tag/v0.5.2)

## Breaking Change

The following repo-owned protobuf surfaces are removed:

- `@codesjoy_bazel_kit//rules/protobuf:buf.bzl`
- `@codesjoy_bazel_kit//gazelle/protobuf`
- custom `buf_format_check`, `buf_lint`, `buf_breaking`, `buf_generate`, `buf_dep_update`
- Bazel-managed `protoc-gen-codesjoy-*` plugin repos from this repo
- custom Gazelle directives such as `codesjoy_protobuf` and `codesjoy_protobuf_plugin`

Use upstream `rules_buf` for:

- `buf_format`
- `buf_lint_test`
- `buf_breaking_test`
- Gazelle generation of `proto_library`, `buf_lint_test`, and `buf_breaking_test`

Use the Buf CLI via `@rules_buf_toolchains//:buf` for:

- `buf generate`
- `buf dep update`

## Bzlmod Setup

Minimal setup for the official path:

```starlark
bazel_dep(name = "gazelle", version = "0.47.0", repo_name = "bazel_gazelle")
bazel_dep(name = "rules_buf", version = "0.5.2")
bazel_dep(name = "rules_proto", version = "7.1.0")

buf = use_extension("@rules_buf//buf:extensions.bzl", "buf")
buf.toolchains(
    version = "v1.47.2",
    sha256 = "1b37b75dc0a777a0cba17fa2604bc9906e55bb4c578823d8b7a8fe3fc9fe4439",
)

use_repo(buf, "rules_buf_toolchains")

register_toolchains("@rules_buf_toolchains//:all")
```

This repo’s own example uses exactly that shape in [`MODULE.bazel`](../MODULE.bazel).

## Gazelle Setup

Buf’s official Gazelle guidance is to add the Buf extension after Gazelle’s native proto language. Source: [Buf Bazel docs, Gazelle setup](https://buf.build/docs/cli/build-systems/bazel/#gazelle)

```starlark
load("@bazel_gazelle//:def.bzl", "gazelle", "gazelle_binary")
load("@rules_buf//buf:defs.bzl", "buf_format")

package(default_visibility = ["//visibility:public"])

exports_files([
    "against.binpb",
    "buf.yaml",
])

# gazelle:buf_breaking_against //examples/protobuf:against.binpb

gazelle_binary(
    name = "gazelle_buf",
    languages = [
        "@bazel_gazelle//language/proto:go_default_library",
        "@rules_buf//gazelle/buf:buf",
    ],
)

gazelle(
    name = "gazelle",
    gazelle = ":gazelle_buf",
    args = ["examples/protobuf"],
)

buf_format(
    name = "buf_format",
)
```

Important behavior:

- `exports_files(["buf.yaml"])` is required so generated rules in subpackages can reference the module root config.
- `# gazelle:buf_breaking_against ...` is required before Gazelle can generate `buf_breaking_test`.
- Module mode is the default and recommended mode for breaking checks because it can detect deleted files. Source: [Buf Bazel docs, breaking detection](https://buf.build/docs/cli/build-systems/bazel/#gazelle)
- Package mode exists via `# gazelle:buf_breaking_mode package`, but this guide does not use it as the default.

## Example Layout

See [`examples/protobuf`](../examples/protobuf) for the full pinned example.

The shape is intentionally small:

- root `BUILD.bazel` with `gazelle_binary`, `gazelle`, `buf_format`, exported `buf.yaml`, and a checked-in baseline image
- root `buf.yaml`
- a normal protobuf source tree under `proto/...`
- Gazelle-generated `BUILD.bazel` files in protobuf packages containing `proto_library` and `buf_lint_test`
- a Gazelle-generated `buf_breaking_test` in the Buf module root package; in this repo that package is [`examples/protobuf/proto`](../examples/protobuf/proto)

## Caller-Owned CLI Workflows

This repo no longer wraps generation or dep maintenance. Use the upstream Buf CLI through the toolchain repo:

```bash
bazel run @rules_buf_toolchains//:buf -- generate examples/protobuf
bazel run @rules_buf_toolchains//:buf -- dep update examples/protobuf
```

To refresh the checked-in breaking baseline image in the example:

```bash
bazel run @rules_buf_toolchains//:buf -- build --exclude-imports examples/protobuf -o examples/protobuf/against.binpb
```

## Migration Map

If you were using the old `bazel-kit` protobuf wrappers, migrate as follows:

| Old usage | New path |
| --- | --- |
| `buf_format` wrapper from this repo | upstream `@rules_buf//buf:defs.bzl` `buf_format` |
| `buf_lint` wrapper | generated upstream `buf_lint_test` via Gazelle |
| `buf_breaking` wrapper | generated upstream `buf_breaking_test` via Gazelle plus `buf_breaking_against` |
| `buf_generate` wrapper | `bazel run @rules_buf_toolchains//:buf -- generate ...` |
| `buf_dep_update` wrapper | `bazel run @rules_buf_toolchains//:buf -- dep update ...` |
| custom protobuf Gazelle extension | upstream `@rules_buf//gazelle/buf:buf` |

There is no compatibility shim in this repo. The pivot is intentionally direct.

## Validation Commands

The rewritten example is expected to satisfy these commands:

```bash
bazel run //examples/protobuf:gazelle
bazel query 'kind(buf_lint_test, //examples/protobuf/...)'
bazel query 'kind(buf_breaking_test, //examples/protobuf/...)'
bazel run //examples/protobuf:buf_format
bazel run @rules_buf_toolchains//:buf -- --version
```

## Limits

- This repo no longer manages protobuf plugins or protobuf-specific tool repos.
- This repo does not wrap `proto_library` or generate language-specific protobuf build graphs.
- Breaking-check image lifecycle remains caller-owned even when Gazelle generates the tests.
