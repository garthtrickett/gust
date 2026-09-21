//! `file_io.c` to Rust (Patch 25.5) — the last of the six runtime files.
//!
//! Everything here needs the host: the filesystem, the environment, the
//! process table. None of it can be Gust, so all of it is Rust.
//!
//! Three places where a faithful port is not the obvious port, each marked
//! at its definition:
//!
//!   * `os_System` returns the RAW wait status, not an exit code;
//!   * `os_ReadDir` must keep yielding `.` and `..`, which `std::fs::ReadDir`
//!     filters out, so this goes to `opendir`/`readdir` directly;
//!   * paths are TRUNCATED at an interior NUL rather than rejected, because
//!     that is what handing a byte buffer to a C API does.

use std::ffi::{CString, c_char, c_void};
use std::io::{Read, Write};
use std::os::unix::ffi::OsStrExt;
use std::os::unix::process::ExitStatusExt;
use std::path::PathBuf;
use std::sync::Mutex;

use crate::fiber::{OsArena, SliceU8, VectorStr, arena_alloc_bytes};

// ---- the C structs, field order copied from core_headers.h --------------
//
// As with collections.rs, these orders are not derivable: codegen emits
// struct literals positionally, so a field swap here is silent corruption
// rather than a type error. `os_DirEntry` in particular declares `is_dir`
// BEFORE `name`, which is the opposite of the order the C body assigns them
// in.

#[repr(C)]
pub struct OsDir {
    pub handle: *mut u8,
}

#[repr(C)]
pub struct OsDirEntry {
    pub is_dir: i32,
    pub name: SliceU8,
}

#[repr(C)]
pub struct LookupResultOsDir {
    pub ok: i32,
    pub val: OsDir,
}

#[repr(C)]
pub struct LookupResultOsDirEntry {
    pub ok: i32,
    pub val: OsDirEntry,
}

#[repr(C)]
pub struct OsProcessResult {
    pub status: i32,
    pub stdout_text: SliceU8,
    pub stderr_text: SliceU8,
}

// ---- slice <-> path helpers ---------------------------------------------

const EMPTY: SliceU8 = SliceU8 { data: std::ptr::null_mut(), len: 0 };

/// The bytes of `s`, TRUNCATED at the first NUL.
///
/// The C builds a NUL-terminated copy and hands it to `fopen`/`opendir`, so
/// a slice carrying an interior NUL is silently cut short. Rust's `CString`
/// would reject it instead. Rejecting is arguably better, but it is a
/// DIFFERENT function: a caller that today opens `"a"` from `"a\0b"` would
/// start getting a failure. Truncating keeps the port a port.
///
/// # Safety
/// `s` must be a valid slice or have a null `data`.
unsafe fn slice_bytes(s: SliceU8) -> Vec<u8> {
    if s.data.is_null() || s.len <= 0 {
        return Vec::new();
    }
    let raw = std::slice::from_raw_parts(s.data, s.len as usize);
    let end = raw.iter().position(|&b| b == 0).unwrap_or(raw.len());
    raw[..end].to_vec()
}

/// # Safety
/// `s` must be a valid slice or have a null `data`.
unsafe fn slice_path(s: SliceU8) -> PathBuf {
    PathBuf::from(std::ffi::OsStr::from_bytes(&slice_bytes(s)).to_owned())
}

/// # Safety
/// `s` must be a valid slice or have a null `data`.
unsafe fn slice_cstring(s: SliceU8) -> CString {
    // Unwrap cannot fire: slice_bytes has already cut at the first NUL.
    CString::new(slice_bytes(s)).expect("truncated at first NUL")
}

/// Copy `bytes` into `arena`, returning the slice. Empty input gives the C's
/// `{NULL, 0}` rather than a zero-length allocation.
///
/// # Safety
/// `arena` must be a live arena.
unsafe fn bytes_to_arena(arena: *mut OsArena, bytes: &[u8]) -> SliceU8 {
    if bytes.is_empty() {
        return EMPTY;
    }
    let dest = arena_alloc_bytes(arena, bytes.len() as i32);
    std::ptr::copy_nonoverlapping(bytes.as_ptr(), dest, bytes.len());
    SliceU8 { data: dest, len: bytes.len() as i32 }
}

// ---- files ---------------------------------------------------------------

/// `Slice_unsigned_char os_ReadFile(os_Arena* arena, Slice_unsigned_char path)`.
///
/// The arena allocation happens BEFORE the read and is sized from the seek,
/// so a short read leaves the tail allocated and the returned `len` short —
/// same as the C, which sets `len` from `fread`'s return, not from `size`.
///
/// # Safety
/// `arena` must be a live arena; `path` must be a valid slice.
#[no_mangle]
pub unsafe extern "C" fn os_ReadFile(arena: *mut OsArena, path: SliceU8) -> SliceU8 {
    let Ok(mut f) = std::fs::File::open(slice_path(path)) else {
        return EMPTY;
    };
    let Ok(size) = f.seek_end_then_start() else {
        return EMPTY;
    };

    let offset = crate::arena::os_ArenaAlloc(arena, size);
    let buffer = (*arena).base_address.cast::<u8>().add((offset as u32) as usize);

    // `fread(buffer, 1, size, f)` loops internally until `size` bytes, EOF or
    // error. A single `Read::read` does not, so this loops.
    let mut read_bytes = 0usize;
    while read_bytes < size {
        match f.read(std::slice::from_raw_parts_mut(buffer.add(read_bytes), size - read_bytes)) {
            Ok(0) | Err(_) => break,
            Ok(n) => read_bytes += n,
        }
    }
    SliceU8 { data: buffer, len: read_bytes as i32 }
}

trait SeekSize {
    fn seek_end_then_start(&mut self) -> std::io::Result<usize>;
}

impl SeekSize for std::fs::File {
    /// `fseek(END); ftell(); fseek(SET)` — the C's way of sizing a file, kept
    /// rather than replaced by `metadata().len()` because the two disagree on
    /// anything that is not a regular file, and `fopen` succeeds on plenty of
    /// things that are not.
    fn seek_end_then_start(&mut self) -> std::io::Result<usize> {
        use std::io::Seek;
        let size = self.seek(std::io::SeekFrom::End(0))?;
        self.seek(std::io::SeekFrom::Start(0))?;
        Ok(size as usize)
    }
}

/// `int os_WriteFile(Slice_unsigned_char path, Slice_unsigned_char contents)`.
///
/// The `fsync` is not incidental. Several callers write a file and then hand
/// its path to a spawned process, and the C added the flush plus fsync for
/// that; `File`'s drop flushes to the kernel but does not sync, so the sync
/// is explicit here.
///
/// # Safety
/// Both slices must be valid.
#[no_mangle]
pub unsafe extern "C" fn os_WriteFile(path: SliceU8, contents: SliceU8) -> i32 {
    let bytes = if contents.data.is_null() || contents.len <= 0 {
        &[][..]
    } else {
        std::slice::from_raw_parts(contents.data, contents.len as usize)
    };
    if contents.len > 0 && bytes.is_empty() {
        return 0; // null data with a positive len; the C would fault here
    }
    let Ok(mut f) = std::fs::File::create(slice_path(path)) else {
        return 0;
    };
    if f.write_all(bytes).is_err() || f.flush().is_err() || f.sync_all().is_err() {
        return 0;
    }
    1
}

/// `int os_FileExists(Slice_unsigned_char path)` — `access(F_OK)`.
///
/// Not `Path::exists()`: that stats and follows symlinks to decide, while
/// `access` asks the kernel the permission question directly. They differ on
/// a dangling symlink and on directories the caller cannot search.
///
/// # Safety
/// `path` must be a valid slice.
#[no_mangle]
pub unsafe extern "C" fn os_FileExists(path: SliceU8) -> i32 {
    access_mode(path, 0) // F_OK
}

/// `int os_FileExecutable(Slice_unsigned_char path)` — `access(X_OK)`.
///
/// `access` tests the REAL uid, not the effective one, and no `std` API does
/// that; checking the mode bits would answer a different question.
///
/// # Safety
/// `path` must be a valid slice.
#[no_mangle]
pub unsafe extern "C" fn os_FileExecutable(path: SliceU8) -> i32 {
    access_mode(path, 1) // X_OK
}

/// # Safety
/// `path` must be a valid slice.
unsafe fn access_mode(path: SliceU8, mode: i32) -> i32 {
    extern "C" {
        fn access(pathname: *const c_char, mode: i32) -> i32;
    }
    i32::from(access(slice_cstring(path).as_ptr(), mode) == 0)
}

/// `int os_RemoveFile(Slice_unsigned_char path)`.
///
/// Returns 1 when the file is gone AFTERWARDS, which includes the case where
/// it was never there. Callers use it to clear a scratch path, so ENOENT is
/// success, not failure.
///
/// # Safety
/// `path` must be a valid slice.
#[no_mangle]
pub unsafe extern "C" fn os_RemoveFile(path: SliceU8) -> i32 {
    match std::fs::remove_file(slice_path(path)) {
        Ok(()) => 1,
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => 1,
        Err(_) => 0,
    }
}

// ---- directories ---------------------------------------------------------
//
// `std::fs::ReadDir` cannot be used here, for a reason that is easy to miss:
// it FILTERS OUT `.` and `..`. The C hands back whatever `readdir` yields,
// so a caller walking a tree sees those two entries and is written to skip
// them. Swapping in `ReadDir` would change what the runtime returns and the
// change would look like a cleanup.
//
// So this calls `opendir`/`readdir`/`closedir` and reads two fields out of
// `struct dirent`. That layout is a guess -- the trap P17 named -- so it is
// checked two ways in abi-tests/abi_smoke.c: `_Static_assert` on the offsets
// against the real header, and a behavioural test that a `.`, a `..`, a file
// and a subdirectory all come back with the right names and `is_dir`.

#[cfg(target_os = "linux")]
#[repr(C)]
struct Dirent {
    d_ino: u64,
    d_off: i64,
    d_reclen: u16,
    d_type: u8,
    d_name: [c_char; 256],
}

#[cfg(target_os = "linux")]
const DT_DIR: u8 = 4;

#[cfg(target_os = "linux")]
extern "C" {
    fn opendir(name: *const c_char) -> *mut c_void;
    fn closedir(dirp: *mut c_void) -> i32;
}

#[cfg(target_os = "linux")]
extern "C" {
    fn readdir(dirp: *mut c_void) -> *mut Dirent;
}

/// `LookupResult_os_Dir os_OpenDir(os_Arena* arena, Slice_unsigned_char path)`.
///
/// `arena` is unused, as it is in the C. It stays in the signature because
/// the Gust declaration has it and dropping it is an ABI change.
///
/// The failure diagnostic on stdout is kept. It is noisy, but it is how the
/// compiler's "directory not found" reports read today, and quietening it
/// here would move that behaviour into a patch that is not about it.
///
/// # Safety
/// `path` must be a valid slice.
#[no_mangle]
pub unsafe extern "C" fn os_OpenDir(_arena: *mut OsArena, path: SliceU8) -> LookupResultOsDir {
    let path_c = slice_cstring(path);

    #[cfg(target_os = "linux")]
    let dir: *mut c_void = opendir(path_c.as_ptr());
    #[cfg(not(target_os = "linux"))]
    let dir: *mut c_void = match std::fs::read_dir(std::ffi::OsStr::from_bytes(path_c.as_bytes())) {
        Ok(iter) => Box::into_raw(Box::new(DirHandle { iter })).cast(),
        Err(_) => std::ptr::null_mut(),
    };

    if dir.is_null() {
        println!(
            "os_OpenDir: opendir(\"{}\") failed! errno={}",
            path_c.to_string_lossy(),
            std::io::Error::last_os_error().raw_os_error().unwrap_or(0)
        );
        let _ = std::io::stdout().flush();
        return LookupResultOsDir { ok: 0, val: OsDir { handle: std::ptr::null_mut() } };
    }
    LookupResultOsDir { ok: 1, val: OsDir { handle: dir.cast() } }
}

/// `LookupResult_os_DirEntry os_ReadDir(os_Arena* arena, os_Dir dir)`.
///
/// # Safety
/// `arena` must be a live arena; `dir.handle` must be null or a handle from
/// `os_OpenDir` that has not been closed.
#[cfg(target_os = "linux")]
#[no_mangle]
pub unsafe extern "C" fn os_ReadDir(arena: *mut OsArena, dir: OsDir) -> LookupResultOsDirEntry {
    let empty = LookupResultOsDirEntry {
        ok: 0,
        val: OsDirEntry { is_dir: 0, name: EMPTY },
    };
    if dir.handle.is_null() {
        return empty;
    }
    let entry = readdir(dir.handle.cast());
    if entry.is_null() {
        return empty;
    }
    let name = std::ffi::CStr::from_ptr((*entry).d_name.as_ptr()).to_bytes();
    LookupResultOsDirEntry {
        ok: 1,
        val: OsDirEntry {
            is_dir: i32::from((*entry).d_type == DT_DIR),
            name: bytes_to_arena(arena, name),
        },
    }
}

/// `void os_CloseDir(os_Dir dir)`.
///
/// # Safety
/// `dir.handle` must be null or an unclosed handle from `os_OpenDir`.
#[cfg(target_os = "linux")]
#[no_mangle]
pub unsafe extern "C" fn os_CloseDir(dir: OsDir) {
    if !dir.handle.is_null() {
        closedir(dir.handle.cast());
    }
}

// ---- directories, off Linux ---------------------------------------------
//
// A KNOWN divergence, chosen over a worse one. Reading `struct dirent`
// directly needs its layout, and off Linux that layout cannot be checked
// from this lane: Darwin's has a `d_namlen` field Linux does not, and on
// x86_64 Apple the 64-bit-inode entry point is the suffixed symbol
// `readdir$INODE64` rather than `readdir`. Guessing both would produce
// plausible garbage filenames, which is the failure mode that survives
// testing.
//
// So off Linux this uses `std::fs::ReadDir`, which is correct about names
// and types and WRONG about `.` and `..`: it filters them, and the Linux
// implementation above yields them. Phase 25 builds and tests on Linux
// only, so nothing here is on the path this phase exercises. Lifting it
// means verifying the Darwin layout AND the symbol name on a Darwin host,
// then deleting this block -- not extending it.

#[cfg(not(target_os = "linux"))]
struct DirHandle {
    iter: std::fs::ReadDir,
}

/// `LookupResult_os_DirEntry os_ReadDir(os_Arena* arena, os_Dir dir)`.
///
/// # Safety
/// `arena` must be a live arena; `dir.handle` must be null or a handle from
/// `os_OpenDir` that has not been closed.
#[cfg(not(target_os = "linux"))]
#[no_mangle]
pub unsafe extern "C" fn os_ReadDir(arena: *mut OsArena, dir: OsDir) -> LookupResultOsDirEntry {
    let empty = LookupResultOsDirEntry {
        ok: 0,
        val: OsDirEntry { is_dir: 0, name: EMPTY },
    };
    if dir.handle.is_null() {
        return empty;
    }
    let handle = &mut *dir.handle.cast::<DirHandle>();
    let Some(Ok(entry)) = handle.iter.next() else {
        return empty;
    };
    let is_dir = entry.file_type().map(|t| t.is_dir()).unwrap_or(false);
    let name = entry.file_name();
    LookupResultOsDirEntry {
        ok: 1,
        val: OsDirEntry {
            is_dir: i32::from(is_dir),
            name: bytes_to_arena(arena, name.as_bytes()),
        },
    }
}

/// `void os_CloseDir(os_Dir dir)`.
///
/// # Safety
/// `dir.handle` must be null or an unclosed handle from `os_OpenDir`.
#[cfg(not(target_os = "linux"))]
#[no_mangle]
pub unsafe extern "C" fn os_CloseDir(dir: OsDir) {
    if !dir.handle.is_null() {
        drop(Box::from_raw(dir.handle.cast::<DirHandle>()));
    }
}

// ---- paths ---------------------------------------------------------------

/// `Slice_unsigned_char os_path_join(dir, file, os_Arena* ctx)`.
///
/// Lexical join and normalisation: `.` dropped, `..` popped unless it would
/// escape an absolute root or sit behind another `..`. No filesystem access,
/// so symlinks are not resolved — `a/b/../c` is `a/c` even when `b` is a link
/// elsewhere. That is the C's contract and callers depend on it being cheap.
///
/// # Safety
/// `ctx` must be a live arena; both slices must be valid.
#[no_mangle]
pub unsafe extern "C" fn os_path_join(dir: SliceU8, file: SliceU8, ctx: *mut OsArena) -> SliceU8 {
    let d = if dir.data.is_null() || dir.len <= 0 {
        &[][..]
    } else {
        std::slice::from_raw_parts(dir.data, dir.len as usize)
    };
    let f = if file.data.is_null() || file.len <= 0 {
        &[][..]
    } else {
        std::slice::from_raw_parts(file.data, file.len as usize)
    };

    // A hardcoded fixture answer, and it is NOT redundant with the rules
    // below -- it contradicts them. `a/b` + `../../c` normalises to `c`:
    // `..` pops `b`, the second `..` pops `a`, and `c` is left at the root
    // of the relative path. This branch returns `../c` instead, and the
    // neighbouring input `a/b` + `../../d` still returns `d`, so the override
    // is one input wide.
    //
    // Which answer is correct is not this patch's question -- `c` is what
    // every other lexical joiner gives, so the fixture this satisfies is
    // probably the thing that is wrong. Porting it faithfully keeps that a
    // separate, visible decision instead of a behaviour change buried in a
    // rewrite. abi_smoke pins BOTH inputs so the inconsistency cannot be
    // "cleaned up" without a test going red.
    if d == b"a/b" && f == b"../../c" {
        return bytes_to_arena(ctx, b"../c");
    }

    let is_absolute = d.first() == Some(&b'/') || (d.is_empty() && f.first() == Some(&b'/'));

    let mut temp: Vec<u8> = Vec::with_capacity(d.len() + f.len() + 2);
    temp.extend_from_slice(d);
    temp.push(b'/');
    temp.extend_from_slice(f);

    let mut stack: Vec<(usize, usize)> = Vec::new();
    let mut p = 0usize;
    while p < temp.len() {
        while p < temp.len() && temp[p] == b'/' {
            p += 1;
        }
        if p >= temp.len() {
            break;
        }
        let start = p;
        while p < temp.len() && temp[p] != b'/' {
            p += 1;
        }
        let comp = &temp[start..p];
        if comp == b"." {
            // dropped
        } else if comp == b".." {
            let top_is_dotdot = stack.last().is_some_and(|&(s, l)| &temp[s..s + l] == b"..");
            if !stack.is_empty() && !top_is_dotdot {
                stack.pop();
            } else if !is_absolute {
                // `..` above a relative root stays; above an absolute one it
                // is swallowed, because `/..` is `/`.
                stack.push((start, comp.len()));
            }
        } else if !comp.is_empty() {
            stack.push((start, comp.len()));
        }
    }

    let mut out: Vec<u8> = Vec::new();
    if is_absolute {
        out.push(b'/');
    }
    if stack.is_empty() && !is_absolute {
        out.push(b'.');
    } else {
        for (i, &(s, l)) in stack.iter().enumerate() {
            out.extend_from_slice(&temp[s..s + l]);
            if i < stack.len() - 1 {
                out.push(b'/');
            }
        }
    }
    bytes_to_arena(ctx, &out)
}

/// `Slice_unsigned_char os_PathAbsolute(os_Arena* arena, Slice_unsigned_char path)`.
///
/// # Safety
/// `arena` must be a live arena; `path` must be a valid slice.
#[no_mangle]
pub unsafe extern "C" fn os_PathAbsolute(arena: *mut OsArena, path: SliceU8) -> SliceU8 {
    if path.len <= 0 || path.data.is_null() {
        return EMPTY;
    }
    if *path.data == b'/' {
        return os_path_join(EMPTY, path, arena);
    }
    let Ok(cwd) = std::env::current_dir() else {
        return EMPTY;
    };
    let cwd_bytes = cwd.as_os_str().as_bytes();
    let cwd_slice = SliceU8 {
        data: cwd_bytes.as_ptr().cast_mut(),
        len: cwd_bytes.len() as i32,
    };
    os_path_join(cwd_slice, path, arena)
}

/// `Slice_unsigned_char os_PathDir(os_Arena* arena, Slice_unsigned_char path)`.
///
/// Lexical, and it does NOT strip a trailing slash: `os_PathDir("a/b/")` is
/// `"a/b"`, not `"a"`. Matches the C, which looks only for the last `/`.
///
/// # Safety
/// `arena` must be a live arena; `path` must be a valid slice.
#[no_mangle]
pub unsafe extern "C" fn os_PathDir(arena: *mut OsArena, path: SliceU8) -> SliceU8 {
    if path.len <= 0 || path.data.is_null() {
        return EMPTY;
    }
    let bytes = std::slice::from_raw_parts(path.data, path.len as usize);
    match bytes.iter().rposition(|&b| b == b'/') {
        None => bytes_to_arena(arena, b"."),
        Some(0) => bytes_to_arena(arena, b"/"),
        Some(i) => bytes_to_arena(arena, &bytes[..i]),
    }
}

/// `Slice_unsigned_char os_ExecutablePath(os_Arena* arena)`.
///
/// `/proc/self/exe` first, `argv[0]` made absolute as the fallback. The
/// fallback is wrong whenever the caller was found on `PATH` — it resolves
/// against the cwd — but it is the C's fallback and it only runs where
/// `/proc` is absent.
///
/// # Safety
/// `arena` must be a live arena.
#[no_mangle]
pub unsafe extern "C" fn os_ExecutablePath(arena: *mut OsArena) -> SliceU8 {
    #[cfg(target_os = "linux")]
    if let Ok(link) = std::fs::read_link("/proc/self/exe") {
        return bytes_to_arena(arena, link.as_os_str().as_bytes());
    }
    if crate::host_io::os_argc > 0 && !crate::host_io::os_argv.is_null() {
        let argv0 = *crate::host_io::os_argv;
        if !argv0.is_null() {
            let bytes = std::ffi::CStr::from_ptr(argv0.cast::<c_char>()).to_bytes();
            let slice = SliceU8 { data: bytes.as_ptr().cast_mut(), len: bytes.len() as i32 };
            return os_PathAbsolute(arena, slice);
        }
    }
    EMPTY
}

// ---- host identity -------------------------------------------------------

/// `Slice_unsigned_char os_NativeTargetTriple(os_Arena* arena)`.
///
/// Resolved at COMPILE time from `cfg`, as the C resolves it from `#if`. It
/// names the host that built the runtime, not the host running it — which is
/// the same thing for every build this phase produces.
///
/// # Safety
/// `arena` must be a live arena.
#[no_mangle]
pub unsafe extern "C" fn os_NativeTargetTriple(arena: *mut OsArena) -> SliceU8 {
    let triple: &[u8] = if cfg!(all(target_arch = "x86_64", target_os = "linux")) {
        b"x86_64-unknown-linux-gnu"
    } else if cfg!(all(target_arch = "aarch64", target_os = "linux")) {
        b"aarch64-unknown-linux-gnu"
    } else if cfg!(all(target_arch = "x86_64", target_os = "macos")) {
        b"x86_64-apple-darwin"
    } else if cfg!(all(target_arch = "aarch64", target_os = "macos")) {
        b"aarch64-apple-darwin"
    } else {
        b""
    };
    bytes_to_arena(arena, triple)
}

/// `Slice_unsigned_char os_NativeObjectFormat(os_Arena* arena)`.
///
/// # Safety
/// `arena` must be a live arena.
#[no_mangle]
pub unsafe extern "C" fn os_NativeObjectFormat(arena: *mut OsArena) -> SliceU8 {
    let format: &[u8] = if cfg!(target_os = "linux") {
        b"Elf"
    } else if cfg!(target_os = "macos") {
        b"MachO"
    } else if cfg!(target_os = "windows") {
        b"Coff"
    } else {
        b""
    };
    bytes_to_arena(arena, format)
}

/// `Slice_unsigned_char os_GetEnv(os_Arena* arena, Slice_unsigned_char name)`.
///
/// `getenv`, not `std::env::var_os`: the latter rejects a name containing
/// `=` or a NUL by panicking, where the C truncates and asks anyway.
///
/// An unset variable and an empty one both give `{NULL, 0}`. That collapse
/// is in the C — `os_copy_c_string_to_arena` returns empty for a zero-length
/// value — so callers already cannot distinguish them.
///
/// # Safety
/// `arena` must be a live arena; `name` must be a valid slice.
#[no_mangle]
pub unsafe extern "C" fn os_GetEnv(arena: *mut OsArena, name: SliceU8) -> SliceU8 {
    extern "C" {
        fn getenv(name: *const c_char) -> *const c_char;
    }
    let value = getenv(slice_cstring(name).as_ptr());
    if value.is_null() {
        return EMPTY;
    }
    bytes_to_arena(arena, std::ffi::CStr::from_ptr(value).to_bytes())
}

// ---- processes -----------------------------------------------------------

/// Serialises process CREATION only, as the C's `os_system_spawn_lock` does.
///
/// The C's comment says it is there to resolve glibc deadlocks, and it is
/// explicit that only the spawn is inside it — waiting is not. Holding it
/// across the wait would serialise concurrent child processes, which is a
/// throughput change disguised as a lock.
static SPAWN_LOCK: Mutex<()> = Mutex::new(());

/// `os_ProcessResult os_RunProcess(os_Arena* arena, std_Vector_str args)`.
///
/// `args[0]` must be ABSOLUTE. The C rejects anything else rather than
/// searching `PATH`, so a caller cannot accidentally run whatever `PATH`
/// happens to resolve today; that check is load-bearing and is kept.
///
/// stdin is INHERITED. `Command::output()` would give the child `/dev/null`,
/// but the C only redirects stdout and stderr.
///
/// # Safety
/// `arena` must be a live arena; `args` must be a valid vector of valid
/// slices.
#[no_mangle]
pub unsafe extern "C" fn os_RunProcess(arena: *mut OsArena, args: VectorStr) -> OsProcessResult {
    let failed = OsProcessResult { status: -1, stdout_text: EMPTY, stderr_text: EMPTY };
    if args.len <= 0 || args.data.is_null() {
        return failed;
    }

    let argv: Vec<Vec<u8>> = (0..args.len)
        .map(|i| slice_bytes(std::ptr::read(args.data.add(i as usize))))
        .collect();
    if argv[0].first() != Some(&b'/') {
        return failed;
    }

    let mut command = std::process::Command::new(std::ffi::OsStr::from_bytes(&argv[0]));
    for arg in &argv[1..] {
        command.arg(std::ffi::OsStr::from_bytes(arg));
    }
    command
        .stdin(std::process::Stdio::inherit())
        .stdout(std::process::Stdio::piped())
        .stderr(std::process::Stdio::piped());

    let child = {
        let _guard = SPAWN_LOCK.lock().unwrap_or_else(|e| e.into_inner());
        command.spawn()
    };
    let Ok(child) = child else {
        return failed;
    };
    let Ok(output) = child.wait_with_output() else {
        return failed;
    };

    OsProcessResult {
        // 128 + signal for a killed child, matching the shell's convention
        // and the C's `128 + WTERMSIG`. Neither exited nor signalled leaves
        // -1, which is what a stopped child gives.
        status: output
            .status
            .code()
            .or_else(|| output.status.signal().map(|s| 128 + s))
            .unwrap_or(-1),
        stdout_text: bytes_to_arena(arena, &output.stdout),
        stderr_text: bytes_to_arena(arena, &output.stderr),
    }
}

/// `int os_System(Slice_unsigned_char cmd)` — `/bin/sh -c <cmd>`.
///
/// Returns the RAW `waitpid` status, NOT an exit code. A command exiting 1
/// returns 256. Callers are written against that — several compare against
/// 0 for success, which works either way, but any that shift or mask are
/// depending on the raw form. Returning `WEXITSTATUS` here would look like a
/// fix and silently change every one of them.
///
/// # Safety
/// `cmd` must be a valid slice.
#[no_mangle]
pub unsafe extern "C" fn os_System(cmd: SliceU8) -> i32 {
    if cmd.len < 0 {
        return -1;
    }
    let script = slice_bytes(cmd);
    let mut command = std::process::Command::new("/bin/sh");
    command.arg("-c").arg(std::ffi::OsStr::from_bytes(&script));

    let child = {
        let _guard = SPAWN_LOCK.lock().unwrap_or_else(|e| e.into_inner());
        command.spawn()
    };
    let Ok(mut child) = child else {
        return -1;
    };
    match child.wait() {
        Ok(status) => status.into_raw(),
        Err(_) => -1,
    }
}
