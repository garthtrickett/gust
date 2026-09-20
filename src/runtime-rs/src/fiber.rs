//! `fiber.c`'s scheduler, ported for Patch 25.6.
//!
//! This file is `std`, and that reverses Patch 25.4's `#![no_std]`. The
//! reason is `pthread_mutex_t`: it is an OPAQUE type whose size and
//! alignment are libc- and platform-specific -- measured 40 bytes / align 8
//! on glibc x86_64, and deliberately unspecified elsewhere. A `no_std` port
//! must hand-declare it as a guessed byte array per platform. Guess low and
//! the mutex scribbles adjacent memory; guess high and it wastes space. Both
//! are silent, and this patch is committed to four platform quadrants (O2,
//! D6) of which three cannot be built here -- so three of the four guesses
//! would be unverifiable in principle.
//!
//! Phase 25's gate is *no C compiler*, not *no libc*. Linking libc needs no
//! `cc`, so `std` costs the phase nothing it is trying to buy, and it
//! supplies `Mutex` with no layout to guess.
//!
//! The port is atomic: measured, sixteen of `fiber.c`'s twenty functions
//! share `gust_Fiber`, `active_shard`, `gust_shards` or `gust_fiber_switch`,
//! because every blocking primitive blocks the same way -- set the fiber's
//! state, push it on a queue, switch. There is no leaf to move first.

use std::cell::Cell;
use std::os::raw::c_void;

/// Matches `gust_FiberState` in `fiber.c`. Values are load-bearing: the
/// scheduler compares them across the C/Rust boundary while both halves
/// exist.
#[repr(C)]
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum FiberState {
    Running = 0,
    Ready = 1,
    Suspended = 2,
    Dead = 3,
}

/// Matches `struct gust_Fiber`. `#[repr(C)]` is required, not stylistic:
/// `gust_context_switch` is raw assembly that takes `&fiber.sp`, so `sp`
/// must stay at offset 0 and the whole layout must match what any remaining
/// C caller sees.
#[repr(C)]
pub struct Fiber {
    pub sp: *mut c_void,
    pub stack_base: *mut c_void,
    pub stack_size: usize,
    pub state: FiberState,
    pub parent: *mut Fiber,
    pub next: *mut Fiber,
    pub shard: *mut c_void,
    pub active_arena: *mut c_void,
}

// The scratch allocator lives in `scratch.c` at layer 1, below fiber at
// layer 3, so these are legal downward calls under the freestanding
// subset's layer order. They move the per-thread scratch arena across a
// context switch, which is why the switch is not just a register swap.
extern "C" {
    fn os_GetThreadScratch_raw() -> *mut c_void;
    fn os_SetThreadScratch(arena: *mut c_void);
    fn gust_context_switch(from_sp: *mut *mut c_void, to_sp: *mut c_void);
}

thread_local! {
    /// `GUST_THREAD_LOCAL int gust_loop_ticks`. Decremented by every loop
    /// codegen emits; when it reaches zero the fiber yields. This is the
    /// symbol that made 25.6 precede 25.5: compiled Gust references it
    /// unconditionally, so it must exist before any Gust runtime module can.
    static LOOP_TICKS: Cell<i32> = const { Cell::new(GUST_TICK_INTERVAL) };
}

pub const GUST_TICK_INTERVAL: i32 = 10_000;

/// `void gust_fiber_switch(gust_Fiber* from, gust_Fiber* to)`.
///
/// The scratch handoff happens BEFORE the register switch, in that order:
/// after `gust_context_switch` returns, execution is on the other fiber's
/// stack and the assignment to `from->active_arena` would land on the wrong
/// fiber. The C original has the same ordering for the same reason.
///
/// # Safety
/// `from` and `to` must be valid, distinct, and `to` must have a stack
/// prepared by `gust_fiber_create` or be a shard's root fiber.
#[no_mangle]
pub unsafe extern "C" fn gust_fiber_switch(from: *mut Fiber, to: *mut Fiber) {
    (*from).active_arena = os_GetThreadScratch_raw();
    os_SetThreadScratch((*to).active_arena);
    gust_context_switch(&mut (*from).sp, (*to).sp);
}
