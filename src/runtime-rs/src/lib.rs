//! The Rust half of the Gust runtime (Patch 25.4).
//!
//! This crate holds the parts of the runtime that cannot be Gust:
//!
//!   * the `tiny_host_*` FFI fixtures, rehomed here by O1;
//!   * later, `fiber.c`'s two assembly functions via `global_asm!` (D3).
//!
//! The fixtures must NOT be rewritten in Gust. Their whole point is that
//! the callee is foreign: a Gust implementation would test Gust calling
//! Gust and the contract under test would evaporate. That is the trap in
//! "everything goes to Gust", and D2 says so explicitly.
//!
//! Symbol names are byte-identical to the C originals, so the 26 files
//! that depend on them -- the phase13_runtime_* sources, four
//! mir_*_smoke_test_entry.gst, the Phase 17 guards and the Cranelift
//! registry -- need no value changes.

// Patch 25.6 removed `#![no_std]`. See src/fiber.rs for why: pthread_mutex_t
// is opaque and platform-specific, so a no_std scheduler must hand-guess its
// layout per platform, and three of this patch's four committed quadrants
// cannot be built here to check the guess. Phase 25's gate is no C COMPILER,
// not no libc, so `std` costs the phase nothing and removes the guessing.
//
// The hand-written #[panic_handler] went with it -- std supplies one, and two
// definitions do not link. `panic = "abort"` is kept in Cargo.toml, so the
// abort behaviour the fixtures relied on is unchanged.

/// Approved scalar import fixture. Was `src/runtime/approved_scalar_imports.c`.
#[no_mangle]
pub extern "C" fn tiny_host_add_one_i32(value: i32) -> i32 {
    value.wrapping_add(1)
}

/// Approved scalar import fixture. Was `src/runtime/approved_scalar_imports.c`.
#[no_mangle]
pub extern "C" fn tiny_host_add_i32(left: i32, right: i32) -> i32 {
    left.wrapping_add(right)
}

/// Approved scalar import fixture. Was `src/runtime/approved_scalar_imports.c`.
#[no_mangle]
pub extern "C" fn tiny_host_is_positive_i32(value: i32) -> i32 {
    i32::from(value > 0)
}

mod fiber_asm;
pub mod fiber;
