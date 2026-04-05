# Protobuf Example

This example shows the official `rules_buf` + Gazelle setup used by `bazel-kit` after the protobuf pivot.

Useful commands:

```bash
bazel run //examples/protobuf:gazelle
bazel query 'kind(buf_lint_test, //examples/protobuf/...)'
bazel query 'kind(buf_breaking_test, //examples/protobuf/...)'
bazel run //examples/protobuf:buf_format
bazel run @rules_buf_toolchains//:buf -- generate examples/protobuf
bazel run @rules_buf_toolchains//:buf -- dep update examples/protobuf
```
