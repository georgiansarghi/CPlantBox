# Build & Packaging Plan

## Context

- Objective: deliver reproducible binary builds (wheels) and pave the way for continuous delivery without depending on plant-science domain expertise.
- Scope: stabilise build workflows, prepare CI to emit artifacts, and reduce maintenance burden for future testing collaborations.

## Prominent Issues

1. **Ad-hoc build orchestration**
   - Wheel production relies on bespoke bash scripts per platform (e.g. `scripts/manylinux/build/build-wheels.sh`, `scripts/ubuntu/smoke_wheel.sh`).
   - Each script injects its own CMake flags and dependency handling, causing drift and repeated logic.
2. **Fragile dependency configuration**
   - `src/CMakeLists.txt` hard-codes IMPORTED libraries for SuiteSparse/SUNDIALS and hand-toggles cache variables to cope with missing `libpython` artefacts.
   - System vs bundled dependency selection is inconsistent; Ubuntu builds initially failed due to absent `libklu.a` while manylinux expects system packages.
3. **Vendor code management**
   - Large third-party code lives in `src/external/` as copied sources without version pinning or dedicated CMake targets, complicating updates and obscuring provenance.
4. **Repository pollution with build artefacts**
   - Wheel outputs under `wheelhouse/` (macOS, manylinux, Ubuntu) are tracked, hiding source diffs and encouraging manual promotion of binaries.
5. **Sparse test coverage and slow feedback**
   - Current validation is limited to a headless visualization golden image and a basic import/simulate smoke script; no unit or integration test layers exist.
6. **Lack of CI integration**
   - No automated workflow builds wheels or publishes artefacts. Manual runs are time-consuming and error prone.

## Recommended Actions (ordered)

1. **Stabilise environment definitions**
   - Capture exact toolchains for macOS, Ubuntu, and manylinux (x86_64, aarch64) using container definitions or documented Homebrew requirements.
   - Freeze Python versions and base images; ensure container builds install SuiteSparse/SUNDIALS consistently.
2. **Streamline Python discovery in CMake**
   - Replace the current fallback logic with a single `find_package(Python3 COMPONENTS Interpreter Development.Module REQUIRED)` and consume `Python3::Module`.
   - Remove script-provided overrides (`Python3_EXECUTABLE` etc.) unless cross-compiling demands them.
3. **Normalize dependency handling**
   - Write or adopt `FindSuiteSparse.cmake` / `FindSUNDIALS.cmake` modules. Use `target_link_libraries` with imported targets rather than manual `IMPORTED_LOCATION` switching.
   - Decide between vendored static archives or system packages per platform, then codify the choice via cache defaults rather than script flags.
4. **Modularise external sources**
   - Promote third-party components in `src/external` to submodules or `FetchContent` declarations with explicit version tags.
   - Encapsulate each dependency in its own CMake target to isolate compilation flags and simplify upgrades.
5. **Modernise the top-level CMake project**
   - Convert global include directories to target-scoped properties.
   - Extract compiler settings, IPO/LTO, sanitizer toggles into `cmake/Toolchain` or similar for re-use across builds.
6. **Rework scripting layer**
   - Replace the bespoke bash scripts with thin wrappers around `pipx run build` or `python -m build`, relying on consistent `CMAKE_ARGS` rather than inline command branching.
   - Ensure scripts only orchestrate environment setup and artifact collection.
7. **Introduce CI wheel matrix**
   - Add GitHub Actions workflows that run builds for Py39–Py312 on manylinux x86_64 and aarch64, plus macOS ARM (if feasible).
   - Upload wheels via `actions/upload-artifact`; gate merges on successful builds.
8. **Remove artefacts from version control**
   - Update `.gitignore` to exclude `wheelhouse/`, `dist/`, `_skbuild/` and purge tracked binaries.
   - Document how to retrieve CI artifacts instead of relying on committed wheels.
9. **Layer testing strategy**
   - Add fast unit tests for computational kernels (e.g. structural/functional C++ components exposed via pybind11).
   - Preserve headless golden tests as slow integration checks; run them nightly or on demand.
   - Prepare fixtures so domain researchers can extend scenarios without touching the build pipeline.
10. **Document workflows and maintenance**
    - Extend `README.md` or a dedicated `CONTRIBUTING.md` with instructions for local wheel builds, CI expectations, and dependency upgrades.

## Next Steps Checklist

- [ ] Lock container images / toolchains for macOS, Ubuntu, manylinux (x86_64 + aarch64).
- [ ] Simplify Python discovery in `src/CMakeLists.txt` and remove script overrides.
- [ ] Replace manual SuiteSparse/SUNDIALS imports with proper `find_package` modules.
- [ ] Externalise `src/external` dependencies (submodules or FetchContent) with version tracking.
- [ ] Update `.gitignore`; remove committed wheels from the repository history.
- [ ] Introduce GitHub Actions workflow building wheels and uploading artifacts per Python version/architecture.
- [ ] Expand automated tests beyond golden screenshots; define unit and integration layers.
- [ ] Document the standard build/test process for developers and researchers.

This plan should bring the build system to a maintainable state, enabling reliable CI artifacts while leaving headroom for future scientific validation and publication flows.
