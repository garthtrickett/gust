# Cranelift Phase 20 Exact Brand Boundary

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase20_exact_brand_boundary.py project`. Do not edit by hand.

- Authority version: `phase20_exact_brand_boundary_v1`
- Status: `patch20_3_complete`
- Next patch: `20.3a`
- Issue: `CR-12/#159`

## Semantic correction

After ordinary structural matching and brand substitution, typed value
boundaries compare both resolved arena identities. Two present identities
must be the same, except for the existing `Any` nesting rule. Existing
unbranded compatibility remains unchanged when either identity is absent.

This rule is generic: Clone, Index, Graph, and library type names are not
special-cased. It applies at annotation, assignment, argument, return,
field, alias, and generic payload boundaries.

## Evidence

- `explicit_annotation`
- `direct_assignment`
- `function_argument`
- `function_return`
- `Index`
- `field`
- `import_alias`
- `generic_substitution`

The frontend validates the same-brand program and the rejected matrix.
Its selected `main -> 23` projection is executed through MIR-to-C and
Cranelift from identical canonical MIR. The direct Cranelift source route
remains an explicit pre-driver rejection until Patch 20.12, with no C
fallback.
