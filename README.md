# bazel-kit

`bazel-kit` is a shared repository for reusable Bazel capabilities used across codesjoy workspaces.

The repository is organized around capability-focused, runnable workflows rather than broad rule ecosystems. Each capability exposes a small public API, manages the external tools it owns through Bzlmod when that adds reproducibility, and keeps usage examples next to the implementation.

## What This Repo Provides

### `devx`

`devx` provides repo-level developer workflow entrypoints such as `devx_workflow`, `devx_doctor`, and `pre-commit` hook lifecycle wrappers. Read [docs/devx.md](docs/devx.md) and inspect [examples/devx](examples/devx).

### `quality`

`quality` manages code-quality workflows for Go, shell, and stable web frontend files. It exposes `go_fmt`, `go_fmt_check`, `go_lint`, `shell_lint`, `shell_scripts_lint`, `web_fmt`, `web_fmt_check`, and `web_lint`. Read [docs/quality.md](docs/quality.md) and inspect [examples/quality/go](examples/quality/go), [examples/quality/shell](examples/quality/shell), and [examples/quality/web](examples/quality/web).

### `web`

`web` manages a frontend workflow around Vite + TypeScript. It provisions Node and pnpm through `web_tools`, and exposes `web_init`, `web_install`, `web_build`, `web_typecheck`, `web_test`, `web_browser_install`, and `web_e2e`. Read [docs/web.md](docs/web.md) and inspect [examples/web/vite](examples/web/vite).

### `protobuf`

`protobuf` is documented here as an official `rules_buf` integration path, not a repo-owned rule surface. This repo keeps migration notes plus a copyable example. Read [docs/protobuf.md](docs/protobuf.md) and inspect [examples/protobuf](examples/protobuf).

### `modelgen`

`modelgen` manages the `codesjoy-modelgen` binary from `github.com/codesjoy/pkg/tools` and exposes a runnable Bazel rule for database-driven GORM model generation. Read [docs/modelgen.md](docs/modelgen.md) and inspect [examples/modelgen](examples/modelgen).

### `workspace`

`workspace` provides maintenance helpers for multi-module Go repositories: `workspace_sync`, `go_mod_tidy`, `go_mod_download`, `go_mod_verify`, `workspace_drift_check`, `workspace_modules_print`, and `go_clean`. Read [docs/workspace.md](docs/workspace.md) and inspect [examples/workspace](examples/workspace).

### `wire`

`wire` provides Bazel-managed access to `google/wire` for generation and drift checking. Read [docs/wire.md](docs/wire.md) and inspect [examples/wire](examples/wire).

### `migrate`

`migrate` wraps `golang-migrate` for repo-native migration workflows while keeping DSNs in runtime env vars when desired. Read [docs/migrate.md](docs/migrate.md) and inspect [examples/migrate](examples/migrate).

### `changelog`

`changelog` wraps `git-chglog` behind Bazel launchers while preserving the `.chglog` config/state contract used by the shell base. Read [docs/changelog.md](docs/changelog.md) and inspect [examples/changelog](examples/changelog).

### `copyright`

`copyright` wraps `addlicense` for add/check flows with repo-local boilerplate and file discovery rules. Read [docs/copyright.md](docs/copyright.md) and inspect [examples/copyright](examples/copyright).

### `pipeline`

`pipeline` provides a Bazel-driven CI/CD orchestration layer for monorepos and microservices. It exposes service declarations, a catalog export, impact analysis, Helm rendering, and reusable GitHub Actions + Argo CD integration helpers. Read [docs/pipeline.md](docs/pipeline.md) and inspect [examples/pipeline/monorepo](examples/pipeline/monorepo).

## Quick Start

```starlark
bazel_dep(name = "codesjoy_bazel_kit", version = "0.2.0")

quality_tools = use_extension("@codesjoy_bazel_kit//rules/quality:extensions.bzl", "quality_tools")
quality_tools.install(domains = ["go", "shell", "web"])

web_tools = use_extension("@codesjoy_bazel_kit//rules/web:extensions.bzl", "web_tools")
web_tools.install()

modelgen_tools = use_extension("@codesjoy_bazel_kit//rules/modelgen:extensions.bzl", "modelgen_tools")
modelgen_tools.install()

pipeline_tools = use_extension("@codesjoy_bazel_kit//rules/pipeline:extensions.bzl", "pipeline_tools")
pipeline_tools.install()

wire_tools = use_extension("@codesjoy_bazel_kit//rules/wire:extensions.bzl", "wire_tools")
wire_tools.install()

migrate_tools = use_extension("@codesjoy_bazel_kit//rules/migrate:extensions.bzl", "migrate_tools")
migrate_tools.install()

changelog_tools = use_extension("@codesjoy_bazel_kit//rules/changelog:extensions.bzl", "changelog_tools")
changelog_tools.install()

copyright_tools = use_extension("@codesjoy_bazel_kit//rules/copyright:extensions.bzl", "copyright_tools")
copyright_tools.install()

use_repo(
    quality_tools,
    "quality_tool_biome",
    "quality_tool_gofumpt",
    "quality_tool_goimports",
    "quality_tool_golangci_lint",
    "quality_tool_golines",
    "quality_tool_shellcheck",
    "quality_tool_shfmt",
)

use_repo(web_tools, "web_tool_node", "web_tool_pnpm")
use_repo(modelgen_tools, "modelgen_tool_codesjoy_modelgen")
use_repo(pipeline_tools, "pipeline_tool_helm")
use_repo(wire_tools, "wire_tool_wire")
use_repo(migrate_tools, "migrate_tool_migrate")
use_repo(changelog_tools, "changelog_tool_git_chglog")
use_repo(copyright_tools, "copyright_tool_addlicense")
```

From there, load the rule entrypoints you need:

- `@codesjoy_bazel_kit//rules/devx:defs.bzl`
- `@codesjoy_bazel_kit//rules/quality:go.bzl`
- `@codesjoy_bazel_kit//rules/quality:shell.bzl`
- `@codesjoy_bazel_kit//rules/quality:web.bzl`
- `@codesjoy_bazel_kit//rules/web:defs.bzl`
- `@codesjoy_bazel_kit//rules/modelgen:defs.bzl`
- `@codesjoy_bazel_kit//rules/workspace:defs.bzl`
- `@codesjoy_bazel_kit//rules/wire:defs.bzl`
- `@codesjoy_bazel_kit//rules/migrate:defs.bzl`
- `@codesjoy_bazel_kit//rules/changelog:defs.bzl`
- `@codesjoy_bazel_kit//rules/copyright:defs.bzl`
- `@codesjoy_bazel_kit//rules/pipeline:defs.bzl`

For protobuf, use upstream `rules_buf` directly instead of a `bazel-kit` wrapper. The repository’s official setup example and migration notes live in [docs/protobuf.md](docs/protobuf.md).

## Capability Matrix

| Capability | Public entrypoints | Managed tools | Writes source tree? | Host prerequisites | Example targets |
| --- | --- | --- | --- | --- | --- |
| `devx` | `devx_workflow`, `devx_doctor`, `hooks_install`, `hooks_verify`, `hooks_run`, `hooks_run_all`, `hooks_clean` | none | no direct source writes; hooks install mutates `.git/hooks` | `bazel`, repo-owned `.pre-commit-config.yaml`, optional Python 3 for `pre-commit` bootstrap | `//examples/devx:check`, `//examples/devx:doctor` |
| `quality` | `go_fmt`, `go_fmt_check`, `go_lint`, `shell_lint`, `shell_scripts_lint`, `web_fmt`, `web_fmt_check`, `web_lint` | `gofumpt`, `goimports`, `golines`, `golangci-lint`, `shfmt`, optional `shellcheck`, `biome` | `go_fmt` and `web_fmt` write source files; the check and lint rules do not | no separate formatter/linter install is required | `//examples/quality/go:fmt`, `//examples/quality/shell:lint`, `//examples/quality/web:lint` |
| `web` | `web_init`, `web_install`, `web_dev`, `web_build`, `web_preview`, `web_typecheck`, `web_test`, `web_browser_install`, `web_e2e` | `node`, `pnpm` | `web_init`, `web_install`, `web_build`, and `web_browser_install` write the source workspace or local tool cache directories | no separate Node or pnpm install is required | `//examples/web/vite:install`, `//examples/web/vite:build` |
| `protobuf` | none in this repo; use upstream `@rules_buf//buf:defs.bzl` and `@rules_buf//gazelle/buf:buf` | upstream `rules_buf` toolchains | upstream `buf_format` writes source files; generated lint/breaking tests do not | image maintenance for breaking checks remains caller-owned | `//examples/protobuf:gazelle`, `//examples/protobuf:buf_format` |
| `modelgen` | `codesjoy_modelgen` | `codesjoy-modelgen` | yes | reachable database; prefer `dsn_env` to keep secrets out of BUILD files | `//examples/modelgen:generate_models` |
| `workspace` | `workspace_sync`, `go_mod_tidy`, `go_mod_download`, `go_mod_verify`, `workspace_drift_check`, `workspace_modules_print`, `go_clean` | none | `workspace_sync` rewrites `go.work`; `go_clean` removes `_output` | `go`, `bazel` for sync flows | `//examples/workspace:sync` |
| `wire` | `wire_gen`, `wire_diff`, `wire_check` | `wire` | yes for `wire_gen`; diff/check only validate | `go`; DI source layout remains caller-owned | `//examples/wire:gen`, `//examples/wire:check` |
| `migrate` | `migrate_up`, `migrate_down`, `migrate_version`, `migrate_force` | `migrate` | no repo writes by default | reachable database; prefer `dsn_env` for secrets | `//examples/migrate:up`, `//examples/migrate:version` |
| `changelog` | `changelog_init`, `changelog_generate`, `changelog_preview`, `changelog_verify`, `changelog_state_print`, `changelog_state_reset` | `git-chglog` | yes; scaffold init and changelog generation update repo files | `git`; repo-owned commit history | `//examples/changelog:init`, `//examples/changelog:generate` |
| `copyright` | `copyright_add`, `copyright_verify` | `addlicense` | `copyright_add` writes source headers | repo-owned boilerplate template | `//examples/copyright:add`, `//examples/copyright:verify` |
| `pipeline` | `pipeline_service`, `pipeline_catalog`, `pipeline_plan`, `pipeline_helm_render` | `helm` | `pipeline_helm_render` writes rendered manifests to an explicit output directory; GitOps helper scripts update external repos | Python 3, `bazel`, optional `git`, and Helm through `pipeline_tools` | `//examples/pipeline/monorepo:plan`, `//examples/pipeline/monorepo:api_render` |

## Design Conventions

- A **capability** is a narrow, cohesive workflow surface such as `quality`, `workspace`, or `pipeline`.
- A **managed tool** is a binary installed through a module extension and imported into the repo with `use_repo`, rather than something callers are expected to preinstall manually.
- A **source-tree-writing** rule is a runnable target that intentionally updates files in `BUILD_WORKSPACE_DIRECTORY`.
- Public APIs stay small on purpose. If a workflow needs more policy, it should usually live in repo config files or surrounding BUILD logic rather than in a wide Bazel abstraction layer here.

## Documentation Map

- [docs/devx.md](docs/devx.md): workflow aggregation, doctor, and pre-commit hook wrappers
- [docs/quality.md](docs/quality.md): Go, shell, and web formatting/linting workflows
- [docs/web.md](docs/web.md): runtime pinning, rule reference, and generated starter shape
- [docs/protobuf.md](docs/protobuf.md): official `rules_buf` migration and example
- [docs/modelgen.md](docs/modelgen.md): pinned tool build and database-backed model generation
- [docs/workspace.md](docs/workspace.md): `go.work` sync, drift checks, module ops, and cleanup
- [docs/wire.md](docs/wire.md): Wire generation and drift checks
- [docs/migrate.md](docs/migrate.md): migration runners and DSN handling
- [docs/changelog.md](docs/changelog.md): changelog scaffold, generation, verification, and state
- [docs/copyright.md](docs/copyright.md): add/check header workflows
- [docs/pipeline.md](docs/pipeline.md): service catalog, impact analysis, Helm rendering, and GitOps contracts

## Example Map

- [examples/devx](examples/devx): workflow aggregation and doctor entrypoints
- [examples/quality/go](examples/quality/go): `go_fmt`, `go_fmt_check`, and `go_lint`
- [examples/quality/shell](examples/quality/shell): `shell_lint`
- [examples/quality/web](examples/quality/web): `web_fmt`, `web_fmt_check`, and `web_lint`
- [examples/web/vite](examples/web/vite): `web_install`, `web_build`, `web_typecheck`, `web_test`, `web_browser_install`, and `web_e2e`
- [examples/protobuf](examples/protobuf): official `rules_buf` + Gazelle setup
- [examples/modelgen](examples/modelgen): launcher wiring for `codesjoy_modelgen`
- [examples/workspace](examples/workspace): `workspace_sync` with a follow-up executable target
- [examples/wire](examples/wire): `wire_gen`, `wire_diff`, and `wire_check`
- [examples/migrate](examples/migrate): migration runners using `dsn_env`
- [examples/changelog](examples/changelog): changelog init/generate/verify/state targets
- [examples/copyright](examples/copyright): add/check license headers
- [examples/pipeline/monorepo](examples/pipeline/monorepo): service catalog, change analysis, Helm charts, GitOps config, and Argo `ApplicationSet` samples
