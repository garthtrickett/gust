# Cranelift Phase 19 Opening Inventory

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase19_opening.py project`. Do not edit by hand.

- Opening version: `phase19_opening_inventory_rebased_on_phase18_closure`
- Inventory version: `phase19_opening_inventory_v1`
- Status: `ready_for_patch19_1`
- Predecessor closure: `phase18_closed_target_object_and_linker_boundary`
- Opening rows: `3`
- Host assumptions: `11`
- Brand vocabularies: `5`
- Inherited residuals rebased: `1`

## Opening rows

| ID | Feature family | CI family | Source requirement | Status |
| --- | --- | --- | --- | --- |
| `p19_brand_identity` | brand_identity | brand-identity | TASK_STDLIB.md CR-2 | candidate_deferred |
| `p19_container_arena_classification` | brand_identity | brand-identity | docs/SHARED_SEMANTIC_ZONE.md D-1 | candidate_deferred |
| `p19_argument_representation` | value_representation | value-representation | docs/SHARED_SEMANTIC_ZONE.md D-2 | candidate_deferred |

## Brand vocabularies

Every list a compiler consults to decide brand identity from a spelling.
Both compilers scan first-match-wins and restart until stable, so the
order of a list is part of its behaviour, not presentation.

| ID | Compiler | Source | Names |
| --- | --- | --- | --- |
| `rust_erasure_bases` | rust_host | `src/codegen.rs:71` | `connCtx`, `arena`, `ctx`, `Any`, `a`, `main_ctx`, `bg_ctx`, `file_ctx` |
| `rust_type_bases` | rust_host | `src/typechecker/types.rs:61` | `connCtx`, `arena`, `ctx`, `Any`, `a`, `main_ctx`, `bg_ctx`, `file_ctx` |
| `rust_suffix_brands` | rust_host | `src/typechecker/types.rs:439` | `ctx`, `connCtx`, `arena`, `a`, `Any`, `ctx1`, `ctx2`, `innerCtx`, `outerCtx`, `current_ctx`, `next_ctx`, `main_ctx`, `bg_ctx`, `file_ctx` |
| `gust_erasure_bases` | self_hosted | `compiler/codegen.gst:658` | `connCtx`, `arena`, `Any`, `a`, `main_ctx`, `bg_ctx`, `file_ctx`, `ctx` |
| `gust_suffix_brands` | self_hosted | `compiler/typechecker.gst:5172` | `ctx`, `connCtx`, `arena`, `a`, `Any`, `ctx1`, `ctx2`, `innerCtx`, `outerCtx`, `current_ctx`, `next_ctx`, `main_ctx`, `bg_ctx`, `file_ctx` |

### Cross-compiler order divergence

| Rust host | Self-hosted | Divergence |
| --- | --- | --- |
| `rust_erasure_bases` | `gust_erasure_bases` | same set, different scan order |
| `rust_type_bases` | `gust_erasure_bases` | same set, different scan order |

Whether each divergence is observable is Patch 19.1's question.
This inventory records only that the two compilers can disagree.

## Host assumptions

| ID | Reachability area | Owning row | Source | Classification |
| --- | --- | --- | --- | --- |
| `ha_rust_codegen_erasure` | brand_resolution | `p19_brand_identity` | `src/codegen.rs` | must_change |
| `ha_rust_alloc_spelling` | container_classification | `p19_container_arena_classification` | `src/codegen.rs` | must_change |
| `ha_rust_type_brand_bases` | type_naming | `p19_brand_identity` | `src/typechecker/types.rs` | must_change |
| `ha_rust_parser_brand_name` | type_naming | `p19_brand_identity` | `src/parser.rs` | must_change |
| `ha_rust_monomorphize_generic_name` | argument_representation | `p19_argument_representation` | `src/typechecker/monomorphize.rs` | must_change |
| `ha_rust_typechecker_clean_part` | brand_resolution | `p19_brand_identity` | `src/typechecker.rs` | must_change |
| `ha_gust_codegen_erasure` | brand_resolution | `p19_brand_identity` | `compiler/codegen.gst` | must_change |
| `ha_gust_alloc_spelling` | container_classification | `p19_container_arena_classification` | `compiler/codegen.gst` | must_change |
| `ha_gust_typechecker_brands` | type_naming | `p19_brand_identity` | `compiler/typechecker.gst` | must_change |
| `ha_gust_default_brand` | brand_resolution | `p19_brand_identity` | `compiler/typechecker.gst` | must_change |
| `ha_seed_encodes_behaviour` | argument_representation | `p19_argument_representation` | `gust_v4.c` | must_change |

## Inherited residual rebase

| Source residual | Origin | Disposition | Selected rows |
| --- | --- | --- | --- |
| `p18_target_authority` | phase18_closure | not_selected | — |
