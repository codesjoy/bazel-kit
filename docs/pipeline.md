# pipeline

`pipeline` provides a Bazel-driven CI/CD flow layer for monorepos and microservice workspaces.

The capability is intentionally orchestration-focused. It does not replace language-specific build and test rules, and it does not invent a repo-owned container stack. Instead, it gives repositories a common service declaration surface, a catalog export, a change analyzer, a Helm render runner, and reusable workflow contracts that connect Bazel, GitHub Actions, and Argo CD GitOps delivery.

## Overview

- Public entrypoints:
  - `@codesjoy_bazel_kit//rules/pipeline:defs.bzl`
  - `@codesjoy_bazel_kit//rules/pipeline:extensions.bzl`
- Managed tool extension:
  - `pipeline_tools`
- Managed tool:
  - `helm`
- Example workspace:
  - [`examples/pipeline/monorepo`](../examples/pipeline/monorepo)

## Managed Tooling

### Bzlmod Setup

```starlark
pipeline_tools = use_extension("@codesjoy_bazel_kit//rules/pipeline:extensions.bzl", "pipeline_tools")
pipeline_tools.install()

use_repo(
    pipeline_tools,
    "pipeline_tool_helm",
)
```

The pipeline capability only manages `helm` in v1. Image build and push remain caller-owned; the recommended path is upstream `rules_oci` plus a repo-local wrapper target that follows the image target contract described below.

## Public API

Load the public entrypoints from:

```starlark
load(
    "@codesjoy_bazel_kit//rules/pipeline:defs.bzl",
    "pipeline_catalog",
    "pipeline_helm_render",
    "pipeline_plan",
    "pipeline_service",
)
```

### `pipeline_service`

`pipeline_service` declares one deployable service in the monorepo.

Required attrs:

- `language`: one of `go`, `web`, `custom`
- `lint_targets`
- `unit_targets`
- `image_targets`
- `render_target`

Optional attrs:

- `service_name`, default the target name
- `analysis_targets`
- `integration_targets`
- `runtime_deps`
- `workload_kind`, default `deployment`, also supports `worker`
- `preview_mode`, default `shared_baseline`, also supports `full_isolated`
- `deploy_environments`, default `["dev", "staging", "prod"]`

### `analysis_targets`

Impact analysis is only as good as the Bazel graph edges you expose. If your lint, test, or render targets are opaque runnable wrappers that do not list source files as Bazel inputs, set `analysis_targets` explicitly to a filegroup or build graph root that does capture the service sources and shared dependencies. The pipeline macro falls back to the stage targets only when `analysis_targets` is omitted.

### `pipeline_catalog`

`pipeline_catalog` exports the declared services into a stable JSON file. That file is what GitHub workflows and helper scripts consume to build matrices and resolve render targets.

Optional attr:

- `repo_config`: a repo-owned JSON file with GitOps, environment, and image repository settings

### `pipeline_plan`

`pipeline_plan` is a runnable target that expands affected services and stage matrices.

Supported runtime args:

- `--changed-files path1,path2`
- `--changed-files-file <file>`
- `--base <git ref> --head <git ref>`
- `--baseline-environment <env>`, default `itest-baseline`
- `--output <file>`

The runner maps changed files to Bazel package expressions, queries reverse dependencies, intersects the result with the service labels from the catalog, and emits a JSON payload with:

- `service_matrix`
- `lint_matrix`
- `unit_matrix`
- `integration_matrix`
- `image_matrix`
- `render_matrix`

### `pipeline_helm_render`

`pipeline_helm_render` is a runnable target that renders a checked-in Helm chart into static YAML.

Required attrs:

- `chart_dir`
- `chart_files`

Optional attrs:

- `service_name`
- `release_name`

Supported runtime args:

- `--environment`
- `--output-dir`
- `--namespace`
- `--host`
- `--image-repository`
- `--image-tag`
- `--image-digest`
- `--preview-id`
- `--baseline-environment`
- `--runtime-dependency name=url`
- `--values-file`
- `--set-string`

The runner always injects a generated values file containing `pipeline`, `image`, `ingress`, and `runtimeDependencies` data. Repositories can reference those keys directly in their chart templates.

## Repo Config Contract

The workflow helpers in [`scripts/pipeline`](../scripts/pipeline) expect a repo-owned JSON file. The checked-in example is [`examples/pipeline/monorepo/pipeline.json`](../examples/pipeline/monorepo/pipeline.json).

The current contract includes:

- top-level `gitops_repo`
- top-level `baseline_environment`
- top-level `argocd`
- `preview`
  - `gitops_root`
  - `namespace_template`
  - `host_template`
  - `scheme`
- `environments.<name>`
  - `gitops_root`
  - `namespace_template`
  - `host_template`
  - `scheme`
- `services.<service>.image_repository`

Templates use `${service}`, `${environment}`, and `${preview_id}` substitutions.

## Image Target Contract

The pipeline capability does not own container rules, so image targets stay repo-local. The workflow helpers assume an image target can be executed like this:

```bash
bazel run //path/to:image_target -- \
  --image-repository ghcr.io/acme/service \
  --image-tag main-abcdef0 \
  --digest-file /tmp/service.digest
```

The target is expected to push or otherwise resolve the image and write a single digest string such as `sha256:...` into the requested file. If your upstream `rules_oci` targets do not match that interface directly, wrap them in a small repo-owned shell or Starlark target.

## Workflow Model

The repository ships reusable GitHub workflow templates under [`.github/workflows`](../.github/workflows):

- `analyze.yml`
- `ci-pr.yml`
- `cd-main.yml`
- `promote-prod.yml`
- `cleanup-preview.yml`

Those workflows pair with:

- [`scripts/pipeline/invoke_image_target.py`](../scripts/pipeline/invoke_image_target.py)
- [`scripts/pipeline/render_to_gitops.py`](../scripts/pipeline/render_to_gitops.py)
- [`scripts/pipeline/gitops_commit.py`](../scripts/pipeline/gitops_commit.py)
- [`scripts/pipeline/cleanup_gitops.py`](../scripts/pipeline/cleanup_gitops.py)

The intended model is:

1. Run `pipeline_plan` to compute affected services and stage matrices.
2. Run only the lint and unit targets from that plan.
3. Build images only for affected services and record digests.
4. Render preview or environment manifests with `pipeline_helm_render`.
5. Copy those rendered YAML files into a dedicated GitOps repository.
6. Let Argo CD or ApplicationSet reconcile from the GitOps repository.

## Operational Notes

- `pipeline_plan` requires Python 3, `bazel`, and optionally `git` when using `--base/--head`.
- `pipeline_helm_render` requires Python 3.
- The launchers resolve a Python 3 interpreter on Windows, macOS, and Linux before dispatching to the repo-owned Python entrypoints.
- `shared_baseline` preview mode routes declared `runtime_deps` to the configured baseline environment.
- `full_isolated` preview mode is intended for independently deployable apps or workers that do not need shared baseline routing.

## Example Targets

- `//examples/pipeline/monorepo:catalog`
- `//examples/pipeline/monorepo:plan`
- `//examples/pipeline/monorepo:api_render`
- `//examples/pipeline/monorepo:web_render`
- `//examples/pipeline/monorepo:worker_render`

## Limits And Non-Goals

- The capability does not wrap or replace `rules_oci`.
- It does not create or manage Argo CD resources directly; it renders manifests and assumes a GitOps repository plus Argo sync layer already exist.
- It does not infer per-service image repositories from Bazel labels.
- It does not abstract every GitHub Actions policy choice; protected environments, approvals, and secret wiring remain repository concerns.
