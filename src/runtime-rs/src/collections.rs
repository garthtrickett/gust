//! `collections.c` to Rust (Patch 25.5) — the generic hashmap and pool.
//!
//! Every function takes `void*` and element SIZES rather than a type, because
//! the C emitter monomorphises at the call site. That shape is preserved: it
//! is the ABI, and changing it would mean changing codegen too.
//!
//! Field order in both structs is unusual (`arena, capacity, keys, len,
//! occupied, values`) and is reproduced exactly. It is not alphabetical or
//! grouped-by-type, so it cannot be re-derived — only copied from
//! core_headers.h and checked.

use crate::fiber::{OsArena, SliceU8, arena_alloc_bytes};

/// Mirrors the anonymous struct `collections.c` re-declares in each function.
#[repr(C)]
pub struct GenericHashMap {
    pub arena: *mut OsArena,
    pub capacity: i32,
    pub keys: *mut u8,
    pub len: i32,
    pub occupied: *mut i32,
    pub values: *mut u8,
}

/// `GenericPool` — core_headers.h:54-63.
#[repr(C)]
pub struct GenericPool {
    pub arena: *mut OsArena,
    pub capacity: i32,
    pub data: *mut u8,
    pub free_len: i32,
    pub free_list: *mut i32,
    pub len: i32,
    pub occupied: *mut i32,
}

/// djb2, as `os_hash_key` in core_headers.h:147. Int keys hash to their own
/// value, which is not a hash at all — preserved because the probe sequence
/// depends on it and changing it would rehash every existing map.
unsafe fn hash_key(key_ptr: *const u8, is_str_key: i32) -> u32 {
    if is_str_key != 0 {
        let s = &*(key_ptr as *const SliceU8);
        let mut hash: u32 = 5381;
        for i in 0..s.len.max(0) {
            hash = hash.wrapping_shl(5).wrapping_add(hash).wrapping_add(*s.data.add(i as usize) as u32);
        }
        hash
    } else {
        *(key_ptr as *const i32) as u32
    }
}

/// `os_key_eq`. The corruption diagnostics in the C are not reproduced: they
/// are a debugging aid that prints and continues, and the comparison result
/// is unaffected by them.
unsafe fn key_eq(a: *const u8, b: *const u8, is_str_key: i32) -> bool {
    if is_str_key != 0 {
        let s1 = &*(a as *const SliceU8);
        let s2 = &*(b as *const SliceU8);
        if s1.len != s2.len { return false; }
        if s1.len <= 0 { return true; }
        std::slice::from_raw_parts(s1.data, s1.len as usize)
            == std::slice::from_raw_parts(s2.data, s2.len as usize)
    } else {
        *(a as *const i32) == *(b as *const i32)
    }
}

unsafe fn map_init(m: &mut GenericHashMap, cap: i32, key_size: usize, val_size: usize) {
    m.capacity = cap;
    m.keys = arena_alloc_bytes(m.arena, cap * key_size as i32);
    m.values = arena_alloc_bytes(m.arena, cap * val_size as i32);
    m.occupied = arena_alloc_bytes(m.arena, cap * std::mem::size_of::<i32>() as i32).cast();
    for i in 0..cap { m.occupied.add(i as usize).write(0); }
}

/// `void* os_HashMapRef_impl(void*, void*, int, size_t, size_t)`.
///
/// Inserts on miss and returns a pointer to the value slot either way --
/// that dual role is the contract, not an accident.
///
/// # Safety
/// `map_void` must point to a GenericHashMap with a live arena.
#[no_mangle]
pub unsafe extern "C" fn os_HashMapRef_impl(
    map_void: *mut u8, key_ptr: *mut u8, is_str_key: i32,
    key_size: usize, val_size: usize,
) -> *mut u8 {
    let m = &mut *(map_void as *mut GenericHashMap);
    if m.capacity == 0 {
        map_init(m, 16, key_size, val_size);
    }
    if m.len * 2 >= m.capacity {
        let old_cap = m.capacity;
        let (old_keys, old_vals, old_occ) = (m.keys, m.values, m.occupied);
        map_init(m, old_cap * 2, key_size, val_size);
        for i in 0..old_cap {
            if old_occ.add(i as usize).read() != 0 {
                let k = old_keys.add(i as usize * key_size);
                let mut idx = (hash_key(k, is_str_key) % m.capacity as u32) as i32;
                while m.occupied.add(idx as usize).read() != 0 {
                    idx = (idx + 1) % m.capacity;
                }
                std::ptr::copy_nonoverlapping(k, m.keys.add(idx as usize * key_size), key_size);
                std::ptr::copy_nonoverlapping(
                    old_vals.add(i as usize * val_size),
                    m.values.add(idx as usize * val_size), val_size);
                m.occupied.add(idx as usize).write(1);
            }
        }
    }
    let mut idx = (hash_key(key_ptr, is_str_key) % m.capacity as u32) as i32;
    let mut probes = 0;
    while m.occupied.add(idx as usize).read() != 0 {
        if key_eq(m.keys.add(idx as usize * key_size), key_ptr, is_str_key) {
            return m.values.add(idx as usize * val_size);
        }
        idx = (idx + 1) % m.capacity;
        probes += 1;
        if probes > m.capacity + 10 {
            // The C dumps the whole occupied array here. Keep the abort and
            // the numbers that distinguish the cause; drop the dump, which
            // can be 100k lines and is not what tells you what happened.
            eprintln!("HASHMAP INFINITE LOOP: capacity={} len={} key_size={} val_size={}",
                      m.capacity, m.len, key_size, val_size);
            std::process::abort();
        }
    }
    std::ptr::copy_nonoverlapping(key_ptr, m.keys.add(idx as usize * key_size), key_size);
    m.occupied.add(idx as usize).write(1);
    m.len += 1;
    m.values.add(idx as usize * val_size)
}

/// `int os_HashMapContains_impl(void*, void*, int, size_t)`.
///
/// # Safety
/// As `os_HashMapRef_impl`.
#[no_mangle]
pub unsafe extern "C" fn os_HashMapContains_impl(
    map_void: *mut u8, key_ptr: *mut u8, is_str_key: i32, key_size: usize,
) -> i32 {
    let m = &mut *(map_void as *mut GenericHashMap);
    if m.capacity == 0 { return 0; }
    let mut idx = (hash_key(key_ptr, is_str_key) % m.capacity as u32) as i32;
    while m.occupied.add(idx as usize).read() != 0 {
        if key_eq(m.keys.add(idx as usize * key_size), key_ptr, is_str_key) { return 1; }
        idx = (idx + 1) % m.capacity;
    }
    0
}

/// `void os_HashMapRemove_impl(void*, void*, int, size_t, size_t)`.
///
/// Backward-shift deletion, not tombstones: after clearing a slot it walks
/// the probe run and moves any entry whose ideal position is now reachable.
/// The wrap-around condition is copied verbatim from the C, because getting
/// it subtly wrong leaves entries unreachable rather than crashing.
///
/// # Safety
/// As `os_HashMapRef_impl`.
#[no_mangle]
pub unsafe extern "C" fn os_HashMapRemove_impl(
    map_void: *mut u8, key_ptr: *mut u8, is_str_key: i32,
    key_size: usize, val_size: usize,
) {
    let m = &mut *(map_void as *mut GenericHashMap);
    if m.capacity == 0 { return; }
    let mut idx = (hash_key(key_ptr, is_str_key) % m.capacity as u32) as i32;
    while m.occupied.add(idx as usize).read() != 0 {
        if key_eq(m.keys.add(idx as usize * key_size), key_ptr, is_str_key) {
            m.occupied.add(idx as usize).write(0);
            m.len -= 1;
            let mut i = idx;
            let mut j = (i + 1) % m.capacity;
            while m.occupied.add(j as usize).read() != 0 {
                let k = m.keys.add(j as usize * key_size);
                let r = (hash_key(k, is_str_key) % m.capacity as u32) as i32;
                if (i < j && (r <= i || r > j)) || (i > j && (r <= i && r > j)) {
                    std::ptr::copy_nonoverlapping(k, m.keys.add(i as usize * key_size), key_size);
                    std::ptr::copy_nonoverlapping(
                        m.values.add(j as usize * val_size),
                        m.values.add(i as usize * val_size), val_size);
                    m.occupied.add(i as usize).write(1);
                    m.occupied.add(j as usize).write(0);
                    i = j;
                }
                j = (j + 1) % m.capacity;
            }
            return;
        }
        idx = (idx + 1) % m.capacity;
    }
}

/// `void os_HashMapClear_impl(void*, size_t, size_t)`.
///
/// # Safety
/// As `os_HashMapRef_impl`.
#[no_mangle]
pub unsafe extern "C" fn os_HashMapClear_impl(map_void: *mut u8, _key_size: usize, _val_size: usize) {
    let m = &mut *(map_void as *mut GenericHashMap);
    if m.capacity == 0 { return; }
    m.len = 0;
    std::ptr::write_bytes(m.occupied, 0, m.capacity as usize);
}

unsafe fn pool_init(p: &mut GenericPool, elem_size: usize) {
    p.capacity = 16;
    p.data = arena_alloc_bytes(p.arena, p.capacity * elem_size as i32);
    p.occupied = arena_alloc_bytes(p.arena, p.capacity * 4).cast();
    for i in 0..p.capacity { p.occupied.add(i as usize).write(0); }
    p.free_list = arena_alloc_bytes(p.arena, p.capacity * 4).cast();
    p.free_len = 0;
    p.len = 0;
}

/// `int std_PoolAlloc_impl(void* pool_void, size_t elem_size)`.
///
/// Reuses a freed index before growing — the free list is LIFO, so the most
/// recently freed slot comes back first.
///
/// # Safety
/// `pool_void` must point to a GenericPool with a live arena.
#[no_mangle]
pub unsafe extern "C" fn std_PoolAlloc_impl(pool_void: *mut u8, elem_size: usize) -> i32 {
    let p = &mut *(pool_void as *mut GenericPool);
    if p.capacity == 0 {
        pool_init(p, elem_size);
    }
    let index;
    if p.free_len > 0 {
        p.free_len -= 1;
        index = p.free_list.add(p.free_len as usize).read();
    } else {
        if p.len >= p.capacity {
            let old_cap = p.capacity;
            p.capacity *= 2;
            let (old_data, old_occ, old_free) = (p.data, p.occupied, p.free_list);

            p.data = arena_alloc_bytes(p.arena, p.capacity * elem_size as i32);
            std::ptr::copy_nonoverlapping(old_data, p.data, old_cap as usize * elem_size);

            p.occupied = arena_alloc_bytes(p.arena, p.capacity * 4).cast();
            std::ptr::copy_nonoverlapping(old_occ, p.occupied, old_cap as usize);
            for i in old_cap..p.capacity { p.occupied.add(i as usize).write(0); }

            p.free_list = arena_alloc_bytes(p.arena, p.capacity * 4).cast();
            std::ptr::copy_nonoverlapping(old_free, p.free_list, old_cap as usize);
        }
        index = p.len;
        p.len += 1;
    }
    p.occupied.add(index as usize).write(1);
    index
}

/// `void std_PoolFree_impl(void* pool_void, int index)`.
///
/// # Safety
/// `pool_void` must point to a GenericPool.
#[no_mangle]
pub unsafe extern "C" fn std_PoolFree_impl(pool_void: *mut u8, index: i32) {
    let p = &mut *(pool_void as *mut GenericPool);
    if index < 0 || index >= p.len {
        // stderr rather than the C's stdout printf, for the reason every
        // other diagnostic in this port moved: a fatal message on stdout
        // corrupts the program's own output on the way out.
        eprintln!("Pool index out of bounds on Free");
        std::process::exit(1);
    }
    p.occupied.add(index as usize).write(0);
    p.free_list.add(p.free_len as usize).write(index);
    p.free_len += 1;
}
