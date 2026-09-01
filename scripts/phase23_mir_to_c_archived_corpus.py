#!/usr/bin/env python3
"""Capture and validate the immutable Patch 23.11 MIR-to-C reference corpus."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os
import resource
import subprocess
import tempfile
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TASK = ROOT / "TASK.md"
CORPUS = ROOT / "compiler/fixtures/phase23_mir_to_c_reference_corpus_v1.json"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE23_MIR_TO_C_ARCHIVED_CORPUS.md"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
JUSTFILE = ROOT / "justfile"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
WORKFLOW = ROOT / ".github/workflows/phase23-mir-to-c-archived-corpus.yml"
GUST = ROOT / "gust"
WORKER = ROOT / "build/gust-native-backend"
RUNTIME_PACKAGE = ROOT / "build/gust-runtime-package.a"
GUARD_L1 = "guard-cranelift-phase23-mir-to-c-archived-corpus-contract"
GUARD_L2 = "guard-cranelift-phase23-mir-to-c-archived-corpus-evidence"
EMPTY_SHA256 = hashlib.sha256(b"").hexdigest()
NORMALIZED_ENV = {
    "LANG": "C",
    "LC_ALL": "C",
    "SOURCE_DATE_EPOCH": "0",
    "TZ": "UTC",
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD_L1}: {message}")


def digest_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def canonical_digest(value: object) -> str:
    return digest_bytes(json.dumps(
        value, sort_keys=True, separators=(",", ":"), ensure_ascii=True,
    ).encode("utf-8"))


def run(command: list[str], *, cwd: Path = ROOT) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(
        command, cwd=cwd, check=False, stdout=subprocess.PIPE,
        stderr=subprocess.PIPE, env={**os.environ, **NORMALIZED_ENV},
    )


def bytes_record(value: bytes) -> dict[str, object]:
    return {
        "size": len(value),
        "sha256": digest_bytes(value),
        "hex": value.hex(),
    }


def file_identity(path: Path, registered: str) -> dict[str, str]:
    if path.is_file():
        return {"kind": "file_sha256", "identity": digest_bytes(path.read_bytes())}
    require(registered.startswith("none_compiler_generated_"),
            f"unclassified canonical MIR identity: {registered}")
    return {
        "kind": "registered_generated_token",
        "identity": canonical_digest({"registered_token": registered}),
    }


def candidate_rows(registry: dict) -> list[dict[str, object]]:
    rows = []
    for entry in sorted(
        (item for item in registry["entries"] if item.get("status") == "migrated"),
        key=lambda item: str(item["id"]),
    ):
        require(entry.get("route_owner") == "generic_canonical_mir",
                f"archive candidate is not generic canonical MIR: {entry['id']}")
        source = str(entry["source_fixture"])
        source_path = ROOT / source
        require(source_path.is_file(), f"archive source is missing: {source}")
        canonical = str(entry["canonical_mir_fixture"])
        rows.append({
            "id": str(entry["id"]),
            "feature_family": str(entry["feature_family"]),
            "source_fixture": source,
            "source_sha256": digest_bytes(source_path.read_bytes()),
            "canonical_mir_fixture": canonical,
            **{
                f"canonical_mir_{key}": value
                for key, value in file_identity(ROOT / canonical, canonical).items()
            },
            "complete_registry_entry_sha256": canonical_digest(entry),
        })
    require(len(rows) == 34, "registered archive-candidate count drifted")
    require(len({row["id"] for row in rows}) == len(rows),
            "archive-candidate IDs are not unique")
    return rows


def side_effects(root: Path) -> list[dict[str, object]]:
    return [
        {
            "path": path.relative_to(root).as_posix(),
            "size": path.stat().st_size,
            "sha256": digest_bytes(path.read_bytes()),
        }
        for path in sorted(root.rglob("*")) if path.is_file()
    ]


def elf_contract(path: Path) -> dict[str, object]:
    header = run(["readelf", "-h", str(path)])
    require(header.returncode == 0, f"cannot inspect artifact: {path.name}")
    require(b"ELF64" in header.stdout and b"Advanced Micro Devices X86-64" in header.stdout,
            f"artifact target drifted: {path.name}")
    return {
        "kind": "linked_native_executable",
        "elf_class": "ELF64",
        "machine": "Advanced Micro Devices X86-64",
        "size": path.stat().st_size,
        "sha256": digest_bytes(path.read_bytes()),
    }


def validate_bytes_record(record: object, *, allow_nonempty: bool) -> bool:
    if not isinstance(record, dict) or set(record) != {"size", "sha256", "hex"}:
        return False
    try:
        value = bytes.fromhex(str(record["hex"]))
    except ValueError:
        return False
    return (
        record["size"] == len(value)
        and record["sha256"] == digest_bytes(value)
        and (allow_nonempty or not value)
    )


def case_policy_accepts(
    case: dict[str, object], candidate: dict[str, object], capture: dict[str, object]
) -> bool:
    required = {
        *candidate.keys(), "oracle_route", "compile", "link", "execution",
        "side_effects", "artifact", "loss_state", "provenance_sha256",
    }
    if set(case) != required or any(case.get(key) != value for key, value in candidate.items()):
        return False
    compile_record = case.get("compile", {})
    link = case.get("link", {})
    execution = case.get("execution", {})
    artifact = case.get("artifact", {})
    if not (
        case.get("oracle_route") == "explicit_--backend_mir-to-c"
        and case.get("loss_state") == "passed"
        and isinstance(compile_record, dict)
        and compile_record.get("exit") == 0
        and validate_bytes_record(compile_record.get("generated_c"), allow_nonempty=True)
        and compile_record["generated_c"]["size"] > 0
        and validate_bytes_record(compile_record.get("stderr"), allow_nonempty=False)
        and isinstance(link, dict) and link.get("exit") == 0
        and validate_bytes_record(link.get("stdout"), allow_nonempty=False)
        and validate_bytes_record(link.get("stderr"), allow_nonempty=False)
        and isinstance(execution, dict) and isinstance(execution.get("exit"), int)
        and validate_bytes_record(execution.get("stdout"), allow_nonempty=True)
        and validate_bytes_record(execution.get("stderr"), allow_nonempty=True)
        and isinstance(case.get("side_effects"), list)
        and isinstance(artifact, dict)
        and artifact.get("kind") == "linked_native_executable"
        and artifact.get("elf_class") == "ELF64"
        and artifact.get("machine") == "Advanced Micro Devices X86-64"
        and isinstance(artifact.get("size"), int) and artifact["size"] > 0
        and isinstance(artifact.get("sha256"), str) and len(artifact["sha256"]) == 64
    ):
        return False
    return case.get("provenance_sha256") == canonical_digest({
        "capture": capture,
        "candidate": candidate,
        "oracle_route": case["oracle_route"],
    })


def corpus_policy_accepts(
    corpus: dict[str, object], candidates: list[dict[str, object]],
    capture: dict[str, object], policy: dict[str, object],
) -> bool:
    return (
        set(corpus) == {"format", "capture_authority", "supersession_policy", "cases"}
        and corpus.get("format") == "gust.phase23.mir_to_c_reference_corpus.v1"
        and corpus.get("capture_authority") == capture
        and corpus.get("supersession_policy") == policy
        and isinstance(corpus.get("cases"), list)
        and len(corpus["cases"]) == len(candidates)
        and all(
            isinstance(case, dict) and case_policy_accepts(case, candidate, capture)
            for case, candidate in zip(corpus["cases"], candidates, strict=True)
        )
    )


def validate_mutations(
    corpus: dict[str, object], candidates: list[dict[str, object]],
    capture: dict[str, object], policy: dict[str, object],
) -> None:
    probes = []
    missing = copy.deepcopy(corpus); missing["cases"] = missing["cases"][1:]
    probes.append(("missing reference", missing))
    stale = copy.deepcopy(corpus); stale["cases"][0]["source_sha256"] = "0" * 64
    probes.append(("stale reference", stale))
    malformed = copy.deepcopy(corpus); del malformed["cases"][0]["execution"]
    probes.append(("malformed reference", malformed))
    empty = copy.deepcopy(corpus)
    empty["cases"][0]["compile"]["generated_c"] = bytes_record(b"")
    probes.append(("empty reference", empty))
    wrong_source = copy.deepcopy(corpus)
    wrong_source["cases"][0]["source_fixture"] = "compiler/wrong-source.gst"
    probes.append(("wrong-source reference", wrong_source))
    wrong_toolchain = copy.deepcopy(corpus)
    wrong_toolchain["capture_authority"]["cc"] = "unregistered compiler"
    probes.append(("wrong-toolchain reference", wrong_toolchain))
    substituted = copy.deepcopy(corpus)
    substituted["cases"][0]["compile"]["generated_c"]["sha256"] = "f" * 64
    probes.append(("digest-substituted reference", substituted))
    for name, probe in probes:
        require(not corpus_policy_accepts(probe, candidates, capture, policy),
                f"accepted {name}")


def validate() -> tuple[dict, dict[str, object]]:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    record = registry.get("phase23_mir_to_c_archived_corpus")
    require(isinstance(record, dict), "Patch 23.11 authority is missing")
    require(record.get("contract_version") == "phase23_mir_to_c_archived_corpus_v1"
            and record.get("status") == "patch23_11_complete"
            and record.get("next_patch") == "23.12", "status or successor drifted")
    require(record.get("owner") == "cranelift"
            and record.get("review_view") == REVIEW.relative_to(ROOT).as_posix()
            and record.get("renderer") == Path(__file__).relative_to(ROOT).as_posix()
            and record.get("corpus_path") == CORPUS.relative_to(ROOT).as_posix(),
            "owner or artifact authority drifted")
    require(CORPUS.is_file(), "archived corpus is missing")
    corpus = json.loads(CORPUS.read_text(encoding="utf-8"))
    candidates = candidate_rows(registry)
    capture = record.get("capture_authority")
    policy = record.get("supersession_policy")
    require(isinstance(capture, dict) and isinstance(policy, dict),
            "capture or supersession authority is missing")
    require(corpus_policy_accepts(corpus, candidates, capture, policy),
            "archived corpus or provenance drifted")
    require(record.get("case_count") == len(candidates)
            and record.get("case_manifest_sha256") == canonical_digest(corpus["cases"])
            and record.get("corpus_sha256") == digest_bytes(CORPUS.read_bytes()),
            "archived corpus identity drifted")
    phase22_extension = record.get("phase22_closed_inventory_extension")
    require(isinstance(phase22_extension, dict) and {
        key: value for key, value in phase22_extension.items()
        if key != "commands"
    } == {
        "status": "exact_phase23_extension_excluded_only_from_phase22_relay_identity",
        "owning_patch": "23.11",
        "path": "scripts/phase23_mir_to_c_archived_corpus.py",
        "selection": "implicit_default",
        "invocation_count": 1,
        "phase22_relay_contract":
            "the_exact_six_site_Stdlib_relay_and_306_invocation_inventory_remain_unchanged",
        "phase23_contract":
            "the_single_default_Cranelift_archive_replay_call_remains_visible_in_the_live_scan_and_is_owned_by_the_Patch_23_11_evidence_guard",
        "falsifier":
            "missing_partial_extra_path_command_or_selection_drift_is_rejected",
    }, "Patch 23.11 Phase 22 closed-inventory successor drifted")
    extension_commands = phase22_extension.get("commands")
    require(isinstance(extension_commands, list)
            and len(extension_commands) == 1
            and extension_commands[0] == "[str(GUST)]",
            "Patch 23.11 Phase 22 successor command drifted")
    validate_mutations(corpus, candidates, capture, policy)
    focused = registry.get("phase23_mir_to_c_focused_live", {})
    require(focused.get("status") == "patch23_10_complete"
            and focused.get("cohort", {}).get("family_count") == 14
            and focused.get("cohort", {}).get("program_count") == 6,
            "focused live lane was replaced or weakened")
    require(record.get("boundary") == {
        "changes_accepted_Gust_program_meaning": False,
        "adds_or_changes_MIR_operations": False,
        "changes_ABI_layout_runtime_symbols_target_or_linker": False,
        "changes_backend_route_default_or_fallback": False,
        "changes_bootstrap_route_or_seed": False,
        "edits_stdlib_or_CR15": False,
        "begins_patch23_12": False,
    }, "Patch 23.11 boundary widened")
    task = TASK.read_text(encoding="utf-8")
    for patch in ("23.7", "23.8", "23.8a", "23.9", "23.10", "23.11"):
        require(f"- [x] Patch {patch} " in task and " — DONE" in next(
            line for line in task.splitlines() if line.startswith(f"- [x] Patch {patch} ")
        ), f"mandatory Patch {patch} status is not DONE")
    levels = json.loads(LEVELS.read_text(encoding="utf-8"))["guards"]
    require(levels.get(GUARD_L1) == 1 and levels.get(GUARD_L2) == 2,
            "Patch 23.11 guard levels drifted")
    just = JUSTFILE.read_text(encoding="utf-8")
    require(f"{GUARD_L1}:" in just and f"{GUARD_L2}:" in just,
            "Patch 23.11 just guards are missing")
    require(f"just {GUARD_L1}" in PR_FAST.read_text(encoding="utf-8"),
            "PR Fast does not own the Patch 23.11 contract")
    workflow = WORKFLOW.read_text(encoding="utf-8")
    for token in (f"just {GUARD_L1}", f"just {GUARD_L2}",
                  "make gust phase10-native-package"):
        require(workflow.count(token) == 1,
                f"archive workflow ownership drifted: {token}")
    require("--backend mir-to-c" not in workflow and "--backend c" not in workflow,
            "archive replay added a second live-C workflow")
    require(REVIEW.is_file() and REVIEW.read_text(encoding="utf-8") == render(record),
            "generated archived-corpus review is stale; run project")
    return record, corpus


def replay_case(case: dict[str, object], root: Path) -> None:
    case_root = root / str(case["id"])
    case_root.mkdir()
    source = str(case["source_fixture"])
    env = {**os.environ, **NORMALIZED_ENV,
           "GUST_NATIVE_BACKEND_DRIVER": str(WORKER.resolve())}
    artifacts = []
    results = []
    effects = []
    for route in ("default", "explicit"):
        artifact = case_root / f"{route}-native"
        command = [str(GUST)]
        if route == "explicit":
            command += ["--backend", "cranelift"]
        command += ["-o", str(artifact), source]
        compiled = subprocess.run(
            command, cwd=ROOT, check=False, stdout=subprocess.PIPE,
            stderr=subprocess.PIPE, env=env,
        )
        require(compiled.returncode == 0 and compiled.stdout == compiled.stderr == b""
                and artifact.is_file(), f"{case['id']}: {route} native compile diverged")
        run_root = case_root / f"run-{route}"
        run_root.mkdir()
        executed = run([str(artifact)], cwd=run_root)
        artifacts.append(artifact)
        results.append(executed)
        effects.append(side_effects(run_root))
        inspected = elf_contract(artifact)
        require(inspected["kind"] == case["artifact"]["kind"]
                and inspected["elf_class"] == case["artifact"]["elf_class"]
                and inspected["machine"] == case["artifact"]["machine"],
                f"{case['id']}: {route} native artifact contract diverged")
    expected = case["execution"]
    require(all(
        result.returncode == expected["exit"]
        and bytes_record(result.stdout) == expected["stdout"]
        and bytes_record(result.stderr) == expected["stderr"]
        for result in results
    ), f"{case['id']}: native observable diverged from archive")
    require(effects[0] == effects[1] == case["side_effects"],
            f"{case['id']}: native side effects diverged from archive")
    require(artifacts[0].read_bytes() == artifacts[1].read_bytes(),
            f"{case['id']}: default and explicit native artifacts diverged")
    require(not list(case_root.rglob("*.c")),
            f"{case['id']}: archive replay generated C")


def evidence() -> None:
    record, corpus = validate()
    for path in (GUST, WORKER, RUNTIME_PACKAGE):
        require(path.is_file(), f"evidence prerequisite is missing: {path.relative_to(ROOT)}")
    started = time.monotonic()
    with tempfile.TemporaryDirectory(prefix="phase23-11-replay-", dir=ROOT / "build") as raw:
        root = Path(raw)
        for case in corpus["cases"]:
            replay_case(case, root)
        elapsed_ms = int((time.monotonic() - started) * 1000)
        peak_rss_kib = resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss
        require(elapsed_ms <= record["budgets"]["max_elapsed_ms"]
                and peak_rss_kib <= record["budgets"]["max_peak_rss_kib"],
                "archived corpus replay exceeded its resource budget")
    print(f"phase23_mir_to_c_archived_corpus: evidence ok cases={len(corpus['cases'])} "
          f"elapsed_ms={elapsed_ms} peak_rss_kib={peak_rss_kib}")


def render(record: dict) -> str:
    capture = record["capture_authority"]
    return "\n".join([
        "# Cranelift Phase 23.11 — Archived MIR-to-C Reference Corpus",
        "",
        "Generated from the canonical registry and immutable corpus. Do not edit by hand.",
        "",
        f"- Contract: `{record['contract_version']}`",
        f"- Status: `{record['status']}`",
        f"- Cases: `{record['case_count']}`",
        f"- Corpus: `{record['corpus_path']}`",
        f"- Corpus SHA-256: `{record['corpus_sha256']}`",
        f"- Case manifest: `{record['case_manifest_sha256']}`",
        f"- Capture source commit: `{capture['source_commit']}`",
        f"- Compiler source manifest: `{capture['compiler_source_manifest_sha256']}`",
        f"- Bootstrap seed: `{capture['bootstrap_seed_sha256']}`",
        f"- C compiler: `{capture['cc']}`",
        f"- Linker: `{capture['linker']}`",
        "- Replay: default and explicit Cranelift, with no C fallback.",
        "- Supersession: a mismatch fails; refresh requires a new version and explicit roadmap authority.",
        "- Patch 23.10's focused live MIR-to-C lane remains intact and is not replaced.",
        "",
        "Patch 23.11 changes no accepted Gust meaning, MIR operation, ABI/layout/runtime",
        "contract, backend route/default/fallback, bootstrap route, or seed.",
        "",
    ])


def project() -> None:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    record = registry["phase23_mir_to_c_archived_corpus"]
    REVIEW.write_text(render(record), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate", "project", "check-review", "evidence"))
    args = parser.parse_args()
    if args.command == "project":
        project()
    elif args.command == "check-review":
        validate()
    elif args.command == "evidence":
        evidence()
    else:
        validate()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
