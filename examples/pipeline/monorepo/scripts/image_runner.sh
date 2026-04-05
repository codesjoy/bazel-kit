#!/usr/bin/env bash
set -euo pipefail

service="$1"
shift

image_repository=""
image_tag=""
digest_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image-repository)
      image_repository="$2"
      shift 2
      ;;
    --image-tag)
      image_tag="$2"
      shift 2
      ;;
    --digest-file)
      digest_file="$2"
      shift 2
      ;;
    *)
      printf 'unexpected arg: %s\n' "$1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$image_repository" || -z "$image_tag" || -z "$digest_file" ]]; then
  printf 'image_runner requires --image-repository, --image-tag, and --digest-file\n' >&2
  exit 1
fi

digest="sha256:$(printf '%s' "${service}:${image_repository}:${image_tag}" | shasum -a 256 | awk '{print $1}')"
printf '%s\n' "$digest" > "$digest_file"
printf 'built %s -> %s@%s\n' "$service" "$image_repository" "$digest" >&2
