# Cranelift Phase 19 Identifier-Spelling Decision Inventory

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase19_spelling_inventory.py project`. Do not edit by hand.

Report-only. Nothing in Patch 19.1 changes behaviour.

- Inventory version: `phase19_spelling_inventory_self_hosted_v2`
- Status: `ready_for_patch19_2`
- Sites: `9`
- Compiler scope: `self_hosted` (the deprecated root Rust prototype is removed)

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
| `available_in_scope` | 1 | the resolved type is already at the site; the spelling is used anyway |
| `available_after_resolution` | 5 | the type exists by this stage but is not threaded to the site |
| `requires_new_authority` | 3 | no declared brand or arena kind exists to consult yet |
| `unavailable_at_this_stage` | 0 | the decision runs before type resolution |

## Sites

| ID | Compiler | Source | Kind | Type information available | Sufficiency |
| --- | --- | --- | --- | --- | --- |
| `gst_codegen_erasure_bases` | self_hosted | `compiler/codegen.gst:502` | type_name_erasure | none: operates on the already-flattened name string | `requires_new_authority` |
| `gst_codegen_is_brand_name` | self_hosted | `compiler/codegen.gst:515` | classification_override | the name only | `available_after_resolution` |
| `gst_codegen_var_arena` | self_hosted | `compiler/codegen.gst:634` | classification_override | resolved expression type and shared type classifier | `available_after_resolution` |
| `gst_codegen_var_arena_2` | self_hosted | `compiler/codegen.gst:634` | classification_override | resolved expression type and shared type classifier | `available_after_resolution` |
| `gst_codegen_alloc_override` | self_hosted | `compiler/codegen.gst:1601` | classification_override | the allocator spelling only | `available_after_resolution` |
| `gst_typechecker_default_brand` | self_hosted | `compiler/typechecker.gst:159` | classification_override | none at the defaulting point | `requires_new_authority` |
| `gst_typechecker_brand_member` | self_hosted | `compiler/typechecker.gst:5064` | classification_override | the name part only | `available_after_resolution` |
| `gst_typechecker_brand_suffixes` | self_hosted | `compiler/typechecker.gst:5251` | type_name_erasure | none: operates on the suffix string | `requires_new_authority` |
| `gst_typechecker_any_compat` | self_hosted | `compiler/typechecker.gst:1847` | classification_override | both brands are in hand as cleaned strings | `available_in_scope` |
