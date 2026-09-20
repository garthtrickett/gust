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

// ---- scheduler state ----------------------------------------------------
//
// Ported faithfully rather than idiomatically: statics and raw pointers,
// mirroring the C. A port whose job is to be behaviour-identical is the
// wrong place to redesign ownership, and the fiber ABI is fixed by the
// assembly regardless -- `Fiber.sp` must stay where `gust_context_switch`
// expects it.
//
// `SchedulerShard` is deliberately NOT `#[repr(C)]`, unlike `Fiber`. It held
// `pthread_mutex_t` and `pthread_t`, the two opaque types that drove the
// `std` decision; here they are `Mutex` and `JoinHandle`, which have no
// layout to match. That is only sound because the port is atomic -- measured,
// sixteen of twenty functions share this state, so there is no intermediate
// build where C and Rust both see this struct.

use std::sync::{Mutex, MutexGuard};
use std::thread::JoinHandle;

pub struct ShardQueue {
    pub run_queue_head: *mut Fiber,
    pub run_queue_tail: *mut Fiber,
    pub active_fiber: *mut Fiber,
}

pub struct SchedulerShard {
    pub id: i32,
    pub thread: Option<JoinHandle<()>>,
    pub queue: Mutex<ShardQueue>,
    pub shard_fiber: Fiber,
}

// The C hands shard pointers between threads freely; the pointers inside are
// only ever dereferenced under `queue`'s lock or by the owning fiber.
unsafe impl Send for ShardQueue {}
unsafe impl Sync for SchedulerShard {}

thread_local! {
    /// `static GUST_THREAD_LOCAL gust_SchedulerShard* active_shard`.
    static ACTIVE_SHARD: Cell<*mut SchedulerShard> = const { Cell::new(std::ptr::null_mut()) };
}

pub(crate) fn active_shard() -> *mut SchedulerShard {
    ACTIVE_SHARD.with(|s| s.get())
}

pub(crate) fn set_active_shard(shard: *mut SchedulerShard) {
    ACTIVE_SHARD.with(|s| s.set(shard));
}

pub(crate) fn lock_queue(shard: &SchedulerShard) -> MutexGuard<'_, ShardQueue> {
    // The C calls pthread_mutex_lock and ignores failure. A poisoned lock
    // here means a fiber panicked mid-critical-section; the queue is still
    // structurally intact, so recover rather than abort the whole runtime
    // -- aborting would turn one fiber's bug into a scheduler shutdown.
    shard.queue.lock().unwrap_or_else(|e| e.into_inner())
}

use std::sync::atomic::{AtomicBool, AtomicI32, Ordering};

/// `static int gust_pending_fibers`. The C used `__sync_*` builtins, which
/// are full barriers; `SeqCst` is the equivalent and keeps the property the
/// C comment relies on -- a host thread observing zero also observes the
/// fiber's published result and other terminal writes.
pub(crate) static PENDING_FIBERS: AtomicI32 = AtomicI32::new(0);
pub(crate) static SCHEDULER_RUNNING: AtomicBool = AtomicBool::new(true);

/// `void gust_yield()`.
///
/// This is the function that made Patch 25.6 precede 25.5: codegen emits a
/// call to it in every `while` loop and every recursive function
/// (`codegen.gst:4018`, `:3870`), unconditionally and with no suppression
/// flag. Every compiled Gust program reaches it on every loop iteration.
///
/// Off a fiber -- on a plain host thread -- it degrades to a scheduler hint
/// rather than doing nothing, matching the C's `sched_yield()`.
#[no_mangle]
pub extern "C" fn gust_yield() {
    let shard_ptr = active_shard();
    if shard_ptr.is_null() {
        std::thread::yield_now();
        return;
    }
    // SAFETY: a non-null ACTIVE_SHARD is set only by `shard_loop` for the
    // lifetime of that thread, and shards outlive their threads.
    let shard = unsafe { &*shard_ptr };
    let current = lock_queue(shard).active_fiber;
    if current.is_null() {
        std::thread::yield_now();
        return;
    }
    unsafe {
        (*current).state = FiberState::Ready;
        (*current).next = std::ptr::null_mut();
        {
            let mut q = lock_queue(shard);
            if q.run_queue_tail.is_null() {
                q.run_queue_head = current;
            } else {
                (*q.run_queue_tail).next = current;
            }
            q.run_queue_tail = current;
        }
        // The switch happens OUTSIDE the lock. Holding it across the switch
        // would carry this thread's guard onto another fiber's stack and
        // deadlock the shard the moment that fiber touched the queue.
        gust_fiber_switch(current, &(*shard_ptr).shard_fiber as *const Fiber as *mut Fiber);
    }
}
