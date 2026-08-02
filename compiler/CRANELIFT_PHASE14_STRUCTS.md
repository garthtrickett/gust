# Cranelift Phase 14 Declaration-Order Structs

<!-- Generated contract projection for Patch 14.9. -->

CRANELIFT_PHASE14_STRUCT_VIEW_VERSION: 1
CRANELIFT_PHASE14_STRUCT_VERSION: phase14_declaration_order_struct_layout_v1
CRANELIFT_PHASE14_STRUCT_STATUS: ready_for_patch14_11
CRANELIFT_PHASE14_STRUCT_OWNER: compiler/mir_struct_layout.gst
CRANELIFT_PHASE14_STRUCT_TABLE_FORMAT: gust.compiler_struct_layout_table.v1
CRANELIFT_PHASE14_STRUCT_PRIMARY_TARGET: x86_64-unknown-linux-gnu
CRANELIFT_PHASE14_STRUCT_LEVEL1_GUARD: guard-cranelift-phase14-struct-contract
CRANELIFT_PHASE14_STRUCT_LEVEL2_GUARD: guard-cranelift-phase14-struct-parity
CRANELIFT_PHASE14_STRUCT_FAMILY_GUARD: guard-cranelift-phase14-structs-enums-parity
CRANELIFT_PHASE14_STRUCT_NEXT_PATCH: 14.11

## Frozen inventory

Each selected struct isolates one padding behaviour.

- `Point { x: i32, y: i32 }` — equal widths, no padding
- `Header { tag: u8, value: i32 }` — compiler-owned inter-field padding
- `Flags { a: u8, b: u8, c: u8 }` — dense byte packing, no padding
- `Padded { id: i32, flag: u8 }` — compiler-owned tail padding
- `Nested { head: Header, extra: i32 }` — one bounded aggregate field

## Compiler-owned layout

The compiler owns declaration indexes, field offsets, inter-field padding,
aggregate alignment, and tail padding. A field offset is
`align_up(running_offset, field_alignment)`; the struct alignment is the
maximum field alignment; the struct size is
`align_up(end_of_last_field, struct_alignment)`.

| Struct | Field offsets | Size | Align |
|---|---|---|---|
| `Point` | `x@0`, `y@4` | 8 | 4 |
| `Header` | `tag@0`, `value@4` | 8 | 4 |
| `Flags` | `a@0`, `b@1`, `c@2` | 3 | 1 |
| `Padded` | `id@0`, `flag@4` | 8 | 4 |
| `Nested` | `head@0`, `extra@8` | 12 | 4 |

## Scalar leaf map

Field storage is modelled as a compiler-derived list of scalar leaves in offset
order, so a nested field path resolves to a real stored scalar rather than to
its own expectation. `Nested` derives `head.tag@0`, `head.value@4`, `extra@8`.
Both backends recompute the leaf map and reject a serialized map that disagrees.

## Canonical operations

- `construct`
- `field_address`
- `field_load`
- `field_store`

## Negative classes

- `duplicate_field`
- `misaligned_field`
- `overlapping_fields`
- `wrong_field_type`
- `size_alignment_mismatch`
- `unknown_field_path`

## Diagnostics

Every rejection is reported through `gust.struct.diagnostic.v1` with the
compiler-owned field name, declaration index, field offset, field size, field
alignment, field count, struct size, alignment, and nesting depth.

## Differential evidence

The MIR-to-C evidence declares real C structs and asserts `sizeof`, `_Alignof`,
and `offsetof` against the compiler-owned numbers at C compile time, so a
disagreement with the platform layout fails to compile rather than silently
passing. Byte-level loads and stores then execute against those same offsets at
run time. All declared targets produce compiler and worker witnesses; MIR-to-C
executes on the primary target. Each negative class is driven by a single-token
request mutation and must fail before driver discovery.

## Boundary

Aggregate parameter and return ABI, packed structs, bitfields, deeper than one
level of nesting, unions, zero-field structs, field reordering, resource-bearing
fields, and unrestricted user field inventories remain deferred.
