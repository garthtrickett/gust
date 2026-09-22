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

// ---------------------------------------------------------------------------
// Patch 25.10a: the other nine, and why they came here rather than staying
// generated.
//
// Patch 25.5 moved these to `compiler/runtime/strings.gst` and checked in
// what the emitter made of them as `src/runtime/strings.c`. The generator
// said so outright -- "It is a second generated artifact in the tree, like
// gust_v4.c, and the honest name for that is a second seed" -- and gave one
// reason for checking it in: `gust_bootstrap` was built from `gust_v4.c`
// plus `src/runtime.c`, so emitting the file needed a compiler and a
// build-time rule would be circular.
//
// Patch 25.9 removed that premise. `gust_bootstrap` is a downloaded,
// digest-verified bridge now, so the circularity is gone. But 25.10 deletes
// the emitter, and then the header's instruction -- "edit the Gust and
// re-run the script" -- names a script that cannot run. Worse than
// hand-written C: edit `strings.gst` and the shipped object silently never
// changes.
//
// The in-thesis fix would be to build `strings.o` from the Gust at build
// time. MEASURED, not assumed -- it is not available:
//
//   $ gust --backend cranelift -o /tmp/strings compiler/runtime/strings.gst
//   gust_native_capability_decision: decision=deferred
//       capability=phase13_generic_source_to_mir
//   Cranelift backend selection is valid, but the source-level route is
//   not connected yet.
//
// That is a Phase 13 residue, not something this phase can clear. So the
// choice was freeze the C or finish the file here, and the falsifier list
// decides it: `runtime-archive-is-glibc-bound` and `runtime-sources-are-c`
// are both recorded `cleared_by: 25.5 and 25.6 -- the runtime stops being
// C`, and neither is cleared while `$(CC)` compiles strings.c into
// `build/gust-runtime-package.a`. Freezing documents the second seed; it
// does not take the C compiler off the runtime's critical path, which is
// exactly what 25.11 needs.
//
// `compiler/runtime/strings.gst` STAYS. It is the behavioural reference
// these are ported against, and the thing to compile when
// phase13_generic_source_to_mir lands.
//
// Two properties of the C this replaces are load-bearing and easy to drop:
//
//   * `gust_tick()` at the top of every loop body. It is the fiber
//     preemption point. A port without it makes `std_str_find` over a long
//     haystack non-yielding, which is a scheduler regression that no string
//     test would show.
//   * the bounds checks call `gust_check_fail`, which does not return.
//     Rust's own panic is not the same observable: `gust_check_fail` is
//     what the rest of the runtime reports through.
//
// The `*_pthread_wrapper` symbols the emitter also produced are NOT ported.
// They are emitted for every function whether or not anything spawns it,
// and none of them appears in PHASE25_RUNTIME_RS_EXPORTS or in the objcopy
// keep-list -- so they were never part of the exported surface.

use crate::fiber::{gust_check_fail, gust_tick};
use crate::host_io::os_LogStr;

const BOUNDS_MESSAGE: &[u8] = b"Slice bounds check failed\0";

/// The `if (i < 0 || i >= len) gust_check_fail(...)` the emitter wraps every
/// slice index in. Kept as one helper so the nine below read like the Gust
/// rather than like the expansion.
#[inline]
unsafe fn at(s: &SliceU8, index: i32) -> u8 {
    if index < 0 || index >= s.len {
        gust_check_fail(BOUNDS_MESSAGE.as_ptr().cast::<i8>(), line!() as i32);
    }
    *s.data.offset(index as isize)
}

/// `void std_str_bounds_fail(Slice_unsigned_char what)`.
///
/// # Safety
/// `what` must be a valid slice.
#[no_mangle]
pub unsafe extern "C" fn std_str_bounds_fail(what: SliceU8) {
    os_LogStr(what);
    std::process::exit(1);
}

#[inline]
unsafe fn bounds_fail(message: &'static [u8]) {
    std_str_bounds_fail(SliceU8 {
        data: message.as_ptr() as *mut u8,
        len: message.len() as i32,
    });
}

/// `int std_str_eq(Slice_unsigned_char s1, Slice_unsigned_char s2)`.
///
/// # Safety
/// Both slices must be valid for their stated lengths.
#[no_mangle]
pub unsafe extern "C" fn std_str_eq(s1: SliceU8, s2: SliceU8) -> i32 {
    if s1.len != s2.len {
        return 0;
    }
    let mut i = 0;
    while i < s1.len {
        gust_tick();
        if at(&s1, i) != at(&s2, i) {
            return 0;
        }
        i += 1;
    }
    1
}

/// `unsigned char std_str_byte_at(Slice_unsigned_char s, int idx)`.
///
/// # Safety
/// `s` must be a valid slice.
#[no_mangle]
pub unsafe extern "C" fn std_str_byte_at(s: SliceU8, idx: i32) -> u8 {
    if idx < 0 || idx >= s.len {
        bounds_fail(b"std.str_byte_at bounds check failed");
    }
    at(&s, idx)
}

/// `unsigned char std_is_alpha(unsigned char b)`.
///
/// Underscore counts. That is the compiler's identifier rule, not an
/// oversight, and dropping it would silently change lexing.
#[no_mangle]
pub extern "C" fn std_is_alpha(b: u8) -> u8 {
    u8::from(b.is_ascii_alphabetic() || b == b'_')
}

/// `unsigned char std_is_digit(unsigned char b)`.
#[no_mangle]
pub extern "C" fn std_is_digit(b: u8) -> u8 {
    u8::from(b.is_ascii_digit())
}

/// `unsigned char std_is_whitespace(unsigned char b)`.
///
/// Space, tab, LF, CR. NOT `is_ascii_whitespace`, which also takes form
/// feed -- a wider set than the original accepted.
#[no_mangle]
pub extern "C" fn std_is_whitespace(b: u8) -> u8 {
    u8::from(matches!(b, b' ' | b'\t' | b'\n' | b'\r'))
}

/// `int std_str_find(Slice_unsigned_char s, Slice_unsigned_char target)`.
///
/// # Safety
/// Both slices must be valid for their stated lengths.
#[no_mangle]
pub unsafe extern "C" fn std_str_find(s: SliceU8, target: SliceU8) -> i32 {
    if target.len == 0 {
        return 0;
    }
    if s.len < target.len {
        return -1;
    }
    let mut i = 0;
    while i <= s.len - target.len {
        gust_tick();
        let mut j = 0;
        let mut hit = true;
        while j < target.len {
            gust_tick();
            if at(&s, i + j) != at(&target, j) {
                hit = false;
                j = target.len;
            } else {
                j += 1;
            }
        }
        if hit {
            return i;
        }
        i += 1;
    }
    -1
}

/// `Slice_unsigned_char std_str_slice(Slice_unsigned_char s, int start, int end)`.
///
/// Allocates nothing: the result borrows `s`. That is why it could leave C
/// at all, where std_Clone_str could not.
///
/// # Safety
/// `s` must be a valid slice.
#[no_mangle]
pub unsafe extern "C" fn std_str_slice(s: SliceU8, start: i32, end: i32) -> SliceU8 {
    if start < 0 || end < start || end > s.len {
        bounds_fail(b"std.str_slice bounds check failed");
    }
    SliceU8 { data: s.data.offset(start as isize), len: end - start }
}

/// `int std_parse_int(Slice_unsigned_char s)`.
///
/// Wrapping arithmetic on purpose. The C is `int` arithmetic with no
/// overflow check, so a long digit run wraps; Rust would panic in a debug
/// profile and diverge from the behaviour being ported.
///
/// # Safety
/// `s` must be a valid slice.
#[no_mangle]
pub unsafe extern "C" fn std_parse_int(s: SliceU8) -> i32 {
    if s.len <= 0 {
        return 0;
    }
    let mut index = 0;
    let mut sign = 1i32;
    match at(&s, 0) {
        b'-' => {
            sign = -1;
            index = 1;
        }
        b'+' => index = 1,
        _ => {}
    }
    let mut result = 0i32;
    while index < s.len {
        gust_tick();
        let c = at(&s, index);
        if !c.is_ascii_digit() {
            break;
        }
        result = result.wrapping_mul(10).wrapping_add((c - b'0') as i32);
        index += 1;
    }
    result.wrapping_mul(sign)
}

/// `Slice_unsigned_char std_str_trim(Slice_unsigned_char s)`.
///
/// # Safety
/// `s` must be a valid slice.
#[no_mangle]
pub unsafe extern "C" fn std_str_trim(s: SliceU8) -> SliceU8 {
    let mut start = 0;
    while start < s.len {
        gust_tick();
        if std_is_whitespace(at(&s, start)) == 0 {
            break;
        }
        start += 1;
    }
    let mut end = s.len;
    while end > start {
        gust_tick();
        if std_is_whitespace(at(&s, end - 1)) == 0 {
            break;
        }
        end -= 1;
    }
    std_str_slice(s, start, end)
}
