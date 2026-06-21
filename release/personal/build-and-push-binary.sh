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
  BUILDER_NAME
  DOCKER_USERNAME
  DOCKER_PASSWORD
  BINARY_DOCKERFILE
  BINARY_AMD64_PATH
  BINARY_ARM64_PATH
)

for v in "${required_vars[@]}"; do
  if [[ -z "${!v:-}" ]]; then
    echo "required variable is empty: $v" >&2
    exit 1
  fi
done

FULL_IMAGE="$REGISTRY/$NAMESPACE/$IMAGE"
AMD64_SRC="$REPO_ROOT/$BINARY_AMD64_PATH"
ARM64_SRC="$REPO_ROOT/$BINARY_ARM64_PATH"
AMD64_DST="$REPO_ROOT/sing-box-amd64"
ARM64_DST="$REPO_ROOT/sing-box-arm64"

if [[ ! -f "$AMD64_SRC" ]]; then
  echo "missing binary: $AMD64_SRC" >&2
  exit 1
fi
if [[ ! -f "$ARM64_SRC" ]]; then
  echo "missing binary: $ARM64_SRC" >&2
  exit 1
fi

cleanup() {
  rm -f "$AMD64_DST" "$ARM64_DST"
}
trap cleanup EXIT

cp "$AMD64_SRC" "$AMD64_DST"
cp "$ARM64_SRC" "$ARM64_DST"
chmod +x "$AMD64_DST" "$ARM64_DST"

echo "$DOCKER_PASSWORD" | docker login "$REGISTRY" -u "$DOCKER_USERNAME" --password-stdin

docker buildx create --name "$BUILDER_NAME" --use --bootstrap >/dev/null 2>&1 || docker buildx use "$BUILDER_NAME"
docker buildx inspect --bootstrap >/dev/null

cd "$REPO_ROOT"

build_args=(
  --platform "$PLATFORMS"
  -f "$BINARY_DOCKERFILE"
  --build-arg "BASE_IMAGE=${BASE_IMAGE:-alpine}"
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
