#!/usr/bin/env python3
"""Validate and project Patch 22.6a default-route seed convergence."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "scripts/cranelift_feature_registry.json"
TASK = ROOT / "TASK.md"
SEED = ROOT / "gust_v4.c"
MAKEFILE = ROOT / "Makefile"
REVIEW = ROOT / "compiler/CRANELIFT_PHASE22_DEFAULT_ROUTE_SEED_CONVERGENCE.md"
WORKFLOW = ROOT / ".github/workflows/phase19-seed-convergence.yml"
PR_FAST = ROOT / ".github/workflows/pr-fast.yml"
JUSTFILE = ROOT / "justfile"
GUARD = "guard-cranelift-phase22-default-route-seed-convergence"


# The one native compile that replaced the four-step C stage chain.
NATIVE_SEED_STEP = ("./build/native-build/bin/gust --backend cranelift "
                    "-o build/.gust.tmp compiler/test_runner_entry.gst")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"{GUARD}: {message}")


def accepted_live_seed_identities(record: dict) -> list[dict]:
    transition = record.get("phase23_successor_transition")
    require(transition == {
        "contract_version": "phase23_diagnostic_seed_reconvergence_transition_v1",
        "status": "landed_post_publication",
        "predecessor_seed_authority": "phase22_default_route_seed_convergence_v1",
        "authority_base_main": "d49cf1835972951b806621b798e7f905aa95df1a",
        "accounted_compiler_authorities": [
            "phase23_structured_guard_defer_native_admission_v1",
            "phase23_same_scope_declaration_v1",
        ],
        "accepted_live_seed_identities": [
            {
                "state": "post_publication",
                "line_count": 64929,
                "seed_digest": "33b23ff4e8dab6c84365920bf3a2a674d7e3f5248646f6ffd69c8f7cc014083a",
            },
        ],
        "generated_seed_diff": {
            "previous_lines": 64825,
            "current_lines": 64929,
            "insertions": 154,
            "deletions": 50,
            "line_delta": 104,
        },
        "seed_pr_policy": "gust_v4_c_only",
        "partial_or_unregistered_identity": "rejected",
        "closure_transition": "collapsed_to_post_publication",
        "landed_seed_evidence": {
            "pull_request": 281,
            "head_sha": "b3ce3637017e29074f34b8657e7e75d9e0a39ef9",
            "merge_main_sha": "5f0130fa24430e96da2425d05f24a8223e914f1d",
            "merged_at": "2026-09-01T00:43:42Z",
            "event": "pull_request",
            "workflow_population": 21,
            "successful_workflows": 21,
            "unfinished_workflows": 0,
            "non_success_workflows": 0,
            "unresolved_non_outdated_review_threads": 0,
            "changed_paths": ["gust_v4.c"],
        },
    }, "Phase 23 seed successor transition drifted")
    predecessor_identities = transition["accepted_live_seed_identities"]
    require(len(predecessor_identities) == 1 and
            predecessor_identities[0]["state"] == "post_publication",
            "Phase 23 seed transition did not collapse to the landed identity")
    successor_diff = transition["generated_seed_diff"]
    require(successor_diff["current_lines"] - successor_diff["previous_lines"] ==
            successor_diff["line_delta"] and
            successor_diff["insertions"] - successor_diff["deletions"] ==
            successor_diff["line_delta"],
            "Phase 23 generated seed line delta is inconsistent")
    deprecation_transition = record.get("phase23_deprecation_seed_transition")
    require(deprecation_transition == {
        "contract_version": "phase23_deprecation_seed_reconvergence_transition_v1",
        "status": "landed_post_publication",
        "predecessor_seed_authority":
            "phase23_diagnostic_seed_reconvergence_transition_v1",
        "authority_base_main": "e39ddaf86fe689a9817fb4ee50e6eab0c506139c",
        "accounted_compiler_authority":
            "phase23_mir_to_c_user_deprecation_v1",
        "accepted_live_seed_identities": [
            {
                "state": "post_publication",
                "line_count": 64929,
                "seed_digest":
                    "af8a283c9ef4dbe621f78729e89a4c7270c0b740aeb7164af57fa953e5f29924",
            },
        ],
        "generated_seed_diff": {
            "previous_lines": 64929,
            "current_lines": 64929,
            "insertions": 2,
            "deletions": 2,
            "line_delta": 0,
        },
        "presentation_diff": {
            "removed": [
                "mir-to-c, c  Emit C source to stdout (retained semantic oracle).",
                "",
            ],
            "added": [
                "mir-to-c, c  DEPRECATED: Emit C source to stdout (retained semantic oracle); backend removal is Phase 24.",
                "Bootstrap C retirement is separate and deferred to Phase 25.",
            ],
        },
        "seed_pr_policy": "gust_v4_c_only",
        "partial_or_unregistered_identity": "rejected",
        "closure_transition": "collapsed_to_post_publication",
        "landed_seed_evidence": {
            "pull_request": 289,
            "head_sha": "ba040834dadef99982892016a2163d0296270a0a",
            "merge_main_sha": "3d9ed5df9188cf38275885a665316e58cfb9dd21",
            "merged_at": "2026-09-01T08:53:43Z",
            "event": "pull_request",
            "workflow_population": 22,
            "successful_workflows": 22,
            "unfinished_workflows": 0,
            "non_success_workflows": 0,
            "unresolved_non_outdated_review_threads": 0,
            "changed_paths": ["gust_v4.c"],
        },
    }, "Phase 23 deprecation seed transition drifted")
    identities = deprecation_transition["accepted_live_seed_identities"]
    require([row["state"] for row in identities] ==
            ["post_publication"],
            "Phase 23 deprecation seed transition state order drifted")
    deprecation_diff = deprecation_transition["generated_seed_diff"]
    require(deprecation_diff["current_lines"] - deprecation_diff["previous_lines"] ==
            deprecation_diff["line_delta"] and
            deprecation_diff["insertions"] - deprecation_diff["deletions"] ==
            deprecation_diff["line_delta"],
            "Phase 23 deprecation seed line delta is inconsistent")
    cr15_transition = record.get("phase24_cr15_seed_transition")
    require(cr15_transition == {
        "contract_version": "phase24_cr15_seed_reconvergence_transition_v1",
        "status": "ready_for_seed_publication",
        "predecessor_seed_authority":
            "phase23_deprecation_seed_reconvergence_transition_v1",
        "authority_base_main": "10076805b56697304e7b236fff09cdf3689fcc05",
        "accounted_compiler_authorities": [
            "phase24_cr15_derivation_v1",
            "phase24_cr15_qualification_v1",
        ],
        "accepted_live_seed_identities": [
            {
                "state": "pre_publication",
                "line_count": 64929,
                "seed_digest":
                    "af8a283c9ef4dbe621f78729e89a4c7270c0b740aeb7164af57fa953e5f29924",
            },
            {
                "state": "post_publication",
                "line_count": 65789,
                "seed_digest":
                    "706430d05010521657d44e0ee2afa2580afb71f1f5e8ca54a88f6e34f1a2e8d9",
            },
        ],
        "generated_seed_diff": {
            "previous_lines": 64929,
            "current_lines": 65789,
            "insertions": 1332,
            "deletions": 472,
            "line_delta": 860,
        },
        "seed_pr_policy": "gust_v4_c_only",
        "partial_or_unregistered_identity": "rejected",
        "closure_transition": "collapse_to_post_publication_after_seed_merge",
    }, "Phase 24 CR-15 seed transition drifted")
    identities = cr15_transition["accepted_live_seed_identities"]
    require([row["state"] for row in identities] ==
            ["pre_publication", "post_publication"],
            "Phase 24 CR-15 seed transition state order drifted")
    require(len({(row["line_count"], row["seed_digest"]) for row in identities}) == 2,
            "Phase 24 CR-15 seed transition identities are not distinct")
    cr15_diff = cr15_transition["generated_seed_diff"]
    require(cr15_diff["current_lines"] - cr15_diff["previous_lines"] ==
            cr15_diff["line_delta"] and
            cr15_diff["insertions"] - cr15_diff["deletions"] ==
            cr15_diff["line_delta"],
            "Phase 24 CR-15 seed line delta is inconsistent")

    # Patch 24.2f moved the seed again, so the CR-15 post-publication identity is
    # now this chain's pre-publication identity. Registered here before Patch
    # 24.2g publishes gust_v4.c, because that publication must contain the seed
    # and nothing else and would otherwise land red.
    transfer_transition = record.get("phase24_2f_seed_transition")
    require(transfer_transition == {
        "contract_version":
            "phase24_2f_resource_transfer_seed_reconvergence_transition_v1",
        "status": "landed_post_publication",
        "predecessor_seed_authority":
            "phase24_cr15_seed_reconvergence_transition_v1",
        "authority_base_main": "6e5aaa671b705c71866cc30d719c70d5cd316b59",
        "accounted_compiler_authorities": [
            "phase24_s1_9_resource_assignment_implementation_v1",
        ],
        "accepted_live_seed_identities": [
            {
                "state": "post_publication",
                "line_count": 65784,
                "seed_digest":
                    "3f898b4bf34172fb0be90c5a78e8d07b8e319c74bee7a383d2f176267d09bf58",
            },
        ],
        "generated_seed_diff": {
            "previous_lines": 65789,
            "current_lines": 65784,
            "insertions": 86,
            "deletions": 91,
            "line_delta": -5,
        },
        "seed_pr_policy": "gust_v4_c_only",
        "partial_or_unregistered_identity": "rejected",
        "closure_transition": "collapsed_to_post_publication",
        "landed_seed_evidence": {
            "pull_request": 327,
            "head_sha": "da7526be64aaedabcd917d05f0c7b989daa69fe1",
            "merge_main_sha": "38c794ec804f00c5ba2477b8212f56505bf7d94f",
            "merged_at": "2026-09-05T00:21:30Z",
            "event": "pull_request",
            "workflow_population": 35,
            "successful_workflows": 35,
            "unfinished_workflows": 0,
            "non_success_workflows": 0,
            "unresolved_non_outdated_review_threads": 0,
            "changed_paths": ["gust_v4.c"],
        },
    }, "Patch 24.2f seed transition drifted")
    transfer_identities = transfer_transition["accepted_live_seed_identities"]
    require(len(transfer_identities) == 1 and
            transfer_identities[0]["state"] == "post_publication",
            "Patch 24.2f seed transition did not collapse to the landed identity")
    transfer_diff = transfer_transition["generated_seed_diff"]
    require(transfer_diff["current_lines"] - transfer_diff["previous_lines"] ==
            transfer_diff["line_delta"] and
            transfer_diff["insertions"] - transfer_diff["deletions"] ==
            transfer_diff["line_delta"],
            "Patch 24.2f seed line delta is inconsistent")
    # The chain must still be continuous after the collapse: this transition's
    # recorded diff starts from the seed CR-15 published and ends at the single
    # landed identity that remains.
    require(transfer_diff["previous_lines"] == identities[1]["line_count"],
            "Patch 24.2f seed transition does not start from the CR-15 fixed point")
    require(transfer_diff["current_lines"] == transfer_identities[0]["line_count"],
            "Patch 24.2f seed diff does not match its own landed identity")

    # Patch 24.3a. CR-a Stage 1 adds the single MIR identity definition to
    # compiler/mir_layout.gst, so the seed moves again and the Patch 24.2f
    # landed identity becomes this chain's pre-publication identity. Registered
    # here before the seed-only publication, for the same reason Patch 24.2f
    # was: that publication must contain gust_v4.c and nothing else, so it
    # cannot carry the registration that would let it land green.
    stage1_transition = record.get("phase24_cra_stage1_seed_transition")
    require(stage1_transition == {
        "contract_version":
            "phase24_cra_stage1_identity_format_seed_reconvergence_transition_v1",
        "status": "landed_post_publication",
        "predecessor_seed_authority":
            "phase24_2f_resource_transfer_seed_reconvergence_transition_v1",
        "authority_base_main": "6b657cb42f485207480d295a86a248630a1a12fa",
        "accounted_compiler_authorities": [
            "phase24_identity_format_ledger_v1",
        ],
        "accepted_live_seed_identities": [
            {
                "state": "post_publication",
                "line_count": 65800,
                "seed_digest":
                    "7373a957f3e55f0a9d60c1a17e84c7776158a43e3b933af5dd047b72ca990abf",
            },
        ],
        "generated_seed_diff": {
            "previous_lines": 65784,
            "current_lines": 65800,
            "insertions": 16,
            "deletions": 0,
            "line_delta": 16,
        },
        "seed_pr_policy": "gust_v4_c_only",
        "partial_or_unregistered_identity": "rejected",
        "closure_transition": "collapsed_to_post_publication",
        "landed_seed_evidence": {
            "pull_request": 358,
            "head_sha": "6341cf79daf4475fcb9802c0eab8c617f0d3ff49",
            "merge_main_sha": "00715c9639c978b97a1dfe1787cbc89c4e2fb69f",
            "merged_at": "2026-09-07T12:50:20Z",
            "event": "pull_request",
            "workflow_population": 35,
            "successful_workflows": 35,
            "unfinished_workflows": 0,
            "non_success_workflows": 0,
            "unresolved_non_outdated_review_threads": 0,
            "changed_paths": ["gust_v4.c"],
        },
    }, "Patch 24.3a seed transition drifted")
    stage1_identities = stage1_transition["accepted_live_seed_identities"]
    # Collapsed: the publication landed, so the superseded pre-publication seed
    # is no longer accepted anywhere. One terminal identity, and the next seed
    # movement must register itself exactly as this one did.
    require(len(stage1_identities) == 1 and
            stage1_identities[0]["state"] == "post_publication",
            "Patch 24.3a seed transition did not collapse to the landed identity")
    stage1_diff = stage1_transition["generated_seed_diff"]
    require(stage1_diff["current_lines"] - stage1_diff["previous_lines"] ==
            stage1_diff["line_delta"] and
            stage1_diff["insertions"] - stage1_diff["deletions"] ==
            stage1_diff["line_delta"],
            "Patch 24.3a seed line delta is inconsistent")
    # The chain stays continuous: this transition's pre-publication identity is
    # exactly what Patch 24.2f landed, and its diff ends at its own post state.
    require(stage1_diff["previous_lines"] == transfer_identities[0]["line_count"],
            "Patch 24.3a seed diff does not start from the Patch 24.2f fixed point")
    require(stage1_diff["current_lines"] == stage1_identities[0]["line_count"],
            "Patch 24.3a seed diff does not match its own landed identity")
    # CR-19 has landed and collapsed: the seed-only publication carried the
    # exact post identity, so the pre-publication seed is no longer accepted
    # anywhere. One terminal identity, and the next seed movement must register
    # itself exactly as this one did. The unpublished intermediate seed was
    # never a committed identity; its attribution to the landed seed is kept
    # below as history, not as an accepted state.
    bundle_transition = record.get("phase24_cr19_seed_transition")
    require(bundle_transition == {
        "contract_version": "phase24_cr19_bundle_validation_seed_reconvergence_transition_v1",
        "status": "landed_post_publication",
        "predecessor_seed_authority": "phase24_cra_stage1_identity_format_seed_reconvergence_transition_v1",
        "authority_base_main": "fd9023cc3585f4ccee1689e9a57a3224e514ae12",
        "accounted_compiler_authorities": [
            "phase24_cr19_multi_module_analysis_v1"
        ],
        "accepted_live_seed_identities": [
            {
                "state": "post_publication",
                "line_count": 65986,
                "seed_digest": "0bb8d3ccea011275366356baa07ee0619d13979fa00fc91ee97eb05718f27539"
            }
        ],
        "generated_seed_diff": {
            "previous_lines": 65800,
            "current_lines": 65986,
            "insertions": 277,
            "deletions": 91,
            "line_delta": 186
        },
        "seed_pr_policy": "gust_v4_c_only",
        "partial_or_unregistered_identity": "rejected",
        "closure_transition": "collapsed_to_post_publication",
        "landed_seed_evidence": {
            "pull_request": 374,
            "head_sha": "7fb7ef4c416235306301452565ee1d7d4135847b",
            "merge_main_sha": "0f6cd3fc562cff02c7b41a0168fff138aa38be17",
            "merged_at": "2026-09-09T09:41:05Z",
            "event": "pull_request",
            "workflow_population": 35,
            "successful_workflows": 35,
            "unfinished_workflows": 0,
            "non_success_workflows": 0,
            "unresolved_non_outdated_review_threads": 0,
            "changed_paths": ["gust_v4.c"]
        },
        "pending_post_supersession": {
            "status": "supersession_closed_B_never_committed_C_landed",
            "unpublished_source_pull_request": 371,
            "unpublished_source_merge": "fd9023cc3585f4ccee1689e9a57a3224e514ae12",
            "unpublished_seed_identity": {
                "line_count": 66042,
                "seed_digest": "e94bbf7623cbe6a9423d05762546c1b32c7240d8e19e16123e5ddfe6d87b9e13"
            },
            "superseding_patch": "CR-b.2b",
            "superseding_pull_request": 366,
            "attribution_diff": {
                "previous_lines": 66042,
                "current_lines": 65986,
                "insertions": 10,
                "deletions": 66,
                "line_delta": -56
            },
            "committed_seed_remains": "preregistration_state_A_superseded_by_landed_C"
        }
    }, "CR-19 seed transition drifted")
    bundle_identities = bundle_transition["accepted_live_seed_identities"]
    require([row["state"] for row in bundle_identities] ==
            ["post_publication"],
            "CR-19 seed transition state order drifted")
    require(len({(row["line_count"], row["seed_digest"])
                 for row in bundle_identities}) == len(bundle_identities),
            "CR-19 seed transition identities are not distinct")
    bundle_diff = bundle_transition["generated_seed_diff"]
    require(bundle_diff["current_lines"] - bundle_diff["previous_lines"] ==
            bundle_diff["line_delta"] and
            bundle_diff["insertions"] - bundle_diff["deletions"] ==
            bundle_diff["line_delta"],
            "CR-19 seed line delta is inconsistent")
    # The chain stays continuous after the collapse: this transition's recorded
    # diff starts from exactly what CR-a Stage 1 landed and ends at the single
    # landed identity that remains.
    require(bundle_diff["previous_lines"] == stage1_identities[0]["line_count"],
            "CR-19 seed diff does not start from the landed CR-a Stage 1 identity")
    require(bundle_diff["current_lines"] == bundle_identities[0]["line_count"],
            "CR-19 seed diff does not match its collapsed landed identity")
    supersession = bundle_transition["pending_post_supersession"]
    unpublished = supersession["unpublished_seed_identity"]
    require(all(unpublished != {
        "line_count": row["line_count"], "seed_digest": row["seed_digest"]
    } for row in bundle_identities),
            "CR-b.2b still accepts the unpublished CR-19-only seed")
    attribution = supersession["attribution_diff"]
    require(attribution["previous_lines"] == unpublished["line_count"] and
            attribution["current_lines"] == bundle_identities[0]["line_count"],
            "CR-b.2b attribution does not connect unpublished B to landed C")
    require(attribution["current_lines"] - attribution["previous_lines"] ==
            attribution["line_delta"] and
            attribution["insertions"] - attribution["deletions"] ==
            attribution["line_delta"],
            "CR-b.2b attribution line delta is inconsistent")
    # Patch 24.2q moves the seed again for str content equality, so the
    # collapsed CR-19 post-publication identity becomes this transition's
    # pre-publication identity. Registered here with the seed bytes in the
    # same patch because the movement is mechanical reconvergence of this
    # patch's own embedded literals, not a separate publication; the seed
    # bytes themselves ship in the seed-only commit, preserving attribution.
    strata_transition = record.get("phase24_2q_seed_transition")
    require(strata_transition == {
        "contract_version": "phase24_2q_str_equality_seed_reconvergence_transition_v1",
        "status": "ready_for_seed_publication",
        "predecessor_seed_authority": "phase24_cr19_bundle_validation_seed_reconvergence_transition_v1",
        "authority_base_main": "a92a8cac73854808d597d3e9e975389280311743",
        "accounted_compiler_authorities": [
            "phase24_2q_str_content_equality_v1"
        ],
        "accepted_live_seed_identities": [
            {
                "state": "pre_publication",
                "line_count": 65986,
                "seed_digest": "0bb8d3ccea011275366356baa07ee0619d13979fa00fc91ee97eb05718f27539"
            },
            {
                "state": "post_publication",
                "line_count": 65998,
                "seed_digest": "a1ba675a1c244af0a77485d48a5865833eee896a4a2b746ea5728e20f590eebb"
            }
        ],
        "generated_seed_diff": {
            "previous_lines": 65986,
            "current_lines": 65998,
            "insertions": 114,
            "deletions": 102,
            "line_delta": 12
        },
        "seed_pr_policy": "gust_v4_c_only",
        "partial_or_unregistered_identity": "rejected",
        "closure_transition": "collapse_to_post_publication_after_seed_merge"
    }, "Patch 24.2q seed transition drifted")
    strata_identities = strata_transition["accepted_live_seed_identities"]
    require([row["state"] for row in strata_identities] ==
            ["pre_publication", "post_publication"],
            "Patch 24.2q seed transition state order drifted")
    require(len({(row["line_count"], row["seed_digest"])
                 for row in strata_identities}) == 2,
            "Patch 24.2q seed transition identities are not distinct")
    require(strata_identities[0] == {
        "state": "pre_publication",
        "line_count": bundle_identities[0]["line_count"],
        "seed_digest": bundle_identities[0]["seed_digest"],
    }, "Patch 24.2q does not start from the landed CR-19 identity")
    strata_diff = strata_transition["generated_seed_diff"]
    require(strata_diff["current_lines"] - strata_diff["previous_lines"] ==
            strata_diff["line_delta"] and
            strata_diff["insertions"] - strata_diff["deletions"] ==
            strata_diff["line_delta"],
            "Patch 24.2q seed line delta is inconsistent")
    require(strata_diff["previous_lines"] == strata_identities[0]["line_count"] and
            strata_diff["current_lines"] == strata_identities[1]["line_count"],
            "Patch 24.2q seed diff does not match its exact pre/post identities")

    # Patch 24.13 continues the chain, for the reason every earlier link
    # continued it: the compiler changed, so the seed a bootstrap regenerates
    # is no longer the landed one.
    #
    # This link is the one that lets the four Makefile bootstrap callers move
    # off the retired spelling. The old seed's gust_bootstrap has only
    # mir-to-c, and the new seed's has only the bootstrap-only entry, so the
    # callers and the seed must land together -- the transition build runs
    # once, with the old callers against the old seed, and produces the seed
    # the new callers need.
    #
    # Verified rather than asserted: from a tree with gust_bootstrap,
    # stage1_compiler.c, stage1_bin and gust_compiler.c deleted, the migrated
    # callers bootstrap against this seed, the stage2/stage3 fixed point
    # holds, and the regenerated seed is this identity again. That last
    # property is what this guard demands -- a regeneration of the landed
    # identity to itself.
    removal_transition = record.get("phase24_13_seed_transition")
    if removal_transition is None:
        return strata_identities
    require(removal_transition == {
        "contract_version":
            "phase24_13_backend_removal_seed_reconvergence_transition_v1",
        "status": "ready_for_seed_publication",
        "predecessor_seed_authority":
            "phase24_2q_str_equality_seed_reconvergence_transition_v1",
        "authority_base_main":
            "890362268ac29401cda0d5847a8266df36fb53a3",
        "accounted_compiler_authorities": [
            "phase24_13_backend_removal_v1"
        ],
        "accepted_live_seed_identities": [
            {
                "state": "pre_publication",
                "line_count": 65998,
                "seed_digest":
                    "a1ba675a1c244af0a77485d48a5865833eee896a4a2b746ea5728e20f590eebb"
            },
            {
                "state": "post_publication",
                "line_count": 66007,
                "seed_digest":
                    "2144a8c0ba5c2babafd58dadc705750b4f3fc8be0304540535cc695e50e87074"
            }
        ],
        "generated_seed_diff": {
            "previous_lines": 65998,
            "current_lines": 66007,
            "insertions": 9,
            "deletions": 0,
            "line_delta": 9
        },
        "seed_pr_policy": "gust_v4_c_only",
        "partial_or_unregistered_identity": "rejected",
        "closure_transition": "collapse_to_post_publication_after_seed_merge"
    }, "Patch 24.13 seed transition drifted")
    removal_identities = removal_transition["accepted_live_seed_identities"]
    require([row["state"] for row in removal_identities] ==
            ["pre_publication", "post_publication"],
            "Patch 24.13 seed transition state order drifted")
    require(len({(row["line_count"], row["seed_digest"])
                 for row in removal_identities}) == 2,
            "Patch 24.13 seed transition identities are not distinct")
    require(removal_identities[0] == {
        "state": "pre_publication",
        "line_count": strata_identities[1]["line_count"],
        "seed_digest": strata_identities[1]["seed_digest"],
    }, "Patch 24.13 does not start from the landed Patch 24.2q identity")
    removal_diff = removal_transition["generated_seed_diff"]
    require(removal_diff["current_lines"] - removal_diff["previous_lines"] ==
            removal_diff["line_delta"] and
            removal_diff["insertions"] - removal_diff["deletions"] ==
            removal_diff["line_delta"],
            "Patch 24.13 seed line delta is inconsistent")
    require(removal_diff["previous_lines"] == removal_identities[0]["line_count"] and
            removal_diff["current_lines"] == removal_identities[1]["line_count"],
            "Patch 24.13 seed diff does not match its exact pre/post identities")

    # Issue #398 removes the retained explicit-C spellings from the compiler
    # entry and the help text, so the seed reconverges again. This is the
    # first link in this chain whose seed gets SMALLER -- the diff is four
    # lines in and nine out -- which is why the arithmetic below is stated as
    # an identity on the delta rather than as a growth check: a shrinking seed
    # is as registrable as a growing one, and neither may disagree with its
    # own pre/post line counts.
    spelling_transition = record.get("phase398_seed_transition")
    if spelling_transition is None:
        return removal_identities
    require(spelling_transition == {
            "accepted_live_seed_identities": [
                    {
                            "line_count": 66007,
                            "seed_digest": "2144a8c0ba5c2babafd58dadc705750b4f3fc8be0304540535cc695e50e87074",
                            "state": "pre_publication"
                    },
                    {
                            "line_count": 66002,
                            "seed_digest": "6e2f45f4276cb63e97902141088b50c2886a6de5132d5ad5384c9070b950bb6f",
                            "state": "post_publication"
                    }
            ],
            "accounted_compiler_authorities": [
                    "phase398_retained_spelling_removal"
            ],
            "authority_base_main": "498329bac1a245b3a6799f1aa112145c48e6e4ec",
            "closure_transition": "collapse_to_post_publication_after_seed_merge",
            "contract_version": "phase398_retained_spelling_removal_seed_reconvergence_transition_v1",
            "generated_seed_diff": {
                    "current_lines": 66002,
                    "deletions": 9,
                    "insertions": 4,
                    "line_delta": -5,
                    "previous_lines": 66007
            },
            "partial_or_unregistered_identity": "rejected",
            "predecessor_seed_authority": "phase24_13_backend_removal_seed_reconvergence_transition_v1",
            "seed_pr_policy": "gust_v4_c_only",
            "status": "ready_for_seed_publication"
    }, "Issue #398 seed transition drifted")
    spelling_identities = spelling_transition["accepted_live_seed_identities"]
    require([row["state"] for row in spelling_identities] ==
            ["pre_publication", "post_publication"],
            "Issue #398 seed transition state order drifted")
    require(len({(row["line_count"], row["seed_digest"])
                 for row in spelling_identities}) == 2,
            "Issue #398 seed transition identities are not distinct")
    require(spelling_identities[0] == {
        "state": "pre_publication",
        "line_count": removal_identities[1]["line_count"],
        "seed_digest": removal_identities[1]["seed_digest"],
    }, "Issue #398 does not start from the landed Patch 24.13 identity")
    # The named authority is a registry key rather than a bare string, so it
    # can be checked. Patch 24.13 registered "phase24_13_backend_removal_v1",
    # which appears nowhere else in the tree and therefore asserted nothing.
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    for name in spelling_transition["accounted_compiler_authorities"]:
        require(isinstance(registry.get(name), dict),
                "Issue #398 accounts a compiler authority that is not "
                f"registered: {name}")
    spelling_diff = spelling_transition["generated_seed_diff"]
    require(spelling_diff["current_lines"] - spelling_diff["previous_lines"] ==
            spelling_diff["line_delta"] and
            spelling_diff["insertions"] - spelling_diff["deletions"] ==
            spelling_diff["line_delta"],
            "Issue #398 seed line delta is inconsistent")
    require(spelling_diff["previous_lines"] ==
            spelling_identities[0]["line_count"] and
            spelling_diff["current_lines"] ==
            spelling_identities[1]["line_count"],
            "Issue #398 seed diff does not match its exact pre/post "
            "identities")
    # Patch 25.6 moves the seed again. Nothing about the compiler's meaning
    # changes: codegen stops inlining a printf/exit pair at 1,963 emission
    # sites and calls the runtime's gust_check_fail instead, which is why the
    # diff is 2,691 lines in and 2,691 out and the line count does not move
    # at all. A digest-only transition is still a transition -- the seed IS
    # different, and a guard that accepted it because the line count matched
    # would be checking the wrong half.
    fiber_transition = record.get("phase256_seed_transition")
    if fiber_transition is None:
        return spelling_identities
    require(fiber_transition == {
            "accepted_live_seed_identities": [
                    {
                            "line_count": 66002,
                            "seed_digest": "6e2f45f4276cb63e97902141088b50c2886a6de5132d5ad5384c9070b950bb6f",
                            "state": "pre_publication"
                    },
                    {
                            "line_count": 66002,
                            "seed_digest": "6992b00adc5790710fbad4689ab9408fdfe55c2500a50f11a557b741ad87725f",
                            "state": "post_publication"
                    }
            ],
            "accounted_compiler_authorities": [
                    "patch256_fiber_global_asm"
            ],
            "authority_base_main": "8acfc3f3e613b7305bf6d7e2d0b00ac55a202369",
            "closure_transition": "collapse_to_post_publication_after_seed_merge",
            "contract_version": "patch256_fiber_global_asm_seed_reconvergence_transition_v1",
            "generated_seed_diff": {
                    "current_lines": 66002,
                    "deletions": 2691,
                    "insertions": 2691,
                    "line_delta": 0,
                    "previous_lines": 66002
            },
            "partial_or_unregistered_identity": "rejected",
            "predecessor_seed_authority": "phase398_retained_spelling_removal_seed_reconvergence_transition_v1",
            "seed_pr_policy": "gust_v4_c_only",
            "status": "ready_for_seed_publication"
    }, "Patch 25.6 seed transition drifted")
    fiber_identities = fiber_transition["accepted_live_seed_identities"]
    require([row["state"] for row in fiber_identities] ==
            ["pre_publication", "post_publication"],
            "Patch 25.6 seed transition state order drifted")
    require(len({(row["line_count"], row["seed_digest"])
                 for row in fiber_identities}) == 2,
            "Patch 25.6 seed transition identities are not distinct")
    require(fiber_identities[0] == {
        "state": "pre_publication",
        "line_count": spelling_identities[1]["line_count"],
        "seed_digest": spelling_identities[1]["seed_digest"],
    }, "Patch 25.6 does not start from the landed Issue #398 identity")
    for name in fiber_transition["accounted_compiler_authorities"]:
        require(isinstance(registry.get(name), dict),
                "Patch 25.6 accounts a compiler authority that is not "
                f"registered: {name}")
    fiber_diff = fiber_transition["generated_seed_diff"]
    require(fiber_diff["current_lines"] - fiber_diff["previous_lines"] ==
            fiber_diff["line_delta"] and
            fiber_diff["insertions"] - fiber_diff["deletions"] ==
            fiber_diff["line_delta"],
            "Patch 25.6 seed line delta is inconsistent")
    require(fiber_diff["previous_lines"] == fiber_identities[0]["line_count"] and
            fiber_diff["current_lines"] == fiber_identities[1]["line_count"],
            "Patch 25.6 seed diff does not match its exact pre/post identities")
    # Patch 25.5 moves it again, and this one grows: measured against the
    # authority base, 5,082 lines in and 2,700 out, +2,382 to 68,384. Six
    # runtime C files stop being compiled into the unity build and nine
    # strings.c functions are emitted from Gust, so the seed carries emitted
    # code it did not carry before. The last +9 of that is the built-in
    # struct suppression: a unit with no `main` no longer receives
    # APIRequest and SessionNode, and the seed carries the codegen change
    # that decides it.
    port_transition = record.get("phase255_seed_transition")
    if port_transition is None:
        return fiber_identities
    require(port_transition == {
            "accepted_live_seed_identities": [
                    {
                            "line_count": 66002,
                            "seed_digest": "6992b00adc5790710fbad4689ab9408fdfe55c2500a50f11a557b741ad87725f",
                            "state": "pre_publication"
                    },
                    {
                            "line_count": 68384,
                            "seed_digest": "9b26b95c42ede32dcc6a248a183ed558f238e1f23f7bf906f2a59487a7236933",
                            "state": "post_publication"
                    }
            ],
            "accounted_compiler_authorities": [
                    "phase255_runtime_to_gust"
            ],
            "authority_base_main": "8acfc3f3e613b7305bf6d7e2d0b00ac55a202369",
            "closure_transition": "collapse_to_post_publication_after_seed_merge",
            "contract_version": "phase255_runtime_to_gust_seed_reconvergence_transition_v1",
            "generated_seed_diff": {
                    "current_lines": 68384,
                    "deletions": 2700,
                    "insertions": 5082,
                    "line_delta": 2382,
                    "previous_lines": 66002
            },
            "partial_or_unregistered_identity": "rejected",
            "predecessor_seed_authority": "patch256_fiber_global_asm_seed_reconvergence_transition_v1",
            "seed_pr_policy": "gust_v4_c_only",
            "status": "ready_for_seed_publication"
    }, "Patch 25.5 seed transition drifted")
    port_identities = port_transition["accepted_live_seed_identities"]
    require([row["state"] for row in port_identities] ==
            ["pre_publication", "post_publication"],
            "Patch 25.5 seed transition state order drifted")
    require(len({(row["line_count"], row["seed_digest"])
                 for row in port_identities}) == 2,
            "Patch 25.5 seed transition identities are not distinct")
    require(port_identities[0] == {
        "state": "pre_publication",
        "line_count": fiber_identities[1]["line_count"],
        "seed_digest": fiber_identities[1]["seed_digest"],
    }, "Patch 25.5 does not start from the landed Patch 25.6 identity")
    for name in port_transition["accounted_compiler_authorities"]:
        require(isinstance(registry.get(name), dict),
                "Patch 25.5 accounts a compiler authority that is not "
                f"registered: {name}")
    port_diff = port_transition["generated_seed_diff"]
    require(port_diff["current_lines"] - port_diff["previous_lines"] ==
            port_diff["line_delta"] and
            port_diff["insertions"] - port_diff["deletions"] ==
            port_diff["line_delta"],
            "Patch 25.5 seed line delta is inconsistent")
    require(port_diff["previous_lines"] == port_identities[0]["line_count"] and
            port_diff["current_lines"] == port_identities[1]["line_count"],
            "Patch 25.5 seed diff does not match its exact pre/post identities")
    return port_identities


def published_seed_identity(record: dict) -> dict:
    """The identity of the seed Patch 25.9 deleted, taken from the release.

    TEN separate guards read `gust_v4.c` to ask the same question -- "is the
    committed seed still the one the chain registered?" -- and deleting the
    file makes every one of them raise FileNotFoundError, not fail with a
    diagnosis. Inverting them one at a time produced ten chances to write
    ten slightly different replacement claims, so they share this instead.

    The claim does not become vacuous when the file goes; it MOVES. Release 0
    publishes those exact bytes as a `source_seed`, so "the committed seed is
    current" becomes "the chain's last registered identity is the one that
    was published". The published digest selects the registry row; the row
    supplies the line count. Reading both out of the registry would have the
    registry agreeing with itself, and reading both out of the manifest would
    drop the chain entirely -- crossing them is the point, and the artifact
    is downloadable, so the pair stays checkable from outside this tree.
    """
    return select_published_identity(accepted_live_seed_identities(record))


def published_source_seeds() -> dict[str, int]:
    """Published `source_seed` artifacts as digest -> line count."""
    manifest = json.loads(
        (ROOT / "docs/RELEASE_MANIFEST.json").read_text(encoding="utf-8"))
    return {entry["digest"]: entry.get("lines")
            for release in manifest.get("releases", [])
            for entry in release.get("artifacts", [])
            if entry.get("role") == "source_seed"}


def select_published_identity(identities: list[dict]) -> dict:
    """Pick the one registered identity release 0 published, by digest.

    Split out from published_seed_identity because the registry is read two
    incompatible ways: this module resolves a chain of transitions from one
    node, while `phase24_cr15_closure` has its own same-named resolver over
    a closed tuple of transition keys. They must not share a resolver -- the
    closed tuple is deliberately un-wideable -- but they must share THIS,
    or the "which bytes were the seed" answer forks in two.
    """
    published = published_source_seeds()
    require(published,
            "gust_v4.c is deleted and no release publishes it as a "
            "`source_seed`, so its registered identity answers to nothing. "
            "Absence is only half of an inverted assertion; the replacement "
            "record has to be there too.")
    rows = [row for row in identities if row["seed_digest"] in published]
    require(len(rows) == 1,
            f"{len(rows)} registered seed identities match a published "
            "`source_seed` digest, so the registry chain and the release "
            "disagree about which bytes were the last seed.")
    row = rows[0]
    # Both halves, from both records. Selecting the row by digest and then
    # returning the row's own line count would leave the count checked by
    # nothing -- the registry would be its own witness for half the
    # identity. The manifest publishes the count too, so the two records
    # have to agree before either is used.
    require(published[row["seed_digest"]] == row["line_count"],
            f"the published `source_seed` records "
            f"{published[row['seed_digest']]} lines but the registry "
            f"identity for the same digest records {row['line_count']}. "
            "One of the two was edited without the other.")
    return {"line_count": row["line_count"],
            "seed_digest": row["seed_digest"]}


def published_seed_line_count(record: dict) -> int:
    return published_seed_identity(record)["line_count"]


def accepted_live_seed_line_counts(record: dict) -> set[int]:
    return {row["line_count"] for row in accepted_live_seed_identities(record)}


def accepted_live_seed_line_count(record: dict, actual_line_count: int) -> int:
    require(actual_line_count in accepted_live_seed_line_counts(record),
            "committed seed line count is outside the exact registered seed transition")
    return actual_line_count


def live_seed_identity_is_accepted(record: dict, line_count: int, seed_digest: str) -> bool:
    return any({"line_count": line_count, "seed_digest": seed_digest} == {
        "line_count": row["line_count"], "seed_digest": row["seed_digest"],
    } for row in accepted_live_seed_identities(record))


def seed_identity(seed_bytes: bytes) -> dict:
    return {
        "line_count": len(seed_bytes.decode("utf-8").splitlines()),
        "seed_digest": hashlib.sha256(seed_bytes).hexdigest(),
    }


def regeneration_is_accepted(record: dict, committed: dict, regenerated: dict) -> bool:
    identities = {
        row["state"]: {
            "line_count": row["line_count"],
            "seed_digest": row["seed_digest"],
        }
        for row in accepted_live_seed_identities(record)
    }
    # Collapsed: the publication landed, so only the landed identity remains
    # and only a regeneration of that identity to itself is accepted. Any
    # other pairing - including the retired pre-publication seed - rejects.
    return (
        committed == identities["post_publication"] and
        regenerated == identities["post_publication"]
    )


def validate_regeneration(record: dict) -> None:
    # Patch 25.9: there is no committed seed to regenerate. This compared
    # HEAD's gust_v4.c against the rebuilt one and required the bootstrap
    # to reproduce it exactly. With the file deleted the check INVERTS: the
    # bootstrap must NOT produce one. A rebuilt seed appearing in the tree
    # means the republish route came back, and the next commit would carry
    # 66,002 lines nobody asked for.
    if not SEED.exists():
        require(not SEED.exists(),
                "gust_v4.c was regenerated by the bootstrap. Patch 25.9 "
                "removed the copy of stage 3 output over the seed; if it is "
                "back, that line is back.")
        return
    committed_seed = subprocess.check_output(
        ["git", "show", "HEAD:gust_v4.c"], cwd=ROOT,
    )
    committed = seed_identity(committed_seed)
    regenerated = seed_identity(SEED.read_bytes())
    require(regeneration_is_accepted(record, committed, regenerated),
            "bootstrap result is not the exact landed post-publication fixed point")


def validate() -> dict:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    prior_seed = registry.get("phase21_native_feature_seed_convergence", {})
    require(prior_seed.get("contract_version") ==
            "phase21_native_feature_seed_convergence_v1",
            "predecessor seed authority drifted")
    flip = registry.get("phase22_default_route_flip", {})
    require(flip.get("contract_version") == "phase22_default_route_flip_v1" and
            flip.get("status") == "implementation_complete",
            "accounted Patch 22.6 authority drifted")

    record = registry.get("phase22_default_route_seed_convergence")
    require(isinstance(record, dict), "Patch 22.6a authority is missing")
    expected = {
        "contract_version": "phase22_default_route_seed_convergence_v1",
        "status": "patch22_6a_complete",
        "next_patch": "22.7",
        "review_view": "compiler/CRANELIFT_PHASE22_DEFAULT_ROUTE_SEED_CONVERGENCE.md",
        "observed_main_sha": "e521f4f660acf59aff7e07f79a9567c73ffb0b2b",
        "seed_path": "gust_v4.c",
        "predecessor_seed_authority": "phase21_native_feature_seed_convergence_v1",
        "accounted_authority": "phase22_default_route_flip_v1",
        "previous_seed_commit": "ec60ea2b496681b5c60d702d1f1cb46fdab8982c",
        "previous_seed_digest": "58006d413edcf55bf0c89e04a2cd7cadb547c1325000cdb07bc117d45822e9e1",
        "converged_seed_digest": "c2e2cd6d5043af87aacc007d92b105d673bbeea7e8f484a61e18126f39a32383",
        "fixed_point_policy": "make_bootstrap_stage2_stage3_byte_identity",
        "seed_only_policy": "generated_seed_and_seed_specific_authority_only",
        "bootstrap_route": "explicit_mir_to_c",
    }
    for key, value in expected.items():
        require(record.get(key) == value, f"{key} drifted")

    require(record.get("seed_help_contract") == {
        "default_backend": "cranelift",
        "explicit_c_role": "retained_semantic_oracle",
        "fallback": "forbidden",
    }, "seed help contract drifted")
    handoff_validators = [
        "scripts/phase19_seed_convergence.py",
        "scripts/phase20_seed_convergence.py",
        "scripts/phase20_post_prerequisite_seed_convergence.py",
        "scripts/phase20_protected_access_seed_convergence.py",
        "scripts/phase21_tenant_scope_seed_convergence.py",
        "scripts/phase21_native_feature_seed_convergence.py",
    ]
    require(record.get("successor_handoff_validators") == handoff_validators,
            "historical seed successor-handoff inventory drifted")
    for relative in handoff_validators:
        require("phase22_default_route_seed_convergence" in
                (ROOT / relative).read_text(encoding="utf-8"),
                f"historical seed validator lacks Patch 22.6a handoff: {relative}")
    diff = record.get("generated_seed_diff")
    require(diff == {
        "previous_lines": 62917,
        "current_lines": 64825,
        "insertions": 2094,
        "deletions": 186,
        "line_delta": 1908,
    }, "generated seed diff accounting drifted")
    require(diff["current_lines"] - diff["previous_lines"] == diff["line_delta"] and
            diff["insertions"] - diff["deletions"] == diff["line_delta"],
            "generated seed line delta is inconsistent")
    require(record.get("boundary") == {
        "adds_or_changes_Gust_semantics": False,
        "adds_or_changes_MIR_or_native_lowering": False,
        "changes_ABI_layout_runtime_symbols_target_or_linker": False,
        "changes_default_backend_or_bootstrap_route": False,
        "changes_bootstrap_seed": True,
        "edits_stdlib_or_CR15": False,
        "begins_patch22_7": False,
    }, "Patch 22.6a widened beyond seed reconvergence")

    # Patch 25.9: the seed is gone, so its identity comes from the artifact
    # that carries the same bytes -- release 0 publishes it as a
    # `source_seed`. The line count is the chain's own final record; the
    # digest is the published one, which keeps the assertion tied to
    # something real rather than to a number copied forward.
    if SEED.exists():
        seed_bytes = SEED.read_bytes()
        seed_text = seed_bytes.decode("utf-8")
        live_seed_identity = seed_identity(seed_bytes)
        require(live_seed_identity_is_accepted(
            record, live_seed_identity["line_count"], live_seed_identity["seed_digest"]),
                "committed seed is not the exact landed post-publication identity")
    else:
        manifest = json.loads(
            (ROOT / "docs/RELEASE_MANIFEST.json").read_text(encoding="utf-8"))
        published = [entry
                     for release in manifest.get("releases", [])
                     for entry in release.get("artifacts", [])
                     if entry.get("role") == "source_seed"]
        require(published,
                "the seed is deleted and no release publishes it as a "
                "source_seed, so its landed identity cannot be checked "
                "against anything")
        accepted = accepted_live_seed_identities(record)
        matched = [row for row in accepted
                   if row["seed_digest"] == published[-1]["digest"]]
        require(matched,
                "the published source_seed digest is not one of the landed "
                "identities this chain registered. The release and the "
                "registry disagree about what the seed was at cut-over.")
        # The selection below keys on the identity; it now comes from the
        # registered row the PUBLISHED artifact matches, so the release is
        # what picks the state rather than a file that no longer exists.
        live_seed_identity = {"line_count": matched[-1]["line_count"],
                              "seed_digest": matched[-1]["seed_digest"]}
        # The help contract moves with the claim, not with the file: it was
        # always about what the COMPILER advertises, and the seed was the
        # emitted proxy for it.
        seed_text = "\n".join(
            path.read_text(encoding="utf-8", errors="replace")
            for path in sorted((ROOT / "compiler").glob("*.gst")))
    help_fragments = [
        "cranelift  Compile to one native executable (default).",
        "fallback to MIR-to-C.",
    ]
    absent_help_fragments: list[str] = []
    if live_seed_identity["seed_digest"] == "33b23ff4e8dab6c84365920bf3a2a674d7e3f5248646f6ffd69c8f7cc014083a":
        help_fragments.append(
            "mir-to-c, c  Emit C source to stdout (retained semantic oracle).")
    elif live_seed_identity in [
            {key: value for key, value in
             record[transition]["accepted_live_seed_identities"][1].items()
             if key != "state"}
            for transition in
            ("phase398_seed_transition", "phase256_seed_transition",
             "phase255_seed_transition")
            if record.get(transition) is not None]:
        # Issue #398's era. This seed is compiled from an entry that REMOVED
        # the retained spellings, so its help cannot advertise them.
        #
        # Patch 25.6's seed is in the same era and is listed alongside it,
        # rather than the era being widened to "any seed after #398". 25.6
        # changes what the emitter INLINES at 1,963 abort sites and nothing
        # about the entry, so its help text is the same text -- and saying
        # that by naming the identity keeps the check on the seed in front
        # of it. A membership test over registered identities also means
        # the next seed-moving patch must add itself here, which is the
        # point: Patch 24.13 wrote an era for a seed it did not have and
        # had to withdraw it.
        #
        # Patch 24.13 wrote an era here for exactly this seed and then had to
        # withdraw it, because the removal was deferred and its seed went on
        # advertising the deprecation wording after all. The era is restored
        # now that the removal actually lands, and gated on the seed IDENTITY
        # rather than on a patch being registered -- so it describes the seed
        # in front of it rather than an intention recorded elsewhere.
        #
        # Both halves are asserted. The deprecation wording must be GONE from
        # the seed, and the rejection that replaces it must be in it. Dropping
        # the first clause would let a seed that still advertises the removed
        # backend pass as long as it also mentions the rejection.
        help_fragments.extend([
            "The generated-C backend was REMOVED in Phase 24; mir-to-c and c are rejected.",
            "the generated-C backend was removed in Phase 24: ",
            "Bootstrap C retirement is separate and deferred to Phase 25.",
        ])
        absent_help_fragments.extend([
            "mir-to-c, c  DEPRECATED: Emit C source to stdout (retained semantic oracle); backend removal is Phase 24.",
            "gust --backend mir-to-c <source.gst>",
            "--backend <mir-to-c|c|cranelift>",
        ])
    else:
        help_fragments.extend([
            "mir-to-c, c  DEPRECATED: Emit C source to stdout (retained semantic oracle); backend removal is Phase 24.",
            "Bootstrap C retirement is separate and deferred to Phase 25.",
        ])
    for help_fragment in help_fragments:
        require(help_fragment in seed_text,
                f"regenerated seed lacks help contract fragment: {help_fragment}")
    for help_fragment in absent_help_fragments:
        require(help_fragment not in seed_text,
                "the regenerated seed still carries a help contract fragment "
                f"Issue #398 removed: {help_fragment}")
    require("- [x] Patch 22.6a — Default-Route Bootstrap Seed Reconvergence — DONE"
            in TASK.read_text(encoding="utf-8"),
            "TASK.md does not mark Patch 22.6a DONE")

    makefile = MAKEFILE.read_text(encoding="utf-8")
    # Patch 22.6a pinned four bootstrap rows as explicit C. Patch 24.13 moves
    # ALL FOUR to the bootstrap-only entry.
    #
    # An earlier version of this patch moved two and left the other two pinned
    # as explicit C, on the reasoning that gust_bootstrap and gust_stage1_bin
    # are compiled from a pre-removal seed and legitimately still have the
    # backend. That described a transitional state correctly and drew the
    # wrong conclusion from it: once the seed reconverges -- which this patch
    # does, because it changes the compiler -- those binaries are 24.13
    # compilers and the spelling they were pinned to no longer exists.
    #
    # Measured, not argued: with the republished seed and the old callers, the
    # second bootstrap fails at Makefile:51 with "the generated-C backend was
    # removed in Phase 24: mir-to-c". With all four moved, a tree whose
    # gust_bootstrap, stage1_compiler.c, stage1_bin and gust_compiler.c are
    # deleted bootstraps cleanly, the fixed point holds, and the regenerated
    # seed is the registered identity again.
    #
    # Every row is INVERTED, not dropped. A deleted clause says nothing: it
    # would pass just as well if a row silently went back to mir-to-c, or
    # vanished from the Makefile entirely. Each asserts both halves -- the
    # retired spelling absent AND the replacement present.
    # Scoped to lines make can execute. The Makefile keeps a comment block
    # recording the four-step chain 25.10 removed and why the native route
    # replaces it; prose quoting a retired spelling is not an invocation of it.
    executable = "\n".join(line for line in makefile.splitlines()
                           if not line.lstrip().startswith("#"))
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
                "Patch 24.13 removed generated-C backend selection, so this "
                f"bootstrap row cannot select it again: {retired}")
        # Patch 25.10 deletes the C stage chain, so all four rebased callers
        # go with the rules that ran them. THIRD copy of this assertion in the
        # tree -- phase22_default_route_flip and phase22_postflip_qualification
        # carry the other two -- and all three flip the same way: both
        # spellings absent, and the ONE native compile that replaced the whole
        # chain present. A tree that deleted the chain and put nothing in its
        # place fails, which is the "vanished passing as migrated" case.
        require(rebased not in executable,
                "a bootstrap caller still drives the seed through the emitter "
                f"Patch 25.10 deleted: {rebased}")
    require(NATIVE_SEED_STEP in executable,
            "the seed path does not reach the compiler through the native "
            f"route: {NATIVE_SEED_STEP}")

    workflow = WORKFLOW.read_text(encoding="utf-8")
    for evidence in (
        "compiler/CRANELIFT_PHASE22_DEFAULT_ROUTE_SEED_CONVERGENCE.md",
        "scripts/phase22_default_route_seed_convergence.py",
        f"just {GUARD}",
    ):
        require(evidence in workflow,
                f"authoritative seed workflow lacks {evidence}")
    # Patch 25.9: same inversion as phase19's copy of this list. The third
    # command asserted the regenerated seed matched the committed one; with
    # no committed seed it passes on a path git does not know, so the
    # workflow is required to carry the absence check instead. TWO guards
    # pinned this same command text -- a harness reference has as many
    # owners as there are guards naming it, and missing one leaves the pair
    # disagreeing about what the workflow should say.
    # Patch 25.10 retires the C fixed point. `cmp build/gust_stage2.c
    # build/gust_stage3.c` compares two files the emitter emitted; with no
    # emitter they are never written, so it fails on missing operands rather
    # than on divergence. FOUR scripts pin this command into the workflow and
    # all four move together -- they were found by enumerating
    # `grep -rln "gust_stage2.c build/gust_stage3.c" scripts/*.py`, after two
    # of them were found one at a time from CI error text and the third
    # turned out to word its message differently.
    for command in (
        "make bootstrap",
        "if [ -e gust_v4.c ]; then",
        "git ls-files --error-unmatch gust_v4.c",
    ):
        require(command in workflow,
                f"authoritative fixed-point workflow lacks {command}")
    require("cmp build/gust_stage2.c build/gust_stage3.c" not in workflow,
            "the fixed-point workflow still compares stage-two and "
            "stage-three C, which Patch 25.10 retired with the emitter")
    require("for stale in build/gust_stage2.c build/gust_stage3.c" in workflow,
            "the fixed-point workflow dropped the C stage comparison without "
            "asserting the stages are gone")
    require("git diff --exit-code -- gust_v4.c" not in workflow,
            "the authoritative fixed-point workflow still runs `git diff "
            "--exit-code -- gust_v4.c`, which cannot fail now that the seed "
            "is deleted")
    require(f"just {GUARD}" in PR_FAST.read_text(encoding="utf-8"),
            "PR Fast does not own the Patch 22.6a Level 1 guard")
    require(f"{GUARD}:" in JUSTFILE.read_text(encoding="utf-8"),
            "Patch 22.6a just guard is missing")
    require(
        "- [x] Patch 23.6a — Diagnostic Bootstrap Seed Reconvergence — DONE"
        in TASK.read_text(encoding="utf-8"),
        "TASK.md does not formally close Patch 23.6a",
    )
    require(
        "- [x] Patch 23.8a — Deprecation Bootstrap Seed Reconvergence — DONE"
        in TASK.read_text(encoding="utf-8"),
        "TASK.md does not formally close Patch 23.8a",
    )
    return record


def render(record: dict) -> str:
    diff = record["generated_seed_diff"]
    transition = record["phase23_successor_transition"]
    landed = transition["landed_seed_evidence"]
    deprecation = record["phase23_deprecation_seed_transition"]
    deprecation_diff = deprecation["generated_seed_diff"]
    deprecation_landed = deprecation["landed_seed_evidence"]
    cr15_transition = record["phase24_cr15_seed_transition"]
    cr15_diff = cr15_transition["generated_seed_diff"]
    return "\n".join([
        "# Cranelift Phase 22 Default-Route Seed Convergence",
        "",
        "Generated from `scripts/cranelift_feature_registry.json` by",
        "`scripts/phase22_default_route_seed_convergence.py project`. Do not edit by hand.",
        "",
        f"- Contract: `{record['contract_version']}`",
        f"- Status: `{record['status']}`",
        f"- Next patch: `{record['next_patch']}`",
        f"- Accounted authority: `{record['accounted_authority']}`",
        f"- Observed main: `{record['observed_main_sha']}`",
        f"- Previous seed commit: `{record['previous_seed_commit']}`",
        f"- Previous seed digest: `{record['previous_seed_digest']}`",
        f"- Converged seed digest: `{record['converged_seed_digest']}`",
        f"- Fixed-point policy: `{record['fixed_point_policy']}`",
        f"- Bootstrap route: `{record['bootstrap_route']}`",
        f"- Seed-only policy: `{record['seed_only_policy']}`",
        "",
        "## Historical validator handoff",
        "",
    ] + [
        f"- `{path}`" for path in record["successor_handoff_validators"]
    ] + [
        "",
        "## Generated seed diff",
        "",
        f"- Previous lines: {diff['previous_lines']}",
        f"- Current lines: {diff['current_lines']}",
        f"- Insertions: {diff['insertions']}",
        f"- Deletions: {diff['deletions']}",
        f"- Net line delta: {diff['line_delta']}",
        "",
        "## Phase 23 successor transition",
        "",
        f"- Contract: `{transition['contract_version']}`",
        f"- Status: `{transition['status']}`",
        f"- Authority base main: `{transition['authority_base_main']}`",
        f"- Accounted compiler authorities: `{', '.join(transition['accounted_compiler_authorities'])}`",
        f"- Seed PR policy: `{transition['seed_pr_policy']}`",
        f"- Partial or unregistered identity: `{transition['partial_or_unregistered_identity']}`",
    ] + [
        f"- Accepted `{row['state']}` identity: {row['line_count']} lines, `{row['seed_digest']}`"
        for row in transition["accepted_live_seed_identities"]
    ] + [
        "",
        "## Phase 23 landed seed evidence",
        "",
        f"- Pull request: `#{landed['pull_request']}`",
        f"- Exact head: `{landed['head_sha']}`",
        f"- Merge main: `{landed['merge_main_sha']}`",
        f"- Merged at: `{landed['merged_at']}`",
        f"- Event: `{landed['event']}`",
        f"- Exact-head workflows: {landed['successful_workflows']}/{landed['workflow_population']} successful, {landed['unfinished_workflows']} unfinished, {landed['non_success_workflows']} non-success",
        f"- Unresolved non-outdated review threads: {landed['unresolved_non_outdated_review_threads']}",
        f"- Changed paths: `{', '.join(landed['changed_paths'])}`",
        "",
        "## Phase 23 deprecation seed transition",
        "",
        f"- Contract: `{deprecation['contract_version']}`",
        f"- Status: `{deprecation['status']}`",
        f"- Authority base main: `{deprecation['authority_base_main']}`",
        f"- Accounted compiler authority: `{deprecation['accounted_compiler_authority']}`",
        f"- Seed PR policy: `{deprecation['seed_pr_policy']}`",
        f"- Partial or unregistered identity: `{deprecation['partial_or_unregistered_identity']}`",
        f"- Generated diff: {deprecation_diff['insertions']} insertions, {deprecation_diff['deletions']} deletions, {deprecation_diff['line_delta']} net lines",
    ] + [
        f"- Accepted `{row['state']}` identity: {row['line_count']} lines, `{row['seed_digest']}`"
        for row in deprecation["accepted_live_seed_identities"]
    ] + [
        "",
        "## Phase 23 deprecation landed seed evidence",
        "",
        f"- Pull request: `#{deprecation_landed['pull_request']}`",
        f"- Exact head: `{deprecation_landed['head_sha']}`",
        f"- Merge main: `{deprecation_landed['merge_main_sha']}`",
        f"- Merged at: `{deprecation_landed['merged_at']}`",
        f"- Event: `{deprecation_landed['event']}`",
        f"- Exact-head workflows: {deprecation_landed['successful_workflows']}/{deprecation_landed['workflow_population']} successful, {deprecation_landed['unfinished_workflows']} unfinished, {deprecation_landed['non_success_workflows']} non-success",
        f"- Unresolved non-outdated review threads: {deprecation_landed['unresolved_non_outdated_review_threads']}",
        f"- Changed paths: `{', '.join(deprecation_landed['changed_paths'])}`",
        "",
        "## Phase 24 CR-15 seed transition",
        "",
        f"- Contract: `{cr15_transition['contract_version']}`",
        f"- Status: `{cr15_transition['status']}`",
        f"- Authority base main: `{cr15_transition['authority_base_main']}`",
        f"- Accounted compiler authorities: `{', '.join(cr15_transition['accounted_compiler_authorities'])}`",
        f"- Seed PR policy: `{cr15_transition['seed_pr_policy']}`",
        f"- Partial or unregistered identity: `{cr15_transition['partial_or_unregistered_identity']}`",
        f"- Generated diff: {cr15_diff['insertions']} insertions, {cr15_diff['deletions']} deletions, {cr15_diff['line_delta']} net lines",
    ] + [
        f"- Accepted `{row['state']}` identity: {row['line_count']} lines, `{row['seed_digest']}`"
        for row in cr15_transition["accepted_live_seed_identities"]
    ] + [
        "",
        "The regenerated seed preserves the final Patch 22.6 default-route compiler",
        "sources and serializes the registered Patch 23.3a guard/defer admission and",
        "Patch 23.6 same-scope diagnostic authorities. Stage 2 and stage 3 are",
        "byte-identical through explicit MIR-to-C. A",
        "compiler rebuilt directly from this seed reports Cranelift as the",
        "default, identifies both explicit C spellings as the retained semantic",
        "oracle, and promises no fallback. This patch adds no Gust semantics,",
        "MIR or native lowering, ABI/layout/runtime symbol, default-route or",
        "bootstrap-route change, Stdlib or CR-15 work, and does not begin 22.7.",
        "",
    ])


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "command",
        choices=("validate", "project", "check-review", "check-regeneration"),
    )
    args = parser.parse_args()
    record = validate()
    if args.command == "project":
        REVIEW.write_text(render(record), encoding="utf-8")
    elif args.command == "check-review":
        require(REVIEW.is_file() and REVIEW.read_text(encoding="utf-8") == render(record),
                "generated review is stale; run project")
    elif args.command == "check-regeneration":
        validate_regeneration(record)
    print(f"{GUARD}: ok")


if __name__ == "__main__":
    main()
