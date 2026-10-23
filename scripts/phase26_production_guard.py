#!/usr/bin/env python3
"""Qualify the enrolled production profile from reproducible public inputs."""
from __future__ import annotations
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
PROFILE = ROOT / "compiler/experiments/cranelift/production"
SCRATCH = ROOT / "build/guards/phase26_production_trust"


def run(args, **kwargs):
    print("RUN", " ".join(map(str, args)), flush=True)
    return subprocess.run(list(map(str, args)), cwd=ROOT, check=True, **kwargs)


def offline_command(args, environment):
    # Root creates only the network namespace. Drop to the original uid/gid
    # before running any compiler or generated program, with no new privilege.
    return ["/usr/bin/sudo", "-n", "/usr/bin/unshare", "--net", "--",
            "/usr/bin/setpriv", "--reuid=" + str(os.getuid()), "--regid=" + str(os.getgid()),
            "--clear-groups", "--no-new-privs", "--", "/usr/bin/env", "-i",
            *(key + "=" + value for key, value in environment.items()), *map(str, args)]


def main():
    if SCRATCH.exists(): shutil.rmtree(SCRATCH)
    SCRATCH.mkdir(parents=True)
    run(["python3", "scripts/phase26_production_toolchain.py", "verify"])
    source = ROOT / "build/guards/phase26_r3_zlib_adapter/build/package"
    if not source.exists():
        raise SystemExit("production owning guard requires preceding pinned R3 artifact build")
    candidate = SCRATCH / "candidate"
    run(["python3", "scripts/phase26_production_package.py", source,
         ROOT / "build/gust-runtime-package.a", PROFILE / "public-identity.json", candidate])
    manifest = candidate / "package/manifest.txt"
    if manifest.read_bytes() != (PROFILE / "manifest.txt").read_bytes():
        raise SystemExit("production artifact set differs from pinned signed manifest; "
                         f"review unsigned candidate {candidate}; sha256=" +
                         hashlib.sha256(manifest.read_bytes()).hexdigest())
    shutil.copyfile(PROFILE / "manifest.sig", candidate / "package/manifest.sig")
    package = candidate / "package"
    linked = SCRATCH / "linked"
    linked.mkdir()
    environment = dict(os.environ, CARGO_BUILD_JOBS="1",
        GUST_PRODUCTION_PACKAGE_DIR=str(package), GUST_PRODUCTION_EXECUTABLE_DIR=str(linked),
        GUST_R2_RUNTIME_ARCHIVE=str(ROOT / "build/gust-runtime-package.a"),
        GUST_R2_RUNTIME_SHA256=hashlib.sha256((ROOT / "build/gust-runtime-package.a").read_bytes()).hexdigest())
    for test in ("enrolled_signature_and_snapshot_fail_closed",
                 "enrolled_production_admission_negative_matrix",
                 "enrolled_production_package_links_and_executes_offline"):
        args = ["cargo", "test", "--locked", "--manifest-path",
                "compiler/experiments/cranelift/Cargo.toml",
                "approved_package::tests::" + test, "--", "--exact", "--nocapture"]
        if test != "enrolled_signature_and_snapshot_fail_closed": args.append("--ignored")
        run(args, env=environment)
    tools = SCRATCH / "clean-tools"
    tools.mkdir()
    for source_path, name in [(ROOT / "gust", "gust"),
                              (ROOT / "build/gust-native-backend", "gust-native-backend"),
                              (package / "gust-runtime-package.a", "gust-runtime-package.a")]:
        shutil.copyfile(source_path, tools / name)
        if name != "gust-runtime-package.a": (tools / name).chmod(0o755)
    shutil.copytree(package, tools / "approved-packages/gust_zlib_1_3_2_production")
    clean_env = {"PATH": "/usr/bin:/bin", "LC_ALL": "C", "HOME": str(SCRATCH),
                 "GUST_TEST_MIR_TO_C_UNAVAILABLE": "1",
                 "GUST_NATIVE_BACKEND_DRIVER": str(tools / "gust-native-backend")}
    launcher_env = {"PATH": "/usr/bin:/bin", "LC_ALL": "C"}
    isolated = subprocess.check_output(offline_command(
        ["/usr/bin/readlink", "/proc/self/ns/net"], launcher_env), env=launcher_env, text=True).strip()
    if isolated == os.readlink("/proc/self/ns/net"):
        raise SystemExit("offline launcher did not change the network namespace")
    results = []
    for case, expected in [("compress", 10), ("decompress", 2), ("empty_decompress", 0)]:
        source_path = ROOT / f"tests/cranelift/phase26_r3_zlib_{case}.gst"
        output = SCRATCH / ("offline-" + case)
        run(offline_command([tools / "gust", "--backend", "cranelift", "-o", output, source_path],
                            clean_env), env=launcher_env)
        status = subprocess.run(offline_command([output],
            {"LD_PRELOAD": "/untrusted.so", "LD_LIBRARY_PATH": "/untrusted"}), env=launcher_env)
        if status.returncode != expected: raise SystemExit(f"production {case}: {status.returncode} != {expected}")
        headers = subprocess.check_output(["readelf", "-l", output], text=True)
        if "INTERP" in headers or "DYNAMIC" in headers:
            raise SystemExit("production executable has dynamic runtime dependencies")
        results.append(dict(case=case, exit=status.returncode,
                            sha256=hashlib.sha256(output.read_bytes()).hexdigest()))
    (SCRATCH / "result.json").write_text(json.dumps({"status": "PASS production profile only; Phase26.1 OPEN",
        "snapshot": json.loads((PROFILE / "snapshot.json").read_text()),
        "offline_network_namespace_verified": True, "cases": results}, indent=2) + "\n")
    print("PRODUCTION_PROFILE_QUALIFICATION_PASS", flush=True)


if __name__ == "__main__": main()
