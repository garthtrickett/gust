#!/usr/bin/env python3
"""Validate and render the Patch 24.4 opening-preflight closure statement.

The preflight (Patches 24.0-24.4) made compiler meaning explicit without
changing it: filename-selected behaviours characterized with paired
pre-change evidence, the universal rule decided and carried as future work,
and every compiler-recognized concrete spelling classified. Patch 24.3 was
amended without a correction, so this closure claims characterization and
authority, never removal of the filename-selected branches.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from phase22_default_route_seed_convergence import (
    published_source_seeds,
)


ROOT = Path(__file__).resolve().parent.parent
GUARD = "guard-cranelift-phase24-preflight-closure"
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TASK = ROOT / "TASK.md"
SEED = ROOT / "gust_v4.c"
VIEW = ROOT / "docs/PHASE24_PREFLIGHT_CLOSURE.md"

EXPECTED_MAIN_SHA = "4fcee4b42e80298ce686c54b5b16700e08919a52"
EXPECTED_SEED_DIGEST = "a1ba675a1c244af0a77485d48a5865833eee896a4a2b746ea5728e20f590eebb"
EXPECTED_SEED_LINES = 65998


def fail(message: str) -> None:
    raise SystemExit(f"{GUARD}: {message}")


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def closure(registry: dict) -> dict:
    node = registry.get("phase24_preflight_closure")
    require(isinstance(node, dict), "preflight closure record is missing")
    return node


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    node = closure(registry)
    require(node.get("version") == "phase24_preflight_closure_v1" and
            node.get("status") == "patch24_4_opening_preflight_closed" and
            node.get("authority_owner") ==
            "scripts/cranelift_feature_registry.json" and
            bool(node.get("wording")),
            "preflight closure identity drifted")
    historical = node.get("authoritative_latest_historical_full", {})
    require(historical.get("workflow") == "Cranelift Historical Full" and
            isinstance(historical.get("run_id"), int) and
            historical["run_id"] > 0 and
            historical.get("event") == "workflow_dispatch" and
            historical.get("head_branch") == "main" and
            historical.get("head_sha") == EXPECTED_MAIN_SHA and
            historical.get("status") == "completed" and
            historical.get("conclusion") == "success" and
            historical.get("successful_jobs") ==
            historical.get("total_jobs") and
            historical.get("total_jobs", 0) > 0 and
            historical.get("unfinished_jobs") == 0 and
            historical.get("non_success_jobs") == 0 and
            historical.get("stale_citation_rejected") == "a92a8ca",
            "authoritative Historical Full is incomplete, stale, or unfilled")
    characterization = node.get("characterization_authority", {})
    require(characterization.get("record") ==
            "phase24_filename_behavior_characterization" and
            characterization.get("witness_pairs") == 4 and
            characterization.get("recorded_observations_hold") == "8_of_8",
            "characterization authority drifted")
    record = registry.get("phase24_filename_behavior_characterization")
    require(isinstance(record, dict) and
            len(record.get("witnesses", [])) == 4,
            "characterization witness record drifted")
    require(node.get("spelling_authority", {}).get("record") ==
            "phase24_semantic_spelling_inventory" and
            node.get("spelling_authority", {}).get("classification") ==
            "report_only_complete" and
            isinstance(registry.get("phase24_semantic_spelling_inventory"),
                       dict),
            "spelling authority drifted")
    future = node.get("universal_rule_future_work", {})
    require(future.get("patch_24_3_roadmap") == "UNCHECKED" and
            future.get("refine_analysis") == "not_taken" and
            future.get("source_migration") == "not_taken",
            "universal-rule future work restated as done")
    require(node.get("no_fallback_authority", {}) ==
            {"default_route": "cranelift", "fallback": "forbidden"},
            "no-fallback authority drifted")
    seed = node.get("bootstrap_authority", {})
    # Patch 25.9 deleted the seed, so "live" is resolved from the artifact
    # carrying the same bytes -- release 0's `source_seed`. Everything below
    # is unchanged: the recorded preflight identity still cannot move, and a
    # live identity that is neither the preflight one nor the one the named
    # successor publishes still fails. Only the SOURCE of the live identity
    # changed, from a file to a published artifact, because deleting a file
    # must not be a way to make this guard stop asking.
    if SEED.is_file():
        live_digest = hashlib.sha256(SEED.read_bytes()).hexdigest()
        live_lines = len(SEED.read_text(encoding="utf-8").splitlines())
    else:
        seeds = published_source_seeds()
        require(len(seeds) == 1,
                f"{len(seeds)} published `source_seed` artifacts; with the "
                "file deleted there is then no single answer to what the "
                "live seed is.")
        live_digest, live_lines = next(iter(seeds.items()))
        require(isinstance(live_lines, int),
                "the published `source_seed` records no line count, so half "
                "of the live identity would be unchecked here.")
    # The RECORD is the seed as Phase 24 preflight closed, and stays exactly
    # that. What cannot stay is the assertion that the live seed still equals
    # it: Patch 24.13 changes the compiler, so the seed reconverges, which is
    # routine in this phase -- five republications precede it.
    #
    # A successor is consulted rather than the pin being relaxed. Without one
    # the original assertion holds unchanged, so a seed that moved for any
    # unregistered reason still fails here. With one, the live seed must be
    # exactly the identity that successor publishes, and the recorded preflight
    # identity must be untouched -- so this cannot be used to launder a seed
    # change past the closure record it is supposed to protect.
    require(seed.get("seed") == "gust_v4.c" and
            seed.get("seed_digest") == EXPECTED_SEED_DIGEST and
            seed.get("seed_lines") == EXPECTED_SEED_LINES and
            seed.get("fixed_point") == "stage2_stage3_byte_identity",
            "the recorded preflight bootstrap seed drifted")
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    # Named in order, newest last, and consulted only when named: Issue #398
    # reconverges the seed again, and a second successor block appearing in
    # the registry must not widen what this guard accepts on its own. Whoever
    # moves the seed next adds their key here and says why.
    convergence = registry.get("phase22_default_route_seed_convergence", {})
    successor_key = None
    for key in ("phase24_13_seed_transition", "phase398_seed_transition",
                # Patch 25.6 then Patch 25.5, in merge order, because the
                # loop takes the LAST key that is present and the last one
                # present has to be the newest. 25.6 moves the seed at
                # 1,963 abort sites; 25.5 moves it again when six runtime
                # C files leave the unity build.
                "phase256_seed_transition", "phase255_seed_transition"):
        if isinstance(convergence.get(key), dict):
            successor_key = key
    transition = convergence.get(successor_key) if successor_key else None
    if transition is None:
        require(live_digest == EXPECTED_SEED_DIGEST and
                live_lines == EXPECTED_SEED_LINES,
                "bootstrap seed drifted under the closure")
    else:
        identities = transition.get("accepted_live_seed_identities", [])
        published = [row for row in identities
                     if row.get("state") == "post_publication"]
        require(len(published) == 1,
                f"the {successor_key} seed transition does not publish "
                "exactly one identity")
        require(live_digest == published[0]["seed_digest"] and
                live_lines == published[0]["line_count"],
                "the live seed is neither the preflight closure identity nor "
                f"the one {successor_key} publishes: "
                f"{live_lines} lines, {live_digest[:16]}")
        require(published[0]["seed_digest"] != EXPECTED_SEED_DIGEST,
                f"the {successor_key} seed transition publishes the preflight "
                "identity, so it is not a reconvergence at all")
    require(node.get("pinned_manifest_closure", {}).get("status") ==
            "patch24_3b_complete_merged_31b49779" and
            isinstance(registry.get(
                "phase24_s1_8_authority_successor", {}).get(
                    "s1_9_resource_assignment_roadmap_successor", {}).get(
                        "pinned_manifest_class_contract", {}).get(
                            "phase24_3b_coordinate_retirement"), dict),
            "pinned-manifest closure drifted")
    require(node.get("cr15_handoff", {}).get("status") ==
            "complete_handed_off" and
            isinstance(registry.get("phase24_cr15_closure"), dict),
            "CR-15 handoff drifted")
    require(node.get("unresolved_material_findings") == 0,
            "unresolved material findings remain")
    require(len(node.get("non_claims", [])) == 5 and
            any("stays unchecked" in claim
                for claim in node["non_claims"]),
            "non-claims narrowed: the unremoved branches must stay named")
    boundary = node.get("boundary", {})
    require(isinstance(boundary, dict) and boundary and
            all(value is False for value in boundary.values()),
            "closure boundary opened a later phase")
    text = TASK.read_text(encoding="utf-8")
    require("- [x] Patch 24.3b — Pinned-Manifest Retirement — DONE" in text and
            "- [ ] Patch 24.3 — Filename-Independent Typechecker Correction" in text and
            "- [x] Patch 24.4 — Opening-Preflight Closure — DONE" in text and
            "- [ ] Patch 24.4 — Opening-Preflight Closure" not in text,
            "preflight Status rows are not in their closed state")
    return node


def render(node: dict) -> str:
    historical = node["authoritative_latest_historical_full"]
    bootstrap = node["bootstrap_authority"]
    lines = [
        "# Phase 24 Opening-Preflight Closure",
        "",
        "<!-- Generated by scripts/phase24_preflight_closure.py from the",
        "     Cranelift feature registry. Do not edit by hand; edit the",
        "     registry and regenerate. -->",
        "",
        f"Status: `{node['status']}`",
        "",
        node["wording"],
        "",
        "## Authoritative closure gate",
        "",
        f"- Workflow/run: `{historical['workflow']}` / `{historical['run_id']}`",
        f"- Event: `{historical['event']}`",
        f"- Exact final implementation head: `{historical['head_sha']}`",
        f"- Conclusion: `{historical['conclusion']}`",
        f"- Jobs: `{historical['successful_jobs']}/{historical['total_jobs']}` successful",
        f"- Created/completed: `{historical['created_at']}` / `{historical['completed_at']}`",
        "",
        "## Characterization and spelling authority",
        "",
        f"- Witness pairs: `{node['characterization_authority']['witness_pairs']}`",
        f"- Recorded observations hold: `{node['characterization_authority']['recorded_observations_hold']}`",
        f"- Spelling inventory: `{node['spelling_authority']['classification']}`",
        f"- Universal rule: decided authority, carried as future work; Patch 24.3 stays unchecked",
        "",
        "## Bootstrap boundary",
        "",
        f"- Seed: `{bootstrap['seed']}`",
        f"- Fixed point: `{bootstrap['fixed_point']}`",
        f"- Default route: `{node['no_fallback_authority']['default_route']}`",
        f"- Fallback: `{node['no_fallback_authority']['fallback']}`",
        "",
        "## What the preflight does not claim",
        "",
    ]
    for claim in node["non_claims"]:
        lines.append(f"- {claim}")
    lines += [
        "",
        "Phase 24 backend retirement, Phase 24.5, Phase 25, Stdlib",
        "implementation, and Web Slice 1 remain inactive after this preflight",
        "closes.",
        "",
    ]
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate", "render", "check-review"))
    args = parser.parse_args()
    node = validate()
    if args.command == "render":
        VIEW.write_text(render(node), encoding="utf-8")
    elif args.command == "check-review":
        require(VIEW.is_file() and
                VIEW.read_text(encoding="utf-8") == render(node),
                "generated preflight closure review is stale; run render")
        print(f"{GUARD}: review current")
    else:
        print(f"{GUARD}: ok")


if __name__ == "__main__":
    main()
