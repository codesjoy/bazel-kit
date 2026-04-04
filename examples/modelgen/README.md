# modelgen example

This example wires `codesjoy-modelgen` into Bazel as a managed runnable tool.

It is intentionally build-only in CI. The target demonstrates how to configure
the launcher, but a live PostgreSQL database is still required to execute the
generator successfully.

Reference target:

```bash
bazel run //examples/modelgen:generate_models
```

The committed configuration mirrors the upstream `codesjoy-modelgen` example:

- schema: `public`
- table list: `users`
- timestamp mode: `unix_nano`
- override file: [`override.yaml`](./override.yaml)

Because the tool talks to a live database, `bazel test //...` only runs a
launcher smoke test for this example instead of executing the generator.
