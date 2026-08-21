# Cranelift Phase 19 Type-Derived Classification

Generated from `scripts/cranelift_feature_registry.json` by
`scripts/phase19_classification.py project`. Do not edit by hand.

- Authority: `phase19_type_derived_classification_v1`
- Status: `ready_for_patch19_5`
- Next patch: `19.5`
- Type authority: `resolved_type_plus_struct_registry_metadata`
- Override policy: `retained_and_asserted_redundant`

## Result

`str`/slice, ordinary pointer, Vector, HashMap, Pool, and arena classification
now come from one resolved-type classifier. Concrete container kinds are propagated
from registered templates into a registry keyed beside `struct_registry`; a
Vector-like user spelling without that metadata remains an ordinary struct.
Compiler-internal fixtures that synthesize container layouts register their
container kind explicitly; `Vector_Pretender` remains deliberately unannotated.

Both typechecking and MIR-to-C consume the same classifier. Arena pointer/value
selection uses the resolved expression type. The remaining Clone brand
representation lookup is explicitly owned by Patch 19.5 and does not decide
whether a value is an arena.

## Measured legacy disagreement

The pre-change self-compilation probe found `1597`
instances of `Reference(Arena)` named
`ctx`. All had one root cause:
`arena_type_predicate_omitted_reference`. The shared classifier now handles that shape.

The spelling override remains in index lowering, but a fatal assertion runs
before it can change the type-derived answer. Self-compilation and the focused
fixtures therefore prove it is redundant without deleting it prematurely.

No MIR instruction, runtime symbol, ABI, layout, or backend-specific semantic
changed.
