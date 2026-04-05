#!/usr/bin/env python3
import argparse
import json
import os
import pathlib
import shutil
import string
import subprocess
import sys
import tempfile


def fail(message: str) -> None:
    print(f"ERROR {message}", file=sys.stderr)
    raise SystemExit(1)


def load_json(path: str) -> dict:
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Render manifests and publish them into a GitOps repository tree.")
    parser.add_argument("--config", required=True)
    parser.add_argument("--service", required=True)
    parser.add_argument("--render-target", required=True)
    parser.add_argument("--environment", required=True)
    parser.add_argument("--preview-mode", required=True)
    parser.add_argument("--runtime-deps-json", default="[]")
    parser.add_argument("--gitops-dir", required=True)
    parser.add_argument("--workspace", default=os.getcwd())
    parser.add_argument("--preview-id", default="")
    parser.add_argument("--baseline-environment", default="")
    parser.add_argument("--image-metadata", default="")
    return parser.parse_args()


def render_template(value: str, variables: dict) -> str:
    return string.Template(value).safe_substitute(variables)


def environment_config(config: dict, environment: str, preview_id: str) -> tuple[dict, str]:
    if environment == "preview":
        preview = dict(config.get("preview", {}))
        if not preview:
            fail("preview configuration is required for preview renders")
        gitops_root = preview.get("gitops_root", "preview")
        if not preview_id:
            fail("preview renders require --preview-id")
        return preview, f"{gitops_root}/{preview_id}"

    environments = config.get("environments", {})
    if environment not in environments:
        fail(f"environment {environment} not found in config")
    env_config = dict(environments[environment])
    gitops_root = env_config.get("gitops_root", f"apps/{environment}")
    return env_config, gitops_root


def service_host(service_name: str, env_config: dict, variables: dict) -> str:
    host_template = env_config.get("host_template", "")
    if not host_template:
        return ""
    values = dict(variables)
    values.setdefault("service", service_name)
    return render_template(host_template, values)


def service_namespace(service_name: str, env_config: dict, variables: dict, environment: str) -> str:
    namespace_template = env_config.get("namespace_template", f"{environment}-${{service}}")
    values = dict(variables)
    values.setdefault("service", service_name)
    values.setdefault("environment", environment)
    return render_template(namespace_template, values)


def runtime_dependency_args(
    config: dict,
    runtime_deps: list[str],
    preview_mode: str,
    environment: str,
    preview_id: str,
    baseline_environment: str,
) -> list[str]:
    if not runtime_deps:
        return []

    if environment == "preview" and preview_mode == "shared_baseline":
        dependency_environment = baseline_environment or config.get("baseline_environment", "itest-baseline")
    elif environment == "preview":
        dependency_environment = "preview"
    else:
        dependency_environment = environment

    env_config, _ = environment_config(config, dependency_environment, preview_id)
    scheme = env_config.get("scheme", "https")
    args = []
    for dependency in runtime_deps:
        variables = {
            "environment": dependency_environment,
            "preview_id": preview_id,
            "service": dependency,
        }
        host = service_host(dependency, env_config, variables)
        if not host:
            continue
        args.extend(["--runtime-dependency", f"{dependency}={scheme}://{host}"])
    return args


def copy_tree(source: pathlib.Path, destination: pathlib.Path) -> None:
    if destination.exists():
        shutil.rmtree(destination)
    destination.mkdir(parents=True, exist_ok=True)
    for item in source.iterdir():
        target = destination / item.name
        if item.is_dir():
            shutil.copytree(item, target)
        else:
            shutil.copy2(item, target)


def main() -> None:
    args = parse_args()
    config = load_json(args.config)
    workspace = pathlib.Path(args.workspace).resolve()
    services = config.get("services", {})
    if args.service not in services:
        fail(f"service {args.service} not found in {args.config}")

    image_metadata = {}
    if args.image_metadata:
        image_metadata = load_json(args.image_metadata)

    env_config, gitops_root = environment_config(config, args.environment, args.preview_id)
    variables = {
        "environment": args.environment,
        "preview_id": args.preview_id,
        "service": args.service,
    }
    host = service_host(args.service, env_config, variables)
    namespace = service_namespace(args.service, env_config, variables, args.environment)
    runtime_deps = json.loads(args.runtime_deps_json or "[]")
    baseline_environment = args.baseline_environment or config.get("baseline_environment", "itest-baseline")

    with tempfile.TemporaryDirectory(prefix = "pipeline-render-") as temp_dir:
        output_dir = pathlib.Path(temp_dir) / "rendered"
        cmd = [
            os.environ.get("PIPELINE_BAZEL_BIN", "bazel"),
            "run",
            args.render_target,
            "--",
            "--environment",
            args.environment,
            "--output-dir",
            str(output_dir),
            "--namespace",
            namespace,
            "--baseline-environment",
            baseline_environment,
        ]
        if host:
            cmd.extend(["--host", host])
        if args.preview_id:
            cmd.extend(["--preview-id", args.preview_id])
        if image_metadata:
            cmd.extend(["--image-repository", image_metadata["image_repository"]])
            cmd.extend(["--image-tag", image_metadata.get("image_tag", "")])
            cmd.extend(["--image-digest", image_metadata.get("image_digest", "")])
        cmd.extend(runtime_dependency_args(
            config = config,
            runtime_deps = runtime_deps,
            preview_mode = args.preview_mode,
            environment = args.environment,
            preview_id = args.preview_id,
            baseline_environment = baseline_environment,
        ))
        result = subprocess.run(
            cmd,
            cwd=workspace,
            check=False,
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            fail("render target failed:\n%s%s" % (result.stdout, result.stderr))

        gitops_dir = pathlib.Path(args.gitops_dir).resolve()
        destination = gitops_dir / gitops_root / args.service
        copy_tree(output_dir, destination)
        print(destination)


if __name__ == "__main__":
    main()
