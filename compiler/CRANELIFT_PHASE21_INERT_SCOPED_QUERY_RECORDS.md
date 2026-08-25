# Cranelift Phase 21 Inert Scoped-Query Semantic Records

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase21_inert_scoped_query_records.py project`. Do not edit by hand.

- Contract: `phase21_inert_scoped_query_semantic_records_v1`
- Status: `patch21_2_complete`
- Next patch: `21.3`
- Module: `compiler/typed_query_semantic_records.gst`
- Enforcement enabled: `false`
- Reachable from normal source typechecking/lowering: `false`

## Opaque record families

- `ScopedEntityDeclaration`
- `CanonicalQueryRoot`
- `PerRootScopeObligation`
- `PredicateProvenance`
- `NestedQueryIdentity`
- `CrossTenantMarker`
- `TrustedScopeOrigin`

Every family is branded and opaque. Every constructor is private, and
the focused self-hosted hook returns only pass/fail, so no ordinary
source program can construct or obtain a trusted Scope-origin record.
The module is absent from parser, typechecker, MIR, codegen, and normal
compiler entrypoints.

## Preserved semantic baseline

- `compiler/phase21_query_shape_trusted_baseline.gst` — `generated_c_golden_and_runtime_observation`
  - Generated-C golden: `compiler/fixtures/phase21_query_shape_trusted_baseline.expected.c`
  - Compile exit: `0`
  - Runtime exit: `21`
- `compiler/phase21_query_shape_untrusted_baseline.gst` — `generated_c_golden_and_runtime_observation`
  - Generated-C golden: `compiler/fixtures/phase21_query_shape_untrusted_baseline.expected.c`
  - Compile exit: `0`
  - Runtime exit: `99`
- `compiler/phase20_resource_empty_forge_invalid.gst` — `unchanged_source_and_exact_diagnostic`
  - Compile exit: `1`
  - Diagnostic class: `OpaqueConstruction`
  - Diagnostic: `Opaque type 'phase20_resource_enforcement_module__Handle' can be constructed only inside its defining module`

The evidence guard compares both generated-C outputs byte-for-byte with
their exact-main goldens, replays both programs, and checks the exact
existing diagnostic. Patch 21.2 adds
no source syntax, rejection, MIR operation,
backend behavior, ABI/layout rule, runtime symbol, or seed update.
