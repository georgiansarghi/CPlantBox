#!/usr/bin/env bash
set -euo pipefail

# Uninstall any existing cplantbox from a project-root venv and install a macOS wheel.
# Usage: scripts/macos/install/install-wheel.sh [WHEEL_PATH]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
cd "$REPO_ROOT"

source "$REPO_ROOT/scripts/common/env.sh"
source "$REPO_ROOT/scripts/common/logging.sh"

WHEEL_INPUT=${1:-}

# Detect an existing venv at repo root (or use current VIRTUAL_ENV)
VENV_DIR="${VIRTUAL_ENV:-}"
if [[ -z "$VENV_DIR" || ! -d "$VENV_DIR" ]]; then
  for cand in .venv venv env; do
    if [[ -d "$REPO_ROOT/$cand" ]]; then
      VENV_DIR="$REPO_ROOT/$cand"
      break
    fi
  done
fi

if [[ -z "${VENV_DIR:-}" || ! -d "$VENV_DIR" ]]; then
  die "No virtual environment found at repo root. Create one (e.g., python3 -m venv .venv) and rerun."
fi

log_info "[macOS-install] Using venv: $VENV_DIR"
source "$VENV_DIR/bin/activate"

# Resolve wheel path if not provided: pick latest matching current Python tag, else latest
if [[ -z "$WHEEL_INPUT" ]]; then
  PYTAG=$(python3 - <<'PY'
import sys
print(f"cp{sys.version_info.major}{sys.version_info.minor}")
PY
  )
  WHEEL_DIR="wheelhouse/macos"
  if [[ -d "$WHEEL_DIR" ]]; then
    set +e
    WHEEL_INPUT=$(ls -1t "$WHEEL_DIR"/*"$PYTAG"*.whl 2>/dev/null | head -n1)
    if [[ -z "$WHEEL_INPUT" ]]; then
      WHEEL_INPUT=$(ls -1t "$WHEEL_DIR"/*.whl 2>/dev/null | head -n1)
    fi
    set -e
  fi
fi

if [[ -z "$WHEEL_INPUT" || ! -f "$WHEEL_INPUT" ]]; then
  die "Wheel not found. Provide a path or build one under wheelhouse/macos."
fi

log_info "[macOS-install] Uninstalling existing cplantbox (if present) ..."
python3 -m pip -q install -U pip
python3 -m pip -q uninstall -y cplantbox || true

log_info "[macOS-install] Installing wheel: $WHEEL_INPUT"
python3 -m pip -q install "$WHEEL_INPUT"

# Verify import from installed wheel, not repo source
TMPDIR=$(mktemp -d 2>/dev/null || mktemp -d -t cplantbox-install)
pushd "$TMPDIR" >/dev/null
PYTHONNOUSERSITE=1 python3 - <<'PY'
import plantbox as pb
import os
print("Installed cplantbox:", getattr(pb, "__version__", "?"))
try:
    print("Module file:", pb.__file__)
except Exception:
    pass
print("Data root exists:", os.path.isdir(getattr(pb, "data_path", lambda: "?")()))
PY
popd >/dev/null

log_info "[macOS-install] Done."


