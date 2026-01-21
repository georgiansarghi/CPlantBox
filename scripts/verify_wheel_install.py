import argparse
import os
import shutil
import subprocess
import sys
import tempfile


def run(cmd, env=None, cwd=None):
    print(">", " ".join(cmd))
    subprocess.check_call(cmd, env=env, cwd=cwd)


def main() -> int:
    parser = argparse.ArgumentParser(description="Verify CPlantBox wheel install and imports.")
    parser.add_argument("wheel", help="Path to wheel (.whl)")
    parser.add_argument(
        "--keep-venv",
        action="store_true",
        help="Keep the temporary venv after running",
    )
    args = parser.parse_args()

    wheel = os.path.abspath(args.wheel)
    if not os.path.isfile(wheel):
        print(f"Wheel not found: {wheel}", file=sys.stderr)
        return 2

    workdir = tempfile.mkdtemp(prefix="cpb-verify-")
    venv_dir = os.path.join(workdir, "venv")
    python = os.path.join(venv_dir, "bin", "python")

    try:
        run([sys.executable, "-m", "venv", venv_dir])
        run([python, "-m", "pip", "-q", "install", "-U", "pip"])
        run([python, "-m", "pip", "-q", "install", wheel])
        vtk_version = os.environ.get("VTK_VERSION")
        if vtk_version:
            run([python, "-m", "pip", "-q", "install", f"vtk=={vtk_version}"])
        else:
            run([python, "-m", "pip", "-q", "install", "vtk"])
        run([python, "-m", "pip", "-q", "install", "scipy"])
        run([python, "-m", "pip", "-q", "install", "mpi4py"])
        code = r"""
import os
import plantbox as pb
print("plantbox:", pb.__file__)
print("data_path:", pb.data_path())
rootsys = os.path.join(pb.data_path(), "structural", "rootsystem", "Anagallis_femina_Leitner_2010.xml")
print("rootsys exists:", os.path.exists(rootsys))
import plantbox.visualisation.vtk_plot as vp
print("vtk_plot:", vp.__file__)
"""
        env = dict(os.environ)
        env.pop("PYTHONPATH", None)
        mpi_lib_dirs = [
            "/opt/homebrew/opt/open-mpi/lib",
            "/usr/local/opt/open-mpi/lib",
        ]
        for d in mpi_lib_dirs:
            if os.path.isdir(d):
                existing = env.get("DYLD_LIBRARY_PATH", "")
                env["DYLD_LIBRARY_PATH"] = f"{d}:{existing}" if existing else d
                break
        run([python, "-c", code], env=env, cwd=workdir)
        return 0
    finally:
        if args.keep_venv:
            print(f"Keeping venv at: {venv_dir}")
        else:
            shutil.rmtree(workdir, ignore_errors=True)


if __name__ == "__main__":
    raise SystemExit(main())
