#!/usr/bin/env python3
"""Owning source diagnostics, typed producer, and native collection evidence."""
import json
import os
import platform
from pathlib import Path
import shutil
import subprocess
import tempfile

assert platform.system() == "Linux" and platform.machine() == "x86_64", "R4 qualification profile is x86_64 GNU/Linux"
ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "build/guards/phase26_r4_collection_validity"
OUTPUT.mkdir(parents=True, exist_ok=True)
RUN = Path(tempfile.mkdtemp(prefix="run-", dir=OUTPUT))
COMPILER = ROOT / "gust"
WORKER = ROOT / "build/gust-native-backend"
RUNTIME = ROOT / "build/gust-runtime-package.a"
ENV = dict(os.environ, GUST_NATIVE_BACKEND_DRIVER=str(WORKER))
# Both predecessor owners remain enforced; the rebuild owner's 10-MiB
# ceiling is stricter than R2's versioned compiler-program ceiling.
REBUILD_MAXIMUM = json.loads((ROOT / "scripts/cranelift_feature_registry.json").read_text())["phase21_native_rebuild_reproducibility"]["measurements"]["maximum_artifact_bytes"]
assert COMPILER.stat().st_size <= REBUILD_MAXIMUM, "compiler exceeds native rebuild artifact ceiling"


def command(args, label, expected=0, timeout=240):
    result = subprocess.run([str(arg) for arg in args], cwd=ROOT, env=ENV,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout)
    (RUN / f"{label}.stdout").write_bytes(result.stdout)
    (RUN / f"{label}.stderr").write_bytes(result.stderr)
    if expected is None:
        assert 0 < result.returncode < 128, (label, result.returncode, result.stdout[-4000:], result.stderr[-4000:])
    else:
        assert result.returncode == expected, (label, result.returncode, result.stdout[-4000:], result.stderr[-4000:])
    return result


# Checked arena slots expose an old optional-fold absent annotation read.
# Inferred scalar and existing query-terminal owners must remain available.
for variant in ["original", "renamed"]:
    source = ROOT / "tests/cranelift/phase26_r4_inferred_scalar.gst"
    if variant == "renamed":
        renamed = RUN / "arbitrary-inferred.gst"
        shutil.copyfile(source, renamed)
        source = renamed
    executable = RUN / f"inferred-{variant}"
    command([COMPILER, "--backend", "cranelift", "-o", executable, source], f"inferred-{variant}-compile")
    command([executable], f"inferred-{variant}-run", expected=3)

for name, expected in [("trusted", 21), ("untrusted", 99)]:
    fixture = ROOT / f"compiler/phase21_query_shape_{name}_baseline.gst"
    for variant in ["original", "renamed"]:
        source = fixture
        if variant == "renamed":
            source = RUN / f"arbitrary-query-{name}.gst"
            shutil.copyfile(fixture, source)
        executable = RUN / f"query-{name}-{variant}"
        command([COMPILER, "--backend", "cranelift", "-o", executable, source],
                f"query-{name}-{variant}-compile")
        command([executable], f"query-{name}-{variant}-run", expected=expected)

# Optional recognizers must decline absent initializers before reading slots.
# This registered source retains its explicit public pre-driver deferral.
for variant in ["original", "renamed"]:
    source = ROOT / "tests/test_thread_local_context_registration_valid.gst"
    if variant == "renamed":
        renamed = RUN / "arbitrary-thread-local.gst"
        shutil.copyfile(source, renamed)
        source = renamed
    output = RUN / f"thread-local-{variant}"
    result = command([COMPILER, "--backend", "cranelift", "-o", output, source],
                     f"thread-local-{variant}", expected=None)
    combined = result.stdout + result.stderr
    assert b"expected_failure_stage=before_driver_discovery" in combined
    assert b"reason_code=" in combined and not output.exists()

for label, body in [("two", "mut unused: int; return 3;"),
                    ("three", "mut unused: int; if true { } return 3;")]:
    source = RUN / f"absent-initializer-{label}.gst"
    source.write_text("func main() int { " + body + " }\n")
    output = RUN / f"absent-initializer-{label}"
    result = subprocess.run([str(COMPILER), "--backend", "cranelift", "-o", str(output), str(source)],
                            cwd=ROOT, env=ENV, capture_output=True, timeout=240)
    assert result.returncode in (0, 1), (label, result.returncode, result.stdout, result.stderr)
    if result.returncode != 0:
        assert b"expected_failure_stage=before_driver_discovery" in result.stdout + result.stderr
        assert not output.exists()

for name, diagnostic in [("metadata_write", "CollectionMetadataAuthority"),
                         ("metadata_reference", "CollectionMetadataAuthority"),
                         ("default_collection", "CollectionConstruction")]:
    fixture = ROOT / f"tests/cranelift/phase26_r4_{name}_rejected.gst"
    for variant, source in [("original", fixture), ("renamed", RUN / f"arbitrary-{name}.gst")]:
        if variant == "renamed": shutil.copyfile(fixture, source)
        output = RUN / f"{name}-{variant}-never-execute"
        result = command([COMPILER, "--backend", "cranelift", "-o", output, source], f"{name}-{variant}", expected=None)
        assert f"[{diagnostic}]".encode() in result.stdout + result.stderr
        assert not output.exists() and not output.is_symlink()

# The smoke executable is valid compiler code. Its output is a source-produced
# canonical program; that valid program is validated, lowered, linked and run.
smoke = RUN / "typed-producer"
command([COMPILER, "--backend", "cranelift", "-o", smoke,
         ROOT / "compiler/typechecker_phase26_collection_authority_test_entry.gst"], "producer-build")
def source_native(label, source=None, expected=7):
    result = command([smoke] + ([source] if source else []), f"{label}-producer-run")
    canonical = RUN / f"{label}.canonical"
    assert result.stdout.endswith(b"\n\n"), "producer logger must add exactly its trailing newline"
    canonical.write_bytes(result.stdout[:-1])
    assert b"|collection_pop.v1|" in result.stdout
    command([WORKER, "phase21-full-program-validate", canonical], f"{label}-validate")
    obj = RUN / f"{label}.o"
    command([WORKER, "phase21-full-program-object", canonical, obj], f"{label}-object")
    executable = RUN / label
    command(["/usr/bin/cc", obj, RUNTIME, "-lpthread", "-ldl", "-lm", "-o", executable], f"{label}-link")
    command(["/bin/sh", "-c", 'ulimit -c 0; exec "$1"', "checked-source", executable],
            f"{label}-native-run", expected=expected)

source_native("source-program")
remove = "func remove(ctx: &Arena, values: &std.Vector[int, ctx]) int { return values.Pop(); } "
main = "func main() int { mut arena := os.Arena.New(); "
public_source = RUN / "public-valid.gst"
public_source.write_text(remove + main + "mut values: std.Vector[int, arena] := std.VectorNew(arena); "
    "values.Push(7); return remove(arena, &values); }")
public_executable = RUN / "public-valid"
command([COMPILER, "--backend", "cranelift", "-o", public_executable, public_source], "public-compile")
command([public_executable], "public-native-run", expected=7)

for initialized in [False, True]:
    setup = ("mut values: std.Vector[int, arena] := std.VectorNew(arena); values.Push(7); "
             "arena.Set(slot, values); ") if initialized else ""
    source_native(f"arena-slot-{initialized}", remove + main +
        "mut slot: Index[std.Vector[int, arena], arena] := os.ArenaAlloc(arena); " + setup +
        "mut borrowed := arena.get_ref(slot); return remove(arena, borrowed); }", 7 if initialized else -4)
    setup = "box.values = std.VectorNew(arena); box.values.Push(7); " if initialized else ""
    source_native(f"nested-{initialized}", "type Box[ctx] struct { values: std.Vector[int, ctx] } " +
        remove + main + "mut box: Box[arena]; " + setup + "return remove(arena, &box.values); }",
        7 if initialized else -4)

source_native("absent-arena-slot", remove + main +
    "mut slot := empty[Index[std.Vector[int, arena], arena]]; "
    "return remove(arena, arena.get_ref(slot)); }", -4)
source_native("returned-nested", "type Box[ctx] struct { values: std.Vector[int, ctx] } " + remove +
    "func make(ctx: &Arena) Box[ctx] { mut box: Box[ctx]; box.values = std.VectorNew(ctx); "
    "box.values.Push(7); return box; } " + main + "mut box := make(arena); return remove(arena, &box.values); }")

# The public enum-argument cohort stays explicitly deferred; qualify the
# existing typed component without calling it public source admission.
source_native("inactive-enum-component", "type Maybe[ctx] enum { None, Some { val: Index[std.Vector[int, ctx], ctx] } } " +
    "func check(ctx: &Arena, value: Maybe[ctx]) int { match value { None => { return 7; } Some { val } => { return 8; } } } " +
    main + "mut optional: Maybe[arena]; return check(arena, optional); } " + remove)

ENV.update(GUST_R4_RUNTIME_ARCHIVE=str(RUNTIME), GUST_R4_TEST_OUTPUT=str(RUN / "native"))
native_result = command(["cargo", "test", "--locked", "--manifest-path", ROOT / "compiler/experiments/cranelift/Cargo.toml",
         "checked_collection::tests", "--", "--include-ignored", "--nocapture"], "native", timeout=600)
assert b"test result: ok. 6 passed; 0 failed; 0 ignored" in native_result.stdout, "R4 native test population did not execute"
# Invert each growth check in an isolated source copy. The production tree is
# never rewritten; each mutant must fail its corresponding semantic assertion.
crate = ROOT / "compiler/experiments/cranelift"
for check, label in [("count_valid", "growth-count-overflow"), ("bytes_valid", "growth-byte-overflow")]:
    mutant = RUN / f"without-{check}" / "compiler/experiments/cranelift"
    mutant.parent.mkdir(parents=True)
    (mutant.parents[1] / "fixtures").symlink_to(ROOT / "compiler/fixtures", target_is_directory=True)
    shutil.copytree(crate, mutant, ignore=shutil.ignore_patterns("target"))
    manifest = mutant / "Cargo.toml"
    package = f"gust-cranelift-r4-without-{check.replace('_', '-')}"
    original_manifest = manifest.read_text()
    assert original_manifest.count('name = "gust-cranelift-experiment"') == 1
    manifest.write_text(original_manifest.replace('name = "gust-cranelift-experiment"', f'name = "{package}"', 1))
    lock = mutant / "Cargo.lock"
    lock.write_text(lock.read_text().replace('name = "gust-cranelift-experiment"', f'name = "{package}"', 1))
    helper = mutant / "src/checked_collection.rs"
    original = helper.read_text()
    assertion = f"    builder.ins().trapz({check}, trap());"
    emitter, separator, rest = original.partition("// Private object-local")
    assert separator and emitter.count(assertion) == 1, "growth inversion did not find exactly its intended mechanism"
    helper.write_text(emitter.replace(assertion, "    // Qualification mutant: selected check removed.", 1) + separator + rest)
    ENV.update(GUST_R4_TEST_OUTPUT=str(RUN / f"mutant-output-{check}"),
               CARGO_TARGET_DIR=str(crate / "target"))
    result = command(["cargo", "test", "--locked", "--manifest-path", mutant / "Cargo.toml",
        "checked_collection::tests::growth_boundaries_use_allocator_bytes_without_i32_byte_ceiling",
        "--", "--include-ignored", "--nocapture"], f"inversion-{check}", expected=None, timeout=600)
    assert f"{label}: expected native overflow trap".encode() in result.stdout + result.stderr, \
        "growth mutant was REJECTED (different assertion)"
print(json.dumps({"guard": "phase26-r4-collection-validity", "status": "PASS", "artifacts": str(RUN),
                  "old_malformed_programs_executed": False, "release_wrapper_status": "OPEN"}))
