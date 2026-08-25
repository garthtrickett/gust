# Cranelift Phase 21 Trusted Scope Provenance

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase21_trusted_scope_provenance.py project`. Do not edit by hand.

- Contract: `phase21_trusted_scope_provenance_v1`
- Status: `patch21_4_complete`
- Next patch: `21.5`
- Diagnostic: `TenantScopeProvenance` — `error: query lacks trusted tenant-scope provenance`

A scoped entity records its declared scope field. A primary query root
creates an obligation for that exact identity. Only provenance emitted
by the reserved compile-time `trusted_scope_from_context` boundary, with
the exact compiler-only nominal type `Scope[scope-identity]`, can discharge
it; arbitrary values, function names, casts, and copied
predicate spelling do not carry the provenance category.

## Evidence

- Positive: `compiler/phase21_trusted_scope_positive.gst` — MIR-to-C and Cranelift exit `41`
- `absent` — `compiler/phase21_trusted_scope_absent_invalid.gst` — rejected at query
- `forged_function` — `compiler/phase21_trusted_scope_forged_invalid.gst` — rejected at query
- `wrong_scope` — `compiler/phase21_trusted_scope_wrong_identity_invalid.gst` — rejected at query
- `arbitrary_value` — `compiler/phase21_trusted_scope_arbitrary_invalid.gst` — rejected at query
- `cast` — `compiler/phase21_trusted_scope_cast_invalid.gst` — rejected at query
- `copied_predicate_spelling` — `compiler/phase21_trusted_scope_syntax_only_invalid.gst` — rejected at query
- `outside_query_use` — `compiler/phase21_trusted_scope_outside_query_invalid.gst` — `TrustedScopeBoundary`
- `reserved_intrinsic_redefinition` — `compiler/phase21_trusted_scope_reserved_intrinsic_invalid.gst` — `ReservedCompilerIntrinsic`

The intrinsic is compile-time-only and is never emitted to either backend.
Trusted request-context establishment is outside this guarantee. Join
roots, nested queries, and cross-tenant capabilities remain explicitly
unenforced for Patches 21.5 and 21.6.
