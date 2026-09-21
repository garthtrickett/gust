//! `arena.c` to Rust (Patch 25.5).
//!
//! Layer 0: the allocator everything else sits on. D2 requires it to call
//! nothing in the runtime, and it does not — only the host allocator.
//!
//! The GUST_DEBUG canary path IS ported, behind the `gust_debug` cargo
//! feature. An earlier version of this file said it was "off in every build
//! this phase touches" and skipped it. That was wrong and a test caught it:
//! `tests/test_runner.gst` compiles anything whose path matches `canary`
//! with `-DGUST_DEBUG`, and `tests/e2e_arena_canary_corruption_detection`
//! exists precisely to make the validator abort. With the path missing it
//! "exited cleanly with status 0" — a negative test that stopped being able
//! to fail.
//!
//! The port is not a transcription, because the mechanism cannot be. In C
//! the `#ifdef` was per translation unit, so one source produced whichever
//! arena the including build asked for. A Rust staticlib is built once and
//! linked into both, so the switch has to move from the compiler to the
//! BUILD: `--features gust_debug` produces a second archive, and the test
//! runner links that one for exactly the tests it compiles with
//! `-DGUST_DEBUG`. Two archives is the honest analogue of two `#ifdef`
//! branches; a runtime flag would have been a third behaviour neither build
//! had.

use std::alloc::{alloc, dealloc, Layout};
use crate::fiber::OsArena;

/// 4 GB non-moving virtual arena capacity, as the C fixes it.
const ARENA_CAPACITY: usize = 4_294_967_296;

fn arena_layout(cap: usize) -> Layout {
    Layout::from_size_align(cap, 8).expect("arena layout")
}

/// The canary word the C writes either side of every payload.
#[cfg(feature = "gust_debug")]
const CANARY: u64 = 0xDEAD_BEEF_DEAD_BEEF;

/// `void os_Arena_Validate(os_Arena*)` — a no-op without `gust_debug`.
///
/// Exactly as it is in every non-GUST_DEBUG build: the C body is entirely
/// inside `#ifdef GUST_DEBUG`. Kept as an exported symbol because callers
/// link against it and the registry lists it; removing it would be an ABI
/// change disguised as a simplification.
#[cfg(not(feature = "gust_debug"))]
#[no_mangle]
pub extern "C" fn os_Arena_Validate(_arena: *mut OsArena) {}

/// `void os_Arena_Validate(os_Arena*)` — the GUST_DEBUG body.
///
/// Walks every block from the base and checks both canaries. Blocks are
/// `[size: 8][pre: 8][payload: size][post: 8]`, so the stride is
/// `8 + 8 + size + 8` and the walk is only well-defined from offset zero —
/// there is no way to find block N without reading blocks 0..N.
///
/// The abort messages are byte-identical to the C's, including the offset,
/// because `e2e_arena_canary_corruption_detection` is a negative test and
/// its expectation is the output.
///
/// # Safety
/// `arena` must be null or a live arena whose blocks were allocated by the
/// `gust_debug` `os_ArenaAlloc`. Validating a non-canary arena reads its
/// payload as a length and walks off into it.
#[cfg(feature = "gust_debug")]
#[no_mangle]
pub unsafe extern "C" fn os_Arena_Validate(arena: *mut OsArena) {
    if arena.is_null() || (*arena).base_address.is_null() {
        return;
    }
    let base = (*arena).base_address.cast::<u8>();
    let mut curr = 0usize;
    while curr < (*arena).offset {
        let size = base.add(curr).cast::<usize>().read();
        let pre = base.add(curr + 8).cast::<u64>().read();
        let post = base.add(curr + 8 + 8 + size).cast::<u64>().read();
        if pre != CANARY {
            canary_abort("Pre", curr);
        }
        if post != CANARY {
            canary_abort("Post", curr);
        }
        curr += 8 + 8 + size + 8;
    }
}

/// stdout and flushed, as the C does. `abort()` does not flush stdio, and
/// stdout is fully buffered when redirected — which the test runner does —
/// so an unflushed message is destroyed on the way out and the test sees
/// only SIGABRT.
#[cfg(feature = "gust_debug")]
fn canary_abort(which: &str, offset: usize) -> ! {
    use std::io::Write;
    println!(
        "GUST_DEBUG Assertion Failure: {which}-canary boundary corruption \
         detected at offset {offset}!"
    );
    let _ = std::io::stdout().flush();
    std::process::abort();
}

/// `os_Arena os_Arena_New()` — returned BY VALUE, as the C does.
#[no_mangle]
pub extern "C" fn os_Arena_New() -> OsArena {
    let base = unsafe { alloc(arena_layout(ARENA_CAPACITY)) };
    if base.is_null() {
        eprintln!("Fatal Error: Failed to allocate arena base memory!");
        std::process::exit(1);
    }
    OsArena { base_address: base.cast(), offset: 0, capacity: ARENA_CAPACITY }
}

/// `void os_Arena_Free(os_Arena*)`.
///
/// # Safety
/// `arena` must point to an arena from `os_Arena_New`, not yet freed.
#[no_mangle]
pub unsafe extern "C" fn os_Arena_Free(arena: *mut OsArena) {
    if arena.is_null() || (*arena).base_address.is_null() {
        return;
    }
    // The C validates on the way out under GUST_DEBUG, which is what makes
    // a corruption that happens after the last allocation detectable at all.
    #[cfg(feature = "gust_debug")]
    os_Arena_Validate(arena);
    dealloc((*arena).base_address.cast(), arena_layout((*arena).capacity));
    (*arena).base_address = std::ptr::null_mut();
}

/// `void std_GenerationalSwap(os_Arena* current, os_Arena* next)`.
///
/// # Safety
/// Both pointers must be live arenas.
#[no_mangle]
pub unsafe extern "C" fn std_GenerationalSwap(current: *mut OsArena, next: *mut OsArena) {
    os_Arena_Free(current);
    std::ptr::write(current, std::ptr::read(next));
    std::ptr::write(next, os_Arena_New());
}

/// The exhaustion diagnostic, shared by both allocators so the two builds
/// cannot drift apart in what they say.
///
/// stderr, flushed, and carrying the numbers. The C's comment explains why
/// and it is worth keeping: this used to be a bare string on stdout, and
/// `abort()` terminates without flushing stdio. stdout is fully buffered
/// whenever redirected -- which every automated caller does, make and CI
/// included -- so the diagnostic was destroyed on the way out and callers
/// saw only SIGABRT. The request size and current occupancy distinguish
/// gradual exhaustion from a single oversized request: different defects,
/// different fixes.
fn out_of_capacity(size: usize, offset: usize, capacity: usize) -> ! {
    use std::io::Write;
    eprintln!(
        "Fatal Error: Out of Arena Capacity: requested {size} bytes, \
         {offset} of {capacity} already in use"
    );
    let _ = std::io::stderr().flush();
    std::process::abort();
}

/// `int os_ArenaAlloc(os_Arena* arena, size_t size)` — bump allocation.
///
/// Returns the payload OFFSET, truncated through `uint32_t`, which is what
/// GUST_ARENA_OFFSET casts back. The truncation is part of the ABI, not an
/// accident: callers reconstruct the pointer as
/// `base + (size_t)(uint32_t)offset`.
///
/// # Safety
/// `arena` must be a live arena.
#[no_mangle]
pub unsafe extern "C" fn os_ArenaAlloc(arena: *mut OsArena, size: usize) -> i32 {
    let size = (size + 7) & !7usize;      // 8-byte hardware alignment

    // The GUST_DEBUG allocator. Every allocation validates the WHOLE arena
    // first, which is quadratic and deliberate: it is what turns "something
    // corrupted memory" into "something corrupted memory before this call".
    // The C does the same and only ever runs in the canary tests.
    #[cfg(feature = "gust_debug")]
    {
        os_Arena_Validate(arena);
        let a = &mut *arena;
        let total = 8 + 8 + size + 8;
        if a.offset + total > a.capacity {
            out_of_capacity(size, a.offset, a.capacity);
        }
        let header = a.offset;
        let pre = header + 8;
        let payload = pre + 8;
        let post = payload + size;
        let base = a.base_address.cast::<u8>();
        base.add(header).cast::<usize>().write(size);
        base.add(pre).cast::<u64>().write(CANARY);
        base.add(post).cast::<u64>().write(CANARY);
        std::ptr::write_bytes(base.add(payload), 0, size);
        a.offset += total;
        return (payload as u32) as i32;
    }

    #[cfg(not(feature = "gust_debug"))]
    {
    let a = &mut *arena;
    if a.offset + size > a.capacity {
        out_of_capacity(size, a.offset, a.capacity);
    }
    let assigned = a.offset;
    std::ptr::write_bytes(a.base_address.cast::<u8>().add(assigned), 0, size);
    a.offset += size;
    (assigned as u32) as i32
    }
}

/// `void os_LogInt(int val)`.
#[no_mangle]
pub extern "C" fn os_LogInt(val: i32) {
    println!("{val}");
}
