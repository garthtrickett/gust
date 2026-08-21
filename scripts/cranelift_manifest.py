#!/usr/bin/env python3
"""Validate the reduced Cranelift architecture manifest and stable surfaces."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"
TEST_RUNNER = ROOT / "compiler/test_runner_entry.gst"
REQUEST_MODEL = ROOT / "compiler/mir_native_backend_request.gst"
SOURCE_ROUTE = ROOT / "compiler/mir_native_backend_source_route.gst"
ROOT_CARGO = ROOT / "Cargo.toml"
EXPERIMENT_CARGO = ROOT / "compiler/experiments/cranelift/Cargo.toml"
MAKEFILE = ROOT / "Makefile"
JUSTFILE = ROOT / "justfile"

EXPECTED_KEYS = {
    "CRANELIFT_ARCHITECTURE_MANIFEST_VERSION": "2",
    "CRANELIFT_ARCHITECTURE_HIGH_LEVEL_STATUS": (
        "phase12_5_closed_cranelift_verification_framework_consolidation"
    ),
    "CRANELIFT_ARCHITECTURE_BACKEND_ISOLATION": (
        "implementation_and_dependencies_live_under_"
        "compiler/experiments/cranelift"
    ),
    "CRANELIFT_ARCHITECTURE_DEFAULT_BACKEND": "mir-to-c",
    "CRANELIFT_ARCHITECTURE_SUPPORTED_BACKEND_SELECTORS": "mir-to-c,cranelift",
    "CRANELIFT_ARCHITECTURE_WORKER_BOUNDARY": (
        "canonical_MIR_request_path_only_no_raw_source_fields"
    ),
    "CRANELIFT_ARCHITECTURE_ARTIFACT_OWNERSHIP_BOUNDARY": (
        "compiler_owns_request_staging_linking_cleanup_and_atomic_executable_"
        "publication_worker_owns_requested_object_emission"
    ),
    "CRANELIFT_ARCHITECTURE_NO_FALLBACK_POLICY": (
        "explicit_cranelift_success_deferral_or_failure_terminates_without_"
        "MIR-to-C_codegen"
    ),
    "CRANELIFT_ARCHITECTURE_RUNTIME_PACKAGE_BOUNDARY": (
        "gust-native-backend_is_an_installed_sibling_or_absolute_"
        "GUST_NATIVE_BACKEND_DRIVER_no_PATH_search_or_auto_build"
    ),
    "CRANELIFT_ARCHITECTURE_FEATURE_REGISTRY_AUTHORITY": (
        "scripts/cranelift_feature_registry.json"
    ),
    "CRANELIFT_ARCHITECTURE_TEST_LEVEL_AUTHORITY": (
        "scripts/cranelift_test_levels.json"
    ),
    "CRANELIFT_ARCHITECTURE_HISTORICAL_EVIDENCE_OWNER": (
        "scheduled_or_manual_Cranelift_Historical_Full"
    ),
}

KEY_PATTERN = re.compile(r"^(CRANELIFT_ARCHITECTURE_[A-Z0-9_]+): (.+)$")
FORBIDDEN_MANIFEST_PATTERNS = {
    "guard recipe names": re.compile(r"guard-cranelift-"),
    "legacy allowed keys": re.compile(
        r"^(?:allowed_|CRANELIFT_EXPERIMENT_ALLOWED_)", re.MULTILINE
    ),
    "row or family totals": re.compile(r"(?:^|_)COUNT(?:S)?(?::|_)", re.MULTILINE),
    "workflow shard inventories": re.compile(r"\bshard(?:s|_count|_names)?\b", re.I),
    "fixture inventories": re.compile(r"(?:compiler/fixtures/|build/guards/)"),
    "byte hashes": re.compile(r"(?:sha-?256|[0-9a-f]{64})", re.I),
}
JUSTFILE_FORBIDDEN_PATTERNS = {
    "legacy manifest key checks": re.compile(r"CRANELIFT_EXPERIMENT_ALLOWED_"),
    "manifest-derived guard inventory": re.compile(
        r"CRANELIFT_EXPERIMENT_ALLOWED_\.\*_NATIVE_GUARD"
    ),
    "required manifest prose arrays": re.compile(r"required_manifest_lines"),
}


class Error(RuntimeError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise Error(message)


def read(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError as exc:
        raise Error(f"missing required file: {path.relative_to(ROOT)}") from exc


def parse_keys(text: str) -> dict[str, str]:
    found: dict[str, str] = {}
    for line_number, line in enumerate(text.splitlines(), start=1):
        if not line.startswith("CRANELIFT_ARCHITECTURE_"):
            continue
        match = KEY_PATTERN.fullmatch(line)
        require(match is not None, f"invalid manifest key line {line_number}: {line}")
        key, value = match.groups()
        require(key not in found, f"duplicate manifest key: {key}")
        found[key] = value
    return found


def validate_manifest() -> None:
    text = read(MANIFEST)
    keys = parse_keys(text)
    require(
        keys == EXPECTED_KEYS,
        "architecture manifest keys differ from the stable contract: "
        f"missing={sorted(set(EXPECTED_KEYS) - set(keys))} "
        f"unexpected={sorted(set(keys) - set(EXPECTED_KEYS))} "
        f"changed={sorted(key for key in EXPECTED_KEYS if keys.get(key) != EXPECTED_KEYS[key])}",
    )

    for label, pattern in FORBIDDEN_MANIFEST_PATTERNS.items():
        match = pattern.search(text)
        if match is not None:
            raise Error(
                f"architecture manifest contains {label}: {match.group(0)!r}"
            )

    require(len(text.splitlines()) <= 80, "architecture manifest must remain concise")


def verify_phase12_5_closure() -> None:
    validate_manifest()
    keys = parse_keys(read(MANIFEST))
    closure_keys = (
        "CRANELIFT_ARCHITECTURE_HIGH_LEVEL_STATUS",
        "CRANELIFT_ARCHITECTURE_DEFAULT_BACKEND",
        "CRANELIFT_ARCHITECTURE_ARTIFACT_OWNERSHIP_BOUNDARY",
        "CRANELIFT_ARCHITECTURE_NO_FALLBACK_POLICY",
        "CRANELIFT_ARCHITECTURE_HISTORICAL_EVIDENCE_OWNER",
    )
    for key in closure_keys:
        require(
            keys.get(key) == EXPECTED_KEYS[key],
            f"Phase 12.5 closure manifest contract drifted for {key}",
        )

    print(
        "✅ Phase 12.5 manifest closure passed: closed status, MIR-to-C default, "
        "Phase 9G artifact ownership, no fallback, historical-suite ownership, "
        "no raw hashes, and no manually maintained active totals."
    )


def validate_compiler_and_package_surface() -> None:
    test_runner = read(TEST_RUNNER)
    require(
        'os.LogStr("  mir-to-c   Emit C source to stdout (default).");' in test_runner,
        "compiler help must keep mir-to-c as the default backend",
    )
    require(
        'os.LogStr("  --backend <mir-to-c|cranelift>  Select the backend explicitly.");'
        in test_runner,
        "compiler help must expose exactly the two supported backend selectors",
    )
    require(
        'os.LogStr("  cranelift  Compile a supported source cohort to one native executable (experimental).");'
        in test_runner,
        "compiler help must keep Cranelift explicitly experimental",
    )
    for token in (
        "GUST_NATIVE_BACKEND_DRIVER",
        "gust-native-backend",
        "There is no PATH search, auto-build, or",
        "fallback to MIR-to-C.",
    ):
        require(token in test_runner, f"compiler help is missing runtime-boundary token: {token}")

    request_model = read(REQUEST_MODEL)
    for forbidden in ("source_text", "source_bytes", "raw_source", "source_path"):
        require(
            forbidden not in request_model,
            f"worker request model contains forbidden raw-source field: {forbidden}",
        )

    require(
        "program_mir_bundle_path" in request_model
        and "program_bundle" in request_model,
        "worker request must carry canonical MIR through the request boundary",
    )

    source_route = read(SOURCE_ROUTE)
    require(
        "request.mir_native_backend_make_request(" in source_route,
        "source route must construct the compiler-owned native request",
    )
    require(
        "os.WriteFile(request_path, serialized_request)" in source_route,
        "source route must publish the serialized request before driver execution",
    )
    require(
        "mir_to_c_program" not in source_route,
        "source route must not call MIR-to-C code generation",
    )

    # The root Cargo manifest belongs to the deprecated Rust prototype, not to
    # the active Cranelift worker. Keep validating its isolation while it is
    # present, but do not make the architecture contract require that retired
    # prototype to exist.
    if ROOT_CARGO.is_file():
        root_cargo = read(ROOT_CARGO)
        for dependency in (
            "cranelift-codegen",
            "cranelift-frontend",
            "cranelift-module",
            "cranelift-native",
            "cranelift-object",
        ):
            require(
                dependency not in root_cargo,
                f"root Cargo manifest must not own experimental dependency {dependency}",
            )

    experiment_cargo = read(EXPERIMENT_CARGO)
    for dependency in (
        "cranelift-codegen",
        "cranelift-frontend",
        "cranelift-module",
        "cranelift-native",
        "cranelift-object",
    ):
        require(
            dependency in experiment_cargo,
            f"experimental Cargo manifest is missing {dependency}",
        )

    makefile = read(MAKEFILE)
    for token in (
        "phase10-native-package: gust build/gust-native-backend",
        'install -m 0755 build/phase10-package/bin/gust-native-backend',
    ):
        require(token in makefile, f"package boundary is missing: {token}")


def validate_guard_ownership() -> None:
    justfile = read(JUSTFILE)
    for label, pattern in JUSTFILE_FORBIDDEN_PATTERNS.items():
        match = pattern.search(justfile)
        if match is not None:
            raise Error(f"justfile still contains {label}: {match.group(0)!r}")

    require(
        "compiler/CRANELIFT_EXPERIMENT_MANIFEST.md" not in justfile,
        "guards must validate the manifest through scripts/cranelift_manifest.py",
    )
    require(
        'manifest_doc="compiler/CRANELIFT_EXPERIMENT_MANIFEST.md"' not in justfile,
        "guards must not reopen the architecture manifest as an operational inventory",
    )


def validate_authorities() -> None:
    for relative in (
        "scripts/cranelift_feature_registry.json",
        "scripts/cranelift_feature_registry.schema.json",
        "scripts/cranelift_registry.py",
        "scripts/cranelift_test_levels.json",
        "scripts/cranelift_test_levels.py",
    ):
        path = ROOT / relative
        require(path.is_file() and not path.is_symlink(), f"missing regular authority: {relative}")


def validate() -> None:
    validate_manifest()
    validate_compiler_and_package_surface()
    validate_guard_ownership()
    validate_authorities()
    print(
        "✅ Cranelift architecture manifest passed: Phase 12.5 is closed; stable backend "
        "policy remains in the manifest and operational inventory remains in structured authorities."
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "command",
        choices=("validate", "verify-phase12-5-closure"),
    )
    args = parser.parse_args()

    try:
        if args.command == "validate":
            validate()
        elif args.command == "verify-phase12-5-closure":
            verify_phase12_5_closure()
    except (Error, OSError) as exc:
        print(f"cranelift manifest error: {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
