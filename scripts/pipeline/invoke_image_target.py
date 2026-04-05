#!/usr/bin/env python3
import argparse
import json
import os
import pathlib
import subprocess
import sys


def fail(message: str) -> None:
    print(f"ERROR {message}", file=sys.stderr)
    raise SystemExit(1)


def load_config(path: str) -> dict:
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Invoke an image target with the pipeline image contract.")
    parser.add_argument("--config", required=True)
    parser.add_argument("--service", required=True)
    parser.add_argument("--target", required=True)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--metadata-file", required=True)
    parser.add_argument("--workspace", default=os.getcwd())
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    config = load_config(args.config)
    workspace = pathlib.Path(args.workspace).resolve()
    services = config.get("services", {})
    if args.service not in services:
        fail(f"service {args.service} not found in {args.config}")

    image_repository = services[args.service].get("image_repository")
    if not image_repository:
        fail(f"service {args.service} is missing image_repository in {args.config}")

    metadata_path = pathlib.Path(args.metadata_file).resolve()
    metadata_path.parent.mkdir(parents=True, exist_ok=True)
    digest_file = metadata_path.with_suffix(".digest")
    cmd = [
        os.environ.get("PIPELINE_BAZEL_BIN", "bazel"),
        "run",
        args.target,
        "--",
        "--image-repository",
        image_repository,
        "--image-tag",
        args.tag,
        "--digest-file",
        str(digest_file),
    ]
    result = subprocess.run(
        cmd,
        cwd=workspace,
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        fail("image target failed:\n%s%s" % (result.stdout, result.stderr))
    if not digest_file.exists():
        fail(f"image target did not write digest file {digest_file}")

    image_digest = digest_file.read_text(encoding="utf-8").strip()
    if not image_digest:
        fail(f"image target wrote an empty digest file {digest_file}")

    payload = {
        "service": args.service,
        "target": args.target,
        "image_repository": image_repository,
        "image_tag": args.tag,
        "image_digest": image_digest,
    }
    with open(metadata_path, "w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2, sort_keys=True)
        handle.write("\n")


if __name__ == "__main__":
    main()
