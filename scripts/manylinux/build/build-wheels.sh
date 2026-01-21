#!/usr/bin/env bash
set -euo pipefail

# Build manylinux2014 wheels for the given arch inside PyPA containers and repair with auditwheel.
# Usage: scripts/manylinux/build/build-wheels.sh [x86_64|aarch64]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
cd "$REPO_ROOT"

ARCH="${1:-x86_64}"
case "$ARCH" in
  x86_64|aarch64) ;;
  *) echo "Unsupported arch: $ARCH (use x86_64 or aarch64)" >&2; exit 2;;
esac

IMAGE="quay.io/pypa/manylinux2014_${ARCH}"
DF="$SCRIPT_DIR/Dockerfile_${ARCH}"
OUT_DIR="wheelhouse/linux/manylinux2014_${ARCH}"
mkdir -p "$OUT_DIR"

echo "[manylinux ${ARCH}] Building builder image with system deps..."
docker buildx build --platform linux/${ARCH} -f "$DF" -t cplantbox-manylinux-build-${ARCH} --load .

echo "[manylinux ${ARCH}] Building + repairing wheels (cp39-cp312)"

DOCKER_CMD=$(cat <<'BASH'
set -euo pipefail
yum -y install suitesparse-devel >/dev/null 2>&1 || true
git -c safe.directory=/project submodule update --init --recursive
rm -rf dist/ _skbuild/
export CMAKE_BUILD_PARALLEL_LEVEL=1

for PYTAG in cp39-cp39 cp310-cp310 cp311-cp311 cp312-cp312; do
  PY="/opt/python/${PYTAG}/bin/python"
  if [[ ! -x "$PY" ]]; then
    echo "Skip ${PYTAG} (missing)"
    continue
  fi
  echo "[manylinux] Building for ${PYTAG}"
  "$PY" -m pip -q install -U pip build auditwheel
  # Clean between builds
  rm -rf dist/ _skbuild/
  PY_PREFIX=$(dirname "$(dirname "$PY")")
  EXTRA_CMAKE_ARGS="-C cmake.define.USE_SYSTEM_SUITESPARSE=ON -C cmake.define.BUNDLE_SUITESPARSE=OFF -C cmake.define.USE_SYSTEM_SUNDIALS=ON -C cmake.define.BUNDLE_SUNDIALS=OFF -C cmake.define.CMAKE_PREFIX_PATH=/opt/sundials -C cmake.define.SUNDIALS_ROOT=/opt/sundials -C cmake.define.Python3_EXECUTABLE=$PY -C cmake.define.Python3_ROOT_DIR=$PY_PREFIX"
  "$PY" -m build --wheel ${EXTRA_CMAKE_ARGS}
  WHEEL=$(ls -1t dist/*.whl | head -n1)
  echo "Built: $WHEEL"
  mkdir -p /project/$OUT_DIR
  "$PY" -m auditwheel repair -w /project/$OUT_DIR "$WHEEL"
done
BASH
)

docker run --rm --platform linux/${ARCH} -e OUT_DIR="$OUT_DIR" -v "$REPO_ROOT":/project -w /project cplantbox-manylinux-build-${ARCH} bash -lc "$DOCKER_CMD"

echo "[manylinux ${ARCH}] Artifacts:"
ls -lh "$OUT_DIR" | cat


