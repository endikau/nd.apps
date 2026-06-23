#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

NPMRC_PATH="${NPMRC_PATH:-$ROOT_DIR/.npmrc}"
if [[ ! -f "$NPMRC_PATH" ]]; then
  echo "Missing npmrc at $NPMRC_PATH. Set NPMRC_PATH or place your .npmrc there." >&2
  exit 1
fi

SECRET_ARGS=(--secret "id=npmrc,src=$NPMRC_PATH")
if [[ -n "${GITHUB_PAT:-}" ]]; then
  SECRET_ARGS+=(--secret "id=github_pat,env=GITHUB_PAT")
fi

RUNTIME_TAG="${RUNTIME_TAG:-4.6.0-py3.12.12-v2}"
BUILDKIT_PROGRESS="${BUILDKIT_PROGRESS:-plain}"  # plain shows step-by-step logs

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
    git ls-files -z \
      | while IFS= read -r -d '' path; do
          if [[ -f "$path" || -L "$path" ]]; then
            printf '%s\0' "$path"
          fi
        done \
      | tar --null -T - -cf - \
      | DOCKER_BUILDKIT=1 BUILDKIT_PROGRESS="$BUILDKIT_PROGRESS" docker buildx build \
        --load \
        --progress "$BUILDKIT_PROGRESS" \
        --build-arg "RUNTIME_TAG=$RUNTIME_TAG" \
        "${SECRET_ARGS[@]}" \
        -f "$df_name" \
        -t "$tag" \
        -
  )
}

build_tracked "$ROOT_DIR/Dockerfile" nd_apps-shiny_serve:local

echo "Done. Image tagged as nd_apps-shiny_serve:local"
