#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/../.." && pwd)
ENV_FILE="$SCRIPT_DIR/release.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "missing env file: $ENV_FILE" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$ENV_FILE"

required_vars=(
  REGISTRY
  NAMESPACE
  IMAGE
  TAG
  PLATFORMS
  DOCKERFILE
  BUILDER_NAME
  DOCKER_USERNAME
  DOCKER_PASSWORD
)

for v in "${required_vars[@]}"; do
  if [[ -z "${!v:-}" ]]; then
    echo "required variable is empty: $v" >&2
    exit 1
  fi
done

FULL_IMAGE="$REGISTRY/$NAMESPACE/$IMAGE"

echo "$DOCKER_PASSWORD" | docker login "$REGISTRY" -u "$DOCKER_USERNAME" --password-stdin

docker buildx create --name "$BUILDER_NAME" --use --bootstrap >/dev/null 2>&1 || docker buildx use "$BUILDER_NAME"
docker buildx inspect --bootstrap >/dev/null

cd "$REPO_ROOT"

# Build arguments list must be assembled safely.
build_args=(
  --platform "$PLATFORMS"
  -f "$DOCKERFILE"
  -t "$FULL_IMAGE:$TAG"
)

if [[ "${PUSH_LATEST:-false}" == "true" ]]; then
  build_args+=( -t "$FULL_IMAGE:latest" )
fi

build_args+=( --push . )

docker buildx build "${build_args[@]}"

docker buildx imagetools inspect "$FULL_IMAGE:$TAG"

echo "published: $FULL_IMAGE:$TAG"
if [[ "${PUSH_LATEST:-false}" == "true" ]]; then
  echo "published: $FULL_IMAGE:latest"
fi
