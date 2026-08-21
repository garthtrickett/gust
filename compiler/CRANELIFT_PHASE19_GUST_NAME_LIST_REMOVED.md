# Cranelift Phase 19 Gust Name-List Removal

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase19_gust_name_list_removed.py project`. Do not edit by hand.

- Contract: `phase19_gust_name_list_removed_v1`
- Status: `ready_for_patch19_9`
- Next patch: `19.9`
- Decision policy: `template_role_and_resolved_type_metadata_only`
- Removed authority: `compiler/phase19_spelling_rule.gst`

## Result

The ordered brand-name vocabulary and every exact, suffix, substring, and
generated-expression consumer are absent from `compiler/*.gst`. Generic
templates record one brand-argument position, resolution represents that
argument with existing AST brand metadata, and codegen consumes those records.
The committed seed compiles the resulting compiler with `make gust`.

## Generated-C difference enumeration

The compiler C changed by 532 insertions and
435 deletions. Every hunk belongs to one of:

- `retired_spelling_authority` — deletes the generated spelling-table helpers and their calls
- `template_role_metadata` — adds template brand-position fields, inference helpers, and built-in role initializers
- `structural_brand_markers` — adds and consumes AST brand markers during resolution and monomorphization
- `flattened_name_recovery` — uses template metadata for flattened generic, Index, namespace, and enclosing-brand recovery
- `canonical_name_normalization` — replaces hardcoded cleanup names with symmetric metadata-driven identity and separator normalization
- `codegen_metadata_consumers` — uses canonical type records and template roles for type erasure and arena classification

The differences are compiler-internal authority and generated helper changes;
there is no new syntax, MIR operation, ABI/layout change, runtime symbol, target
policy, linker policy, or backend-specific meaning.

## Level 2 parity

The paired sources differ only by renaming the template/allocator brand from
`ctx` to `region`. Both compile without diagnostics and return 19, proving an
arbitrary spelling follows the same structural role.
