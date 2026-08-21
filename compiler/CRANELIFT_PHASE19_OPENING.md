# Cranelift Phase 19 Opening Inventory

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase19_opening.py project`. Do not edit by hand.

- Opening version: `phase19_opening_inventory_rebased_on_phase18_closure`
- Inventory version: `phase19_opening_inventory_self_hosted_v2`
- Status: `ready_for_patch19_1`
- Predecessor closure: `phase18_closed_target_object_and_linker_boundary`
- Opening rows: `3`
- Host assumptions: `5`
- Brand vocabularies: `2`
- Inherited residuals rebased: `1`
- Compiler scope: `self_hosted` (the deprecated root Rust prototype is retiring)

## Opening rows

| ID | Feature family | CI family | Source requirement | Status |
| --- | --- | --- | --- | --- |
| `p19_brand_identity` | brand_identity | brand-identity | TASK_STDLIB.md CR-2 | candidate_deferred |
| `p19_container_arena_classification` | brand_identity | brand-identity | docs/SHARED_SEMANTIC_ZONE.md D-1 | candidate_deferred |
| `p19_argument_representation` | value_representation | value-representation | docs/SHARED_SEMANTIC_ZONE.md D-2 | candidate_deferred |

## Brand vocabularies

Every list the self-hosted compiler consults to decide brand identity
from a spelling. The compiler scans first-match-wins and restarts until
stable, so the order of a list is part of its behaviour, not presentation.

| ID | Compiler | Source | Names |
| --- | --- | --- | --- |
| `gust_erasure_bases` | self_hosted | `compiler/codegen.gst:658` | `connCtx`, `arena`, `Any`, `a`, `main_ctx`, `bg_ctx`, `file_ctx`, `ctx` |
| `gust_suffix_brands` | self_hosted | `compiler/typechecker.gst:5172` | `ctx`, `connCtx`, `arena`, `a`, `Any`, `ctx1`, `ctx2`, `innerCtx`, `outerCtx`, `current_ctx`, `next_ctx`, `main_ctx`, `bg_ctx`, `file_ctx` |

## Host assumptions

| ID | Reachability area | Owning row | Source | Classification |
| --- | --- | --- | --- | --- |
| `ha_gust_codegen_erasure` | brand_resolution | `p19_brand_identity` | `compiler/codegen.gst` | must_change |
| `ha_gust_alloc_spelling` | container_classification | `p19_container_arena_classification` | `compiler/codegen.gst` | must_change |
| `ha_gust_typechecker_brands` | type_naming | `p19_brand_identity` | `compiler/typechecker.gst` | must_change |
| `ha_gust_default_brand` | brand_resolution | `p19_brand_identity` | `compiler/typechecker.gst` | must_change |
| `ha_seed_encodes_behaviour` | argument_representation | `p19_argument_representation` | `gust_v4.c` | must_change |

## Inherited residual rebase

| Source residual | Origin | Disposition | Selected rows |
| --- | --- | --- | --- |
| `p18_target_authority` | phase18_closure | not_selected | — |
