# migrate

`migrate` wraps the open-source `golang-migrate` CLI as a Bazel-managed runnable workflow.

## Bzlmod Setup

```starlark
migrate_tools = use_extension("@codesjoy_bazel_kit//rules/migrate:extensions.bzl", "migrate_tools")
migrate_tools.install()

use_repo(
    migrate_tools,
    "migrate_tool_migrate",
)
```

## Public API

```starlark
load("@codesjoy_bazel_kit//rules/migrate:defs.bzl", "migrate_down", "migrate_force", "migrate_up", "migrate_version")
```

- `migrate_up`
- `migrate_down`
- `migrate_version`
- `migrate_force`

Common attrs:

- exactly one of `dsn` or `dsn_env`
- `migrations_dir`
- `table`, default `schema_migrations`

Additional attrs:

- `down_steps` for `migrate_down`
- `force_version` for `migrate_force`

The launcher appends `x-migrations-table` to the DSN using the same query-string rules as the prior Makefile base.

## Example

See [`examples/migrate`](../examples/migrate).
