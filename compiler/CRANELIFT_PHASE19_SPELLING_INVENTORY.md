# Cranelift Phase 19 Identifier-Spelling Decision Inventory

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase19_spelling_inventory.py project`. Do not edit by hand.

Report-only. Nothing in Patch 19.1 changes behaviour.

- Inventory version: `phase19_spelling_inventory_v1`
- Status: `ready_for_patch19_2`
- Sites: `22`

## Regression surface

A dated measurement, not an invariant. `compiler/*.gst` is shared with
every lane, so these counts move for reasons that have nothing to do
with Phase 19 and are reported rather than asserted.

Measured at Phase 19.1, 2026-08-21. Run
`scripts/phase19_spelling_inventory.py surface` for the live figures;
they are deliberately not baked in here, because a generated artifact
holding a live count is checked for staleness and so is just the same
brittleness one step removed.

| Measure | Count |
| --- | --- |
| `compiler/*.gst` files scanned | 715 |
| Files declaring `Index[...]` | 155 |
| `Index[...]` occurrences | 1989 |
| Brand-parameterised `Index[T, ctx]` | 260 |

## Where the type information already is

| Sufficiency | Sites | Meaning |
| --- | --- | --- |
| `available_in_scope` | 4 | the resolved type is already at the site; the spelling is used anyway |
| `available_after_resolution` | 7 | the type exists by this stage but is not threaded to the site |
| `requires_new_authority` | 9 | no declared brand or arena kind exists to consult yet |
| `unavailable_at_this_stage` | 2 | the decision runs before type resolution |

## Cross-compiler divergence

| Divergence | Sites | Meaning |
| --- | --- | --- |
| `none` | 11 | the two compilers make this decision the same way |
| `scan_order` | 2 | same names, different scan order, and both scan first-match-wins |
| `suffix_set` | 3 | the two sites accept different suffix sets |
| `absent_in_counterpart` | 6 | one compiler makes this decision and the other does not |

## Sites

| ID | Compiler | Source | Kind | Type information available | Sufficiency | Divergence |
| --- | --- | --- | --- | --- | --- | --- |
| `rs_codegen_erasure_bases` | rust_host | `src/codegen.rs:71` | type_name_erasure | none: operates on the already-flattened name string | `requires_new_authority` | `scan_order` |
| `rs_codegen_is_brand_type` | rust_host | `src/codegen.rs:125` | classification_override | the resolved Type and the struct-layout registry are both parameters | `available_in_scope` | `none` |
| `rs_codegen_arena_override` | rust_host | `src/codegen.rs:1759` | classification_override | alloc_type is matched against Type::Arena on the immediately preceding line | `available_in_scope` | `suffix_set` |
| `rs_typechecker_clean_part` | rust_host | `src/typechecker.rs:118` | classification_override | the name part only; the owning type is not threaded here | `available_after_resolution` | `none` |
| `rs_typechecker_name_member` | rust_host | `src/typechecker.rs:155` | classification_override | the name only | `available_after_resolution` | `absent_in_counterpart` |
| `rs_types_brand_bases` | rust_host | `src/typechecker/types.rs:61` | type_name_erasure | none: operates on the name string | `requires_new_authority` | `none` |
| `rs_types_suffix_brands` | rust_host | `src/typechecker/types.rs:438` | type_name_erasure | none: operates on the suffix string | `requires_new_authority` | `none` |
| `rs_types_any_compat` | rust_host | `src/typechecker/types.rs:199` | classification_override | both resolved brands are in hand as Option<String> | `available_in_scope` | `none` |
| `rs_mono_generic_is_arena` | rust_host | `src/typechecker/monomorphize.rs:596` | classification_override | the argument is a resolved Type, but the parameter carries no declared kind | `requires_new_authority` | `absent_in_counterpart` |
| `rs_mono_generic_is_arena_2` | rust_host | `src/typechecker/monomorphize.rs:719` | classification_override | the argument is a resolved Type, but the parameter carries no declared kind | `requires_new_authority` | `absent_in_counterpart` |
| `rs_mono_default_arena` | rust_host | `src/typechecker/monomorphize.rs:232` | classification_override | none at the defaulting point | `requires_new_authority` | `none` |
| `rs_parser_brand_name` | rust_host | `src/parser.rs:732` | classification_override | none: the parser runs before type resolution | `unavailable_at_this_stage` | `absent_in_counterpart` |
| `rs_parser_arena_spelling` | rust_host | `src/parser.rs:751` | type_name_erasure | none: the parser runs before type resolution | `unavailable_at_this_stage` | `absent_in_counterpart` |
| `gst_codegen_erasure_bases` | self_hosted | `compiler/codegen.gst:658` | type_name_erasure | none: operates on the already-flattened name string | `requires_new_authority` | `scan_order` |
| `gst_codegen_is_brand_name` | self_hosted | `compiler/codegen.gst:762` | classification_override | the name only | `available_after_resolution` | `none` |
| `gst_codegen_var_arena` | self_hosted | `compiler/codegen.gst:896` | classification_override | the variable name only at this site | `available_after_resolution` | `suffix_set` |
| `gst_codegen_var_arena_2` | self_hosted | `compiler/codegen.gst:1101` | classification_override | the variable name only at this site | `available_after_resolution` | `absent_in_counterpart` |
| `gst_codegen_alloc_override` | self_hosted | `compiler/codegen.gst:1851` | classification_override | the allocator spelling only | `available_after_resolution` | `suffix_set` |
| `gst_typechecker_default_brand` | self_hosted | `compiler/typechecker.gst:159` | classification_override | none at the defaulting point | `requires_new_authority` | `none` |
| `gst_typechecker_brand_member` | self_hosted | `compiler/typechecker.gst:4975` | classification_override | the name part only | `available_after_resolution` | `none` |
| `gst_typechecker_brand_suffixes` | self_hosted | `compiler/typechecker.gst:5172` | type_name_erasure | none: operates on the suffix string | `requires_new_authority` | `none` |
| `gst_typechecker_any_compat` | self_hosted | `compiler/typechecker.gst:2279` | classification_override | both brands are in hand as cleaned strings | `available_in_scope` | `none` |
