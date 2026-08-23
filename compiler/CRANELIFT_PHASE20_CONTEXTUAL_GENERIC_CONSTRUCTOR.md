# Cranelift Phase 20 Contextual Generic Constructor Result

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase20_contextual_generic_constructor.py project`. Do not edit by hand.

- Authority version: `phase20_contextual_generic_constructor_result_v1`
- Status: `patch20_3a_complete`
- Next patch: `20.4`

## Semantic correction

An already-resolved compatible annotation, assignment, argument, or
return type is the result authority for a generic constructor expression.
Normal template, payload, and exact-brand matching must succeed first;
context does not authorize a conversion or cast.

MIR-to-C consumes that recorded semantic result. It does not reconstruct
an `_Any` specialization from a constructor spelling. The rule is shared
by every registered constructor family and contains no Channel-only path.

## Evidence

- Context boundary: `explicit_annotation`
- Context boundary: `direct_assignment`
- Context boundary: `function_argument`
- Context boundary: `function_return`
- Constructor family: `Vector`
- Constructor family: `HashMap`
- Constructor family: `Pool`
- Constructor family: `Mutex`
- Constructor family: `Channel`
- Constructor family: `Graph`

The inferred/explicit pair emits byte-identical, host-compilable C and
returns 31. Cross-template and wrong-brand contexts remain rejected.
Selected canonical MIR returns 31 through MIR-to-C and Cranelift. The
direct Cranelift source route remains an explicit pre-driver deferral
with no C fallback. Seed publication remains isolated to Patch 20.11.
