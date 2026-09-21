//! `scratch.c` to Rust (Patch 25.5).
//!
//! Ports cleanly where `gust_loop_ticks` could not, and the difference is
//! the ACCESS not the storage: every thread-local here is reached through a
//! function (`os_SetThreadScratch`, `os_GetThreadScratch_raw`,
//! `os_ScratchAlloc`, `os_ScratchReset`). Nothing outside reads the storage
//! as a symbol, so `thread_local!` is sufficient and no `__thread` data
//! export is needed.

use std::cell::{Cell, RefCell};
use crate::fiber::OsArena;

const GUST_SCRATCH_SIZE: usize = 131072;

extern "C" {
    fn os_Arena_New() -> OsArena;
    fn os_ArenaAlloc(arena: *mut OsArena, size: i32) -> i32;
}

thread_local! {
    /// The 128 KB fallback buffer, used when a program has NOT opted in to
    /// arena-backed scratch.
    static SCRATCH_BUFFER: RefCell<Vec<u8>> = RefCell::new(vec![0u8; GUST_SCRATCH_SIZE]);
    static SCRATCH_OFFSET: Cell<usize> = const { Cell::new(0) };
    /// The program's own arena, if it called os_SetThreadScratch.
    static ACTIVE_THREAD_ARENA: Cell<*mut OsArena> = const { Cell::new(std::ptr::null_mut()) };
    /// Scratch's OWN arena, created lazily.
    static SCRATCH_ARENA: RefCell<Option<Box<OsArena>>> = const { RefCell::new(None) };
}

/// `void os_SetThreadScratch(os_Arena* arena)`.
#[no_mangle]
pub extern "C" fn os_SetThreadScratch(arena: *mut OsArena) {
    ACTIVE_THREAD_ARENA.with(|a| a.set(arena));
}

/// `os_Arena* os_GetThreadScratch_raw()`.
#[no_mangle]
pub extern "C" fn os_GetThreadScratch_raw() -> *mut OsArena {
    ACTIVE_THREAD_ARENA.with(|a| a.get())
}

/// `void* os_ScratchAlloc(size_t size)`.
///
/// Scratch gets its OWN arena rather than the caller's, and the C's comment
/// explaining why is carried over rather than summarised, because it records
/// a measurement and a trap:
///
/// > RELOCATION IS NOT RECLAMATION. Nothing is reset here and no lifetime
/// > changes: with no reset, scratch memory stays valid for the whole
/// > process exactly as it does today. Every pointer valid before this
/// > change is valid after it.
/// >
/// > Why: os_ScratchAlloc took `active_thread_arena`, which programs set to
/// > their OWN arena, so every std.Concat and every int-to-string in
/// > compiled Gust permanently consumed the program's main arena. Measured
/// > while self-compiling the compiler: **1.98 GB across 15.8 million
/// > allocations**, 46% of a 4 GB arena that was 99.84% full with 9,584
/// > bytes to spare.
/// >
/// > SHARING, for whoever adds the reset later: `active_thread_arena` is
/// > saved and restored per fiber switch, so each fiber used to scratch into
/// > its own arena. This scratch arena is thread-local, so ALL FIBERS ON A
/// > THREAD NOW SHARE ONE SCRATCH ARENA. With no reset that is safe — merely
/// > shared. A future reset must account for it: rewinding this arena
/// > affects every fiber on the thread, not just the one that called.
///
/// # Safety
/// The returned pointer is valid for the process lifetime; there is no reset.
#[no_mangle]
pub unsafe extern "C" fn os_ScratchAlloc(size: usize) -> *mut std::ffi::c_void {
    let size = (size + 7) & !7usize;   // 8-byte alignment, as the C does
    if !ACTIVE_THREAD_ARENA.with(|a| a.get()).is_null() {
        return SCRATCH_ARENA.with(|cell| {
            let mut slot = cell.borrow_mut();
            if slot.is_none() {
                *slot = Some(Box::new(os_Arena_New()));
            }
            let arena: &mut OsArena = slot.as_mut().unwrap();
            let ptr: *mut OsArena = arena;
            let offset = os_ArenaAlloc(ptr, size as i32);
            (*ptr).base_address.cast::<u8>().add((offset as u32) as usize).cast()
        });
    }
    SCRATCH_BUFFER.with(|buf| {
        SCRATCH_OFFSET.with(|off| {
            let start = off.get();
            if start + size > GUST_SCRATCH_SIZE {
                // The C prints and exits. Same, but to stderr: a runtime
                // failure interleaved into stdout corrupts the program's
                // own output while reporting the fault.
                eprintln!("Out of thread-local scratch memory! Size requested: {size}");
                std::process::exit(1);
            }
            off.set(start + size);
            buf.borrow_mut().as_mut_ptr().add(start).cast()
        })
    })
}

/// `void os_ScratchReset()`.
///
/// Resets the 128 KB buffer only. It does NOT touch the scratch arena --
/// see the note above: that arena is shared by every fiber on the thread,
/// and rewinding it here would free memory other fibers still hold. The C
/// has the same asymmetry.
#[no_mangle]
pub extern "C" fn os_ScratchReset() {
    SCRATCH_OFFSET.with(|off| off.set(0));
}
