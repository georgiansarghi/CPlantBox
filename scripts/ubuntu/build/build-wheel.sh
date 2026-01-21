#!/usr/bin/env bash
set -euo pipefail

# Build a wheel inside a dedicated Ubuntu build image.
# Usage: scripts/ubuntu/build/build-wheel.sh [linux/amd64|linux/arm64]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
cd "$REPO_ROOT"

source "$REPO_ROOT/scripts/common/env.sh"
source "$REPO_ROOT/scripts/common/logging.sh"
source "$REPO_ROOT/scripts/common/docker.sh"

PLATFORM="${1:-linux/amd64}"
ARCH_SHORT="${PLATFORM#linux/}"
IMAGE_NAME="cplantbox-ubuntu-wheel-build-${ARCH_SHORT}"
if [[ "$ARCH_SHORT" == "arm64" ]]; then
  DOCKERFILE_PATH="scripts/ubuntu/build/Dockerfile_arm64"
else
  DOCKERFILE_PATH="scripts/ubuntu/build/Dockerfile_amd64"
fi

log_info "[ubuntu-build] Ensuring buildx builder..."
ensure_buildx_builder cplantbox-builder

log_info "[ubuntu-build] Building image ${IMAGE_NAME} from ${DOCKERFILE_PATH} for ${PLATFORM}..."
docker_build_image "$IMAGE_NAME" "$DOCKERFILE_PATH" "$PLATFORM" .

OUT_DIR="wheelhouse/linux/ubuntu/${ARCH_SHORT}"
mkdir -p "$OUT_DIR"

# Default to system libraries on Ubuntu builds for both arches (these wheels are for local smoke only)
HOST_CONFIG_OPTS="${EXTRA_BUILD_ARGS:-}" 
if [[ -z "${HOST_CONFIG_OPTS}" ]]; then
  HOST_CONFIG_OPTS="-C cmake.define.USE_SYSTEM_SUITESPARSE=ON -C cmake.define.BUNDLE_SUITESPARSE=OFF -C cmake.define.USE_SYSTEM_SUNDIALS=ON -C cmake.define.BUNDLE_SUNDIALS=OFF"
fi

log_info "[ubuntu-build] Running wheel build in container..."
CMD="set -euo pipefail; export PYTHONPATH=/src:/src/src:\${PYTHONPATH:-}; git submodule update --init --recursive; python3 -m pip -q install -U pip build; rm -rf dist/ _skbuild/; CONFIG_OPTS=\"$HOST_CONFIG_OPTS\"; python3 -m build --wheel $HOST_CONFIG_OPTS; echo Built wheels: && ls -lh dist/*.whl"
docker_run_project "$IMAGE_NAME" "$PLATFORM" /src "$CMD"

log_info "[ubuntu-build] Copying wheels to ${OUT_DIR}"
if ls dist/*.whl >/dev/null 2>&1; then
  cp -v dist/*.whl "$OUT_DIR"/
  {
    echo "# Ubuntu-built wheels — local testing only"
    date -u +"%Y-%m-%dT%H:%M:%SZ"
    python3 -V || true
    echo "Artifacts:"
    ls -1 "$OUT_DIR"/*.whl || true
  } > "$OUT_DIR/index.txt"
  log_info "[ubuntu-build] Done."
else
  log_warn "[ubuntu-build] No wheels found under dist/*.whl"
fi


