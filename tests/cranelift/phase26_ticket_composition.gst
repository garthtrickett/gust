type CopyOutcome[pool] enum {
    Completed { handle: Index[std.Vector[byte, pool], pool] },
    Rejected { number: int }
}

// These concrete brand-polymorphic signatures use the existing destination brand
// convention; no user type-generic function or new enum construction syntax.
func reject_copy(pool: &Arena, number: int) CopyOutcome[pool] {
    mut result: CopyOutcome[pool];
    unsafe {
        result.tag = 1;
        result.Rejected.number = number;
    }
    return result;
}

func classify_failure(pool: &Arena, number: int) CopyOutcome[pool] {
    mut result: CopyOutcome[pool];
    unsafe {
        result.tag = 1;
        result.Rejected.number = 0 - 5;
    }
    return result;
}

func complete_copy(pool: &Arena,
    handle: Index[std.Vector[byte, pool], pool]) CopyOutcome[pool] {
    mut result: CopyOutcome[pool];
    unsafe {
        result.tag = 0;
        result.Completed.handle = handle;
    }
    return result;
}

#[repr(C)]
#[linear]
#[destructor(release_region)]
#[opaque]
type CallRegion struct { raw: *byte }

#[repr(C)]
type RegionResult struct { Ok: int, Code: int, Val: CallRegion }

extern func os_FfiCallRegionTryCreate(input_len: int #[ffi(value)], output_cap: int #[ffi(value)]) RegionResult #[ffi(fallible_owned_out)];
extern func os_FfiCallRegionFree(raw: *byte #[ffi(release_owned)]);
extern func os_FfiCallRegionWriteInput(raw: *byte #[ffi(region_access_call)], index: int #[ffi(value)], value: byte #[ffi(value)]) int #[ffi(value)];
extern func os_FfiCallRegionInputAddress(raw: *byte #[ffi(region_access_call)]) *byte #[ffi(raw_untrusted)];
extern func os_FfiCallRegionOutputAddress(raw: *byte #[ffi(region_access_call)]) *byte #[ffi(raw_untrusted)];
extern func os_FfiCallRegionAcceptResult(raw: *byte #[ffi(region_access_call)], count: int #[ffi(value)]) int #[ffi(value)];
extern func os_FfiCallRegionReadOutput(raw: *byte #[ffi(region_access_call)], index: int #[ffi(value)], out: *byte #[ffi(borrow_write_call)]) int #[ffi(value)];
extern func gust_zlib_compress(input: *byte #[ffi(borrow_read_call)], input_count: int #[ffi(value)], collected: *byte #[ffi(borrow_write_call)], output_cap: int #[ffi(value)], level: int #[ffi(value)]) int #[ffi(value)];

func release_region(region: CallRegion) {
    unsafe { os_FfiCallRegionFree(region.raw); }
}

// Generic compiler qualification fixture; not a Stdlib API.
func copy_bytes(pool: &Arena, input: &std.Vector[byte, pool], output_cap: int, level: int) CopyOutcome[pool] {
    if output_cap < 0 { return reject_copy(pool, 0 - 1); }
    if output_cap > 1073741824 { return reject_copy(pool, 0 - 1); }
    mut collected: std.Vector[byte, pool] := std.VectorNew(pool);
    mut input_count: int := len(input);
    mut fill := 0;
    while fill < output_cap {
        collected.Push(0 as byte);
        fill = fill + 1;
    }
    collected.Clear();
    unsafe {
        mut acquired := os_FfiCallRegionTryCreate(input_count, output_cap);
        mut status: int := acquired.Code;
        guard region := move acquired else { return classify_failure(pool, status); }
        mut i := 0;
        while i < input_count {
            mut write_status: int := os_FfiCallRegionWriteInput(region.raw, i, input[i]);
            if write_status != 0 { return reject_copy(pool, write_status); }
            i = i + 1;
        }
        mut produced: int := gust_zlib_compress(
            os_FfiCallRegionInputAddress(region.raw), input_count,
            os_FfiCallRegionOutputAddress(region.raw), output_cap, level
        );
        if produced < 0 { return reject_copy(pool, produced); }
        if produced > output_cap { return reject_copy(pool, 93); }
        mut accept_status: int := os_FfiCallRegionAcceptResult(region.raw, produced);
        if accept_status != 0 { return reject_copy(pool, accept_status); }
        mut j := 0;
        while j < produced {
            mut value: byte := 0 as byte;
            mut read_status: int := os_FfiCallRegionReadOutput(region.raw, j, (&value) as *byte);
            if read_status != 0 { return reject_copy(pool, read_status); }
            collected.Push(value);
            j = j + 1;
        }
    }
    // The native owner is gone here. Publish only a completed safe Vector.
    mut handle: Index[std.Vector[byte, pool], pool] := os.ArenaAlloc(pool);
    pool.Set(handle, collected);
    return complete_copy(pool, handle);
}

extern func gust_zlib_decompress(input: *byte #[ffi(borrow_read_call)], input_count: int #[ffi(value)], collected: *byte #[ffi(borrow_write_call)], output_cap: int #[ffi(value)]) int #[ffi(value)];
func restore_bytes(pool: &Arena, input: &std.Vector[byte, pool], output_cap: int, level: int) CopyOutcome[pool] {
    if output_cap < 0 { return reject_copy(pool, 0 - 1); }
    if output_cap > 1073741824 { return reject_copy(pool, 0 - 1); }
    mut collected: std.Vector[byte, pool] := std.VectorNew(pool);
    mut input_count: int := len(input);
    mut fill := 0;
    while fill < output_cap {
        collected.Push(0 as byte);
        fill = fill + 1;
    }
    collected.Clear();
    unsafe {
        mut acquired := os_FfiCallRegionTryCreate(input_count, output_cap);
        mut status: int := acquired.Code;
        guard region := move acquired else { return classify_failure(pool, status); }
        mut i := 0;
        while i < input_count {
            mut write_status: int := os_FfiCallRegionWriteInput(region.raw, i, input[i]);
            if write_status != 0 { return reject_copy(pool, write_status); }
            i = i + 1;
        }
        mut produced: int := gust_zlib_decompress(
            os_FfiCallRegionInputAddress(region.raw), input_count,
            os_FfiCallRegionOutputAddress(region.raw), output_cap
        );
        if produced < 0 { return reject_copy(pool, produced); }
        if produced > output_cap { return reject_copy(pool, 93); }
        mut accept_status: int := os_FfiCallRegionAcceptResult(region.raw, produced);
        if accept_status != 0 { return reject_copy(pool, accept_status); }
        mut j := 0;
        while j < produced {
            mut value: byte := 0 as byte;
            mut read_status: int := os_FfiCallRegionReadOutput(region.raw, j, (&value) as *byte);
            if read_status != 0 { return reject_copy(pool, read_status); }
            collected.Push(value);
            j = j + 1;
        }
    }
    // The native owner is gone here. Publish only a completed safe Vector.
    mut handle: Index[std.Vector[byte, pool], pool] := os.ArenaAlloc(pool);
    pool.Set(handle, collected);
    return complete_copy(pool, handle);
}

func main() int {
    mut destination := os.Arena.New();
    defer destination.Free();
    mut input: std.Vector[byte, destination] := std.VectorNew(&destination);
    input.Push(3 as byte);
    input.Push(4 as byte);
    mut result := copy_bytes(&destination, &input, 64, 6);
    match result {
        Completed { handle } => {
            mut copied := *handle;
            mut bytes := destination.get_ref(copied);
            mut roundtrip := restore_bytes(&destination, bytes, 2, 6);
            match roundtrip {
                Completed { handle } => {
                    mut decoded := *handle;
                    mut original := destination.get_ref(decoded);
                    return 100 + len(original) * 10 + (original[0] as int) * 10 + (original[1] as int);
                }
                Rejected { number } => { return *number; }
            }
        }
        Rejected { number } => { return *number; }
    }
}
