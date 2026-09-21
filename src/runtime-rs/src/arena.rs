//! `arena.c` to Rust (Patch 25.5).
//!
//! Layer 0: the allocator everything else sits on. D2 requires it to call
//! nothing in the runtime, and it does not — only the host allocator.
//!
//! The GUST_DEBUG canary path is NOT ported. It is `#ifdef`-gated and off in
//! every build this phase touches; reproducing it would mean carrying a
//! second, untested allocation layout. Recorded as a deliberate omission
//! rather than dropped silently — see the note on `os_Arena_Validate`.

use std::alloc::{alloc, dealloc, Layout};
use crate::fiber::OsArena;

/// 4 GB non-moving virtual arena capacity, as the C fixes it.
const ARENA_CAPACITY: usize = 4_294_967_296;

fn arena_layout(cap: usize) -> Layout {
    Layout::from_size_align(cap, 8).expect("arena layout")
}

/// `void os_Arena_Validate(os_Arena*)`.
///
/// A no-op, exactly as it is in every non-GUST_DEBUG build — the C body is
/// entirely inside `#ifdef GUST_DEBUG`. Kept as an exported symbol because
/// callers link against it and the registry lists it; removing it would be
/// an ABI change disguised as a simplification.
#[no_mangle]
pub extern "C" fn os_Arena_Validate(_arena: *mut OsArena) {}

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
    let a = &mut *arena;
    if a.offset + size > a.capacity {
        // stderr, flushed, and carrying the numbers. The C's comment explains
        // why, and it is worth keeping: this used to be a bare string on
        // stdout, and abort() terminates without flushing stdio. stdout is
        // fully buffered whenever redirected -- which every automated caller
        // does, make and CI included -- so the diagnostic was destroyed on
        // the way out and callers saw only SIGABRT. The request size and
        // current occupancy distinguish gradual exhaustion from a single
        // oversized request: different defects, different fixes.
        eprintln!(
            "Fatal Error: Out of Arena Capacity: requested {} bytes, \
             {} of {} already in use",
            size, a.offset, a.capacity
        );
        use std::io::Write;
        let _ = std::io::stderr().flush();
        std::process::abort();
    }
    let assigned = a.offset;
    std::ptr::write_bytes(a.base_address.cast::<u8>().add(assigned), 0, size);
    a.offset += size;
    (assigned as u32) as i32
}

/// `void os_LogInt(int val)`.
#[no_mangle]
pub extern "C" fn os_LogInt(val: i32) {
    println!("{val}");
}
