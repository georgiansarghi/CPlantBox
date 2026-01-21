#!/usr/bin/env bash
set -euo pipefail

# Build a macOS wheel on host (no Docker). Intended for Apple Silicon (arm64),
# but also works on Intel Macs.
# Usage: scripts/macos/build/build-wheel.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
cd "$REPO_ROOT"

source "$REPO_ROOT/scripts/common/env.sh"
source "$REPO_ROOT/scripts/common/logging.sh"

ARCH=$(uname -m)
log_info "[macOS-build] Host arch: ${ARCH}"

if ! command -v brew >/dev/null 2>&1; then
  die "Homebrew not found. Install from https://brew.sh then install: brew install sundials suite-sparse"
fi

BREW_PREFIX=$(brew --prefix)

# Ensure required system dependencies are available
missing=()
brew ls --versions sundials >/dev/null 2>&1 || missing+=(sundials)
brew ls --versions suite-sparse >/dev/null 2>&1 || missing+=(suite-sparse)
if ((${#missing[@]})); then
  die "Missing Homebrew packages: ${missing[*]}. Install with: brew install ${missing[*]}"
fi

export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
export CMAKE_PREFIX_PATH="${BREW_PREFIX}:${CMAKE_PREFIX_PATH:-}"
# Prefer system libraries on macOS builds
export CMAKE_ARGS="-DUSE_SYSTEM_SUITESPARSE=ON -DBUNDLE_SUITESPARSE=OFF -DUSE_SYSTEM_SUNDIALS=ON -DBUNDLE_SUNDIALS=OFF -DCMAKE_OSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET} ${CMAKE_ARGS:-}"

OUT_DIR="wheelhouse/macos"
mkdir -p "$OUT_DIR"

log_info "[macOS-build] Installing build backend and cleaning build dirs..."
python3 -m pip -q install -U pip build
rm -rf dist/ _skbuild/

log_info "[macOS-build] Building wheel (CMAKE_ARGS=${CMAKE_ARGS})..."
python3 -m build --wheel

if ls dist/*.whl >/dev/null 2>&1; then
  log_info "[macOS-build] Built wheel(s):"
  ls -lh dist/*.whl | cat
  log_info "[macOS-build] Copying to ${OUT_DIR}"
  cp -v dist/*.whl "$OUT_DIR"/
  {
    echo "# macOS-built wheels"
    date -u +"%Y-%m-%dT%H:%M:%SZ"
    python3 -V || true
    echo "Artifacts:"
    ls -1 "$OUT_DIR"/*.whl || true
  } > "$OUT_DIR/index.txt"
  log_info "[macOS-build] Done."
else
  log_warn "[macOS-build] No wheels found under dist/*.whl"
fi


