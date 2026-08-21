# Cranelift Phase 19 Self-Hosted Rule Convergence

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase19_rule_convergence.py project`. Do not edit by hand.

- Authority: `phase19_self_hosted_spelling_rule_v1`
- Status: `ready_for_patch19_7`
- Next patch: `19.7`
- Shared compiler authority: `compiler/phase19_spelling_rule.gst`
- Ordered legacy spellings: `14`
- Shared cases: `13`

## Result

The legacy brand-spelling rule has one ordered table. Exact brand-member
recognition, type-name suffix extraction, and generated-expression matching
all consume that table. The self-hosted typechecker and codegen no longer
carry independent vocabularies. This patch deliberately retains the rule;
Patch 19.8 removes the centralized compatibility path after Patch 19.7 proves
the retired prototype cannot reintroduce a second implementation.

The shared case family covers exact names, single- and module-suffix forms,
dot substrings, `->ctx`, `->a`, and negative controls. `Any` compatibility is
recorded separately because wildcard compatibility is an explicit semantic
rule, not evidence that an arbitrary spelling denotes an arena.

## Patch 19.1 site termination

| Site | Disposition |
| --- | --- |
| `gst_codegen_erasure_bases` | `retired_by_canonical_type_name_authority` |
| `gst_codegen_is_brand_name` | `delegates_shared_suffix_rule` |
| `gst_codegen_var_arena` | `retired_by_resolved_type_classifier` |
| `gst_codegen_var_arena_2` | `retired_by_resolved_type_classifier` |
| `gst_codegen_alloc_override` | `delegates_shared_expression_rule` |
| `gst_typechecker_default_brand` | `retired_by_explicit_brand_identity_authority` |
| `gst_typechecker_brand_member` | `delegates_shared_exact_rule` |
| `gst_typechecker_brand_suffixes` | `delegates_shared_suffix_rule` |
| `gst_typechecker_any_compat` | `separate_explicit_wildcard_semantics` |

No runtime symbol, MIR instruction, ABI, layout, resource rule, target policy,
or source syntax changed.
