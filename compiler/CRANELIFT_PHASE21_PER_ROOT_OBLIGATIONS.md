# Cranelift Phase 21 Per-Root Query Obligations

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase21_per_root_obligations.py project`. Do not edit by hand.

- Contract: `phase21_per_root_obligations_v1`
- Status: `patch21_5_complete`
- Next patch: `21.6`
- Diagnostic: `TenantScopeProvenance` — `error: query lacks trusted tenant-scope provenance`

Every scoped primary or joined root owns a distinct obligation in
deterministic source order. A join can be discharged only by its own
predicate. Every nested query is checked as a fresh boundary, so outer,
sibling, or earlier evidence cannot clear it.

Query values use conservative projection: the complete local obligation
set must be discharged before the terminal becomes an ordinary value.
Therefore unresolved sets cannot be laundered through aliases, returns,
branches, or aggregate-shaped nested queries.

## Positive evidence

- `scoped_joins_and_nested` — `compiler/phase21_per_root_obligations_positive.gst` — MIR-to-C exit `51`, Cranelift exit `51`
- `unscoped_join` — `compiler/phase21_unscoped_join_positive.gst` — MIR-to-C exit `54`
- `nested_aggregate_shape` — `compiler/phase21_nested_aggregate_positive.gst` — MIR-to-C exit `55`, Cranelift exit `55`
- `branch_return_alias_flow` — `compiler/phase21_query_value_flow_positive.gst` — MIR-to-C exit `52`

## Rejection evidence

- `join_missing` — `compiler/phase21_join_obligation_missing_invalid.gst` — `join` binding `member` rejected at its query
- `sibling_discharge` — `compiler/phase21_join_sibling_isolation_invalid.gst` — `join` binding `second_member` rejected at its query
- `nested_missing` — `compiler/phase21_nested_obligation_missing_invalid.gst` — `primary` binding `inner_workspace` rejected at its query
- `query_value_unresolved` — `compiler/phase21_query_value_unresolved_invalid.gst` — `primary` binding `workspace` rejected at its query
- `branch_unresolved` — `compiler/phase21_query_value_branch_invalid.gst` — `primary` binding `second_workspace` rejected at its query

Unscoped joins create no obligation. Cross-tenant capability
enforcement remains Patch 21.6. Trusted-context establishment, raw
SQL, MIR operations, ABI/layout, runtime symbols, and Stdlib remain
outside this patch.
