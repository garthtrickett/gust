# Cranelift Phase 20 Canonical Brand Matching

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase20_brand_matching.py project`. Do not edit by hand.

- Authority version: `phase20_canonical_brand_matching_v1`
- Status: `ready_for_patch20_2`
- Next patch: `20.2`
- Identity authority: `phase19_brand_identity_authority_v1`
- Behaviour policy: `resolved_identity_shadow_only_legacy_acceptance_and_diagnostics_unchanged`

## Canonical operations

- `brand_identity_exact_match`
- `brand_identity_nesting_membership`
- `brand_identity_mismatch_description`

Exact matching compares non-empty resolved arena identities and ignores
their provenance labels. Nesting membership adds the existing `Any`
wildcard policy. Mismatch text is produced from the same identities.

## Behaviour-neutral shadow

`env_is_element_allowed_in_brand` still owns acceptance and still uses
`strip_brand_prefix`. Its branded comparison now records whether the
resolved-identity answer agrees with that legacy result. No shadow result
is used to accept, reject, or construct a diagnostic in Patch 20.1.

The frozen source contains `49`
legacy cleaner calls (plus the function definition). Later patches must
remove those callers from this baseline rather than adding parallel rules.

The semantic fixture covers nested wrappers, distinct same-shaped arena
identities, registered fields, import aliases, generic substitution, exact
and wildcard comparison, mismatch text, and both shadow agreement states.
