#!/usr/bin/env python3
"""Qualify OD20's earlier rejection of the retained R2 forged-length source."""
from pathlib import Path
import sys
import tempfile

DIAGNOSTIC = (b"Semantic Error: [CollectionMetadataAuthority] Collection metadata mutation "
              b"and field-address escape require validated collection operations")


def require(ok, message):
    if not ok:
        raise SystemExit("R4 forged-length frontend rejection: " + message)


def validate(directory, status):
    require(0 < status < 128, "expected normal compiler failure")
    entries = {path.relative_to(directory).as_posix() for path in directory.rglob("*")}
    require(entries == {"compile.stdout", "compile.stderr"} and
            all((directory / name).is_file() and not (directory / name).is_symlink()
                for name in entries), "unexpected artifact or nonregular log")
    stdout = (directory / "compile.stdout").read_bytes()
    stderr = (directory / "compile.stderr").read_bytes()
    require(stdout.startswith(b"TypeError in ") and DIAGNOSTIC in stdout,
            "missing exact frontend diagnostic")
    require(not stderr and b"gust_native_capability_decision:" not in stdout and
            b"gust_backend_" not in stdout, "backend reached before rejection")


def inversions():
    def rejected(label, mutate, expected):
        with tempfile.TemporaryDirectory(prefix="gust-r4-frontend-rejection-") as name:
            directory = Path(name)
            (directory / "compile.stdout").write_bytes(b"TypeError in fixture: " + DIAGNOSTIC + b"\n")
            (directory / "compile.stderr").write_bytes(b"")
            validate(directory, 1)
            status = mutate(directory)
            try:
                validate(directory, 1 if status is None else status)
            except SystemExit as error:
                require(expected in str(error), f"{label}: REJECTED (different assertion): {error}")
                print(f"{label}: REJECTED (expected assertion)")
            else:
                raise SystemExit(f"{label}: ACCEPTED")

    for status in (0, -4, 132):
        rejected(f"wrong compiler status {status}", lambda directory, status=status: status,
                 "expected normal compiler failure")
    for output in (b"", b"TypeError in fixture: unrelated error\n",
                   b"gust_backend_request_failure: stage=canonical_mir_validation\n"):
        def wrong_diagnostic(directory, output=output):
            (directory / "compile.stdout").write_bytes(output)
        rejected("missing or wrong-stage diagnostic", wrong_diagnostic, "missing exact frontend diagnostic")
    def backend(directory):
        (directory / "compile.stderr").write_bytes(b"gust_backend_request_failure: invalid_canonical_mir\n")
    rejected("backend diagnostic", backend, "backend reached before rejection")
    for marker in (b"gust_native_capability_decision:", b"gust_backend_request_failure:"):
        def backend_stdout(directory, marker=marker):
            with (directory / "compile.stdout").open("ab") as output:
                output.write(marker + b"\n")
        rejected("backend marker with correct diagnostic", backend_stdout, "backend reached before rejection")
    for path in ("never-execute", "program.o", "keep/program.mir.bundle"):
        def artifact(directory, path=path):
            output = directory / path
            output.parent.mkdir(parents=True, exist_ok=True)
            output.write_bytes(b"not executable")
        rejected(f"published {path}", artifact, "unexpected artifact")
    def symlink(directory):
        (directory / "never-execute").symlink_to("missing-target")
    rejected("dangling executable symlink", symlink, "unexpected artifact")
    def log_symlink(directory):
        (directory / "compile.stderr").unlink()
        (directory / "compile.stderr").symlink_to("compile.stdout")
    rejected("symlinked compiler log", log_symlink, "unexpected artifact or nonregular log")
    print("R4 earlier frontend rejection inversions ok")


if __name__ == "__main__":
    if sys.argv[1:] == ["inversions"]:
        inversions()
    elif len(sys.argv) == 4 and sys.argv[1] == "validate":
        validate(Path(sys.argv[2]), int(sys.argv[3]))
        print("R4 forged-length source rejected before native publication")
    else:
        raise SystemExit("expected validate DIRECTORY STATUS | inversions")
