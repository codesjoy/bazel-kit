# pipeline monorepo example

This example wires the `pipeline` capability into a small monorepo with:

- a Go-style API service in `services/api`
- a web frontend in `services/web`
- a custom worker in `services/worker`
- a shared contract in `shared/contracts`
- Helm charts in `deploy/*`
- an Argo CD `ApplicationSet` sample in `argo/applicationsets.yaml`

The example keeps the build and test targets intentionally small so the `pipeline_service` declarations stay easy to read. In a real repository, replace the `*_image` shell targets with repository-owned wrappers around upstream `rules_oci` targets and replace the shell test targets with your actual unit and integration targets.

Useful commands:

```bash
bazel run //examples/pipeline/monorepo:plan -- \
  --changed-files examples/pipeline/monorepo/shared/contracts/api.schema.json

python3 scripts/pipeline/invoke_image_target.py \
  --config examples/pipeline/monorepo/pipeline.json \
  --service api \
  --target //examples/pipeline/monorepo:api_image \
  --tag dev-local \
  --metadata-file /tmp/api-image.json

python3 scripts/pipeline/render_to_gitops.py \
  --config examples/pipeline/monorepo/pipeline.json \
  --service api \
  --render-target //examples/pipeline/monorepo:api_render \
  --environment preview \
  --preview-mode shared_baseline \
  --runtime-deps-json '["web"]' \
  --image-metadata /tmp/api-image.json \
  --preview-id pr-42 \
  --gitops-dir /tmp/gitops
```
