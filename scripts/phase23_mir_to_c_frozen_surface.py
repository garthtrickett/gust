#!/usr/bin/env python3
"""Freeze and validate the Patch 23.9 retained MIR-to-C surface."""

from __future__ import annotations

import argparse
import copy
import hashlib
import importlib.util
import json
import re
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TASK = ROOT / "TASK.md"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE23_MIR_TO_C_FROZEN_SURFACE.md"
LEVELS = ROOT / "scripts/cranelift_test_levels.json"
JUSTFILE = ROOT / "justfile"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
WORKFLOW = ROOT / ".github/workflows/phase23-mir-to-c-frozen-surface.yml"
OPENING = ROOT / "scripts/phase23_mir_to_c_deprecation_opening.py"
GUARD_L1 = "guard-cranelift-phase23-mir-to-c-frozen-surface-contract"
GUARD_L2 = "guard-cranelift-phase23-mir-to-c-frozen-surface-evidence"

OBSERVABLE_FIELDS = (
    "positive_expectation",
    "differential_stderr_policy",
    "differential_side_effect_policy",
    "individual_evidence_guard",
)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD_L1}: {message}")


def digest_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def canonical_digest(value: object) -> str:
    encoded = json.dumps(
        value, sort_keys=True, separators=(",", ":"), ensure_ascii=True
    ).encode("utf-8")
    return digest_bytes(encoded)


def opening_module():
    path = ROOT / "scripts/phase22_opening.py"
    spec = importlib.util.spec_from_file_location("phase22_opening", path)
    require(spec is not None and spec.loader is not None,
            "cannot load the canonical compiler invocation scanner")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def capability_rows(registry: dict) -> list[dict[str, object]]:
    entries = sorted(
        (entry for entry in registry["entries"]
         if entry.get("status") == "migrated"),
        key=lambda entry: str(entry["id"]),
    )
    require(entries, "migrated capability surface is empty")
    require(len({entry["id"] for entry in entries}) == len(entries),
            "migrated capability IDs are not unique")
    rows: list[dict[str, object]] = []
    for entry in entries:
        entry_id = str(entry["id"])
        require(entry.get("route_owner") == "generic_canonical_mir",
                f"{entry_id} is a C-only or backend-only capability")
        source = str(entry["source_fixture"])
        source_path = ROOT / source
        require(source_path.is_file(), f"{entry_id} source fixture is missing")
        canonical = str(entry["canonical_mir_fixture"])
        canonical_path = ROOT / canonical
        if canonical_path.is_file():
            canonical_kind = "file_sha256"
            canonical_identity = digest_bytes(canonical_path.read_bytes())
        else:
            require(canonical.startswith("none_compiler_generated_"),
                    f"{entry_id} has an unclassified canonical MIR identity")
            canonical_kind = "registered_generated_token"
            canonical_identity = canonical_digest({"registered_token": canonical})
        evidence = entry.get("evidence")
        require(isinstance(evidence, dict), f"{entry_id} evidence is missing")
        observable = {field: evidence.get(field) for field in OBSERVABLE_FIELDS}
        require(all(observable.values()),
                f"{entry_id} observable contract is incomplete")
        rows.append({
            "id": entry_id,
            "origin_phase": entry["origin_phase"],
            "feature_family": entry["feature_family"],
            "route_owner": entry["route_owner"],
            "source_fixture": source,
            "source_digest": digest_bytes(source_path.read_bytes()),
            "canonical_mir_fixture": canonical,
            "canonical_mir_identity_kind": canonical_kind,
            "canonical_mir_identity": canonical_identity,
            "differential_case_id": entry["differential_case_id"],
            "observable_contract": observable,
            "complete_registry_entry_digest": canonical_digest(entry),
        })
    return rows


def live_c_case_rows() -> list[dict[str, object]]:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    transition = None
    if "stdlib_guard_transition" in registry.get("phase24_cr15_opening", {}):
        path = ROOT / "scripts/phase24_cr15_stdlib_guard_transition.py"
        spec = importlib.util.spec_from_file_location("phase24_cr15_guard_transition", path)
        require(spec is not None and spec.loader is not None,
                "cannot load the Patch 24.0c guard transition")
        transition = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(transition)
    rows = []
    for row in opening_module().scan_invocations():
        if row["selection"] != "explicit_c":
            continue
        path = str(row["path"])
        line = int(row["line"])
        recipe = str(row["recipe"])
        owner_path = ROOT / path
        require(owner_path.is_file(), f"live-C owner path is missing: {path}")
        complete = {
            "path": path,
            "line": line,
            "recipe": recipe,
            "compiler_token": row["compiler_token"],
            "selection": row["selection"],
            "consumer_class": row["consumer_class"],
            "owner": row["owner"],
            "command": row["command"],
        }
        rows.append({
            "case_id": f"{path}:{line}:{recipe or 'direct'}",
            "path": path,
            "line": line,
            "recipe": recipe,
            "owner": row["owner"],
            "selection": row["selection"],
            "consumer_class": row["consumer_class"],
            "compiler_token": row["compiler_token"],
            "command_digest": canonical_digest(row["command"]),
            "owner_file_digest": (
                transition.normalized_owner_file_digest(
                    registry, path, digest_bytes(owner_path.read_bytes())
                ) if transition is not None else
                digest_bytes(owner_path.read_bytes())
            ),
            "complete_case_digest": canonical_digest(complete),
        })
    rows.sort(key=lambda row: str(row["case_id"]))
    require(rows, "live explicit-C case surface is empty")
    require(len({row["case_id"] for row in rows}) == len(rows),
            "live explicit-C case IDs are not unique")
    return rows


def capability_summary(rows: list[dict[str, object]]) -> dict[str, object]:
    fixtures: dict[str, dict[str, object]] = {}
    for row in rows:
        source = str(row["source_fixture"])
        fixtures[source] = {
            "path": source,
            "kind": "source_fixture",
            "identity": row["source_digest"],
        }
        canonical = str(row["canonical_mir_fixture"])
        fixtures[canonical] = {
            "path": canonical,
            "kind": row["canonical_mir_identity_kind"],
            "identity": row["canonical_mir_identity"],
        }
    observable = [
        {"id": row["id"], "contract": row["observable_contract"]}
        for row in rows
    ]
    return {
        "count": len(rows),
        "complete_identity_manifest_digest": canonical_digest(rows),
        "feature_id_manifest_digest": canonical_digest(
            [row["id"] for row in rows]
        ),
        "fixture_count": len(fixtures),
        "fixture_manifest_digest": canonical_digest(
            sorted(fixtures.values(), key=lambda row: str(row["path"]))
        ),
        "observable_contract_manifest_digest": canonical_digest(observable),
        "origin_phase_counts": dict(sorted(Counter(
            str(row["origin_phase"]) for row in rows
        ).items())),
        "feature_family_counts": dict(sorted(Counter(
            str(row["feature_family"]) for row in rows
        ).items())),
    }


def live_c_summary(rows: list[dict[str, object]]) -> dict[str, object]:
    owner_contracts = sorted({
        (str(row["path"]), str(row["owner_file_digest"])) for row in rows
    })
    return {
        "count": len(rows),
        "complete_identity_manifest_digest": canonical_digest(rows),
        "case_id_manifest_digest": canonical_digest(
            [row["case_id"] for row in rows]
        ),
        "owner_contract_count": len(owner_contracts),
        "owner_contract_manifest_digest": canonical_digest(owner_contracts),
        "owner_counts": dict(sorted(Counter(
            str(row["owner"]) for row in rows
        ).items())),
        "consumer_class_counts": dict(sorted(Counter(
            str(row["consumer_class"]) for row in rows
        ).items())),
        "selection_counts": dict(sorted(Counter(
            str(row["selection"]) for row in rows
        ).items())),
    }


def scan(registry: dict) -> dict[str, object]:
    capabilities = capability_rows(registry)
    live_cases = live_c_case_rows()
    return {
        "capability_surface": capability_summary(capabilities),
        "live_c_case_surface": live_c_summary(live_cases),
    }


def policy_accepts(record: dict, summary: dict[str, object]) -> bool:
    transition = record.get("focused_live_transition", {})
    archive_transition = record.get("archived_corpus_transition", {})
    production_transition = record.get("production_release_transition", {})
    expected_live = production_transition.get(
        "current_live_c_case_surface", archive_transition.get(
        "current_live_c_case_surface", transition.get(
        "current_live_c_case_surface", record.get("live_c_case_surface")
    )))
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    expected_live = registry.get("phase23_cross_feature_qualification", {}).get(
        "frozen_surface_transition", {}).get(
            "current_live_c_case_surface", expected_live)
    expected_live = registry.get("phase23_closure", {}).get(
        "frozen_surface_transition", {}).get(
            "current_live_c_case_surface", expected_live)
    return (
        record.get("capability_surface") == summary["capability_surface"] and
        expected_live == summary["live_c_case_surface"] and
        record.get("maintenance_policy") == {
            "classification": "compatibility_correction_only",
            "new_feature_prerequisite":
                "authorized_shared_semantics_and_supported_cranelift_path_first",
            "c_only_capability": "forbidden",
            "backend_only_semantic_claim": "forbidden",
            "fallback": "forbidden",
            "weakened_expected_inventory": "forbidden",
        }
    )


def validate_mutations(record: dict, registry: dict) -> None:
    capabilities = capability_rows(registry)
    cases = live_c_case_rows()
    expected = scan(registry)
    require(policy_accepts(record, expected), "registered frozen surface drifted")

    probes: list[tuple[str, dict[str, object]]] = []
    probes.append(("capability omission", {
        **expected,
        "capability_surface": capability_summary(capabilities[1:]),
    }))
    added = copy.deepcopy(capabilities)
    synthetic = copy.deepcopy(added[0])
    synthetic["id"] = "synthetic_new_c_only_feature"
    synthetic["route_owner"] = "mir_to_c_only"
    added.append(synthetic)
    probes.append(("capability addition", {
        **expected,
        "capability_surface": capability_summary(added),
    }))
    substituted = copy.deepcopy(capabilities)
    substituted[0]["id"] = str(substituted[0]["id"]) + "_substituted"
    probes.append(("same-count feature-name substitution", {
        **expected,
        "capability_surface": capability_summary(substituted),
    }))
    c_only = copy.deepcopy(capabilities)
    c_only[0]["route_owner"] = "mir_to_c_only"
    probes.append(("C-only route", {
        **expected,
        "capability_surface": capability_summary(c_only),
    }))
    backend_claim = copy.deepcopy(capabilities)
    backend_claim[0]["observable_contract"]["backend_only_semantic_claim"] = True
    probes.append(("backend-only semantic claim", {
        **expected,
        "capability_surface": capability_summary(backend_claim),
    }))
    probes.append(("live-C case omission", {
        **expected,
        "live_c_case_surface": live_c_summary(cases[1:]),
    }))
    case_substitution = copy.deepcopy(cases)
    case_substitution[0]["case_id"] = \
        str(case_substitution[0]["case_id"]) + ":substituted"
    probes.append(("same-count live-C case substitution", {
        **expected,
        "live_c_case_surface": live_c_summary(case_substitution),
    }))
    for name, probe in probes:
        require(not policy_accepts(record, probe), f"accepted {name}")

    weakened = copy.deepcopy(record)
    weakened["capability_surface"]["count"] -= 1
    require(not policy_accepts(weakened, expected),
            "accepted weakened capability count")
    fallback = copy.deepcopy(record)
    fallback["maintenance_policy"]["fallback"] = "allowed"
    require(not policy_accepts(fallback, expected),
            "accepted fallback policy")


def validate() -> tuple[dict, dict[str, object]]:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    record = registry.get("phase23_mir_to_c_frozen_surface")
    require(isinstance(record, dict), "Patch 23.9 authority is missing")
    require(record.get("contract_version") ==
            "phase23_mir_to_c_frozen_surface_v1",
            "contract version drifted")
    require(record.get("status") == "patch23_9_complete" and
            record.get("next_patch") == "23.10",
            "status or successor drifted")
    require(record.get("owner") == "cranelift" and
            record.get("review_view") == REVIEW.relative_to(ROOT).as_posix() and
            record.get("renderer") == Path(__file__).relative_to(ROOT).as_posix(),
            "owner, review, or renderer authority drifted")
    summary = scan(registry)
    transition = record.get("focused_live_transition")
    require(isinstance(transition, dict) and
            transition.get("contract_version") ==
            "phase23_frozen_live_c_transition_v1" and
            transition.get("status") == "patch23_10_complete" and
            transition.get("authority_base_main") ==
            "7178ee245d6d340329f6b5614dbf8be12fe8d273" and
            transition.get("previous_live_c_case_surface") ==
            record.get("live_c_case_surface") and
            transition.get("unchanged_fields") == [
                "count", "owner_contract_count", "owner_counts",
                "consumer_class_counts", "selection_counts",
            ] and
            transition.get("change_reason") ==
            "authority_and_workflow_routing_changed_case_lines_and_owner_file_digests_without_changing_live_explicit_C_population" and
            transition.get("partial_or_unregistered_surface") == "rejected",
            "Patch 23.10 frozen live-C transition drifted")
    for field in transition["unchanged_fields"]:
        require(transition["current_live_c_case_surface"].get(field) ==
                transition["previous_live_c_case_surface"].get(field),
                f"Patch 23.10 changed frozen live-C field: {field}")
    archive_transition = record.get("archived_corpus_transition")
    require(isinstance(archive_transition, dict) and
            archive_transition.get("contract_version") ==
            "phase23_frozen_archive_transition_v1" and
            archive_transition.get("status") == "patch23_11_complete" and
            archive_transition.get("authority_base_main") ==
            "7941bceb2ed62bca97917ad241290caf5fd97bf6" and
            archive_transition.get("previous_live_c_case_surface") ==
            transition.get("current_live_c_case_surface") and
            archive_transition.get("unchanged_fields") == [
                "count", "owner_contract_count", "owner_counts",
                "consumer_class_counts", "selection_counts",
            ] and
            archive_transition.get("change_reason") ==
            "archive_authority_and_native_replay_shifted_command_lines_and_owner_file_digests_without_adding_a_live_explicit_C_case" and
            archive_transition.get("partial_or_unregistered_surface") ==
            "rejected", "Patch 23.11 frozen archive transition drifted")
    for field in archive_transition["unchanged_fields"]:
        require(archive_transition["current_live_c_case_surface"].get(field) ==
                archive_transition["previous_live_c_case_surface"].get(field),
                f"Patch 23.11 changed frozen live-C field: {field}")
    require(archive_transition["current_live_c_case_surface"] ==
            record.get("production_release_transition", {}).get(
                "previous_live_c_case_surface"),
            "Patch 23.12 predecessor is not the registered Patch 23.11 successor")
    production_transition = record.get("production_release_transition")
    require(isinstance(production_transition, dict) and
            production_transition.get("contract_version") ==
            "phase23_frozen_production_release_transition_v1" and
            production_transition.get("status") == "patch23_12_complete" and
            production_transition.get("authority_base_main") ==
            "c2b6ec8c4a3650e704541ebd00b57020783f1def" and
            production_transition.get("previous_live_c_case_surface") ==
            archive_transition.get("current_live_c_case_surface") and
            production_transition.get("preserved_case") == {
                "path": "scripts/run-gust-file.sh",
                "owner": "cranelift",
                "reason":
                    "historical_C_route_preserved_while_supported_callers_select_explicit_cranelift",
            } and production_transition.get("unchanged_fields") == [
                "count", "owner_contract_count", "owner_counts",
                "consumer_class_counts", "selection_counts",
            ] and production_transition.get("change_reason") ==
            "dual_route_authority_shifted_the_preserved_case_line_and_owner_file_digests_without_changing_live_explicit_C_population" and
            production_transition.get("partial_or_unregistered_surface") ==
            "rejected", "Patch 23.12 frozen live-C transition drifted")
    for field in production_transition["unchanged_fields"]:
        require(production_transition["current_live_c_case_surface"].get(field) ==
                production_transition["previous_live_c_case_surface"].get(field),
                f"Patch 23.12 changed frozen live-C field: {field}")
    qualification_transition = registry.get(
        "phase23_cross_feature_qualification", {}).get(
            "frozen_surface_transition", {})
    require(isinstance(qualification_transition, dict) and
            qualification_transition.get("contract_version") ==
            "phase23_cross_feature_frozen_surface_transition_v1" and
            qualification_transition.get("status") == "patch23_13_complete" and
            qualification_transition.get("authority_base_main") ==
            "9b89296b25d2ab0cf1963ea1d1707139149d0576" and
            qualification_transition.get("previous_live_c_case_surface") ==
            production_transition.get("current_live_c_case_surface") and
            qualification_transition.get("unchanged_fields") == [
                "count", "case_id_manifest_digest", "owner_contract_count",
                "owner_counts", "consumer_class_counts", "selection_counts",
            ] and qualification_transition.get(
                "partial_or_unregistered_surface") == "rejected",
            "Patch 23.13 frozen live-C transition drifted")
    for field in qualification_transition["unchanged_fields"]:
        require(qualification_transition["current_live_c_case_surface"].get(field) ==
                qualification_transition["previous_live_c_case_surface"].get(field),
                f"Patch 23.13 changed frozen live-C field: {field}")
    closure_transition = registry.get("phase23_closure", {}).get(
        "frozen_surface_transition")
    if closure_transition is None:
        require(qualification_transition["current_live_c_case_surface"] ==
                summary["live_c_case_surface"],
                "live explicit-C surface is not the registered Patch 23.13 successor")
    else:
        closure_unchanged = [
            "count", "case_id_manifest_digest", "owner_contract_count",
            "owner_counts", "consumer_class_counts", "selection_counts",
        ]
        require(closure_transition.get("contract_version") ==
                "phase23_closure_frozen_surface_transition_v1" and
                closure_transition.get("status") == "patch23_15_complete" and
                closure_transition.get("authority_base_main") ==
                "8985a3d09b1f119accd12cd952940ef019d6a698" and
                closure_transition.get("previous_live_c_case_surface") ==
                qualification_transition["current_live_c_case_surface"] and
                closure_transition.get("current_live_c_case_surface") ==
                summary["live_c_case_surface"] and
                closure_transition.get("unchanged_fields") == closure_unchanged and
                closure_transition.get("change_reason") ==
                "closure_authority_and_workflow_wiring_shifted_command_lines_and_owner_file_digests_without_changing_the_frozen_explicit_C_case_population" and
                closure_transition.get("partial_or_unregistered_surface") ==
                "rejected",
                "Patch 23.15 frozen live-C transition drifted")
        for field in closure_unchanged:
            require(closure_transition["current_live_c_case_surface"].get(field) ==
                    closure_transition["previous_live_c_case_surface"].get(field),
                    f"Patch 23.15 changed frozen live-C field: {field}")
    validate_mutations(record, registry)
    require(record.get("explicit_c_byte_authority") ==
            registry["phase23_mir_to_c_deprecation_opening"]
            ["deprecation_contract"]["explicit_c_byte_authority"],
            "explicit-C byte authority changed")
    require(record.get("boundary") == {
        "changes_accepted_Gust_program_meaning": False,
        "adds_or_changes_MIR_operations": False,
        "changes_backend_capability_route_or_fallback": False,
        "changes_ABI_layout_runtime_symbols_target_or_linker": False,
        "changes_bootstrap_route_or_seed": False,
        "edits_stdlib_or_CR15": False,
        "begins_patch23_10": False,
    }, "Patch 23.9 boundary drifted")
    task = TASK.read_text(encoding="utf-8")
    for patch in ("23.7", "23.8", "23.8a", "23.9", "23.10", "23.11"):
        require(re.search(
            rf"^- \[x\] Patch {re.escape(patch)} .* — DONE$", task, re.M
        ) is not None, f"mandatory Patch {patch} status is not DONE")
    levels = json.loads(LEVELS.read_text(encoding="utf-8"))["guards"]
    require(levels.get(GUARD_L1) == 1 and levels.get(GUARD_L2) == 2,
            "Patch 23.9 guard levels drifted")
    just = JUSTFILE.read_text(encoding="utf-8")
    require(f"{GUARD_L1}:" in just and f"{GUARD_L2}:" in just,
            "Patch 23.9 just guards are missing")
    require(f"just {GUARD_L1}" in PR_FAST.read_text(encoding="utf-8"),
            "PR Fast does not own the Patch 23.9 contract")
    workflow = WORKFLOW.read_text(encoding="utf-8")
    require(f"just {GUARD_L1}" in workflow and f"just {GUARD_L2}" in workflow,
            "dedicated workflow does not own both Patch 23.9 guards")
    for path_filter in (
        "'TASK.md'", "'README.md'", "'GEMINI.md'", "'gust_v4.c'",
        "'Makefile'", "'*.sh'", "'compiler/**'", "'docs/**'",
        "'scripts/**'", "'src/**'", "'tests/**'", "'justfile*'",
        "'.github/workflows/**'",
    ):
        require(workflow.count(path_filter) == 2,
                f"workflow does not own both path filters for {path_filter}")
    require(REVIEW.is_file() and REVIEW.read_text(encoding="utf-8") ==
            render(record, registry),
            "generated frozen-surface review is stale; run project")
    return record, summary


def evidence(record: dict) -> None:
    opening = json.loads(REGISTRY.read_text(encoding="utf-8"))[
        "phase23_mir_to_c_deprecation_opening"
    ]
    baseline = opening["deprecation_contract"]["explicit_c_byte_authority"]
    require(record["explicit_c_byte_authority"] == baseline and
            baseline["mir_to_c"] == baseline["c_alias"] and
            baseline["mir_to_c"]["compile_status"] == 0 and
            baseline["mir_to_c"]["stdout_size"] > 0 and
            baseline["mir_to_c"]["stderr_size"] == 0,
            "frozen explicit-C byte authority is invalid or changed")
    print("phase23_mir_to_c_frozen_surface: evidence ok")


def render(record: dict, registry: dict) -> str:
    capabilities = capability_rows(registry)
    cases = live_c_case_rows()
    cap = record["capability_surface"]
    live = registry.get("phase23_closure", {}).get(
        "frozen_surface_transition", {}).get(
            "current_live_c_case_surface",
            registry["phase23_cross_feature_qualification"][
                "frozen_surface_transition"]["current_live_c_case_surface"],
        )
    lines = [
        "# Cranelift Phase 23.9 — Frozen MIR-to-C Feature Surface",
        "",
        "Generated from the canonical feature registry and live Patch 23.7",
        "invocation scanner. Do not edit by hand.",
        "",
        f"- Contract: `{record['contract_version']}`",
        f"- Status: `{record['status']}`",
        f"- Frozen migrated capabilities: `{cap['count']}`",
        f"- Capability identity manifest: `{cap['complete_identity_manifest_digest']}`",
        f"- Capability observable manifest: `{cap['observable_contract_manifest_digest']}`",
        f"- Frozen live explicit-C cases: `{live['count']}`",
        f"- Live-C identity manifest: `{live['complete_identity_manifest_digest']}`",
        "- Current identity is the registered Phase 23 closure successor; the explicit-C population and complete case-ID manifest are unchanged.",
        f"- Maintenance: `{record['maintenance_policy']['classification']}`",
        "- New features require authorized shared semantics and a supported Cranelift path first.",
        "- C-only capabilities, backend-only semantic claims, and fallback are forbidden.",
        "",
        "## Frozen accepted capabilities",
        "",
        "| ID | Phase | Family | Source identity | Canonical MIR identity | Observable contract | Entry identity |",
        "| --- | --- | --- | --- | --- | --- | --- |",
    ]
    for row in capabilities:
        lines.append(
            f"| `{row['id']}` | `{row['origin_phase']}` | "
            f"`{row['feature_family']}` | `{row['source_digest']}` | "
            f"`{row['canonical_mir_identity']}` | "
            f"`{canonical_digest(row['observable_contract'])}` | "
            f"`{row['complete_registry_entry_digest']}` |"
        )
    lines += [
        "",
        "## Frozen live explicit-C cases",
        "",
        "| Case | Owner | Class | Compiler | Command identity | Owner-file identity | Complete identity |",
        "| --- | --- | --- | --- | --- | --- | --- |",
    ]
    for row in cases:
        lines.append(
            f"| `{row['case_id']}` | `{row['owner']}` | "
            f"`{row['consumer_class']}` | `{row['compiler_token']}` | "
            f"`{row['command_digest']}` | `{row['owner_file_digest']}` | "
            f"`{row['complete_case_digest']}` |"
        )
    lines += [
        "",
        "Patch 23.9 changes no accepted Gust meaning, MIR operation, backend",
        "capability, route, fallback, ABI/layout/runtime symbol, or bootstrap seed.",
        "The surface may receive compatibility corrections only; expansion must",
        "start from shared semantic authority and an already-supported Cranelift path.",
        "",
    ]
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=(
        "scan", "validate", "project", "check-review", "evidence",
    ))
    args = parser.parse_args()
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    if args.command == "scan":
        print(json.dumps(scan(registry), indent=2, sort_keys=True))
        return
    if args.command == "project":
        record = registry.get("phase23_mir_to_c_frozen_surface")
        require(isinstance(record, dict), "Patch 23.9 authority is missing")
        REVIEW.write_text(render(record, registry), encoding="utf-8")
        validate()
        print(f"{GUARD_L1}: project ok")
        return
    record, _ = validate()
    if args.command == "evidence":
        evidence(record)
    else:
        print(f"{GUARD_L1}: ok")


if __name__ == "__main__":
    main()
