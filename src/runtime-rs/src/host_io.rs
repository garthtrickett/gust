//! `host_io.c` to Rust (Patch 25.5).
//!
//! The file's own header said these "have no pure Gust equivalent and are
//! expected to remain retained C". The first half is right and the second
//! is what Phase 25 changes: process argv and the standard streams are host
//! primitives, so they cannot be Gust — but they can be Rust, which is what
//! D2's per-file fallback is for.
//!
//! Every function here needs something Gust does not express: raw arena
//! bytes (`os_Args`), an allocation the caller frees (`os_MockPayload`), or
//! a standard stream (`os_LogStr`, `os_LogError`).

use std::io::Write;
use crate::fiber::{OsArena, SliceU8, VectorStr, arena_alloc_bytes};

/// `int os_argc` / `char** os_argv`, populated by `main()`.
///
/// Exported as DATA, which works here and did not for `gust_loop_ticks`:
/// these are ordinary globals, not thread-locals. Stable Rust can export a
/// `static mut` under a fixed symbol; it cannot export a `__thread` one.
#[no_mangle]
pub static mut os_argc: i32 = 0;
#[no_mangle]
pub static mut os_argv: *mut *mut i8 = std::ptr::null_mut();

/// `struct std_Vector_str os_Args(os_Arena* ctx)`.
///
/// # Safety
/// `ctx` must be a live arena, and `os_argv` must hold `os_argc` valid
/// NUL-terminated pointers — the contract `main()` establishes.
#[no_mangle]
pub unsafe extern "C" fn os_Args(ctx: *mut OsArena) -> VectorStr {
    let mut vec = VectorStr { data: std::ptr::null_mut(), len: 0, capacity: 0, arena: ctx };
    for i in 0..os_argc {
        let arg = *os_argv.add(i as usize);
        let len = std::ffi::CStr::from_ptr(arg).to_bytes().len() as i32;
        let dest = arena_alloc_bytes(ctx, len);
        std::ptr::copy_nonoverlapping(arg.cast::<u8>(), dest, len as usize);
        crate::fiber::vector_push_str(&mut vec, SliceU8 { data: dest, len });
    }
    vec
}

/// `Slice_unsigned_char os_MockPayload()`.
///
/// Allocates 1024 bytes the caller never frees, exactly as the C does. That
/// leak is the existing contract, not an oversight introduced here: the
/// three sentinel writes are what callers check, and changing the ownership
/// would change what the fixture tests.
#[no_mangle]
pub extern "C" fn os_MockPayload() -> SliceU8 {
    let mut buf = vec![0u8; 1024].into_boxed_slice();
    let ptr = buf.as_mut_ptr();
    std::mem::forget(buf);
    unsafe {
        let words = ptr.cast::<i32>();
        words.write(42);
        words.add(1).write(42);
        words.add(2).write(42);
    }
    SliceU8 { data: ptr, len: 1024 }
}

/// `void os_LogStr(Slice_unsigned_char s)` — stdout, newline-terminated.
///
/// # Safety
/// `s` must be a valid slice.
#[no_mangle]
pub unsafe extern "C" fn os_LogStr(s: SliceU8) {
    let bytes = if s.data.is_null() || s.len <= 0 {
        &[][..]
    } else {
        std::slice::from_raw_parts(s.data, s.len as usize)
    };
    let stdout = std::io::stdout();
    let mut out = stdout.lock();
    let _ = out.write_all(bytes);
    let _ = out.write_all(b"\n");
}

/// `void os_LogError(Slice_unsigned_char s)` — stderr, newline ADDED ONLY IF
/// absent, then flushed.
///
/// The conditional newline is load-bearing: callers that already terminate
/// their message must not get a blank line, and callers that do not must
/// not have their output run together. The C checks the last byte; so does
/// this.
///
/// # Safety
/// `s` must be a valid slice.
#[no_mangle]
pub unsafe extern "C" fn os_LogError(s: SliceU8) {
    let bytes = if s.data.is_null() || s.len <= 0 {
        &[][..]
    } else {
        std::slice::from_raw_parts(s.data, s.len as usize)
    };
    let stderr = std::io::stderr();
    let mut err = stderr.lock();
    let _ = err.write_all(bytes);
    if bytes.last() != Some(&b'\n') {
        let _ = err.write_all(b"\n");
    }
    let _ = err.flush();
}
