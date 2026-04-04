# web

`web` provides a Bazel-managed frontend workflow surface for Vite-based TypeScript projects.

It is intentionally separate from `quality`: `quality` handles formatting and linting, while `web` handles project initialization, dependency installation, dev/build flows, type checking, unit tests, Playwright browser installation, and end-to-end tests.

## Overview

- Public entrypoint:
  - `@codesjoy_bazel_kit//rules/web:defs.bzl`
- Managed runtime extension:
  - `web_tools`
- Quality companion entrypoint:
  - `@codesjoy_bazel_kit//rules/quality:web.bzl`
- Example workspace:
  - [`examples/web/vite`](../examples/web/vite)

## Bzlmod Setup

```starlark
quality_tools = use_extension("@codesjoy_bazel_kit//rules/quality:extensions.bzl", "quality_tools")
quality_tools.install(domains = ["web"])

web_tools = use_extension("@codesjoy_bazel_kit//rules/web:extensions.bzl", "web_tools")
web_tools.install()

use_repo(
    quality_tools,
    "quality_tool_biome",
)

use_repo(
    web_tools,
    "web_tool_node",
    "web_tool_pnpm",
)
```

## Managed Tools

### `quality/web`

`quality/web` installs a standalone Biome binary and uses it for:

- `web_fmt`
- `web_fmt_check`
- `web_lint`

Default managed version:

| Tool | Default version | Notes |
| --- | --- | --- |
| `biome` | `v2.4.10` | standalone binary |

### `web_tools`

`web_tools` provisions the runtime layer used by the workflow rules:

| Tool | Default version | Notes |
| --- | --- | --- |
| `node` | `v24.14.1` | downloaded archive, exposes `node` |
| `pnpm` | `v10.33.0` | downloaded npm tarball, executed through managed Node |

Overrides are explicit and curated:

```starlark
web_tools.override(name = "node", version = "v24.14.1")
web_tools.override(name = "pnpm", version = "v10.33.0")
quality_tools.override(domain = "web", name = "biome", version = "v2.4.10")
```

## Public API

Load the workflow rules from:

```starlark
load("@codesjoy_bazel_kit//rules/web:defs.bzl", "web_browser_install", "web_build", "web_dev", "web_e2e", "web_init", "web_install", "web_preview", "web_test", "web_typecheck")
```

| Rule | Required attrs | Writes source tree? | Behavior |
| --- | --- | --- | --- |
| `web_init` | `project_dir`, `package_name` | yes | Generates a Vite + vanilla TypeScript starter |
| `web_install` | `project_dir` | yes | Runs `pnpm install`, using `--frozen-lockfile` when `pnpm-lock.yaml` exists |
| `web_dev` | `project_dir` | no | Runs `pnpm exec vite dev --host 0.0.0.0` |
| `web_build` | `project_dir` | yes | Runs `pnpm exec vite build` |
| `web_preview` | `project_dir` | no | Runs `pnpm exec vite preview --host 0.0.0.0` |
| `web_typecheck` | `project_dir` | no | Runs `pnpm exec tsc --noEmit` |
| `web_test` | `project_dir` | no | Runs `pnpm exec vitest run` |
| `web_browser_install` | `project_dir` | yes | Runs `pnpm exec playwright install` |
| `web_e2e` | `project_dir` | no | Runs `pnpm exec playwright test` after browser assets exist |

## Generated Starter

`web_init` writes:

- `package.json`
- `biome.json`
- `tsconfig.json`
- `vite.config.ts`
- `vitest.config.ts`
- `playwright.config.ts`
- `index.html`
- `src/main.ts`
- `src/counter.ts`
- `src/style.css`
- `tests/counter.test.ts`
- `e2e/app.spec.ts`

If `project_dir` is nested and the workspace root does not already contain `pnpm-workspace.yaml`, the rule writes a minimal file that points at the generated project path.

## Operational Notes

- All commands run against `BUILD_WORKSPACE_DIRECTORY`, not Bazel runfiles.
- The rules prepend the managed Node binary to `PATH`, so locally installed Node is not required.
- `pnpm` always uses a workspace-local store at `.pnpm-store`.
- Playwright browsers are installed into `.playwright-browsers`.
- `web_e2e` fails fast if browser assets are missing; it does not perform implicit downloads.
- v1 is intentionally scoped to stable `js/jsx/ts/tsx/json/jsonc/css/html` flows and a Vite + vanilla TypeScript starter.

## Example Targets

- `//examples/web/vite:install`
- `//examples/web/vite:build`
- `//examples/web/vite:typecheck`
- `//examples/web/vite:test`
- `//examples/web/vite:browser_install`
- `//examples/web/vite:e2e`
