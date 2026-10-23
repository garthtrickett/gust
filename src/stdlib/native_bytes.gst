// Safe bounded native byte compression over the enrolled first-release profile.
// GNU/Linux x86_64 signed adapter profile; no backend fallback.
// Error.code: -1 arguments, -2 range, -3 insufficient destination,
// -4 corrupt input, -5 native/region allocation, -6 other native failure.
// Gust arena exhaustion and collection traps retain process-level behavior.
type BytesResult[ctx] enum {
    Bytes { ticket: Index[std.Vector[byte, ctx], ctx] },
    Error { code: int }
}

// These concrete brand-polymorphic signatures use the existing destination brand
// convention; no user type-generic function or new enum construction syntax.
func error_result(ctx: &Arena, code: int) BytesResult[ctx] {
    mut result: BytesResult[ctx];
    unsafe {
        result.tag = 1;
        result.Error.code = code;
    }
    return result;
}

func bytes_result(ctx: &Arena,
    ticket: Index[std.Vector[byte, ctx], ctx]) BytesResult[ctx] {
    mut result: BytesResult[ctx];
    unsafe {
        result.tag = 0;
        result.Bytes.ticket = ticket;
    }
    return result;
}

// Call-region allocation uses -2; adapter range also uses -2. Keep domains
// distinct: normalize failed region acquisition into the public -5 category.
// Validated region acquisition can fail only in its allocation path.
func region_error_result(ctx: &Arena, status: int) BytesResult[ctx] {
    mut result: BytesResult[ctx];
    unsafe {
        result.tag = 1;
        result.Error.code = 0 - 5;
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
extern func gust_zlib_compress(input: *byte #[ffi(borrow_read_call)], input_count: int #[ffi(value)], output: *byte #[ffi(borrow_write_call)], output_cap: int #[ffi(value)], level: int #[ffi(value)]) int #[ffi(value)];
extern func gust_zlib_decompress(input: *byte #[ffi(borrow_read_call)], input_count: int #[ffi(value)], output: *byte #[ffi(borrow_write_call)], output_cap: int #[ffi(value)]) int #[ffi(value)];

func release_region(region: CallRegion) {
    unsafe { os_FfiCallRegionFree(region.raw); }
}

// Input carries its own inferred input_ctx brand; ctx owns only the output.
// Both arenas must remain live for their respective checked accesses.
// Bounded compression. Capacity is caller-chosen; no untrusted size controls it.
func compress(ctx: &Arena, input: &std.Vector[byte, input_ctx], output_cap: int, level: int) BytesResult[ctx] {
    if output_cap < 0 { return error_result(ctx, 0 - 1); }
    if output_cap > 1073741824 { return error_result(ctx, 0 - 2); }
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
        guard region := move acquired else { return region_error_result(ctx, status); }
        mut i := 0;
        while i < input_count {
            mut write_status: int := os_FfiCallRegionWriteInput(region.raw, i, input[i]);
            if write_status != 0 { return error_result(ctx, write_status); }
            i = i + 1;
        }
        mut produced: int := gust_zlib_compress(
            os_FfiCallRegionInputAddress(region.raw), input_count,
            os_FfiCallRegionOutputAddress(region.raw), output_cap, level
        );
        if produced < 0 { return error_result(ctx, produced); }
        if produced > output_cap { return error_result(ctx, 0 - 6); }
        mut accept_status: int := os_FfiCallRegionAcceptResult(region.raw, produced);
        if accept_status != 0 { return error_result(ctx, accept_status); }
        mut j := 0;
        while j < produced {
            mut value: byte := 0 as byte;
            mut read_status: int := os_FfiCallRegionReadOutput(region.raw, j, (&value) as *byte);
            if read_status != 0 { return error_result(ctx, read_status); }
            output.Push(value);
            j = j + 1;
        }
    }
    // The native owner is gone here. Publish only a completed safe Vector.
    mut ticket: Index[std.Vector[byte, ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(ticket, output);
    return bytes_result(ctx, ticket);
}

// Bounded decompression; capacity never comes from the compressed stream.
// The input_ctx brand is independent of the explicit output arena ctx.
func decompress(ctx: &Arena, input: &std.Vector[byte, input_ctx], output_cap: int) BytesResult[ctx] {
    if output_cap < 0 { return error_result(ctx, 0 - 1); }
    if output_cap > 1073741824 { return error_result(ctx, 0 - 2); }
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
        guard region := move acquired else { return region_error_result(ctx, status); }
        mut i := 0;
        while i < input_count {
            mut write_status: int := os_FfiCallRegionWriteInput(region.raw, i, input[i]);
            if write_status != 0 { return error_result(ctx, write_status); }
            i = i + 1;
        }
        mut produced: int := gust_zlib_decompress(
            os_FfiCallRegionInputAddress(region.raw), input_count,
            os_FfiCallRegionOutputAddress(region.raw), output_cap
        );
        if produced < 0 { return error_result(ctx, produced); }
        if produced > output_cap { return error_result(ctx, 0 - 6); }
        mut accept_status: int := os_FfiCallRegionAcceptResult(region.raw, produced);
        if accept_status != 0 { return error_result(ctx, accept_status); }
        mut j := 0;
        while j < produced {
            mut value: byte := 0 as byte;
            mut read_status: int := os_FfiCallRegionReadOutput(region.raw, j, (&value) as *byte);
            if read_status != 0 { return error_result(ctx, read_status); }
            output.Push(value);
            j = j + 1;
        }
    }
    // The native owner is gone here. Publish only a completed safe Vector.
    mut ticket: Index[std.Vector[byte, ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(ticket, output);
    return bytes_result(ctx, ticket);
}
