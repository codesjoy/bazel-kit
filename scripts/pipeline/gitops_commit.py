#!/usr/bin/env python3
import argparse
import subprocess
import sys


def fail(message: str) -> None:
    print(f"ERROR {message}", file=sys.stderr)
    raise SystemExit(1)


def run(cmd: list[str], cwd: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, cwd=cwd, check=False, capture_output=True, text=True)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Commit and push GitOps changes.")
    parser.add_argument("gitops_dir")
    parser.add_argument("message")
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    result = run(["git", "add", "-A", "."], cwd=args.gitops_dir)
    if result.returncode != 0:
        fail(f"git add failed:\n{result.stdout}{result.stderr}")

    result = run(["git", "diff", "--cached", "--quiet"], cwd=args.gitops_dir)
    if result.returncode == 0:
        print("INFO  no GitOps changes to commit", file=sys.stderr)
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
