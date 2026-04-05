#!/usr/bin/env python3
import argparse
import json
import os
import pathlib
import subprocess
import sys
import tempfile


def info(message: str) -> None:
    print(f"INFO  {message}", file=sys.stderr)


def fail(message: str) -> None:
    print(f"ERROR {message}", file=sys.stderr)
    raise SystemExit(1)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Render Helm manifests for a pipeline service.")
    parser.add_argument("--environment", required=True)
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--release-name", default="")
    parser.add_argument("--manifest-name", default="manifest.yaml")
    parser.add_argument("--namespace", default="")
    parser.add_argument("--host", default="")
    parser.add_argument("--image-repository", default="")
    parser.add_argument("--image-tag", default="")
    parser.add_argument("--image-digest", default="")
    parser.add_argument("--preview-id", default="")
    parser.add_argument("--baseline-environment", default="")
    parser.add_argument("--runtime-dependency", action="append", default=[])
    parser.add_argument("--values-file", action="append", default=[])
    parser.add_argument("--set-string", action="append", default=[])
    return parser.parse_args()


def workspace_dir() -> pathlib.Path:
    return pathlib.Path(os.environ.get("BUILD_WORKSPACE_DIRECTORY", os.getcwd())).resolve()


def runtime_dependency_map(values: list[str]) -> dict[str, str]:
    pairs = {}
    for raw in values:
        name, separator, url = raw.partition("=")
        if not separator or not name or not url:
            fail(f"invalid --runtime-dependency value: {raw}")
        pairs[name] = url
    return pairs


def resolve_values_files(
    chart_dir: pathlib.Path,
    workspace: pathlib.Path,
    environment: str,
    explicit: list[str],
) -> list[pathlib.Path]:
    discovered = []
    for candidate in [
        chart_dir / f"values.{environment}.yaml",
        chart_dir / f"values.{environment}.yml",
        chart_dir / f"values-{environment}.yaml",
        chart_dir / f"values-{environment}.yml",
        chart_dir / "environments" / f"{environment}.yaml",
        chart_dir / "environments" / f"{environment}.yml",
    ]:
        if candidate.exists():
            discovered.append(candidate)

    for item in explicit:
        candidate = pathlib.Path(item)
        if not candidate.is_absolute():
            candidate = workspace / candidate
        discovered.append(candidate)

    ordered = []
    seen = set()
    for candidate in discovered:
        resolved = candidate.resolve()
        if resolved in seen:
            continue
        seen.add(resolved)
        ordered.append(resolved)
    return ordered


def override_payload(
    service_name: str,
    environment: str,
    image_repository: str,
    image_tag: str,
    image_digest: str,
    host: str,
    preview_id: str,
    baseline_environment: str,
    runtime_dependencies: dict[str, str],
) -> dict:
    payload = {
        "pipeline": {
            "service": service_name,
            "environment": environment,
        },
    }

    if preview_id:
        payload["pipeline"]["previewId"] = preview_id
    if baseline_environment:
        payload["pipeline"]["baselineEnvironment"] = baseline_environment
    if image_repository or image_tag or image_digest:
        payload["image"] = {}
        if image_repository:
            payload["image"]["repository"] = image_repository
        if image_tag:
            payload["image"]["tag"] = image_tag
        if image_digest:
            payload["image"]["digest"] = image_digest
    if host:
        payload["ingress"] = {"host": host}
    if runtime_dependencies:
        payload["runtimeDependencies"] = runtime_dependencies

    return payload


def write_metadata(path: pathlib.Path, payload: dict) -> None:
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2, sort_keys=True)
        handle.write("\n")


def main() -> None:
    args = parse_args()
    workspace = workspace_dir()
    chart_dir_value = os.environ.get("PIPELINE_CHART_DIR")
    helm = os.environ.get("PIPELINE_HELM")
    service_name = os.environ.get("PIPELINE_SERVICE_NAME")
    default_release_name = os.environ.get("PIPELINE_RELEASE_NAME")

    if not chart_dir_value or not helm or not service_name:
        fail("PIPELINE_CHART_DIR, PIPELINE_HELM, and PIPELINE_SERVICE_NAME are required")

    chart_dir = (workspace / chart_dir_value).resolve()
    if not (chart_dir / "Chart.yaml").exists():
        fail(f"Chart.yaml not found under {chart_dir}")

    output_dir = pathlib.Path(args.output_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    namespace = args.namespace or f"{args.environment}-{service_name}"
    release_name = args.release_name or default_release_name or service_name
    values_files = resolve_values_files(chart_dir, workspace, args.environment, args.values_file)
    runtime_dependencies = runtime_dependency_map(args.runtime_dependency)
    overrides = override_payload(
        service_name = service_name,
        environment = args.environment,
        image_repository = args.image_repository,
        image_tag = args.image_tag,
        image_digest = args.image_digest,
        host = args.host,
        preview_id = args.preview_id,
        baseline_environment = args.baseline_environment,
        runtime_dependencies = runtime_dependencies,
    )

    cmd = [helm, "template", release_name, str(chart_dir), "--namespace", namespace]
    for values_file in values_files:
        cmd.extend(["--values", str(values_file)])
    for item in args.set_string:
        cmd.extend(["--set-string", item])

    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, encoding="utf-8") as handle:
        json.dump(overrides, handle, sort_keys=True)
        handle.write("\n")
        override_file = pathlib.Path(handle.name)

    cmd.extend(["--values", str(override_file)])
    info("Rendering Helm manifests")
    result = subprocess.run(
        cmd,
        cwd=workspace,
        check=False,
        capture_output=True,
        text=True,
    )
    try:
        override_file.unlink(missing_ok = True)
    except TypeError:
        if override_file.exists():
            override_file.unlink()

    if result.returncode != 0:
        fail("helm template failed:\n%s%s" % (result.stdout, result.stderr))

    manifest_path = output_dir / args.manifest_name
    with open(manifest_path, "w", encoding="utf-8") as handle:
        handle.write(result.stdout)

    metadata = {
        "service": service_name,
        "environment": args.environment,
        "release_name": release_name,
        "namespace": namespace,
        "chart_dir": chart_dir.relative_to(workspace).as_posix(),
        "values_files": [path.relative_to(workspace).as_posix() if path.is_relative_to(workspace) else str(path) for path in values_files],
        "manifest": str(manifest_path),
    }
    write_metadata(output_dir / "metadata.json", metadata)
    info(f"Wrote rendered manifests to {manifest_path}")


if __name__ == "__main__":
    main()
