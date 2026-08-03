# Cranelift Phase 14 Aggregate Transport Across Basic Blocks

<!-- Generated contract projection for Patch 14.11. -->

CRANELIFT_PHASE14_AGGREGATE_VIEW_VERSION: 1
CRANELIFT_PHASE14_AGGREGATE_VERSION: phase14_aggregate_basic_block_transport_v1
CRANELIFT_PHASE14_AGGREGATE_STATUS: ready_for_patch14_12
CRANELIFT_PHASE14_AGGREGATE_OWNER: compiler/mir_aggregate_transport.gst
CRANELIFT_PHASE14_AGGREGATE_TABLE_FORMAT: gust.compiler_aggregate_transport_table.v1
CRANELIFT_PHASE14_AGGREGATE_PRIMARY_TARGET: x86_64-unknown-linux-gnu
CRANELIFT_PHASE14_AGGREGATE_LEVEL1_GUARD: guard-cranelift-phase14-aggregate-contract
CRANELIFT_PHASE14_AGGREGATE_LEVEL2_GUARD: guard-cranelift-phase14-aggregate-parity
CRANELIFT_PHASE14_AGGREGATE_CI_FAMILY: aggregate-flow
CRANELIFT_PHASE14_AGGREGATE_NEXT_PATCH: 14.12

## Selected classes and their transport policy

Each class gets exactly one compiler-owned transport policy. The policy fixes
the block-argument arity, which is what stops MIR-to-C and Cranelift from
flattening differently.

| Class | Example | Transport policy | Block arguments |
|---|---|---|---|
| `string_view` | borrowed view | `fieldwise_canonical_values` | one per component (2) |
| `slice` | `[]i32` | `fieldwise_canonical_values` | one per component (2) |
| `struct` | `Point` | `fieldwise_canonical_values` | one per component (2) |
| `enum` | `MaybeI32` | `fieldwise_canonical_values` | tag + payload (2) |
| `fixed_array` | `[4]i32` | `layout_backed_stack_copy` | single slot (1) |
| `nested` | `Nested` | `layout_backed_stack_copy` | single slot (1) |

`agg_array` carries four components but exactly **one** block argument. That
divergence between component count and arity is the compiler's decision, and
both backends must reproduce it.

## Consumed authorities

Layout identities are taken from the frozen upstream authorities, never
re-derived: Patch 14.7 string views, Patch 14.8 arrays and slices, Patch 14.9
struct layout, and Patch 14.10 enums.

## Canonical block-parameter representation

Blocks declare aggregate parameters; edges carry one argument value per
parameter. A block's `total_block_argument_count` is the sum of its parameters'
policy-implied arities, and every incoming edge must reproduce that sum.

```
entry ──true──→ then_block ─┐
      └─false─→ else_block ─┴→ if_join      (2 params, 4 block arguments)
                                  ↓
                              seq_block     (1 param,  2 block arguments)
                                  ↓
                              loop_header   (2 params, 3 block arguments) ←┐
                                  ↓                                        │
                              loop_body ────────────backedge───────────────┘
                                  ↓
                              exit_block    (1 param,  1 block argument) → scalar return
```

## Canonical operations

- `block_param_declare`
- `edge_argument_pass`
- `join_observe`
- `loop_carry`
- `early_return`

## Validation

Aggregate type identity, layout identity, block-argument count, block-argument
type, copy or move policy, initialization, lifetime, and join consistency. Join
consistency requires every incoming edge to agree on type, layout, transport
policy, size, alignment, component count, and enum variant.

## Negative classes

- `join_layout_mismatch`
- `field_count_mismatch`
- `variant_mismatch`
- `invalid_lifetime`
- `use_after_move`
- `resource_bearing_copy`

## Differential evidence

The generated C runs real control flow: an `if/else` that selects the joined
value, and a loop whose backedge re-copies the layout-backed state. Fieldwise
classes cross edges as one scalar C variable per canonical component;
layout-backed classes cross as a single `memcpy` of compiler-owned size. Field
values and semantic layout witnesses are compared after both the join and the
loop. All declared targets produce compiler and worker witnesses; MIR-to-C
executes on the primary target.

## Boundary

Aggregate function parameters and returns remain deferred to a later ABI phase;
early returns are supported only while the return ABI stays scalar. Copies are
limited to values with explicit non-resource copy semantics. Resource-bearing
aggregate movement and destruction, unbounded nesting, and aggregates crossing
the FFI boundary remain deferred.
