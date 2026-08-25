# Cranelift Phase 21 Typed-Query No-op Surface

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase21_typed_query_noop_surface.py project`. Do not edit by hand.

- Contract: `phase21_typed_query_noop_surface_v1`
- Status: `patch21_3_complete`
- Next patch: `21.4`
- Scoped declaration: `#[scoped(field)] type Entity struct`
- Complete surface exit: `37`
- Scope enforcement: `false`

## Query clauses

- `root Entity as binding`
- `predicate expression`
- `join Entity as binding predicate expression`
- `nested query expression`
- `cross_tenant capability_expression`
- `terminal expression`

`query` remains an ordinary identifier unless immediately followed by
`{`. The AST records every clause, but typechecking, C generation, and
the supported native constant route obtain the query value only from
the terminal expression. No obligation or rejection is active.

## Migrated executable witnesses

- `compiler/phase21_query_shape_trusted_baseline.gst` — MIR-to-C `21`, Cranelift `21`
- `compiler/phase21_query_shape_untrusted_baseline.gst` — MIR-to-C `99`, Cranelift `99`

The checked-in bootstrap seed builds the complete parser and compiler
surface. This patch adds syntax only: it adds no MIR operation, backend
observable, ABI/layout rule, runtime symbol, seed update, or Stdlib edit.
Patch 21.4 owns trusted Scope provenance and query-site enforcement.
