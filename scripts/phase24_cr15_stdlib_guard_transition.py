#!/usr/bin/env python3
"""Validate the exact pre/post Stdlib CR-15 prerequisite-guard transition."""

from __future__ import annotations

import argparse
import copy
import hashlib
import importlib.util
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE24_CR15_STDLIB_GUARD_TRANSITION.md"
JUSTFILE = ROOT / "justfile"
GUARD = "guard-cranelift-phase24-cr15-stdlib-guard-transition"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD}: {message}")


def digest_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def authority(registry: dict | None = None) -> dict:
    if registry is None:
        registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    opening = registry.get("phase24_cr15_opening", {})
    value = opening.get("stdlib_guard_transition")
    require(isinstance(value, dict), "transition authority is missing")
    return value


def validate_static(value: dict) -> None:
    require(value.get("contract_version") ==
            "phase24_cr15_stdlib_guard_transition_v1",
            "contract version drifted")
    require(value.get("status") == "authorized_exact_pre_or_post_relay" and
            value.get("owner") == "cranelift" and
            value.get("owning_stdlib_pull_request") == 304 and
            value.get("owning_stdlib_exact_head_sha") ==
            "45074ffef9a899c892a98837d9ba085a820ab35b" and
            value.get("owning_stdlib_base_sha") ==
            "da1889834f78853d685570cdbef70be77b9be06c",
            "owning relay identity drifted")
    require(value.get("changed_paths") == ["justfile"] and
            value.get("changed_path_count") == 1 and
            value.get("changed_site_count") == 1,
            "relay path or site count drifted")
    require(value.get("pre_relay_justfile_digest") ==
            "47b2886ff09862a09bac75419c4dd8714e184333e79e7415af6ac73f4064ff2c" and
            value.get("post_relay_justfile_digest") ==
            "97ebdee95b04c0f036b1f84a7d6a9d7ad1bb6adacc9c3ee2c5e2f8ea4bf43467",
            "relay file identity drifted")
    site = value.get("changed_site", {})
    require(site == {
        "path": "justfile",
        "recipe": "guard-stdlib-s1-resource-prerequisites",
        "compiler_token": "./gust",
        "selection": "explicit_c",
        "command": 'if ./gust --backend mir-to-c "$witness" >"$output" 2>&1; then',
        "pre_relay_line": 23258,
        "post_relay_line": 23270,
    }, "relay site identity drifted")
    require(value.get("phase22_invocation_summary") == {
        "total": 318,
        "selection_counts": {
            "explicit_c": 178,
            "explicit_cranelift": 119,
            "explicit_invalid_or_parser_probe": 3,
            "implicit_default": 18,
        },
        "consumer_class_counts": {
            "already_explicit_or_parser_probe": 300,
            "cranelift_C_or_diagnostic_guard": 5,
            "help_surface_probe": 3,
            "intentional_default_selection_probe": 8,
            "invocation_parser_probe": 2,
        },
        "owner_counts": {"cranelift": 289, "stdlib": 29},
        "unclassified_count": 0,
    }, "Phase 22 aggregate identity drifted")
    require(value.get("projection_policy") == {
        "pre_relay": "accepted_as_live_predecessor",
        "post_relay": "accepted_only_at_exact_registered_file_and_site_identity",
        "closed_phase_projection": "canonical_pre_relay_identity",
        "partial_extra_substituted_or_unrelated": "rejected",
        "authorization_is_not_landed_merge_evidence": True,
    }, "projection policy drifted")


def live_state(registry: dict | None = None) -> str:
    value = authority(registry)
    validate_static(value)
    digest = digest_bytes(JUSTFILE.read_bytes())
    if digest == value["pre_relay_justfile_digest"]:
        return "pre_relay"
    if digest == value["post_relay_justfile_digest"]:
        return "post_relay"
    require(False,
            "justfile is neither the exact pre-relay nor exact one-site post-relay state")
    raise AssertionError("unreachable")


def normalize_phase22_invocations(
        registry: dict, rows: list[dict[str, object]]) -> list[dict[str, object]]:
    """Project the exact post relay onto the closed Phase 22 site identity."""
    value = authority(registry)
    state = live_state(registry)
    site = value["changed_site"]
    line_key = f"{state}_line"
    matches = [
        row for row in rows
        if row.get("path") == site["path"] and
        row.get("recipe") == site["recipe"] and
        row.get("compiler_token") == site["compiler_token"]
    ]
    require(len(matches) == 1, "relay site is missing, duplicated, or substituted")
    match = matches[0]
    require(match.get("line") == site[line_key] and
            match.get("selection") == site["selection"] and
            match.get("command") == site["command"],
            "relay site command, route, or location drifted")
    normalized = copy.deepcopy(rows)
    target = next(
        row for row in normalized
        if row.get("path") == site["path"] and
        row.get("recipe") == site["recipe"] and
        row.get("compiler_token") == site["compiler_token"]
    )
    target["line"] = site["pre_relay_line"]
    normalized.sort(key=lambda row: (
        str(row["path"]), int(row["line"]), str(row["command"])
    ))
    return normalized


def normalize_phase23_text_surfaces(
        registry: dict, rows: list[dict[str, object]]) -> list[dict[str, object]]:
    """Keep closed Phase 23 projection identity across this exact control-plane relay."""
    value = authority(registry)
    live_state(registry)
    canonical = value.get("canonical_phase23_text_surfaces", [])
    require([row.get("path") for row in canonical] == [
        "justfile", "scripts/phase22_opening.py",
    ], "canonical text-surface path manifest drifted")
    by_path = {str(row["path"]): row for row in rows}
    for expected in canonical:
        path = str(expected["path"])
        require(path in by_path, f"canonical text surface is missing: {path}")
        live = by_path[path]
        accepted = expected.get("accepted_live_digests", [])
        require(live.get("digest") in accepted,
                f"unregistered text-surface identity: {path}")
        for field in (
            "match_counts", "classification", "owner", "current_route",
            "deprecation_action", "removal_phase", "falsifier",
        ):
            require(live.get(field) == expected.get(field),
                    f"text-surface classification drifted: {path}: {field}")
        by_path[path] = {
            key: copy.deepcopy(expected[key])
            for key in (
                "path", "digest", "match_counts", "classification", "owner",
                "current_route", "deprecation_action", "removal_phase", "falsifier",
            )
        }
    return [by_path[str(row["path"])] for row in rows]


def normalized_owner_file_digest(
        registry: dict, path: str, digest: str) -> str:
    """Normalize only the exact registered justfile owner identity."""
    if path != "justfile":
        return digest
    value = authority(registry)
    state = live_state(registry)
    expected = value[f"{state}_justfile_digest"]
    require(digest == expected, "live-C justfile owner identity drifted")
    return value["pre_relay_justfile_digest"]


def validate() -> tuple[dict, str]:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    value = authority(registry)
    state = live_state(registry)

    opening_path = ROOT / "scripts/phase22_opening.py"
    spec = importlib.util.spec_from_file_location("phase22_transition_opening", opening_path)
    require(spec is not None and spec.loader is not None,
            "cannot load the Phase 22 invocation scanner")
    opening = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(opening)
    rows = opening.scan_invocations()
    require(opening.scan_summary(rows) == value["phase22_invocation_summary"],
            "effective Phase 22 aggregate drifted")
    return value, state


def render(value: dict) -> str:
    site = value["changed_site"]
    summary = value["phase22_invocation_summary"]
    return "\n".join([
        "# Cranelift Phase 24 CR-15 Stdlib Guard Transition",
        "",
        "Generated by `scripts/phase24_cr15_stdlib_guard_transition.py`; do not edit by hand.",
        "",
        f"- Contract: `{value['contract_version']}`",
        f"- Status: `{value['status']}`",
        f"- Owning Stdlib PR: `#{value['owning_stdlib_pull_request']}`",
        f"- Exact owning head: `{value['owning_stdlib_exact_head_sha']}`",
        "- Changed paths: `justfile` (exactly one)",
        f"- Changed site: `{site['recipe']}` / `{site['compiler_token']}`",
        f"- Pre-relay line: `{site['pre_relay_line']}`",
        f"- Post-relay line: `{site['post_relay_line']}`",
        f"- Preserved invocation total: `{summary['total']}`",
        f"- Preserved explicit-C count: `{summary['selection_counts']['explicit_c']}`",
        f"- Preserved unclassified count: `{summary['unclassified_count']}`",
        "",
        "The exact pre-relay file or the exact registered one-site successor is accepted.",
        "Closed Phase 22/23 projections use the canonical predecessor identity because",
        "the compiler command and route are unchanged. Partial, extra-site, substituted,",
        "path-drifted, or unrelated `justfile` changes are rejected.",
        "",
        "This row authorizes the transition; it does not claim the Stdlib PR has merged.",
        "It changes no language, MIR, backend, route/default/fallback, runtime, bootstrap,",
        "or Stdlib semantics.",
        "",
    ])


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate", "project", "check-review"))
    args = parser.parse_args()
    value, state = validate()
    expected = render(value)
    if args.command == "project":
        REVIEW.write_text(expected, encoding="utf-8")
    elif args.command == "check-review":
        require(REVIEW.is_file() and REVIEW.read_text(encoding="utf-8") == expected,
                "generated review is stale")
    print(f"{GUARD}: {args.command} ok ({state})")


if __name__ == "__main__":
    main()
