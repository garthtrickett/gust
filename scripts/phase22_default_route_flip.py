#!/usr/bin/env python3
"""Validate, project, and replay Patch 22.6 default-route authority."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TASK = ROOT / "TASK.md"
ENTRY = ROOT / "compiler/test_runner_entry.gst"
HELP = ROOT / "compiler/phase10_help.txt"
MAKEFILE = ROOT / "Makefile"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE22_DEFAULT_ROUTE_FLIP.md"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
JUSTFILE = ROOT / "justfile"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
WORKFLOW = ROOT / ".github/workflows/phase22-default-route-flip.yml"
PACKAGED_GUST = ROOT / "build/phase10-package/bin/gust"
GUARD_L1 = "guard-cranelift-phase22-default-route-flip-contract"
GUARD_L2 = "guard-cranelift-phase22-default-route-flip-evidence"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD_L1}: {message}")


def run(command: list[str], *, env: dict[str, str] | None = None,
        timeout: float = 180.0) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(command, cwd=ROOT, env=env, stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE, timeout=timeout, check=False)


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    record = registry.get("phase22_default_route_flip")
    require(isinstance(record, dict), "Patch 22.6 authority is missing")
    require(record.get("contract_version") == "phase22_default_route_flip_v1",
            "contract version drifted")
    require(record.get("status") == "implementation_complete" and
            record.get("next_action") ==
            "patch22_6a_default_route_bootstrap_seed_reconvergence",
            "status or next action drifted")
    require(record.get("predecessor_authority") ==
            registry.get("phase22_preflip_default_cohort", {}).get(
                "contract_version") == "phase22_preflip_default_cohort_v1",
            "predecessor authority drifted")
    require(registry["phase22_preflip_default_cohort"]["status"] ==
            "qualification_complete_default_flip_prerequisites_satisfied",
            "pre-flip prerequisite is incomplete")
    scanner = __import__("phase22_opening")
    scanner.validate_post_flip_relay_transition(
        registry, scanner.scan_invocations()
    )
    require(record.get("route_contract") == {
        "default_backend": "cranelift",
        "explicit_native_backend": "cranelift",
        "default_and_explicit_native_route":
            "identical_shared_post_semantic_pipeline_route",
        "explicit_c_spellings": ["mir-to-c", "c"],
        "explicit_c_role": "retained_semantic_oracle",
        "native_implicit_output":
            "source_directory_and_exact_terminal_dot_gst_stem",
        "native_package":
            "executable_relative_three_artifact_sibling_package",
        "fallback": "forbidden",
        "bootstrap_route": "explicit_mir_to_c",
    }, "route contract drifted")

    entry = ENTRY.read_text(encoding="utf-8")
    for marker in (
        "invocation.backend.tag = 1; // Cranelift",
        'os.LogStr("  cranelift  Compile to one native executable (default).");',
        # Patch 24.13 briefly rebased this onto a removal statement. The
        # removal is deferred until the live-C surface drains (issue #398),
        # so the deprecation wording is accurate again and stays pinned.
        'os.LogStr("  mir-to-c, c  DEPRECATED: Emit C source to stdout (retained semantic oracle); backend removal is Phase 24.");',
        "if invocation.backend.tag == 1 {",
        "native_source_route.mir_native_scalar_source_compile(",
        "codegen.codegen_generate(programs, module_prefixes, &env, ctx)",
    ):
        require(marker in entry, f"compiler route marker is missing: {marker}")
    require(entry.count("native_source_route.mir_native_scalar_source_compile(") == 1,
            "default and explicit native forms do not share one route")
    native_start = entry.index("if invocation.backend.tag == 1 {")
    c_start = entry.index("mut c_code := codegen.codegen_generate(")
    native_branch = entry[native_start:c_start]
    require("codegen.codegen_generate(" not in native_branch,
            "native route can fall back to MIR-to-C")
    require("experimental" not in "\n".join(
        line.lower() for line in entry.splitlines() if "os.Log" in line),
        "active compiler diagnostics or help still call Cranelift experimental")

    help_text = HELP.read_text(encoding="utf-8")
    # Patch 24.13 briefly swapped the deprecation clause for a removal
    # statement; withdrawn with the removal itself (issue #398).
    require("Compile to one native executable (default)." in help_text and
            "The generated-C backend was REMOVED in Phase 24; mir-to-c and c are rejected." in help_text and
            "Bootstrap C retirement is separate and deferred to Phase 25." in help_text and
            "Optional Cranelift output; defaults to the source stem." in help_text and
            "fallback to MIR-to-C." in help_text,
            "checked help projection drifted")
    makefile = MAKEFILE.read_text(encoding="utf-8")
    # Patch 24.13: the whole bootstrap chain reaches the bootstrap-only entry.
    #
    # An earlier version of this split the chain in two, keeping the seed- and
    # bridge-driven callers on the retired spelling because "this patch does
    # not touch them and Phase 25 owns them". That was true only while the
    # seed still predated the removal. This patch reconverges the seed, so
    # gust_bootstrap and gust_stage1_bin are 24.13 compilers and the spelling
    # they were asserted to keep no longer exists -- measured, the second
    # bootstrap would fail at Makefile:51 once the spelling is withdrawn.
    # That withdrawal is deferred (issue #398), so this is a sequencing
    # argument rather than a measured failure today.
    #
    # Both halves still stay asserted, which is what this guard is for: the
    # retired spelling must be ABSENT from every caller and the entry must be
    # PRESENT, so dropping a caller entirely fails just as loudly as
    # reintroducing the old one.
    for retired, rebased in (
        ("./gust_bootstrap --backend mir-to-c compiler/test_runner_bootstrap_bridge_entry.gst",
         "./gust_bootstrap --backend bootstrap-emitter compiler/test_runner_bootstrap_bridge_entry.gst"),
        ("./build/gust_stage1_bin --backend mir-to-c compiler/test_runner_entry.gst",
         "./build/gust_stage1_bin --backend bootstrap-emitter compiler/test_runner_entry.gst"),
        ("./gust --backend mir-to-c compiler/test_runner_entry.gst",
         "./gust --backend bootstrap-emitter compiler/test_runner_entry.gst"),
        ("./build/gust_stage2_bin --backend mir-to-c compiler/test_runner_entry.gst",
         "./build/gust_stage2_bin --backend bootstrap-emitter compiler/test_runner_entry.gst"),
    ):
        require(retired not in makefile,
                f"a bootstrap caller selects the removed backend: {retired}")
        require(rebased in makefile,
                f"bootstrap route is not the explicit bootstrap entry: {rebased}")
    implementation = record.get("implementation_patch", {})
    require(implementation.get("pull_request") == 259 and
            implementation.get("base_sha") ==
            "8b2135ac664dfdeb32c2fd5ca28cc43bbf80ed3b" and
            implementation.get("head_sha") ==
            "40be16fd5eb190d3c468fc8e4c5652d61ba5ec43" and
            implementation.get("merge_sha") ==
            "e521f4f660acf59aff7e07f79a9567c73ffb0b2b" and
            implementation.get("bootstrap_seed_changed") is False and
            "gust_v4.c" not in implementation.get("reviewed_change_paths", []),
            "reviewed Patch 22.6 commit range includes the bootstrap seed")
    successor = registry.get("phase22_default_route_seed_convergence", {})
    successor_complete = (
        successor.get("contract_version") ==
        "phase22_default_route_seed_convergence_v1" and
        successor.get("status") == "patch22_6a_complete" and
        successor.get("accounted_authority") ==
        "phase22_default_route_flip_v1"
    )
    require(successor_complete,
            "Patch 22.6a no longer accounts for the separate seed transition")

    corpus = record.get("frozen_preflip_c_corpus", [])
    require(len(corpus) == 4 and len({row["source"] for row in corpus}) == 4 and
            all(len(row["digest"]) == 64 for row in corpus),
            "frozen pre-flip C corpus drifted")
    task = TASK.read_text(encoding="utf-8")
    pending_successor = (
        "- [ ] Patch 22.6a — Default-Route Bootstrap Seed Reconvergence" in task
    )
    completed_successor = (
        "- [x] Patch 22.6a — Default-Route Bootstrap Seed Reconvergence — DONE"
        in task
    )
    require("- [x] Patch 22.6 — Cranelift Default Route Flip — DONE" in task and
            ((pending_successor and not successor_complete) or
             (completed_successor and successor_complete)),
            "22.6/22.6a roadmap boundary drifted")
    levels = json.loads(LEVELS.read_text(encoding="utf-8"))["guards"]
    require(levels.get(GUARD_L1) == 1 and levels.get(GUARD_L2) == 2,
            "guard levels drifted")
    just = JUSTFILE.read_text(encoding="utf-8")
    require(f"{GUARD_L1}:" in just and f"{GUARD_L2}:" in just,
            "just guards are missing")
    require(f"just {GUARD_L1}" in PR_FAST.read_text(encoding="utf-8"),
            "PR Fast does not own the contract")
    workflow = WORKFLOW.read_text(encoding="utf-8")
    require(f"just {GUARD_L1}" in workflow and f"just {GUARD_L2}" in workflow and
            "make gust phase10-native-package" in workflow,
            "focused workflow does not own build and both guards")
    boundary = record.get("boundary", {})
    require(boundary.get("changes_default_backend") is True and
            boundary.get("changes_help_route_status") is True and
            all(value is False for key, value in boundary.items()
                if key not in {"changes_default_backend", "changes_help_route_status"}),
            "Patch 22.6 boundary widened")
    return record


def render(record: dict) -> str:
    route = record["route_contract"]
    evidence = record["evidence"]
    implementation = record["implementation_patch"]
    lines = [
        "# Cranelift Phase 22.6 — Default Route Flip",
        "",
        "Generated from `scripts/cranelift_feature_registry.json`. Do not edit by hand.",
        "",
        f"- Contract: `{record['contract_version']}`",
        f"- Status: `{record['status']}`",
        f"- Next action: `{record['next_action']}`",
        f"- Observed main: `{record['observed_main_sha']}`",
        f"- Predecessor: `{record['predecessor_authority']}`",
        f"- Implementation PR/base/head: `#{implementation['pull_request']}` / `{implementation['base_sha']}` / `{implementation['head_sha']}`",
        f"- Merge commit: `{implementation['merge_sha']}`",
        f"- Bootstrap seed changed in implementation patch: `{str(implementation['bootstrap_seed_changed']).lower()}`",
        "",
        "## Route",
        "",
        f"- Default backend: `{route['default_backend']}`",
        f"- Default/explicit native route: `{route['default_and_explicit_native_route']}`",
        f"- Explicit C spellings: `{', '.join(route['explicit_c_spellings'])}`",
        f"- Explicit C role: `{route['explicit_c_role']}`",
        f"- Native output: `{route['native_implicit_output']}`",
        f"- Native package: `{route['native_package']}`",
        f"- Fallback: `{route['fallback']}`",
        f"- Bootstrap route: `{route['bootstrap_route']}`",
        "",
        "## Evidence",
        "",
        f"- Native artifact identity: `{evidence['bare_and_explicit_native_artifacts']}`",
        f"- Native execution identity: `{evidence['bare_and_explicit_native_execution']}`",
        f"- Native failure identity: `{evidence['bare_and_explicit_native_failure']}`",
        f"- Explicit C: `{evidence['explicit_c_spellings']}`",
    ]
    lines += [f"- `{row['source']}`: `{row['digest']}`"
              for row in record["frozen_preflip_c_corpus"]]
    lines += [
        "",
        "Backend selection remains after the shared semantic pipeline. This patch",
        "changes routing policy and active help only: it adds no source meaning,",
        "canonical MIR, lowering, ABI/layout, runtime symbol, target, linker, or",
        "bootstrap-seed change. Patch 22.6a remains a separate generated-seed patch.",
        "",
    ]
    return "\n".join(lines)


def evidence() -> None:
    record = validate()
    require(PACKAGED_GUST.is_file(), "packaged compiler prerequisite is missing")
    output = ROOT / "build/guards/phase22_default_route_flip"
    if output.exists():
        shutil.rmtree(output)
    output.mkdir(parents=True)
    env = os.environ.copy()
    env.pop("GUST_NATIVE_BACKEND_DRIVER", None)
    source = ROOT / "compiler/phase10_scalar_return_source.gst"
    bare = output / "bare-program"
    explicit = output / "explicit-program"
    bare_build = run([str(PACKAGED_GUST), "-o", str(bare), str(source)], env=env)
    explicit_build = run([str(PACKAGED_GUST), "--backend", "cranelift", "-o",
                          str(explicit), str(source)], env=env)
    require(bare_build.returncode == explicit_build.returncode == 0 and
            bare.is_file() and explicit.is_file() and
            bare.read_bytes() == explicit.read_bytes() and
            bare_build.stdout == explicit_build.stdout == b"" and
            bare_build.stderr == explicit_build.stderr == b"",
            "bare and explicit native artifacts or diagnostics differ")
    bare_run = run([str(bare)])
    explicit_run = run([str(explicit)])
    require((bare_run.returncode, bare_run.stdout, bare_run.stderr) ==
            (explicit_run.returncode, explicit_run.stdout, explicit_run.stderr),
            "bare and explicit native execution differs")

    failed_env = dict(env)
    failed_env["GUST_NATIVE_BACKEND_DRIVER"] = "/nonexistent/gust-native-backend"
    bare_failed = output / "bare-failed"
    explicit_failed = output / "explicit-failed"
    bare_failed.write_bytes(b"preserve\n")
    explicit_failed.write_bytes(b"preserve\n")
    bare_failure = run([str(PACKAGED_GUST), "-o", str(bare_failed), str(source)],
                       env=failed_env)
    explicit_failure = run([str(PACKAGED_GUST), "--backend", "cranelift", "-o",
                            str(explicit_failed), str(source)], env=failed_env)
    require(bare_failure.returncode == explicit_failure.returncode != 0 and
            bare_failure.stdout == explicit_failure.stdout and
            bare_failure.stderr == explicit_failure.stderr and
            bare_failed.read_bytes() == explicit_failed.read_bytes() == b"preserve\n" and
            b"Native backend driver discovery error:" in
            bare_failure.stdout + bare_failure.stderr,
            "native failure parity, diagnostic, or output preservation differs")
    require(b"#include" not in bare_failure.stdout,
            "unavailable default-native route emitted fallback C")

    # Patch 24.12b: retired, and INVERTED rather than deleted.
    #
    # This loop compiled four sources through BOTH retired spellings and
    # required their emitted C be identical, then pinned the bytes against a
    # frozen digest. Both halves are properties of the retired emitter: the
    # spelling-parity arm compares the retired backend against itself, and the
    # digest pins bytes only it produces. There is no native counterpart for
    # either, so no frozen vector can stand in -- this is the emitter-only
    # class, like the two CR-15 arms.
    #
    # The frozen_preflip_c_corpus rows stay in the registry as the historical
    # record they are. What stops is replaying them against a backend that is
    # being removed. The assertion below fails if the replay comes back.
    retired_route = "--backend" + '", "' + "mir-to-c"
    own_source = Path(__file__).read_text(encoding="utf-8")
    require(retired_route not in own_source,
            "the retired explicit-C spelling parity replay is back in "
            "phase22_default_route_flip")
    require(len(record["frozen_preflip_c_corpus"]) == 4,
            "the frozen pre-flip corpus is a historical record and must keep "
            "its four rows even though they are no longer replayed")
    print(f"{GUARD_L2}: evidence ok")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate", "project", "check-review", "evidence"))
    args = parser.parse_args()
    record = validate()
    rendered = render(record)
    if args.command == "project":
        REVIEW.write_text(rendered, encoding="utf-8")
    elif args.command == "check-review":
        require(REVIEW.exists() and REVIEW.read_text(encoding="utf-8") == rendered,
                "generated review view is stale")
    elif args.command == "evidence":
        evidence()
    print(f"{GUARD_L1}: {args.command} ok")


if __name__ == "__main__":
    main()
