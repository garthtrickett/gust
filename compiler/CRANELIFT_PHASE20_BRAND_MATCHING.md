# Cranelift Phase 20 Canonical Brand Matching

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase20_brand_matching.py project`. Do not edit by hand.

- Authority version: `phase20_canonical_brand_matching_v2`
- Status: `patch20_2_nesting_acceptance_enabled`
- Next patch: `20.3`
- Identity authority: `phase19_brand_identity_authority_v1`
- Behaviour policy: `resolved_identity_authoritative_for_brand_nesting_with_legacy_shadow_observation_only`

## Canonical operations

- `brand_identity_exact_match`
- `brand_identity_nesting_membership`
- `brand_identity_mismatch_description`

Exact matching compares non-empty resolved arena identities and ignores
their provenance labels. Nesting membership adds the existing `Any`
wildcard policy. Mismatch text is produced from the same identities.

## Behaviour-neutral shadow

`env_is_element_allowed_in_brand` owns nesting acceptance and now returns
the resolved-identity answer. The previous `strip_brand_prefix` result is
retained only as a disagreement counter and cannot accept or reject source.

The frozen source contains `47`
legacy cleaner calls (plus the function definition). Later patches must
remove those callers from this baseline rather than adding parallel rules.

The semantic fixture covers nested wrappers, distinct same-shaped arena
identities, registered fields, import aliases, generic substitution, exact
and wildcard comparison, mismatch text, and both shadow agreement states.
