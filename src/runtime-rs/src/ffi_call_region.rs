//! Private, call-scoped byte storage for the versioned Phase 26 FFI plan.
//!
//! The source compiler and native worker must authenticate the one direct call,
//! its owner, and the cleanup edge. These functions enforce the allocation and
//! byte-state part of that contract; a raw pointer alone grants no Gust owner.

use std::alloc::{alloc, dealloc, Layout};
use std::collections::HashSet;
use std::ptr;
use std::sync::{Mutex, OnceLock};

const PREPARED: u8 = 0;
const READABLE: u8 = 1;

#[repr(C)]
pub struct FfiCallRegionV1 {
    input: *mut u8,
    output: *mut u8,
    input_len: usize,
    output_cap: usize,
    accepted_count: usize,
    state: u8,
}

fn live_regions() -> &'static Mutex<HashSet<usize>> {
    static LIVE: OnceLock<Mutex<HashSet<usize>>> = OnceLock::new();
    LIVE.get_or_init(|| Mutex::new(HashSet::new()))
}

fn lock_regions() -> std::sync::MutexGuard<'static, HashSet<usize>> {
    live_regions()
        .lock()
        .unwrap_or_else(std::sync::PoisonError::into_inner)
}

fn rounded_eight(n: usize) -> Option<usize> {
    n.checked_add(7).map(|value| value & !7)
}

fn buffer_layout(logical: usize) -> Option<Layout> {
    Layout::from_size_align(rounded_eight(logical.max(1))?, 8).ok()
}

#[cfg(test)]
thread_local! {
    static FAIL_ALLOCATION_AT: std::cell::Cell<Option<usize>> = const { std::cell::Cell::new(None) };
    static ALLOCATION_NUMBER: std::cell::Cell<usize> = const { std::cell::Cell::new(0) };
    static FAIL_REGISTRY_RESERVE: std::cell::Cell<bool> = const { std::cell::Cell::new(false) };
    static LIVE_ALLOCATIONS: std::cell::Cell<usize> = const { std::cell::Cell::new(0) };
}

fn allocation_is_injected_failure() -> bool {
    #[cfg(test)]
    {
        return ALLOCATION_NUMBER.with(|number| {
            let current = number.get();
            number.set(current + 1);
            FAIL_ALLOCATION_AT.with(|failure| failure.get() == Some(current))
        });
    }
    #[cfg(not(test))]
    {
        false
    }
}

unsafe fn allocate_zeroed(layout: Layout) -> *mut u8 {
    if allocation_is_injected_failure() {
        return ptr::null_mut();
    }
    let address = alloc(layout);
    if !address.is_null() {
        ptr::write_bytes(address, 0, layout.size());
        #[cfg(test)]
        LIVE_ALLOCATIONS.with(|count| count.set(count.get() + 1));
    }
    address
}

unsafe fn release(address: *mut u8, layout: Layout) {
    dealloc(address, layout);
    #[cfg(test)]
    LIVE_ALLOCATIONS.with(|count| count.set(count.get() - 1));
}

fn registry_reserve_is_injected_failure() -> bool {
    #[cfg(test)]
    {
        return FAIL_REGISTRY_RESERVE.with(std::cell::Cell::get);
    }
    #[cfg(not(test))]
    {
        false
    }
}

/// Returns 0 with one live region, -1 for invalid size, or -2 for allocation
/// failure. On every failure a nonnull `out` is set to null and no owner exists.
///
/// # Safety
/// `out` must be null or a writable pointer to one region pointer.
#[no_mangle]
pub unsafe extern "C" fn os_FfiCallRegionTryCreate(
    input_len: i32,
    output_cap: i32,
    out: *mut *mut FfiCallRegionV1,
) -> i32 {
    if out.is_null() {
        return -1;
    }
    *out = ptr::null_mut();
    if input_len < 0 || output_cap < 0 {
        return -1;
    }
    let input_len = input_len as usize;
    let output_cap = output_cap as usize;
    let Some(header_size) = rounded_eight(std::mem::size_of::<FfiCallRegionV1>()) else {
        return -1;
    };
    let Some(input_layout) = buffer_layout(input_len) else {
        return -1;
    };
    let Some(output_layout) = buffer_layout(output_cap) else {
        return -1;
    };
    if header_size
        .checked_add(input_layout.size())
        .and_then(|total| total.checked_add(output_layout.size()))
        .is_none()
    {
        return -1;
    }

    let header_layout = Layout::new::<FfiCallRegionV1>();
    let header = allocate_zeroed(header_layout).cast::<FfiCallRegionV1>();
    if header.is_null() {
        return -2;
    }
    let input = allocate_zeroed(input_layout);
    if input.is_null() {
        release(header.cast(), header_layout);
        return -2;
    }
    let output = allocate_zeroed(output_layout);
    if output.is_null() {
        release(input, input_layout);
        release(header.cast(), header_layout);
        return -2;
    }
    ptr::write(
        header,
        FfiCallRegionV1 {
            input,
            output,
            input_len,
            output_cap,
            accepted_count: 0,
            state: PREPARED,
        },
    );
    let mut live = lock_regions();
    if registry_reserve_is_injected_failure() || live.try_reserve(1).is_err() {
        release(output, output_layout);
        release(input, input_layout);
        release(header.cast(), header_layout);
        return -2;
    }
    live.insert(header as usize);
    *out = header;
    0
}

/// # Safety
/// `region` may be null or an address previously returned by TryCreate.
#[no_mangle]
pub unsafe extern "C" fn os_FfiCallRegionWriteInput(
    region: *mut FfiCallRegionV1,
    index: i32,
    value: u8,
) -> i32 {
    let live = lock_regions();
    if !live.contains(&(region as usize)) || index < 0 {
        return -1;
    }
    let current = &mut *region;
    if current.state != PREPARED || index as usize >= current.input_len {
        return -1;
    }
    *current.input.add(index as usize) = value;
    0
}

/// # Safety
/// `region` may be null or an address previously returned by TryCreate.
#[no_mangle]
pub unsafe extern "C" fn os_FfiCallRegionInputAddress(region: *const FfiCallRegionV1) -> *const u8 {
    let live = lock_regions();
    if !live.contains(&(region as usize)) || (*region).state != PREPARED {
        return ptr::null();
    }
    (*region).input
}

/// # Safety
/// `region` may be null or an address previously returned by TryCreate.
#[no_mangle]
pub unsafe extern "C" fn os_FfiCallRegionOutputAddress(region: *mut FfiCallRegionV1) -> *mut u8 {
    let live = lock_regions();
    if !live.contains(&(region as usize)) || (*region).state != PREPARED {
        return ptr::null_mut();
    }
    (*region).output
}

/// # Safety
/// `region` may be null or an address previously returned by TryCreate.
#[no_mangle]
pub unsafe extern "C" fn os_FfiCallRegionAcceptResult(
    region: *mut FfiCallRegionV1,
    count: i32,
) -> i32 {
    let live = lock_regions();
    if !live.contains(&(region as usize)) || count < 0 {
        return -1;
    }
    let current = &mut *region;
    if current.state != PREPARED || count as usize > current.output_cap {
        return -1;
    }
    current.accepted_count = count as usize;
    current.state = READABLE;
    0
}

/// # Safety
/// `region` may be null or an address previously returned by TryCreate;
/// `out` must be null or writable for one byte.
#[no_mangle]
pub unsafe extern "C" fn os_FfiCallRegionReadOutput(
    region: *const FfiCallRegionV1,
    index: i32,
    out: *mut u8,
) -> i32 {
    let live = lock_regions();
    if !live.contains(&(region as usize)) || out.is_null() || index < 0 {
        return -1;
    }
    let current = &*region;
    if current.state != READABLE || index as usize >= current.accepted_count {
        return -1;
    }
    *out = *current.output.add(index as usize);
    0
}

/// End one successful acquisition. The compiler plan must call this once on
/// every ordinary exit after success and never on an acquisition failure.
///
/// # Safety
/// `region` must be a live region returned by TryCreate. A stale pointer is
/// rejected unless its address has been reused for a later live allocation;
/// the compiler's activation-bound owner proof prevents that ABA case.
#[no_mangle]
pub unsafe extern "C" fn os_FfiCallRegionFree(region: *mut FfiCallRegionV1) {
    let mut live = lock_regions();
    if !live.remove(&(region as usize)) {
        std::process::abort();
    }
    let current = &*region;
    let input_layout = buffer_layout(current.input_len).expect("live input layout");
    let output_layout = buffer_layout(current.output_cap).expect("live output layout");
    release(current.output, output_layout);
    release(current.input, input_layout);
    release(region.cast(), Layout::new::<FfiCallRegionV1>());
}

#[cfg(test)]
mod tests {
    use super::*;

    fn fail_at(ordinal: Option<usize>) {
        FAIL_ALLOCATION_AT.with(|failure| failure.set(ordinal));
        ALLOCATION_NUMBER.with(|number| number.set(0));
        FAIL_REGISTRY_RESERVE.with(|failure| failure.set(false));
    }

    fn outstanding() -> usize {
        LIVE_ALLOCATIONS.with(std::cell::Cell::get)
    }

    #[test]
    fn zero_sizes_have_distinct_storage_and_no_readable_byte() {
        unsafe {
            let mut region = ptr::null_mut();
            assert_eq!(os_FfiCallRegionTryCreate(0, 0, &mut region), 0);
            assert_eq!(outstanding(), 3);
            assert!(!region.is_null());
            let input = os_FfiCallRegionInputAddress(region);
            let output = os_FfiCallRegionOutputAddress(region);
            assert!(!input.is_null() && !output.is_null() && input != output);
            assert_eq!((input as usize) % 8, 0);
            assert_eq!((output as usize) % 8, 0);
            assert_eq!(os_FfiCallRegionWriteInput(region, -1, 7), -1);
            assert_eq!(os_FfiCallRegionWriteInput(region, 0, 7), -1);
            assert_eq!(os_FfiCallRegionAcceptResult(region, -1), -1);
            assert_eq!(os_FfiCallRegionAcceptResult(region, 0), 0);
            let mut byte = 91;
            assert_eq!(os_FfiCallRegionReadOutput(region, 0, &mut byte), -1);
            assert_eq!(byte, 91);
            assert!(os_FfiCallRegionInputAddress(region).is_null());
            os_FfiCallRegionFree(region);
            assert_eq!(outstanding(), 0);
            assert_eq!(os_FfiCallRegionReadOutput(region, 0, &mut byte), -1);
        }
    }

    #[test]
    fn allocation_failures_publish_no_owner() {
        unsafe {
            for ordinal in 0..3 {
                fail_at(Some(ordinal));
                let mut region = 1usize as *mut FfiCallRegionV1;
                assert_eq!(os_FfiCallRegionTryCreate(1, 1, &mut region), -2);
                assert!(region.is_null());
                assert_eq!(outstanding(), 0);
            }
            fail_at(None);
            FAIL_REGISTRY_RESERVE.with(|failure| failure.set(true));
            let mut region = 1usize as *mut FfiCallRegionV1;
            assert_eq!(os_FfiCallRegionTryCreate(1, 1, &mut region), -2);
            assert!(region.is_null());
            assert_eq!(outstanding(), 0);
            FAIL_REGISTRY_RESERVE.with(|failure| failure.set(false));
            let mut region = ptr::null_mut();
            assert_eq!(os_FfiCallRegionTryCreate(-1, 1, &mut region), -1);
            assert!(region.is_null());
            assert_eq!(os_FfiCallRegionTryCreate(1, 1, &mut region), 0);
            os_FfiCallRegionFree(region);
            assert_eq!(outstanding(), 0);
        }
    }

    #[test]
    fn output_requires_acceptance_and_validated_count() {
        unsafe {
            let mut region = ptr::null_mut();
            assert_eq!(os_FfiCallRegionTryCreate(2, 1, &mut region), 0);
            assert_eq!(outstanding(), 3);
            assert_eq!(os_FfiCallRegionWriteInput(region, 0, 42), 0);
            assert_eq!(os_FfiCallRegionWriteInput(region, 2, 42), -1);
            assert_eq!(*os_FfiCallRegionInputAddress(region), 42);
            let mut byte = 0;
            assert_eq!(os_FfiCallRegionReadOutput(region, 0, &mut byte), -1);
            assert_eq!(os_FfiCallRegionAcceptResult(region, 2), -1);
            assert_eq!(os_FfiCallRegionReadOutput(region, 0, &mut byte), -1);
            *os_FfiCallRegionOutputAddress(region) = 73;
            assert_eq!(os_FfiCallRegionAcceptResult(region, 1), 0);
            assert_eq!(os_FfiCallRegionReadOutput(region, 0, &mut byte), 0);
            assert_eq!(byte, 73);
            assert_eq!(os_FfiCallRegionWriteInput(region, 1, 3), -1);
            assert_eq!(os_FfiCallRegionAcceptResult(region, 1), -1);
            os_FfiCallRegionFree(region);
            assert_eq!(outstanding(), 0);
        }
    }
}
