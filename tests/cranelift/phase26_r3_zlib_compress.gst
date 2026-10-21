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
extern func gust_zlib_compress(input: *byte #[ffi(borrow_read_call)], input_count: int #[ffi(value)], output: *byte #[ffi(borrow_write_call)], output_cap: int #[ffi(value)], level: int #[ffi(value)]) int #[ffi(value)];

func release_region(region: CallRegion) {
    unsafe { os_FfiCallRegionFree(region.raw); }
}

func copy_shape(ctx: &Arena, input: &std.Vector[byte, ctx], output_cap: int, level: int) int {
    if output_cap < 0 { return 0 - 1; }
    if output_cap > 1073741824 { return 0 - 1; }
    mut output: std.Vector[byte, ctx] := std.VectorNew(ctx);
    mut input_count: int := len(input);
    mut fill := 0;
    while fill < output_cap {
        output.Push(0 as byte);
        fill = fill + 1;
    }
    output.Clear();
    unsafe {
        mut acquired := os_FfiCallRegionTryCreate(input_count, output_cap);
        mut status: int := acquired.Code;
        guard region := move acquired else { return status; }
        mut i := 0;
        while i < input_count {
            mut write_status: int := os_FfiCallRegionWriteInput(region.raw, i, input[i]);
            if write_status != 0 { return write_status; }
            i = i + 1;
        }
        mut produced: int := gust_zlib_compress(
            os_FfiCallRegionInputAddress(region.raw), input_count,
            os_FfiCallRegionOutputAddress(region.raw), output_cap, level
        );
        if produced < 0 { return produced; }
        if produced > output_cap { return 93; }
        mut accept_status: int := os_FfiCallRegionAcceptResult(region.raw, produced);
        if accept_status != 0 { return accept_status; }
        mut j := 0;
        while j < produced {
            mut value: byte := 0 as byte;
            mut read_status: int := os_FfiCallRegionReadOutput(region.raw, j, (&value) as *byte);
            if read_status != 0 { return read_status; }
            output.Push(value);
            j = j + 1;
        }
        return len(output);
    }
}

func main() int {
    mut arena := os.Arena.New();
    defer arena.Free();
    mut input: std.Vector[byte, arena] := std.VectorNew(&arena);
    input.Push(3 as byte);
    input.Push(4 as byte);
    return copy_shape(&arena, &input, 64, 6);
}
