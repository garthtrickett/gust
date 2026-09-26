#!/usr/bin/env python3
"""Validate and project Patch 23.12 production/release route evidence."""

from __future__ import annotations

import argparse
import copy
import hashlib
import importlib.util
import json
import re
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TASK = ROOT / "TASK.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE23_PRODUCTION_RELEASE_AUDIT.md"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
JUSTFILE = ROOT / "justfile"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
WORKFLOW = ROOT / ".github/workflows/phase23-production-release-audit.yml"
RUNNER = ROOT / "scripts/run-gust-file.sh"
EVIDENCE = ROOT / "scripts/phase23_production_release_audit.sh"
GUARD_L1 = "guard-cranelift-phase23-production-release-audit-contract"
GUARD_L2 = "guard-cranelift-phase23-production-release-audit-evidence"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD_L1}: {message}")


def digest_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def canonical_digest(value: object) -> str:
    return digest_bytes(json.dumps(
        value, sort_keys=True, separators=(",", ":"), ensure_ascii=True,
    ).encode("utf-8"))


def load_opening():
    path = ROOT / "scripts/phase23_mir_to_c_deprecation_opening.py"
    spec = importlib.util.spec_from_file_location("phase23_opening", path)
    require(spec is not None and spec.loader is not None,
            "cannot load the Phase 23 invocation scanner")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def surface(path: str, role: str, markers: tuple[str, ...]) -> dict[str, object]:
    absolute = ROOT / path
    require(absolute.is_file(), f"supported surface is missing: {path}")
    text = absolute.read_text(encoding="utf-8")
    for marker in markers:
        require(marker in text, f"supported surface marker is missing: {path}: {marker}")
    digest = digest_bytes(absolute.read_bytes())
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    if (path == "justfile" and
            "stdlib_guard_transition" in registry.get("phase24_cr15_opening", {})):
        transition_path = ROOT / "scripts/phase24_cr15_stdlib_guard_transition.py"
        spec = importlib.util.spec_from_file_location(
            "phase24_cr15_guard_transition", transition_path)
        require(spec is not None and spec.loader is not None,
                "cannot load the Patch 24.0c guard transition")
        transition = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(transition)
        digest = transition.normalized_owner_file_digest(registry, path, digest)
    return {
        "path": path,
        "role": role,
        "sha256": digest,
        "markers": markers,
    }



def project_reference_receiver_production_audit(registry: dict, live: dict) -> dict:
    """Project one registered native guard invocation off the closed audit."""
    live = project_phase26_ffi_repr_c_production_audit(registry, live)
    live = project_phase26_ffi_position_production_audit(registry, live)
    prerequisite = registry.get("phase26_activation_audit", {}).get(
        "reference_receiver_prerequisite", {})
    successor = prerequisite.get("production_audit_successor")
    if successor is None:
        return live
    invocation = prerequisite.get("phase22_invocation_successor", {}).get(
        "added_row", {})
    require(successor == {
        "contract_version":
            "phase26_reference_receiver_production_audit_successor_v1",
        "previous_repository_invocation_count": 150,
        "current_repository_invocation_count": 151,
        "added_invocation_path":
            "scripts/phase16_reference_receiver_parity.sh",
        "unchanged_other_fields": True,
        "partial_extra_or_substituted_audit": "rejected",
    } and invocation.get("path") == successor["added_invocation_path"] and
            invocation.get("selection") == "explicit_cranelift" and
            live["repository_invocation_count"] == 151,
            "Phase 26 reference receiver production audit successor drifted")
    previous = dict(live)
    previous["repository_invocation_count"] = 150
    return previous


def project_phase26_ffi_repr_c_production_audit(
        registry: dict, live: dict) -> dict:
    increment = registry.get("phase26_activation_audit", {}).get(
        "ffi_repr_c_layout_increment", {})
    successor = increment.get("production_audit_successor")
    if successor is None:
        return live
    rows = increment.get("phase22_invocation_successor", {}).get(
        "added_rows", [])
    require(successor == {
        "contract_version": "phase26_1d2_production_audit_successor_v1",
        "previous_repository_invocation_count": 155,
        "current_repository_invocation_count": 158,
        "added_invocation_path": "scripts/phase26_ffi_repr_c_layout.sh",
        "unchanged_other_fields": True,
        "partial_extra_or_substituted_audit": "rejected",
    } and len(rows) == 3 and
            all(row.get("path") == successor["added_invocation_path"] and
                row.get("selection") == "explicit_cranelift" for row in rows) and
            live["repository_invocation_count"] == 158,
            "Phase 26.1D2 production audit successor drifted")
    previous = dict(live)
    previous["repository_invocation_count"] = 155
    return previous


def project_phase26_ffi_position_production_audit(
        registry: dict, live: dict) -> dict:
    """Project the four D1 native probes off the closed production census."""
    increment = registry.get("phase26_activation_audit", {}).get(
        "ffi_position_policy_increment", {})
    successor = increment.get("production_audit_successor")
    if successor is None:
        return live
    rows = increment.get("phase22_invocation_successor", {}).get(
        "added_rows", [])
    require(successor == {
        "contract_version": "phase26_1d1_production_audit_successor_v1",
        "previous_repository_invocation_count": 151,
        "current_repository_invocation_count": 155,
        "added_invocation_path": "scripts/phase26_ffi_position_policy.sh",
        "unchanged_other_fields": True,
        "partial_extra_or_substituted_audit": "rejected",
    } and len(rows) == 4 and
            all(row.get("path") == successor["added_invocation_path"] and
                row.get("selection") == "explicit_cranelift" for row in rows) and
            live["repository_invocation_count"] == 155,
            "Phase 26.1D1 production audit successor drifted")
    previous = dict(live)
    previous["repository_invocation_count"] = 151
    return previous


def phase2510_emitter_audit(registry: dict, live: dict) -> dict:
    """Project the live audit back past Patch 25.10.

    Newest first: this runs BEFORE the 25.10a projection, which runs
    before 25.5's, so each is handed the tree it was registered against.

    This patch deletes the emitter, so it moves more of the audit than any
    link below it: the supported-surface manifest (the Makefile lost its
    whole C stage chain), the invocation count (every bootstrap-emitter
    caller is gone), and the explicit-C count with them.
    """
    # Patch 25.12b: the SECOND reader of the production-audit chain --
    # scripts/phase23_closure.py is the first -- and both must see the same
    # tail. 25.12b deletes src/runtime.c, which moves the supported-surface
    # manifest digest and nothing else, so 25.10 is now compared against
    # 25.12b's previous and 25.12b's current against live.
    runtime_c_audit = registry.get(
        "phase2512b_runtime_c_retirement", {}).get(
            "production_audit_transition")
    node = registry.get("phase2510_emitter_deletion", {}).get(
        "production_audit_transition")
    if node is None:
        return live
    previous = node.get("previous_audit")
    expected_current = (live if runtime_c_audit is None
                        else runtime_c_audit.get("previous_audit"))
    require(node.get("contract_version") ==
            "phase2510_emitter_deletion_audit_transition_v1" and
            node.get("current_audit") == expected_current and
            isinstance(previous, dict) and
            node.get("partial_or_substituted_audit") == "rejected",
            "Patch 25.10 production audit transition drifted")
    if runtime_c_audit is not None:
        require(runtime_c_audit.get("current_audit") == live,
                "Patch 25.12b production audit transition does not end at "
                "the live audit")
    moved = sorted(key for key in set(previous) | set(live)
                   if previous.get(key) != live.get(key))
    require(moved == sorted(node.get("moved_fields", [])),
            "Patch 25.10 moved a production audit field it does not "
            f"register: {moved}")
    return dict(previous)


def phase2510a_strings_audit(registry: dict, live: dict) -> dict:
    """Project the live audit back past Patch 25.10a.

    Newest-first, the same discipline the text-surface chain uses: this
    runs BEFORE the Patch 25.5 projection so that one is handed the tree
    it was registered against rather than one a patch ahead.

    ONE field moves. src/runtime/strings.c is retired into the Rust crate
    and the Makefile is a supported surface, so its manifest digest moves
    with it. Nothing else does, and that is the interesting part:

      repository_invocation_count       UNCHANGED at 160. The new
                                        differential is a link-and-compare
                                        against a pinned blob; it never
                                        invokes the compiler, so it adds
                                        no row to the invocation scan.
      repository_explicit_c_count       UNCHANGED at 2. Deleting a
                                        GENERATED C file does not move the
                                        explicit-C count, because that
                                        count was never what src/runtime/
                                        strings.c contributed to.
    """
    node = registry.get("phase2510a_strings_retirement", {}).get(
        "production_audit_transition")
    if node is None:
        return live
    previous = node.get("previous_audit")
    require(node.get("contract_version") ==
            "phase2510a_strings_audit_transition_v1" and
            node.get("current_audit") == live and
            isinstance(previous, dict) and
            node.get("partial_or_substituted_audit") == "rejected",
            "Patch 25.10a production audit transition drifted")
    moved = sorted(key for key in set(previous) | set(live)
                   if previous.get(key) != live.get(key))
    require(moved == sorted(node.get("moved_fields", [])),
            "Patch 25.10a moved a production audit field it does not "
            f"register: {moved}")
    return dict(previous)


def phase25_runtime_port_audit(registry: dict, live: dict) -> dict:
    """Peel Patch 25.5's changes off the live audit, or return it unchanged.

    Every transition below this one ends by comparing its registered
    `current_audit` against the LIVE scan, because each was the newest
    thing to touch the audit when it was written. Issue #398's block does
    exactly that. Patch 25.5 is newer, so without a link here its two
    changes reach #398's comparison and it reports that ITS OWN transition
    drifted -- a failure that names the wrong patch and says nothing about
    what moved.

    So this registers Patch 25.5's delta and hands the earlier links the
    state they were written against. It is the same chain shape as the
    Phase 22 census successor, and like that one it ADDS where every
    predecessor reduced.

    Two fields move and they have different causes, which is why they are
    registered separately rather than as one digest bump:

      repository_invocation_count       the strings differential has to
                                        emit the Gust side, and scripts/*.sh
                                        is inside the invocation scan
      supported_surface_manifest_digest the Makefile is a supported
                                        surface and this phase edits it
    """
    node = registry.get("phase25_runtime_port_invocations", {}).get(
        "production_audit_transition")
    if node is None:
        return live
    previous = node.get("previous_audit")
    require(node.get("contract_version") ==
            "phase25_runtime_port_audit_transition_v1" and
            node.get("current_audit") == live and
            isinstance(previous, dict) and
            node.get("partial_or_substituted_audit") == "rejected",
            "Patch 25.5 production audit transition drifted")
    moved = sorted(key for key in set(previous) | set(live)
                   if previous.get(key) != live.get(key))
    require(moved == sorted(node.get("moved_fields", [])),
            "Patch 25.5 moved a production audit field it does not "
            f"register: {moved}")
    # The invocation count and the Phase 22 census are two measurements of
    # one thing. If they disagree, one of them is measuring something else.
    successor = registry.get("phase25_runtime_port_invocations", {})
    added = successor.get("added_invocation_count")
    require(live["repository_invocation_count"] -
            previous["repository_invocation_count"] == added,
            "the Patch 25.5 production audit and invocation successor "
            "disagree about how many invocations it adds")
    require(live["repository_explicit_c_count"] ==
            previous["repository_explicit_c_count"] and
            live["phase25_bootstrap_explicit_c_count"] ==
            previous["phase25_bootstrap_explicit_c_count"],
            "Patch 25.5 must not move explicit-C counts; it ports the "
            "runtime, it does not retire a spelling")
    return previous


def scan() -> dict[str, object]:
    opening = load_opening()
    invocations = opening.scan_invocations()
    explicit_c = [row for row in invocations if row["selection"] == "explicit_c"]
    bootstrap = [row for row in explicit_c if row["path"] == "Makefile"]
    non_bootstrap = [row for row in explicit_c if row["path"] != "Makefile"]
    supported = (
        surface("Makefile", "default_build_package_and_install", (
            ".DEFAULT_GOAL := phase10-native-package",
            "all: phase10-native-package",
            "install: phase10-native-package",
            "install -m 0755 build/phase10-package/bin/gust",
        )),
        surface("README.md", "user_build_run_install_contract", (
            "build/phase10-package/bin/gust program.gst",
            "make install",
            # Patch 24.15 rebased this onto "were removed in" and withdrew
            # it: the removal was deferred, so the compiler still accepted
            # both spellings and documentation announcing a removal the CLI
            # does not perform would be the same defect as help text that
            # did. Issue #398 performs it, so the wording is the removal
            # again -- and the scheduling promise it replaced is required
            # absent, because a README that says both is no clearer than one
            # that says the wrong thing.
            "were removed in",
            "Phase 24. Bootstrap-C retirement is a separate Phase 25 change",
            "There is no automatic fallback",
        )),
        surface("flake.nix", "developer_single_program_entry", (
            'gt-one-gst() {',
            'GUST_RUNNER_ROUTE=cranelift bash scripts/run-gust-file.sh "$1"',
        )),
        surface("justfile", "developer_single_program_commands", (
            'GUST_RUNNER_ROUTE=cranelift bash scripts/run-gust-file.sh "{{file}}"',
        )),
        # Patch 24.13: the runner's default is now cranelift (#411), so the
        # marker recording the old default is rebased rather than dropped --
        # the surface still has to carry a default, and the audit still has to
        # see which one. Defaulting away from the retired route is separable
        # from refusing it, and only the first is this patch's to make.
        surface("scripts/run-gust-file.sh", "shared_explicit_route_runner", (
            'RUNNER_ROUTE="${GUST_RUNNER_ROUTE:-cranelift}"',
            "make phase10-native-package",
            "./build/phase10-package/bin/gust",
            "--backend cranelift",
            # Patch 24.13 rebased this pair onto the runner's own rejection
            # of the route and withdrew it with the removal. Issue #398 lands
            # both: the runner no longer has a C route to call, so what the
            # audit must see is the refusal and the reason it gives.
            'if [ "$RUNNER_ROUTE" = "mir-to-c" ]; then',
            "which was removed in Phase 24",
            'NATIVE_OUTPUT="build/${TEST_STEM}_bin"',
            "COMPILING GUST WITH CRANELIFT",
        )),
        surface("scripts/phase22_default_native_package.sh",
                "clean_install_and_relocation_predecessor", (
            'make install DESTDIR="$install_root" PREFIX=/opt/gust',
            "assert_clean_failure",
            "missing-runtime.diagnostic",
        )),
    )
    runner = RUNNER.read_text(encoding="utf-8")
    # Patch 24.13 inverted this to require no mir-to-c invocation and exactly
    # one refusal site, and withdrew it with the removal. Issue #398 lands
    # both halves, and both are needed.
    #
    # "No C invocation" alone would pass on a runner that had quietly dropped
    # the route without telling anyone who asked for it -- the caller would
    # get a native build they did not request. "Exactly one refusal" alone
    # would pass on a runner that refused in one branch and still compiled C
    # in another. Together they say: the route is gone, and asking for it
    # says so.
    require(runner.count("--backend mir-to-c") == 0 and
            runner.count("--backend cranelift") == 1,
            "shared runner does not expose exactly one explicit native route "
            "with no C route beside it")
    require(runner.count('if [ "$RUNNER_ROUTE" = "mir-to-c" ]; then') == 1,
            "the shared runner does not refuse the retired route exactly "
            "once, so a caller who asks for it is not told it is gone")
    require("GUST_RUNNER_ROUTE must be 'mir-to-c' or 'cranelift'" in runner,
            "shared runner does not reject an unknown explicit route")
    # Patch 24.13 (#398, #433): rebased twice, and both reasons are recorded
    # rather than the number silently bumped.
    #
    # The first rebase moved two of the five Makefile callers -- the stage-2
    # and stage-3 emissions -- to the bootstrap-only entry, and left three
    # counted as explicit C on the reasoning that they are driven by the seed
    # and the bridge, which Phase 25 owns.
    #
    # That was a transitional state read as a final one. This patch changes the
    # compiler, so the seed reconverges; once it does, gust_bootstrap and
    # gust_stage1_bin ARE 24.13 compilers and the spelling they were counted
    # under no longer exists. Measured: with the republished seed and the old
    # callers, the second bootstrap fails at Makefile:51 with "the generated-C
    # backend was removed in Phase 24: mir-to-c".
    #
    # So all four Makefile callers now reach the bootstrap-only entry, and the
    # Makefile's explicit-C bootstrap count is zero. What remains Phase
    # 25-owned is the bridge parser's own acceptance of the spelling, which
    # this patch leaves alone.
    require(not bootstrap,
            "a Makefile bootstrap caller still selects explicit C: "
            f"{bootstrap}")
    # Patch 25.10 INVERTS this. It required exactly five
    # `--backend bootstrap-emitter` callers in the Makefile -- the count
    # Patch 24.13 landed -- and the emitter is deleted, so the right
    # assertion is that none of them invokes it.
    #
    # Counted over NON-COMMENT lines, not over the whole file. The
    # Makefile still spells the flag twice, inside the comment that
    # records what the C stage chain used to be, and that record is worth
    # keeping. A raw `count == 0` would force the history to be deleted to
    # make the guard pass, which is the wrong pressure: it would push a
    # patch toward erasing the explanation rather than removing the
    # caller.
    makefile_lines = (ROOT / "Makefile").read_text(
        encoding="utf-8").splitlines()
    live_callers = [line for line in makefile_lines
                    if "--backend bootstrap-emitter" in line
                    and not line.lstrip().startswith("#")]
    require(not live_callers,
            "the Makefile still invokes the bootstrap emitter, which Patch "
            f"25.10 deleted: {live_callers[:3]}")
    return {
        "supported_surface_count": len(supported),
        "supported_surface_manifest_digest": canonical_digest(supported),
        "repository_invocation_count": len(invocations),
        "repository_explicit_c_count": len(explicit_c),
        "phase25_bootstrap_explicit_c_count": len(bootstrap),
        "non_bootstrap_retained_test_surface_count": len(non_bootstrap),
        "supported_production_or_release_explicit_c_count": 0,
        # Patch 24.14: DERIVED, not declared. These were the literals `1` and
        # "phase23_mir_to_c_focused_live", so the audit whose job is to say
        # what live C remains asserted one surviving lane regardless of the
        # tree. Patch 24.14 retires exactly that lane, which would have left
        # this audit -- and every consumer of it through 24.15, 24.16 and the
        # closure -- claiming a lane that no longer exists. A declared value
        # standing in for a measured one is the #393 defect, here in the
        # instrument the residue audit trusts most.
        #
        # A lane is ACTIVE when the script that owns it still builds an argv
        # selecting the retired backend, which the frozen oracle already
        # derives from the tree.
        **_active_live_c_lanes(),
        "unknown_downstream_count": 0,
    }



# Registered non-bootstrap live-C lanes, and the script whose retired-backend
# argv is what makes each one live.
_LIVE_C_LANES = {
    "phase23_mir_to_c_focused_live":
        "scripts/phase21_cranelift_built_compiler_programs.py",
}


def _active_live_c_lanes() -> dict[str, object]:
    """Which registered live-C lanes still execute the retired backend."""
    spec = importlib.util.spec_from_file_location(
        "_frozen_oracle", ROOT / "scripts/phase24_frozen_oracle.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    sites = module.python_retired_argv_sites()
    active = sorted(lane for lane, owner in _LIVE_C_LANES.items()
                    if owner in sites)
    return {
        "active_non_bootstrap_live_c_lane_count": len(active),
        "active_non_bootstrap_live_c_owner": active[0] if active else None,
    }


def accepted(record: dict, summary: dict[str, object]) -> bool:
    return record.get("audit") == summary and record.get("route_contract") == {
        "default_and_explicit_native": "cranelift",
        "fallback": "forbidden",
        "supported_production_or_release_requires_mir_to_c": False,
        "remaining_live_c_owners": [
            "phase23_mir_to_c_focused_live", "phase25_bootstrap",
        ],
        "historical_and_archived_call_sites":
            "retained_as_nonproduction_evidence_not_supported_routes",
        "explicit_c_availability": "deprecated_and_retained_through_phase23",
    }


def validate_mutations(record: dict, summary: dict[str, object]) -> None:
    require(accepted(record, summary), "registered production/release audit drifted")
    for label, key, value in (
        ("production C dependency", "supported_production_or_release_explicit_c_count", 1),
        ("second live C lane", "active_non_bootstrap_live_c_lane_count", 2),
        ("unknown downstream", "unknown_downstream_count", 1),
        ("missing bootstrap caller", "phase25_bootstrap_explicit_c_count", 4),
        ("same-count supported surface substitution", "supported_surface_manifest_digest", "0" * 64),
    ):
        mutated = {**summary, key: value}
        require(not accepted(record, mutated), f"accepted {label}")
    fallback = copy.deepcopy(record)
    fallback["route_contract"]["fallback"] = "allowed"
    require(not accepted(fallback, summary), "accepted fallback")


def validate() -> tuple[dict, dict[str, object]]:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    record = registry.get("phase23_production_release_audit")
    require(isinstance(record, dict), "Patch 23.12 authority is missing")
    expected = {
        "contract_version": "phase23_production_release_audit_v1",
        "status": "patch23_12_complete",
        "next_patch": "23.13",
        "owner": "cranelift",
        "review_view": REVIEW.relative_to(ROOT).as_posix(),
        "renderer": Path(__file__).relative_to(ROOT).as_posix(),
    }
    for key, value in expected.items():
        require(record.get(key) == value, f"{key} drifted")
    require(registry.get("phase23_mir_to_c_archived_corpus", {}).get("status") ==
            "patch23_11_complete", "Patch 23.11 predecessor is not complete")
    require(registry.get("phase23_mir_to_c_focused_live", {}).get(
            "route_contract", {}).get("non_bootstrap_live_lane_count") == 1,
            "focused live-C predecessor drifted")
    summary = project_reference_receiver_production_audit(registry, scan())
    summary = phase2510_emitter_audit(registry, summary)
    summary = phase2510a_strings_audit(registry, summary)
    summary = phase25_runtime_port_audit(registry, summary)
    closure_transition = registry.get("phase23_closure", {}).get(
        "production_audit_transition")
    derivation_transition = registry.get("phase24_cr15_derivation", {}).get(
        "production_audit_transition")
    retirement_transition = registry.get(
        "phase24_frozen_oracle_replacement", {}).get(
            "production_audit_transition")
    emitter_only_transition = registry.get(
        "phase24_12a_emitter_only_retirement", {}).get(
            "production_audit_transition")
    if closure_transition is None:
        validate_mutations(record, summary)
    else:
        unchanged = [
            "supported_surface_count", "repository_invocation_count",
            "repository_explicit_c_count", "phase25_bootstrap_explicit_c_count",
            "non_bootstrap_retained_test_surface_count",
            "supported_production_or_release_explicit_c_count",
            "active_non_bootstrap_live_c_lane_count",
            "active_non_bootstrap_live_c_owner", "unknown_downstream_count",
        ]
        require(closure_transition.get("contract_version") ==
                "phase23_closure_production_audit_transition_v1" and
                closure_transition.get("status") == "patch23_15_complete" and
                closure_transition.get("authority_base_main") ==
                "8985a3d09b1f119accd12cd952940ef019d6a698" and
                closure_transition.get("previous_audit") == record.get("audit") and
                closure_transition.get("current_audit") ==
                (summary if derivation_transition is None else
                 derivation_transition.get("previous_audit")) and
                closure_transition.get("unchanged_fields") == unchanged and
                closure_transition.get("change_reason") ==
                "closure_status_and_guard_wiring_changed_supported_surface_file_digests_without_changing_routes_or_counts" and
                closure_transition.get("partial_extra_or_substituted_audit") ==
                "rejected",
                "Patch 23.15 production audit transition drifted")
        for field in unchanged:
            require(closure_transition["current_audit"].get(field) ==
                    closure_transition["previous_audit"].get(field),
                    f"Patch 23.15 changed production audit field: {field}")
        effective = copy.deepcopy(record)
        effective["audit"] = closure_transition["current_audit"]
        if derivation_transition is not None:
            require(
                derivation_transition.get("contract_version") ==
                "phase24_cr15_derivation_production_audit_transition_v1" and
                derivation_transition.get("status") == "patch24_0c_complete" and
                derivation_transition.get("authority_base_main") ==
                "c37024afa580d1e03c5ff70150ed0ae7518a9648" and
                derivation_transition.get("previous_audit") ==
                closure_transition["current_audit"] and
                derivation_transition.get("current_audit") ==
                (summary if retirement_transition is None
                 else retirement_transition.get("previous_audit")) and
                derivation_transition.get("unchanged_fields") == unchanged and
                derivation_transition.get("change_reason") ==
                "CR15_derivation_preserved_the_production_audit_through_exact_relay_projection" and
                derivation_transition.get("partial_extra_or_substituted_audit") ==
                "rejected",
                "Patch 24.0c production audit transition drifted")
            for field in unchanged:
                require(derivation_transition["current_audit"].get(field) ==
                        derivation_transition["previous_audit"].get(field),
                        f"Patch 24.0c changed production audit field: {field}")
            effective["audit"] = derivation_transition["current_audit"]
        # Patch 24.12 is the first successor to move these counts rather than
        # preserve them: converting a parity guard removes the invocation it
        # used to make. Three fields go down by exactly the number of live-C
        # cases the frozen-surface transition registers as removed, every
        # other field is held, and the audit's own mutation evidence then runs
        # against the moved state rather than the closed one.
        if retirement_transition is not None:
            require(derivation_transition is not None,
                    "the Patch 24.12 production audit successor has no "
                    "registered predecessor")
            previous = retirement_transition.get("previous_audit", {})
            current = retirement_transition.get("current_audit", {})
            reduced = retirement_transition.get("reduced_fields", [])
            require(retirement_transition.get("contract_version") ==
                    "phase24_12_frozen_oracle_production_audit_transition_v1"
                    and retirement_transition.get("status") ==
                    "patch24_12_complete" and
                    retirement_transition.get("authority_base_main") ==
                    "8aa9922eb40ad404647a86f865f0790ab37a3589" and
                    previous == derivation_transition["current_audit"] and
                    current == (summary if emitter_only_transition is None
                                else emitter_only_transition.get(
                                    "previous_audit")) and
                    sorted(reduced) == [
                        "non_bootstrap_retained_test_surface_count",
                        "repository_explicit_c_count",
                        "repository_invocation_count"] and
                    retirement_transition.get(
                        "partial_extra_or_substituted_audit") == "rejected",
                    "Patch 24.12 production audit transition drifted")
            removed = retirement_transition.get("removed_invocation_count")
            surface = registry.get(
                "phase24_frozen_oracle_replacement", {}).get(
                    "frozen_surface_transition", {})
            require(removed == surface.get("removed_case_count"),
                    "the production audit and the frozen-surface transition "
                    "disagree about how many live-C cases Patch 24.12 removed")
            for field in reduced:
                require(previous[field] - current[field] == removed,
                        f"Patch 24.12 production audit field moved by "
                        f"something other than the registered removal: "
                        f"{field}")
            for field in unchanged:
                if field in reduced:
                    continue
                require(current.get(field) == previous.get(field),
                        f"Patch 24.12 changed an unregistered production "
                        f"audit field: {field}")
            effective["audit"] = current
        # Patch 24.12a moves the same three fields again, by exactly the
        # number of live-C cases its own frozen-surface successor registers.
        # Two authorities, one number: if they disagree the chain is wrong
        # somewhere, which is the whole point of registering it twice.
        if emitter_only_transition is not None:
            require(retirement_transition is not None,
                    "the Patch 24.12a production audit successor has no "
                    "registered predecessor")
            previous = emitter_only_transition.get("previous_audit", {})
            conversion_transition = registry.get(
                "phase24_12b_python_parity_conversion", {}).get(
                    "production_audit_transition")
            removal_transition = registry.get(
                "phase24_13_backend_removal", {}).get(
                    "production_audit_transition")
            current = emitter_only_transition.get("current_audit", {})
            reduced = emitter_only_transition.get("reduced_fields", [])
            require(emitter_only_transition.get("contract_version") ==
                    "phase24_12a_production_audit_transition_v1" and
                    emitter_only_transition.get("status") ==
                    "patch24_12a_complete" and
                    previous == retirement_transition["current_audit"] and
                    current == (
                        conversion_transition["previous_audit"]
                        if conversion_transition is not None else summary) and
                    sorted(reduced) == [
                        "non_bootstrap_retained_test_surface_count",
                        "repository_explicit_c_count",
                        "repository_invocation_count"] and
                    emitter_only_transition.get(
                        "partial_extra_or_substituted_audit") == "rejected",
                    "Patch 24.12a production audit transition drifted")
            # Patch 24.12b is the newest link and so is the tail that must
            # equal the live scan.
            if conversion_transition is not None:
                require(conversion_transition.get("contract_version") ==
                        "phase24_12b_production_audit_transition_v1" and
                        conversion_transition.get("previous_audit") ==
                        current and
                        conversion_transition.get("current_audit") ==
                        (removal_transition["previous_audit"]
                         if removal_transition is not None else summary) and
                        sorted(conversion_transition.get(
                            "reduced_fields", [])) == [
                            "non_bootstrap_retained_test_surface_count",
                            "repository_explicit_c_count",
                            "repository_invocation_count"] and
                        conversion_transition.get(
                            "partial_extra_or_substituted_audit") ==
                        "rejected",
                        "Patch 24.12b production audit transition drifted")
            # Patch 24.13 is the tail when present: it reclassifies two
            # bootstrap callers onto the bootstrap-only entry, so the
            # explicit-C counts fall while the calls remain.
            toolchain_transition = registry.get(
                "phase24_14_toolchain_removal", {}).get(
                    "production_audit_transition")
            docs_transition = registry.get(
                "phase24_15_package_docs_registry", {}).get(
                    "production_audit_transition")
            spelling_transition = registry.get(
                "phase398_retained_spelling_removal", {}).get(
                    "production_audit_transition")
            if removal_transition is not None:
                require(removal_transition.get("contract_version") ==
                        "phase24_13_production_audit_transition_v1" and
                        removal_transition.get("current_audit") ==
                        (toolchain_transition["previous_audit"]
                         if toolchain_transition is not None else summary) and
                        sorted(removal_transition.get("reduced_fields",
                                                      [])) == [
                            "phase25_bootstrap_explicit_c_count",
                            "repository_explicit_c_count"] and
                        removal_transition.get(
                            "partial_extra_or_substituted_audit") ==
                        "rejected",
                        "Patch 24.13 production audit transition drifted")
                # Patch 24.14 becomes the tail. It retires the focused live
                # oracle, so it reduces the non-bootstrap counts and leaves the
                # Phase-25-owned bootstrap C alone -- the opposite shape from
                # 24.13, which reduced bootstrap C by moving two Makefile rows
                # to the bootstrap-only entry.
                if toolchain_transition is not None:
                    require(
                        toolchain_transition.get("contract_version") ==
                        "phase24_14_production_audit_transition_v1" and
                        toolchain_transition.get("current_audit") ==
                        (docs_transition["previous_audit"]
                         if docs_transition is not None
                         else spelling_transition["previous_audit"]
                         if spelling_transition is not None else summary) and
                        toolchain_transition.get(
                            "partial_extra_or_substituted_audit") ==
                        "rejected",
                        "Patch 24.14 production audit transition drifted")
                    was = toolchain_transition["previous_audit"]
                    require(
                        was["phase25_bootstrap_explicit_c_count"] ==
                        summary["phase25_bootstrap_explicit_c_count"],
                        "Patch 24.14 must not move Phase-25-owned bootstrap C")
                    require(
                        summary["active_non_bootstrap_live_c_lane_count"] == 0,
                        "Patch 24.14 retires the last non-bootstrap live-C "
                        "lane, so this audit must measure none")
                # Patch 24.15 is the tail when present, and its shape is
                # DIGEST-ONLY: it states removal in user documentation, which
                # moves the supported-surface manifest digest and must move no
                # count at all. A documentation patch that changes a count has
                # changed a route, which is not what it claims to be doing.
                if docs_transition is not None:
                    require(
                        docs_transition.get("contract_version") ==
                        "phase24_15_production_audit_transition_v1" and
                        docs_transition.get("current_audit") == summary and
                        docs_transition.get("digest_only") is True and
                        docs_transition.get(
                            "partial_extra_or_substituted_audit") ==
                        "rejected",
                        "Patch 24.15 production audit transition drifted")
                    was = docs_transition["previous_audit"]
                    moved = [key for key in set(was) | set(summary)
                             if was.get(key) != summary.get(key)]
                    require(
                        moved == ["supported_surface_manifest_digest"],
                        "Patch 24.15 states removal in documentation, so only "
                        "the supported-surface digest may move; these also "
                        f"moved: {sorted(k for k in moved if k != 'supported_surface_manifest_digest')}")
                # Issue #398 is the tail. Unlike 24.15 it is not
                # digest-only: it removes the backend, so the three
                # non-bootstrap counts fall together and the
                # supported-surface digest moves with them. Phase-25-owned
                # bootstrap C must NOT move -- that is the line this patch is
                # not allowed to cross, and it is checked rather than
                # promised.
                #
                # The two other records of the same removal are consulted
                # rather than restated: the frozen-surface transition says how
                # many live-C cases went, the invocation successor says how
                # many invocations went. Three independent measurements of one
                # removal; if any disagrees, one of them is measuring
                # something else.
                if spelling_transition is not None:
                    require(
                        spelling_transition.get("contract_version") ==
                        "phase398_production_audit_transition_v1" and
                        spelling_transition.get("current_audit") == summary and
                        spelling_transition.get(
                            "partial_extra_or_substituted_audit") ==
                        "rejected",
                        "Issue #398 production audit transition drifted")
                    was = spelling_transition["previous_audit"]
                    moved = sorted(key for key in set(was) | set(summary)
                                   if was.get(key) != summary.get(key))
                    require(
                        moved == sorted(
                            list(spelling_transition["reduced_fields"]) +
                            ["supported_surface_manifest_digest"]),
                        "Issue #398 moved a production audit field it does "
                        f"not register: {moved}")
                    require(
                        was["phase25_bootstrap_explicit_c_count"] ==
                        summary["phase25_bootstrap_explicit_c_count"],
                        "Issue #398 must not move Phase-25-owned bootstrap C")
                    probes = spelling_transition["retained_probe_count"]
                    require(
                        summary["repository_explicit_c_count"] ==
                        summary["non_bootstrap_retained_test_surface_count"]
                        == probes,
                        "the explicit-C count Issue #398 leaves is not the "
                        f"{probes} inverted probes it registers: "
                        f"{summary['repository_explicit_c_count']} and "
                        f"{summary['non_bootstrap_retained_test_surface_count']}")
                    removal_node = registry.get(
                        "phase398_retained_spelling_removal", {})
                    frozen = removal_node.get("frozen_surface_transition", {})
                    cases_removed = (
                        frozen.get("previous_live_c_case_surface", {})
                        .get("count", 0) -
                        frozen.get("current_live_c_case_surface", {})
                        .get("count", 0))
                    explicit_removed = (
                        was["repository_explicit_c_count"] -
                        summary["repository_explicit_c_count"])
                    require(
                        explicit_removed == cases_removed,
                        "the Issue #398 production audit and frozen-surface "
                        "transitions disagree about how many live-C cases it "
                        f"removed: {explicit_removed} against {cases_removed}")
                    invocations = removal_node.get(
                        "phase22_invocation_successor", {})
                    require(
                        was["repository_invocation_count"] -
                        summary["repository_invocation_count"] ==
                        invocations.get(
                            "unfiltered_retired_explicit_c_count"),
                        "the Issue #398 production audit and invocation "
                        "successor disagree about how many invocations it "
                        "retired")
            removed = emitter_only_transition.get("removed_invocation_count")
            surface = registry.get(
                "phase24_12a_emitter_only_retirement", {}).get(
                    "frozen_surface_transition", {})
            require(removed == surface.get("removed_case_count"),
                    "the Patch 24.12a production audit and frozen-surface "
                    "transitions disagree about how many live-C cases it "
                    "removed")
            for field in reduced:
                require(previous[field] - current[field] == removed,
                        f"Patch 24.12a production audit field moved by "
                        f"something other than the registered removal: "
                        f"{field}")
            for field in unchanged:
                if field in reduced:
                    continue
                require(current.get(field) == previous.get(field),
                        f"Patch 24.12a changed an unregistered production "
                        f"audit field: {field}")
            # Patch 24.12b, when present, is the tail: the effective audit is
            # its current_audit, not 24.12a's, because that is the one the
            # live scan has to match.
            # Patch 24.14 is the tail when present, then 24.13, then 24.12b:
            # the effective audit is the newest registered successor's
            # current_audit, because that is the one the live scan must match.
            docs_transition = registry.get(
                "phase24_15_package_docs_registry", {}).get(
                    "production_audit_transition")
            # Issue #398 is newest, so it is checked first: the live scan has
            # to match the newest registered successor, not the newest one
            # that happens to be listed here.
            spelling_transition = registry.get(
                "phase398_retained_spelling_removal", {}).get(
                    "production_audit_transition")
            effective["audit"] = (
                spelling_transition["current_audit"]
                if spelling_transition is not None
                else docs_transition["current_audit"]
                if docs_transition is not None
                else toolchain_transition["current_audit"]
                if toolchain_transition is not None
                else removal_transition["current_audit"]
                if removal_transition is not None
                else conversion_transition["current_audit"]
                if conversion_transition is not None else current)
        validate_mutations(effective, summary)
    require(record.get("timelines") == {
        "phase24": "remove_generated_C_backend_and_explicit_C_publication_routes",
        "phase25": "remove_bootstrap_seed_host_C_chain_and_residual_bootstrap_C",
        "repository_wide_C_absence": "not_claimed_or_scheduled_by_phase23",
    }, "Phase 24/25 timeline boundary drifted")
    require(record.get("package_contract") == {
        "artifacts": ["gust", "gust-native-backend", "gust-runtime-package.a"],
        "repository_install_and_relocated_use": "qualified_native",
        "clean_environment": "temporary_DESTDIR_and_relocated_sibling_directory",
        "cleanup": "owned_temporary_directory_removed",
        "failure_diagnostics": ["missing_worker", "missing_runtime_archive"],
        "no_fallback": "native_succeeds_with_mir_to_c_test_poisoned",
    }, "package qualification contract drifted")
    phase22_migration = record.get("phase22_closed_inventory_migration", {})
    require(phase22_migration.get("status") ==
            "exact_phase23_dual_route_projected_to_phase22_predecessor" and
            phase22_migration.get("owning_patch") == "23.12" and
            phase22_migration.get("path") == "scripts/run-gust-file.sh" and
            phase22_migration.get("previous_row", {}).get("selection") == "explicit_c" and
            phase22_migration.get("current_historical_row", {}).get("selection") ==
            "explicit_c" and
            phase22_migration.get("added_native_row", {}).get("selection") ==
            "explicit_cranelift" and phase22_migration.get("falsifier") ==
            "missing_partial_extra_or_same_count_command_substitution_is_rejected",
            "Phase 22 closed-inventory migration authority drifted")
    require(record.get("budgets") == {
        "workflow_timeout_minutes": 45,
        "evidence_elapsed_ms": 300000,
    }, "audit budgets drifted")
    require(record.get("boundary") == {
        "changes_accepted_Gust_program_meaning": False,
        "adds_or_changes_MIR_operations": False,
        "changes_ABI_layout_runtime_symbols_target_or_linker": False,
        "changes_backend_route_default_or_fallback": False,
        "changes_bootstrap_route_or_seed": False,
        "edits_stdlib_or_CR15": False,
        "begins_patch23_13": False,
    }, "Patch 23.12 boundary widened")
    task = TASK.read_text(encoding="utf-8")
    for patch in ("23.10", "23.11", "23.12"):
        require(re.search(rf"^- \[x\] Patch {re.escape(patch)} .* — DONE$", task, re.M)
                is not None, f"mandatory Patch {patch} status is not DONE")
    levels = json.loads(LEVELS.read_text(encoding="utf-8"))["guards"]
    require(levels.get(GUARD_L1) == 1 and levels.get(GUARD_L2) == 2,
            "guard levels drifted")
    just = JUSTFILE.read_text(encoding="utf-8")
    require(f"{GUARD_L1}:" in just and f"{GUARD_L2}:" in just,
            "just guards are missing")
    require(f"just {GUARD_L1}" in PR_FAST.read_text(encoding="utf-8"),
            "PR Fast does not own the audit contract")
    workflow = WORKFLOW.read_text(encoding="utf-8")
    for token in (f"just {GUARD_L1}", f"just {GUARD_L2}",
                  "make phase10-native-package"):
        require(workflow.count(token) == 1,
                f"dedicated workflow ownership drifted: {token}")
    for marker in ("temporary DESTDIR", "GUST_TEST_MIR_TO_C_UNAVAILABLE=1",
                   "missing-worker", "missing-runtime"):
        require(marker in EVIDENCE.read_text(encoding="utf-8"),
                f"focused evidence marker is missing: {marker}")
    require(REVIEW.is_file() and REVIEW.read_text(encoding="utf-8") ==
            render(record), "generated audit review is stale; run project")
    return record, summary


def render(record: dict) -> str:
    audit = record["audit"]
    lines = [
        "# Cranelift Phase 23.12 — Production, Release, Package, and Downstream Audit",
        "",
        "Generated from the canonical feature registry. Do not edit by hand.",
        "",
        f"- Contract: `{record['contract_version']}`",
        f"- Status: `{record['status']}`",
        f"- Next patch: `{record['next_patch']}`",
        f"- Supported surfaces: `{audit['supported_surface_count']}`",
        f"- Supported surface manifest: `{audit['supported_surface_manifest_digest']}`",
        f"- Repository compiler invocations: `{audit['repository_invocation_count']}`",
        f"- Retained explicit-C call sites: `{audit['repository_explicit_c_count']}`",
        f"- Phase 25 bootstrap explicit-C call sites: `{audit['phase25_bootstrap_explicit_c_count']}`",
        f"- Non-production historical/test call sites: `{audit['non_bootstrap_retained_test_surface_count']}`",
        f"- Supported production/release explicit-C calls: `{audit['supported_production_or_release_explicit_c_count']}`",
        f"- Active non-bootstrap live-C lanes: `{audit['active_non_bootstrap_live_c_lane_count']}`",
        f"- Active live-C owner: `{audit['active_non_bootstrap_live_c_owner']}`",
        f"- Unknown registered downstream consumers: `{audit['unknown_downstream_count']}`",
        "",
        "The remaining historical and archived call sites are retained evidence, not",
        "supported production or release routes. The only live non-bootstrap C owner",
        "is the Patch 23.10 focused oracle lane; bootstrap remains owned by Phase 25.",
        "Explicit C remains deprecated and available through Phase 23. Phase 24 removes",
        "the backend route; Phase 25 separately removes bootstrap C. Repository-wide C",
        "absence is not claimed.",
        "",
    ]
    return "\n".join(lines)


def evidence() -> None:
    result = subprocess.run(
        ["bash", str(EVIDENCE)], cwd=ROOT, check=False,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
        timeout=300,
    )
    require(result.returncode == 0,
            f"package/release evidence failed:\n{result.stdout}{result.stderr}")
    require("phase23_production_release_audit: evidence ok" in result.stdout,
            "package/release evidence completion marker is missing")
    print("phase23_production_release_audit: evidence ok")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate", "project", "check-review", "evidence"))
    args = parser.parse_args()
    if args.command == "evidence":
        validate()
        evidence()
        return
    record, _ = validate() if args.command != "project" else (
        json.loads(REGISTRY.read_text(encoding="utf-8"))["phase23_production_release_audit"], {}
    )
    rendered = render(record)
    if args.command == "project":
        REVIEW.write_text(rendered, encoding="utf-8")
    elif args.command == "check-review":
        require(REVIEW.is_file() and REVIEW.read_text(encoding="utf-8") == rendered,
                "generated audit review is stale")
    print(f"{GUARD_L1}: {args.command} ok")


if __name__ == "__main__":
    main()
