scripts/
========

High-level entry points for building and testing CPlantBox wheels across macOS, manylinux, and Ubuntu environments. Legacy helpers remain in `old_scripts/` for reference.

Common Utilities
----------------

- `common/env.sh` sets deterministic defaults (`OMP_NUM_THREADS=1`) and provides `repo_root` for locating the repository root.
- `common/logging.sh` adds simple timestamped logging helpers (`log_info`, `log_warn`, `log_error`, `die`).
- `common/docker.sh` wraps common Docker buildx operations and includes helpers to run commands inside project-mounted containers.
- `common/golden_test.py` runs the cross-platform golden image smoke test. It installs the wheel into the active interpreter context, renders a deterministic plant image, copies artifacts back to `test/golden`, and compares against platform-specific goldens.

macOS Workflow
--------------

- `macos/run_all.sh` orchestrates a full macOS wheel build followed by the golden test smoke.
- `macos/build/build-wheel.sh` builds a wheel directly on the host (Apple Silicon preferred) using Homebrew-provided SuiteSparse and Sundials. Artifacts land in `wheelhouse/macos` with an `index.txt` summary.
- `macos/install/install-wheel.sh` locates a repository virtual environment (or uses `$VIRTUAL_ENV`), removes any existing install, installs the selected macOS wheel, and verifies import plus data availability.
- `macos/test/test-wheel.sh` selects the latest wheel for the host architecture and dispatches to `run_golden.sh` for the full smoke.
- `macos/test/run_golden.sh` creates temporary virtual environments for two phases: a minimal import/simulate smoke and the headless golden comparison executed via `macos/test/golden_test.py`.
- `macos/test/golden_test.py` mirrors the shared golden logic but fixes expectations for macOS-specific reference imagery.

manylinux Workflow
------------------

- `manylinux/build/build-wheels.sh [x86_64|aarch64]` builds manylinux2014 wheels inside PyPA containers for CPython 3.9–3.12. It relies on architecture-specific Dockerfiles that install SuiteSparse and compile a static Sundials into `/opt/sundials`, then repairs wheels with `auditwheel` and stores them under `wheelhouse/linux/manylinux2014_<arch>`.
- `manylinux/test/test-wheel.sh [arch] [wheel]` reuses the Ubuntu golden test runner to validate a selected manylinux wheel on the matching architecture.
- `manylinux/test/run_golden_in_container.sh [arch] <wheel>` spins up a dedicated manylinux test container, installs pytest/vtk, provisions the wheel, and executes the shared `golden_test.py` under Xvfb.
- `manylinux/test/Dockerfile_{x86_64,aarch64}` define the headless testing containers preloaded with the required OpenGL/X11 packages and vtk (9.5.0 for aarch64).

Ubuntu Workflow
---------------

- `ubuntu/run_all.sh` builds the local Ubuntu test image and runs the smoke flow end-to-end.
- `ubuntu/build_image.sh` ensures a buildx builder exists and builds `docker/Dockerfile.ubuntu-test-env` into `cplantbox-ubuntu-test-env` for `linux/amd64`.
- `ubuntu/smoke_wheel.sh` enters the test image, builds a wheel, performs minimal smoke tests plus a pytest-based golden comparison (with VTK installed), and copies non-portable artifacts to `wheelhouse/linux/ubuntu`.
- `ubuntu/build/build-wheel.sh [platform]` builds architecture-specific Ubuntu images (`Dockerfile_amd64` or `Dockerfile_arm64`), runs wheel builds inside them, and publishes results to `wheelhouse/linux/ubuntu/<arch>`.
- `ubuntu/test/test-wheel.sh [platform] [wheel]` builds a headless Ubuntu test image, calculates the wheel path relative to the repo root, and runs `run_golden_in_container.sh` inside the container.
- `ubuntu/test/run_golden_in_container.sh <wheel>` creates a venv with system GL drivers, installs the wheel, launches the golden smoke under `xvfb-run`, and pins `CPB_GOLDEN_OS=linux`.
- `ubuntu/test/Dockerfile_{amd_64,arm64}` create the headless test images with Mesa/OpenGL/Xvfb dependencies and architecture-appropriate vtk versions (9.2.6 for amd64, 9.5.0 for arm64).

Operational Notes
-----------------

- Docker Desktop with buildx and QEMU is required to build or test non-native architectures on macOS hosts.
- Most flows clean `dist/` and `_skbuild/` before kicking off a build to avoid stale artifacts.
- After many scripts finish, wheel artifacts are copied into architecture-specific subdirectories of `wheelhouse/` alongside a timestamped `index.txt` for quick inspection.
- Golden tests expect reference imagery under `test/golden/<os>/example_plant_headless.png`; regenerated test artifacts land at `test/golden/generated_by_test.png` for manual review.
