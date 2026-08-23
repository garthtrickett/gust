# Cranelift Phase 20 Nested Brand Annotation

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase20_nested_brand_annotation.py project`. Do not edit by hand.

- Authority version: `phase20_nested_brand_annotation_correction_v1`
- Status: `patch20_2_complete`
- Next patch: `20.3`
- Issue: `CR-11/#158`

## Semantic correction

Nested generic placeholders are instantiated while their substitution
arguments are still typed. Brand nesting then compares resolved arena
identities; flattened type-name spelling is not an acceptance input.

A primary nesting diagnostic remains in the environment while the
successfully constructed generic type is preserved. This prevents a
secondary declaration mismatch against synthetic `Void`.

## Evidence

- `two_nested_brands`
- `three_nested_brands`
- `explicit_declaration`
- `inferred_declaration`
- `import_alias`
- `field_brand`
- `illegal_escape`

The frontend validates the full accepted program. Its unreachable type
annotation probes project to the selected `main -> 20` canonical MIR,
which MIR-to-C and Cranelift execute with the same observable result.
The direct whole-program Cranelift source route remains an explicit
pre-driver source/type rejection until Patch 20.12; no C fallback is
permitted.
