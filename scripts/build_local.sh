#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

NPMRC_PATH="${NPMRC_PATH:-$ROOT_DIR/.npmrc}"
if [[ ! -f "$NPMRC_PATH" ]]; then
  echo "Missing npmrc at $NPMRC_PATH. Set NPMRC_PATH or place your .npmrc there." >&2
  exit 1
fi

SECRET_ARG=(--secret "id=npmrc,src=$NPMRC_PATH")

# Ensure a buildx builder is available (required for streaming context + secrets).
if ! docker buildx inspect >/dev/null 2>&1; then
  echo "Creating a temporary buildx builder"
  docker buildx create --use >/dev/null
fi

build_tracked() {
  local dockerfile="$1"
  local tag="$2"
  local df_name
  df_name="$(basename "$dockerfile")"
  echo "Building $tag from tracked files only"
  (
    cd "$ROOT_DIR"
    git ls-files -z | tar --null -T - -cf - | \
      DOCKER_BUILDKIT=1 docker buildx build \
        --load \
        "${SECRET_ARG[@]}" \
        -f "$df_name" \
        -t "$tag" \
        -
  )
}

build_tracked "$ROOT_DIR/shiny_serve.Dockerfile" nd_apps-shiny_serve:local

echo "Done. Image tagged as nd_apps-shiny_serve:local"
