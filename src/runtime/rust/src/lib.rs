//! Phase 17.6 reference Rust runtime component.
//!
//! This component exists because signed-overflow behaviour is undefined in C
//! and well-defined in Rust. It is compiled independently of any Gust program,
//! exports stable ABI-facing symbols with `#[no_mangle] extern "C"`, and never
//! relies on Rust-internal mangling as a runtime contract.
//!
//! Boundaries this component declares to the Phase 17 runtime authority:
//!
//! * **Panic boundary** — `abort_no_unwind_across_ffi`. Both cargo profiles set
//!   `panic = "abort"`, so an unwind can never cross back into compiled Gust.
//! * **Allocation boundary** — `no_allocation_caller_owns_all_memory`. Nothing
//!   here allocates; every out-parameter is caller-owned storage.

#![no_std]

use core::panic::PanicInfo;

/// Checked signed addition. Returns 1 and writes the sum on success, 0 on
/// overflow leaving `out` untouched. The failure is an explicit return value,
/// never a panic and never undefined behaviour.
///
/// # Safety
/// `out` must be a valid, aligned, writable `i32` owned by the caller.
#[no_mangle]
pub unsafe extern "C" fn gust_rt_checked_add_i32(a: i32, b: i32, out: *mut i32) -> i32 {
    match a.checked_add(b) {
        Some(value) => {
            if out.is_null() {
                return 0;
            }
            *out = value;
            1
        }
        None => 0,
    }
}

/// Saturating signed addition. Total: clamps at `i32::MIN` / `i32::MAX` and
/// cannot fail, so callers need no error path.
#[no_mangle]
pub extern "C" fn gust_rt_saturating_add_i32(a: i32, b: i32) -> i32 {
    a.saturating_add(b)
}

extern "C" {
    /// Host `abort(3)`. This component is always linked into a C-hosted
    /// program, so the platform's abort is available and stable to call.
    fn abort() -> !;
}

/// `#![no_std]` staticlib needs its own panic handler. Reaching it would mean
/// the abort boundary above was breached, so it aborts rather than unwinding
/// back across the extern "C" boundary into compiled Gust code.
#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    unsafe { abort() }
}
