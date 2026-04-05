#!/usr/bin/env python3
import argparse
import json
import os
import pathlib
import subprocess
import sys
from typing import Optional

GLOBAL_IMPACT_FILES = {
    ".bazelrc",
    "MODULE.bazel",
    "MODULE.bazel.lock",
}

GLOBAL_IMPACT_PREFIXES = [
    ".github/workflows/",
]


def info(message: str) -> None:
    print(f"INFO  {message}", file=sys.stderr)


def warn(message: str) -> None:
    print(f"WARN  {message}", file=sys.stderr)


def fail(message: str) -> None:
    print(f"ERROR {message}", file=sys.stderr)
    raise SystemExit(1)


def tool_path(env_key: str, default: str) -> str:
    return os.environ.get(env_key, default)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Analyze changed files and expand affected pipeline service matrices.",
    )
    parser.add_argument("--changed-files", default="")
    parser.add_argument("--changed-files-file", default="")
    parser.add_argument("--base", default="")
    parser.add_argument("--head", default="HEAD")
    parser.add_argument("--output", default="")
    parser.add_argument("--baseline-environment", default="itest-baseline")
    return parser.parse_args()


def load_catalog() -> dict:
    catalog_path = os.environ.get("PIPELINE_CATALOG")
    if not catalog_path:
        fail("PIPELINE_CATALOG is required")
    with open(catalog_path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def workspace_dir() -> pathlib.Path:
    return pathlib.Path(os.environ.get("BUILD_WORKSPACE_DIRECTORY", os.getcwd())).resolve()


def normalize_changed_path(raw: str, workspace: pathlib.Path) -> Optional[str]:
    path = raw.strip()
    if not path:
        return None

    candidate = pathlib.Path(path)
    if candidate.is_absolute():
        try:
            candidate = candidate.resolve().relative_to(workspace)
        except ValueError:
            return None

    normalized = pathlib.PurePosixPath(candidate.as_posix()).as_posix().lstrip("./")
    if not normalized or normalized.startswith("../"):
        return None
    return normalized


def load_changed_files(args: argparse.Namespace, workspace: pathlib.Path) -> list[str]:
    changed: list[str] = []

    if args.changed_files:
        for item in args.changed_files.split(","):
            normalized = normalize_changed_path(item, workspace)
            if normalized:
                changed.append(normalized)

    if args.changed_files_file:
        with open(args.changed_files_file, "r", encoding="utf-8") as handle:
            for line in handle:
                normalized = normalize_changed_path(line, workspace)
                if normalized:
                    changed.append(normalized)

    if not changed and args.base:
        info(f"Collecting changed files from git diff {args.base}..{args.head}")
        result = subprocess.run(
            [tool_path("PIPELINE_GIT_BIN", "git"), "diff", "--name-only", "--diff-filter=ACMRD", args.base, args.head],
            cwd=workspace,
            check=False,
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            fail(f"git diff failed:\n{result.stderr.strip()}")
        for line in result.stdout.splitlines():
            normalized = normalize_changed_path(line, workspace)
            if normalized:
                changed.append(normalized)

    seen = set()
    ordered = []
    for item in changed:
        if item in seen:
            continue
        seen.add(item)
        ordered.append(item)
    return ordered


def package_for_path(relpath: str, workspace: pathlib.Path) -> Optional[str]:
    current = (workspace / relpath).parent
    while True:
        if (current / "BUILD.bazel").exists() or (current / "BUILD").exists():
            if current == workspace:
                return ""
            return current.relative_to(workspace).as_posix()
        if current == workspace:
            return None
        current = current.parent


def expression_for_path(relpath: str, workspace: pathlib.Path) -> Optional[str]:
    if relpath in GLOBAL_IMPACT_FILES:
        return "//..."
    for prefix in GLOBAL_IMPACT_PREFIXES:
        if relpath.startswith(prefix):
            return "//..."

    name = pathlib.PurePosixPath(relpath).name
    package = package_for_path(relpath, workspace)

    if relpath.endswith(".bzl"):
        return f"siblings(rbuildfiles({relpath}))"
    if name in {"BUILD", "BUILD.bazel"}:
        return f"//{package}:all" if package else "//:all"
    if package is None:
        return None

    prefix = f"{package}/" if package else ""
    target_name = relpath[len(prefix) :] if prefix and relpath.startswith(prefix) else relpath
    if not target_name:
        return f"//{package}:all" if package else "//:all"
    return f"//{package}:{target_name}" if package else f"//:{target_name}"


def query_affected_service_labels(
    changed_expressions: list[str],
    service_labels: list[str],
    workspace: pathlib.Path,
) -> list[str]:
    if not changed_expressions or not service_labels:
        return []
    if "//..." in changed_expressions:
        return service_labels

    query = "(rdeps(//..., {changed})) intersect ({services})".format(
        changed=" + ".join(changed_expressions),
        services=" + ".join(service_labels),
    )
    info("Running bazel query for affected pipeline services")
    result = subprocess.run(
        [tool_path("PIPELINE_BAZEL_BIN", "bazel"), "query", "--keep_going", "--noshow_progress", query],
        cwd=workspace,
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode not in (0, 3):
        fail("bazel query failed:\n%s%s" % (result.stdout, result.stderr))

    labels = []
    for line in result.stdout.splitlines():
        line = line.strip()
        if line:
            labels.append(line)
    return labels


def service_row(service: dict, baseline_environment: str) -> dict:
    deploy_environments = service.get("deploy_environments", [])
    runtime_deps = service.get("runtime_deps", [])
    return {
        "service": service["service_name"],
        "label": service["label"],
        "language": service["language"],
        "workload_kind": service["workload_kind"],
        "preview_mode": service["preview_mode"],
        "render_target": service["render_target"],
        "baseline_environment": baseline_environment,
        "runtime_deps_csv": ",".join(runtime_deps),
        "runtime_deps_json": json.dumps(runtime_deps, separators=(",", ":")),
        "deploy_environments_csv": ",".join(deploy_environments),
        "deploy_environments_json": json.dumps(deploy_environments, separators=(",", ":")),
    }


def stage_matrix(services: list[dict], stage: str, baseline_environment: str) -> dict:
    if stage == "render":
        accessor = lambda service: [service["render_target"]]
    else:
        accessor = lambda service: service.get(f"{stage}_targets", [])

    included = []
    seen: dict[str, dict] = {}
    for service in services:
        for target in accessor(service):
            if not target:
                continue
            entry = seen.get(target)
            if entry is None:
                entry = service_row(service, baseline_environment)
                entry["target"] = target
                entry["owners"] = [service["service_name"]]
                seen[target] = entry
                included.append(entry)
            elif service["service_name"] not in entry["owners"]:
                entry["owners"].append(service["service_name"])

    for entry in included:
        entry["owners_csv"] = ",".join(entry["owners"])
    return {"include": included}


def build_output(
    catalog: dict,
    affected_labels: list[str],
    changed_files: list[str],
    changed_expressions: list[str],
    baseline_environment: str,
) -> dict:
    services_by_label = {service["label"]: service for service in catalog.get("services", [])}
    affected_services = []
    for service in catalog.get("services", []):
        if service["label"] in affected_labels:
            affected_services.append(service)

    return {
        "version": 1,
        "repo_config": catalog.get("repo_config", ""),
        "baseline_environment": baseline_environment,
        "changed_files": changed_files,
        "changed_expressions": changed_expressions,
        "affected_service_labels": [service["label"] for service in affected_services],
        "affected_service_names": [service["service_name"] for service in affected_services],
        "empty": len(affected_services) == 0,
        "service_matrix": {
            "include": [service_row(service, baseline_environment) for service in affected_services],
        },
        "lint_matrix": stage_matrix(affected_services, "lint", baseline_environment),
        "unit_matrix": stage_matrix(affected_services, "unit", baseline_environment),
        "integration_matrix": stage_matrix(affected_services, "integration", baseline_environment),
        "image_matrix": stage_matrix(affected_services, "image", baseline_environment),
        "render_matrix": stage_matrix(affected_services, "render", baseline_environment),
        "services_by_label": {
            label: {
                "service_name": service["service_name"],
                "language": service["language"],
                "preview_mode": service["preview_mode"],
            }
            for label, service in services_by_label.items()
        },
    }


def write_output(payload: dict, output_path: str) -> None:
    encoded = json.dumps(payload, indent=2, sort_keys=False) + "\n"
    if output_path:
        with open(output_path, "w", encoding="utf-8") as handle:
            handle.write(encoded)
        info(f"Wrote pipeline plan to {output_path}")
    else:
        sys.stdout.write(encoded)


def main() -> None:
    args = parse_args()
    catalog = load_catalog()
    workspace = workspace_dir()
    changed_files = load_changed_files(args, workspace)
    changed_expressions = []

    for path in changed_files:
        expression = expression_for_path(path, workspace)
        if expression is None:
            warn(f"Skipping changed path outside a Bazel package: {path}")
            continue
        if expression not in changed_expressions:
            changed_expressions.append(expression)

    service_labels = [service["label"] for service in catalog.get("services", [])]
    affected_labels = query_affected_service_labels(changed_expressions, service_labels, workspace)
    payload = build_output(
        catalog = catalog,
        affected_labels = affected_labels,
        changed_files = changed_files,
        changed_expressions = changed_expressions,
        baseline_environment = args.baseline_environment,
    )
    write_output(payload, args.output)


if __name__ == "__main__":
    main()
