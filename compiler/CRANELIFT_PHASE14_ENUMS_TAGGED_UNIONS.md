# Cranelift Phase 14 Enums and Tagged Unions

<!-- Generated contract projection for Patch 14.10. -->

CRANELIFT_PHASE14_ENUM_VIEW_VERSION: 1
CRANELIFT_PHASE14_ENUM_VERSION: phase14_enums_and_tagged_unions_v1
CRANELIFT_PHASE14_ENUM_STATUS: ready_for_patch14_11
CRANELIFT_PHASE14_ENUM_OWNER: compiler/mir_enum.gst
CRANELIFT_PHASE14_ENUM_TABLE_FORMAT: gust.compiler_enum_table.v1
CRANELIFT_PHASE14_ENUM_PRIMARY_TARGET: x86_64-unknown-linux-gnu
CRANELIFT_PHASE14_ENUM_LEVEL1_GUARD: guard-cranelift-phase14-enum-contract
CRANELIFT_PHASE14_ENUM_LEVEL2_GUARD: guard-cranelift-phase14-enum-parity
CRANELIFT_PHASE14_ENUM_NEXT_PATCH: 14.11

## Frozen inventory

The inventory follows the patch scope progression in order.

- `Color` — fieldless, compiler-assigned discriminants `0, 1, 2`
- `Status` — fieldless, explicit discriminants `100, 200, 300`
- `MaybeI32` — single payload: `None`, `Some(i32)`
- `Packet` — multiple payload layouts: `Empty`, `Small(u8)`, `Large(i32)`
- `Batch` — nested aggregate payload: `Idle`, `Pair([2]i32)`

## Compiler-owned tag selection

The compiler selects the tag type, tag width, valid discriminant set, and tag
offset. The narrowest declared unsigned tag that holds every discriminant wins:
`Color`, `MaybeI32`, `Packet`, and `Batch` select a `u8` tag; `Status` selects
an `i32` tag because `300` exceeds the `u8` capacity. The tag always lives at
offset `0`.

## Compiler-owned payload layout

Each variant owns its payload type, payload layout identity, element count, and
element stride. The layout owns one shared payload offset
(`align_up(tag_width, max_payload_alignment)`), the maximum payload size and
alignment across variants, and the total enum size
(`align_up(payload_offset + max_payload_size, alignment)`) and alignment
(`max(tag_alignment, max_payload_alignment)`).

| Enum | Tag | Tag width | Payload offset | Max payload | Size | Align |
|---|---|---|---|---|---|---|
| `Color` | `u8` | 1 | 1 | 0 | 1 | 1 |
| `Status` | `i32` | 4 | 4 | 0 | 4 | 4 |
| `MaybeI32` | `u8` | 1 | 4 | 4 | 8 | 4 |
| `Packet` | `u8` | 1 | 4 | 4 | 8 | 4 |
| `Batch` | `u8` | 1 | 4 | 8 | 12 | 4 |

The selected aggregate payload reuses the Patch 14.8 fixed-array authority
rather than introducing a second array layout rule.

## Representation

Representation is always an explicit tag plus a payload at a compiler-selected
shared offset. Niche optimization is not selected and remains deferred.

## Canonical operations

- `variant_construct`
- `tag_read`
- `variant_test`
- `payload_project`
- `match_branch`

`payload_project` is checked: it must name the variant the tag selects, stay
inside that variant's element count, and stay inside the compiler-owned enum
storage. `match_branch` lowers to a checked tag dispatch over the declared
variants with an explicit invalid-tag trap.

## Negative classes

- `duplicate_discriminant`
- `discriminant_out_of_range`
- `invalid_tag_value`
- `wrong_payload_type`
- `invalid_payload_projection`
- `inconsistent_variant_layout`

## Diagnostics

Every rejection is reported through `gust.enum.diagnostic.v1` with the
compiler-owned variant name, declaration index, discriminant, payload size, tag
type, tag width, tag offset, payload offset, size, and alignment. No diagnostic
re-derives a layout decision from the backend.

## Differential evidence

The primary target compares both selected tag widths, compiler-assigned and
explicit discriminants, fieldless values, scalar payloads, an array payload
projected at two element offsets, an enum value held in an addressable local,
and an enum value observed after a branch join. All declared targets produce
compiler and worker witnesses; MIR-to-C executes on the primary target. Each of
the six negative classes is driven by a single-token request mutation and must
fail before driver discovery without touching the protected output.

## Boundary

Struct payloads are not selected by this patch's inventory
(`deferred_struct_payloads_not_selected_by_patch14_10`). Patch 14.9 owns the
declaration-order struct layout they would consume, so selecting them is
future-patch work rather than a blocked dependency. Niche and
null-pointer optimization, open or non-exhaustive variant sets, discriminant
expressions, recursive and boxed payloads, enum values crossing the FFI
boundary, resource-bearing payloads, and unrestricted user payload inventories
remain deferred.
