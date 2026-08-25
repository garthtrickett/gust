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

- `compiler/phase21_query_shape_trusted_baseline.gst` — `generated_c_sha256`
  - Exit: `0`
  - SHA-256: `38f9f29cee0632ac0793ebf6f0496be1d8b6a10434aba88bab02f415be3d17a1`
- `compiler/phase21_query_shape_untrusted_baseline.gst` — `generated_c_sha256`
  - Exit: `0`
  - SHA-256: `29b340c24244b76d938cf5af11ca3bb0cacd7af97dcf7a3743db72af87860d78`
- `compiler/phase20_resource_empty_forge_invalid.gst` — `diagnostic_stdout_sha256`
  - Exit: `1`
  - SHA-256: `b8cf3e1ce5e3f77fb303162f38adc5eb24f3861c36d5d282b497149afc77b144`

These hashes were measured on exact predecessor main before the inert
module was added and are replayed after it is built. They pin generated
C for both existing query-shaped programs and one existing compiler
diagnostic. Patch 21.2 adds no source syntax, rejection, MIR operation,
backend behavior, ABI/layout rule, runtime symbol, or seed update.
