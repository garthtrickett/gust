//! `strings.c`'s two arena-taking functions, ported for Patch 25.5.
//!
//! Nine of strings.c's eleven functions went to Gust. These two stayed, and
//! the reason is measured rather than stylistic: both allocate N RAW BYTES
//! from a caller-supplied arena, and Gust has no spelling for that.
//! `os.ArenaAlloc` takes one argument -- the allocator -- because Gust
//! allocates by TYPE through `ctx[T]` and codegen supplies the `sizeof`.
//! `os.ScratchAlloc` does take a byte count, which is why std_str_slice
//! could move, but scratch resets and a clone must outlive the scope.
//!
//! D2 allows Rust as the per-file fallback "on its own merits". Needing an
//! operation the language does not express is a merit.
//!
//! They live here rather than in fiber.rs, where the port first put them.
//! Patch 17.1 registers every runtime helper against the source unit that
//! defines it, and "strings.c's functions are in the scheduler" is not a
//! thing the census can be asked to say.

use crate::arena::os_ArenaAlloc;
use crate::fiber::{vector_push_str, OsArena, SliceU8, VectorStr};

/// `Slice_unsigned_char std_Clone_str(os_Arena* arena, Slice_unsigned_char s)`.
///
/// # Safety
/// `arena` must be a live arena; `s` must be a valid slice.
#[no_mangle]
pub unsafe extern "C" fn std_Clone_str(arena: *mut OsArena, s: SliceU8) -> SliceU8 {
    if s.data.is_null() || s.len <= 0 {
        return SliceU8 { data: std::ptr::null_mut(), len: 0 };
    }
    let offset = os_ArenaAlloc(arena, s.len as usize);
    // GUST_ARENA_OFFSET(offset) is ((size_t)(uint32_t)(offset)) -- the cast
    // through uint32_t is load-bearing, not decoration: a negative i32 must
    // become a large positive offset, exactly as the C does, or the copy
    // lands before the arena base.
    let byte_offset = (offset as u32) as usize;
    let dest = (*arena).base_address.cast::<u8>().add(byte_offset);
    std::ptr::copy_nonoverlapping(s.data, dest, s.len as usize);
    SliceU8 { data: dest, len: s.len }
}

/// `struct std_Vector_str std_str_split(Slice_unsigned_char s, Slice_unsigned_char delim, os_Arena* ctx)`.
///
/// The last of strings.c. It stayed out of Gust for the same reason
/// std_Clone_str did -- raw arena bytes -- and additionally because
/// os_VectorPush is a macro, so even a Gust caller could not reach it.
///
/// # Safety
/// `s`, `delim` and `ctx` must be valid.
#[no_mangle]
pub unsafe extern "C" fn std_str_split(s: SliceU8, delim: SliceU8, ctx: *mut OsArena) -> VectorStr {
    let mut vec = VectorStr {
        data: std::ptr::null_mut(), len: 0, capacity: 0, arena: ctx,
    };
    if delim.len == 0 {
        // The C emits one single-byte slice per input byte.
        for i in 0..s.len {
            vector_push_str(&mut vec, SliceU8 { data: s.data.add(i as usize), len: 1 });
        }
        return vec;
    }
    let mut start = 0i32;
    let mut i = 0i32;
    while i <= s.len - delim.len {
        let hit = std::slice::from_raw_parts(s.data.add(i as usize), delim.len as usize)
            == std::slice::from_raw_parts(delim.data, delim.len as usize);
        if hit {
            vector_push_str(&mut vec, SliceU8 {
                data: s.data.add(start as usize), len: i - start,
            });
            i += delim.len;
            start = i;
        } else {
            i += 1;
        }
    }
    // The C's trailing `if (start <= s.len)` is always true here, and emits
    // the final segment. Kept as an unconditional push so the element count
    // matches: a split with no match still yields one element, the whole
    // string, which several callers rely on.
    vector_push_str(&mut vec, SliceU8 {
        data: s.data.add(start as usize), len: s.len - start,
    });
    vec
}
