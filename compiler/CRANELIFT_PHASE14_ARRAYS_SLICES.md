# Cranelift Phase 14 Arrays and Slices

<!-- Generated contract projection for Patch 14.8. -->

CRANELIFT_PHASE14_ARRAY_SLICE_VIEW_VERSION: 1
CRANELIFT_PHASE14_ARRAY_SLICE_VERSION: phase14_fixed_arrays_and_bounded_slices_v1
CRANELIFT_PHASE14_ARRAY_SLICE_STATUS: ready_for_patch14_9
CRANELIFT_PHASE14_ARRAY_SLICE_OWNER: compiler/mir_array_slice.gst
CRANELIFT_PHASE14_ARRAY_SLICE_TABLE_FORMAT: gust.compiler_array_slice_table.v1
CRANELIFT_PHASE14_ARRAY_SLICE_PRIMARY_TARGET: x86_64-unknown-linux-gnu
CRANELIFT_PHASE14_ARRAY_SLICE_LEVEL1_GUARD: guard-cranelift-phase14-array-slice-contract
CRANELIFT_PHASE14_ARRAY_SLICE_LEVEL2_GUARD: guard-cranelift-phase14-array-slice-parity
CRANELIFT_PHASE14_ARRAY_SLICE_NEXT_PATCH: 14.9

## Frozen inventory

- `[4]i32`
- `[3]u8`
- `[2]i32`
- `[2][2]i32`
- `[]i32`
- `[]u8`
- canonical empty `[]i32`

## Compiler-owned layouts

Array layout authority owns element layout identity, element count, element
stride, total size, alignment, and selected nesting depth. Slice layout
authority owns element layout identity, data-pointer and length field offsets,
pointer size and alignment, nullability, bounds, and lifetime policy.

## Canonical operations

- `array_init`
- `element_address`
- `element_load`
- `element_store`
- `array_to_slice`
- `slice_length`
- `bounded_index`
- `subslice`

## Empty representation

An empty slice is normalized to a null data pointer and zero length. A null
pointer with non-zero length is rejected before driver discovery.

## Negative classes

- `count_overflow`
- `total_size_overflow`
- `invalid_stride`
- `out_of_bounds_access`
- `wrong_element_type`
- `invalid_slice_pointer_length_pair`
- `lifetime_escape`

## Differential evidence

The primary target compares first, middle, and last i32 elements, byte-stride
u8 access, compiler-stride addresses, a selected nested array, canonical empty
slices, bounded subslices, and slice metadata crossing a branch/join origin.
All declared targets produce compiler and worker witnesses; MIR-to-C executes
on the primary target.

## Boundary

Variable-length stack arrays, zero-count fixed-array storage, arbitrary nesting,
unsized aggregate storage, heap-owned slices, resizing, resource-bearing
elements, and unrestricted user aggregate element inventories remain deferred.