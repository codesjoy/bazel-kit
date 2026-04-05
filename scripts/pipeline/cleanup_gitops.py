#!/usr/bin/env python3
import argparse
import shutil
import subprocess
import sys
from pathlib import Path


def fail(message: str) -> None:
    print(f"ERROR {message}", file=sys.stderr)
    raise SystemExit(1)


def run(cmd: list[str], cwd: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, cwd=cwd, check=False, capture_output=True, text=True)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Remove a GitOps path, then commit and push the cleanup.")
    parser.add_argument("gitops_dir")
    parser.add_argument("path_to_remove")
    parser.add_argument("message")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    target = Path(args.gitops_dir) / args.path_to_remove
    if target.exists():
        if target.is_dir():
            shutil.rmtree(target)
        else:
            target.unlink()

    result = run(["git", "add", "-A", "."], cwd=args.gitops_dir)
    if result.returncode != 0:
        fail(f"git add failed:\n{result.stdout}{result.stderr}")

    result = run(["git", "diff", "--cached", "--quiet"], cwd=args.gitops_dir)
    if result.returncode == 0:
        print("INFO  no GitOps cleanup changes to commit", file=sys.stderr)
        return
    if result.returncode not in (0, 1):
        fail(f"git diff --cached failed:\n{result.stdout}{result.stderr}")

    result = run(["git", "commit", "-m", args.message], cwd=args.gitops_dir)
    if result.returncode != 0:
        fail(f"git commit failed:\n{result.stdout}{result.stderr}")

    result = run(["git", "push", "origin", "HEAD"], cwd=args.gitops_dir)
    if result.returncode != 0:
        fail(f"git push failed:\n{result.stdout}{result.stderr}")


if __name__ == "__main__":
    main()
