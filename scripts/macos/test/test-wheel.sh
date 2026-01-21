#!/usr/bin/env bash
set -euo pipefail

# Test a macOS wheel by installing it into a fresh venv and running:
# 1) minimal import/simulate smoke
# 2) headless golden image comparison
# Usage: scripts/macos/test/test-wheel.sh [WHEEL_PATH]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
cd "$REPO_ROOT"

source "$REPO_ROOT/scripts/common/env.sh"
source "$REPO_ROOT/scripts/common/logging.sh"

WHEEL_PATH_INPUT=${1:-}

if [[ -z "$WHEEL_PATH_INPUT" ]]; then
  WHEEL_DIR="wheelhouse/macos"
  if [[ ! -d "$WHEEL_DIR" ]]; then
    die "No wheelhouse dir found at $WHEEL_DIR. Run macOS build first."
  fi
  WHEEL_PATH_INPUT=$(ls -1t "$WHEEL_DIR"/*.whl | head -n1)
fi

if [[ ! -f "$WHEEL_PATH_INPUT" ]]; then
  die "Wheel not found: $WHEEL_PATH_INPUT"
fi

# Convert to absolute path for clarity
WHEEL_ABS=$(python3 -c 'import os,sys; print(os.path.abspath(sys.argv[1]))' "$WHEEL_PATH_INPUT")

log_info "[macOS-test] Using wheel: $WHEEL_ABS"

# Reuse the same inner logic as a dedicated runner script
"$REPO_ROOT/scripts/macos/test/run_golden.sh" "$WHEEL_ABS"

log_info "[macOS-test] Completed."


