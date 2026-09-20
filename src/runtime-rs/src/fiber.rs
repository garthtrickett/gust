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
// The C stores shards in a global array reachable from every thread.
unsafe impl Send for SchedulerShard {}

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

// ---- scheduler lifecycle ------------------------------------------------

/// Shard storage. The C `malloc`s an array and hands out interior pointers
/// that fibers keep in `Fiber.shard`, so the addresses must be stable for
/// the scheduler's lifetime. Leaking each shard gives exactly that, and
/// `destroy` reclaims them explicitly -- matching the C, where the array is
/// freed only in `gust_scheduler_destroy`.
static SHARDS: Mutex<Vec<&'static mut SchedulerShard>> = Mutex::new(Vec::new());

/// A shard pointer crossing into its thread. The C passes `&gust_shards[i]`
/// to `pthread_create` directly; Rust needs the promise spelled out.
struct ShardPtr(*mut SchedulerShard);
unsafe impl Send for ShardPtr {}

/// `int get_num_threads_to_use()`.
///
/// Exported under its exact C name. It looks internal, but
/// `phase21_collection_string_native_source.sh` compares the runtime
/// archive's defined-symbol set EXACTLY, and this name is in that list --
/// so making it private would delete an expected export and fail the guard
/// with a symbol-set mismatch that says nothing about the port.
#[no_mangle]
pub extern "C" fn get_num_threads_to_use() -> i32 {
    num_threads_to_use() as i32
}

fn num_threads_to_use() -> usize {
    if let Ok(v) = std::env::var("GUST_THREADS") {
        // The C uses atoi, which yields 0 on garbage and is then rejected by
        // `val > 0`. parse().ok() rejects the same inputs without the
        // silent-zero step.
        if let Ok(n) = v.parse::<i32>() {
            if n > 0 {
                return n as usize;
            }
        }
    }
    std::thread::available_parallelism().map(|n| n.get()).unwrap_or(4)
}

fn empty_shard_fiber() -> Fiber {
    Fiber {
        sp: std::ptr::null_mut(),
        stack_base: std::ptr::null_mut(),
        stack_size: 0,
        state: FiberState::Running,
        parent: std::ptr::null_mut(),
        next: std::ptr::null_mut(),
        shard: std::ptr::null_mut(),
        active_arena: std::ptr::null_mut(),
    }
}

/// `void gust_scheduler_init(int num_shards)`.
#[no_mangle]
pub extern "C" fn gust_scheduler_init(num_shards: i32) {
    let n = if num_shards <= 0 { 1 } else { num_shards as usize };
    SCHEDULER_RUNNING.store(true, Ordering::SeqCst);
    let mut shards = SHARDS.lock().unwrap_or_else(|e| e.into_inner());
    for i in 0..n {
        let shard: &'static mut SchedulerShard = Box::leak(Box::new(SchedulerShard {
            id: i as i32,
            thread: None,
            queue: Mutex::new(ShardQueue {
                run_queue_head: std::ptr::null_mut(),
                run_queue_tail: std::ptr::null_mut(),
                active_fiber: std::ptr::null_mut(),
            }),
            shard_fiber: empty_shard_fiber(),
        }));
        let ptr = ShardPtr(shard as *mut SchedulerShard);
        shard.thread = Some(std::thread::spawn(move || {
            let p = ptr;
            shard_loop(p.0);
        }));
        shards.push(shard);
    }
}

/// `void gust_scheduler_destroy()`.
///
/// Drains before stopping, in that order. Setting `running = false` first
/// would strand queued fibers and let the host observe a completed scheduler
/// with work still pending -- the C drains first for the same reason.
#[no_mangle]
pub extern "C" fn gust_scheduler_destroy() {
    loop {
        let mut work_remaining = PENDING_FIBERS.load(Ordering::SeqCst) > 0;
        {
            let shards = SHARDS.lock().unwrap_or_else(|e| e.into_inner());
            for shard in shards.iter() {
                let q = lock_queue(shard);
                if !q.run_queue_head.is_null() || !q.active_fiber.is_null() {
                    work_remaining = true;
                }
            }
        }
        if !work_remaining {
            break;
        }
        std::thread::sleep(std::time::Duration::from_micros(1000));
    }

    SCHEDULER_RUNNING.store(false, Ordering::SeqCst);
    let mut shards = SHARDS.lock().unwrap_or_else(|e| e.into_inner());
    for shard in shards.iter_mut() {
        if let Some(handle) = shard.thread.take() {
            let _ = handle.join();
        }
        let mut curr = lock_queue(shard).run_queue_head;
        while !curr.is_null() {
            // SAFETY: the shard's thread has joined, so nothing else holds
            // or will observe these fibers.
            let next = unsafe { (*curr).next };
            unsafe { gust_fiber_free(curr) };
            curr = next;
        }
    }
    // Reclaim the leaked shards now that their threads are joined.
    for shard in shards.drain(..) {
        drop(unsafe { Box::from_raw(shard as *mut SchedulerShard) });
    }
}

// ---- fiber lifecycle ----------------------------------------------------

/// `gust_Fiber* gust_fiber_create(size_t, void (*)(void*), void*)`.
///
/// The stack layout is the delicate part and is NOT a translation choice:
/// it must match, register for register, what `gust_context_switch` pops.
/// That assembly moved to `fiber_asm.rs` byte-identically in this patch, so
/// the ordering below is copied from the C rather than reasoned out afresh.
///
/// # Safety
/// `entry_fn` must remain valid until the fiber runs, and `arg` must outlive
/// the fiber or be owned by it.
#[no_mangle]
pub unsafe extern "C" fn gust_fiber_create(
    stack_size: usize,
    entry_fn: Option<extern "C" fn(*mut c_void)>,
    arg: *mut c_void,
) -> *mut Fiber {
    let stack_size = if stack_size < 16384 { 16384 } else { stack_size };
    let layout = match std::alloc::Layout::from_size_align(stack_size, 16) {
        Ok(l) => l,
        Err(_) => return std::ptr::null_mut(),
    };
    let stack_base = std::alloc::alloc(layout);
    if stack_base.is_null() {
        return std::ptr::null_mut();
    }
    let fiber = Box::into_raw(Box::new(Fiber {
        sp: std::ptr::null_mut(),
        stack_base: stack_base as *mut c_void,
        stack_size,
        state: FiberState::Ready,
        parent: std::ptr::null_mut(),
        next: std::ptr::null_mut(),
        shard: std::ptr::null_mut(),
        active_arena: std::ptr::null_mut(),
    }));

    // 16-byte align the top, as the C does with `& ~15UL`.
    let top = ((stack_base as usize + stack_size) & !15usize) as *mut u64;
    let entry = entry_fn.map(|f| f as usize).unwrap_or(0) as u64;

    #[cfg(target_arch = "x86_64")]
    {
        let mut sp = top;
        sp = sp.offset(-1); *sp = (gust_fiber_entry_wrapper as unsafe extern "C" fn()) as usize as u64;
        sp = sp.offset(-1); *sp = 0;                       // rbp
        sp = sp.offset(-1); *sp = 0;                       // rbx
        sp = sp.offset(-1); *sp = entry;                   // r12
        sp = sp.offset(-1); *sp = arg as u64;              // r13
        sp = sp.offset(-1); *sp = fiber as u64;            // r14
        sp = sp.offset(-1); *sp = 0;                       // r15
        (*fiber).sp = sp as *mut c_void;
    }
    #[cfg(target_arch = "aarch64")]
    {
        let sp = top.offset(-12);
        *sp.offset(11) = (gust_fiber_entry_wrapper as unsafe extern "C" fn()) as usize as u64;
        for i in 3..=10 { *sp.offset(i) = 0; }
        *sp.offset(2) = fiber as u64;
        *sp.offset(1) = arg as u64;
        *sp.offset(0) = entry;
        (*fiber).sp = sp as *mut c_void;
    }
    #[cfg(not(any(target_arch = "x86_64", target_arch = "aarch64")))]
    {
        (*fiber).sp = top as *mut c_void;
    }
    fiber
}

/// `void gust_fiber_free(gust_Fiber*)`.
///
/// # Safety
/// `fiber` must have come from `gust_fiber_create` and must not be running.
#[no_mangle]
pub unsafe extern "C" fn gust_fiber_free(fiber: *mut Fiber) {
    if fiber.is_null() {
        return;
    }
    let f = Box::from_raw(fiber);
    if !f.stack_base.is_null() {
        if let Ok(layout) = std::alloc::Layout::from_size_align(f.stack_size, 16) {
            std::alloc::dealloc(f.stack_base as *mut u8, layout);
        }
    }
}

extern "C" {
    fn gust_fiber_entry_wrapper();
}

// ---- the shard loop -----------------------------------------------------

/// Pin this thread to `core_id`.
///
/// `std` has no affinity API, and `cpu_set_t` is another OPAQUE libc type --
/// the same trap that decided `no_std` against us. Avoided by going to the
/// KERNEL ABI instead of the libc struct: `sched_setaffinity` takes a size
/// in bytes and a bitmask, both stable, so a 128-byte buffer is correct
/// whatever libc declares `cpu_set_t` to be.
///
/// Linux only. The C also pinned on macOS via `thread_policy_set`, which has
/// no syscall equivalent; that quadrant is unpinned here and recorded rather
/// than silently dropped -- affinity is an optimisation, not a correctness
/// requirement, and three of four quadrants are unbuilt anyway.
#[cfg(target_os = "linux")]
fn pin_to_core(core_id: i32) {
    extern "C" {
        fn sched_setaffinity(pid: i32, cpusetsize: usize, mask: *const u64) -> i32;
    }
    if core_id < 0 || core_id >= 1024 {
        return;
    }
    let mut mask = [0u64; 16]; // 1024 bits, glibc's cpu_set_t size
    mask[(core_id / 64) as usize] = 1u64 << (core_id % 64);
    // Ignoring the result matches the C, which also ignores it: failing to
    // pin costs throughput, never correctness.
    unsafe { sched_setaffinity(0, std::mem::size_of_val(&mask), mask.as_ptr()) };
}

#[cfg(not(target_os = "linux"))]
fn pin_to_core(_core_id: i32) {}

/// `void* gust_shard_loop(void* arg)`.
///
/// Kept exported with the C signature for the same reason as
/// `get_num_threads_to_use`: it is in the exact symbol list that guard
/// compares. Rust spawns threads through `std::thread`, so nothing calls
/// this as a thread entry point any more -- but the runtime's export
/// surface is part of its shape, and dropping a symbol is as much a change
/// as adding one.
///
/// # Safety
/// `arg` must be a shard pointer from `gust_scheduler_init`.
#[no_mangle]
pub unsafe extern "C" fn gust_shard_loop(arg: *mut c_void) -> *mut c_void {
    shard_loop(arg as *mut SchedulerShard);
    std::ptr::null_mut()
}

fn shard_loop(shard_ptr: *mut SchedulerShard) {
    set_active_shard(shard_ptr);
    // SAFETY: shards are leaked by `init` and reclaimed by `destroy` only
    // after this thread has joined.
    let shard = unsafe { &*shard_ptr };
    pin_to_core(shard.id);

    while SCHEDULER_RUNNING.load(Ordering::SeqCst) {
        let next = {
            let mut q = lock_queue(shard);
            let next = q.run_queue_head;
            if !next.is_null() {
                unsafe {
                    q.run_queue_head = (*next).next;
                    if q.run_queue_head.is_null() {
                        q.run_queue_tail = std::ptr::null_mut();
                    }
                    (*next).next = std::ptr::null_mut();
                    // The C transitions state INSIDE the critical section
                    // "to prevent TOCTOU races during scheduler shutdown";
                    // destroy() reads active_fiber under the same lock, so
                    // publishing the fiber and its state together is what
                    // stops destroy seeing an empty shard with work in hand.
                    (*next).parent = &shard.shard_fiber as *const Fiber as *mut Fiber;
                    (*next).shard = shard_ptr as *mut c_void;
                    (*next).state = FiberState::Running;
                }
                q.active_fiber = next;
            }
            next
        };

        if next.is_null() {
            // `poll(NULL, 0, 1)` in the C: a 1 ms sleep, not a spin.
            std::thread::sleep(std::time::Duration::from_millis(1));
            continue;
        }

        unsafe {
            gust_fiber_switch(&shard.shard_fiber as *const Fiber as *mut Fiber, next);
        }
        lock_queue(shard).active_fiber = std::ptr::null_mut();

        if unsafe { (*next).state } == FiberState::Dead {
            PENDING_FIBERS.fetch_sub(1, Ordering::SeqCst);
            unsafe { gust_fiber_free(next) };
        }
    }
}
