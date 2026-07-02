import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut arena_alloc_origin := typechecker.address_origin_record_for_arena_allocation("ctx", "Step51AddressNode", ctx);
    if typechecker.address_origin_record_is_arena(arena_alloc_origin) != 1 {
        os.LogStr("Error: arena allocation origin was not classified as arena");
        os.Exit(1);
    }
    if typechecker.address_origin_record_is_arena_allocation(arena_alloc_origin) != 1 {
        os.LogStr("Error: arena allocation origin was not classified as arena allocation");
        os.Exit(1);
    }
    if typechecker.address_origin_record_is_managed_storage(arena_alloc_origin) != 1 {
        os.LogStr("Error: arena allocation origin was not classified as managed storage");
        os.Exit(1);
    }
    if typechecker.address_origin_record_is_scratchpad(arena_alloc_origin) != 0 {
        os.LogStr("Error: arena allocation origin was incorrectly classified as scratchpad");
        os.Exit(1);
    }

    mut arena_read_origin := typechecker.address_origin_record_for_arena_read("ctx", "node_idx", ctx);
    if typechecker.address_origin_record_is_arena_read(arena_read_origin) != 1 {
        os.LogStr("Error: arena read origin was not classified as arena read");
        os.Exit(1);
    }

    mut scratchpad_origin := typechecker.address_origin_record_for_scratchpad_allocation("thread_scratch", "bytes", ctx);
    if typechecker.address_origin_record_is_scratchpad(scratchpad_origin) != 1 {
        os.LogStr("Error: scratchpad allocation origin was not classified as scratchpad");
        os.Exit(1);
    }
    if typechecker.address_origin_record_is_scratchpad_allocation(scratchpad_origin) != 1 {
        os.LogStr("Error: scratchpad allocation origin was not classified as scratchpad allocation");
        os.Exit(1);
    }
    if typechecker.address_origin_record_is_managed_storage(scratchpad_origin) != 1 {
        os.LogStr("Error: scratchpad allocation origin was not classified as managed storage");
        os.Exit(1);
    }

    mut ffi_origin := typechecker.address_origin_record_for_ffi_return("native_make_node", "*Step51AddressNode", ctx);
    if typechecker.address_origin_record_is_ffi(ffi_origin) != 1 {
        os.LogStr("Error: ffi return origin was not classified as ffi");
        os.Exit(1);
    }
    if typechecker.address_origin_record_is_ffi_return(ffi_origin) != 1 {
        os.LogStr("Error: ffi return origin was not classified as ffi return");
        os.Exit(1);
    }
    if typechecker.address_origin_record_is_external_like(ffi_origin) != 1 {
        os.LogStr("Error: ffi return origin was not classified as external-like");
        os.Exit(1);
    }
    if typechecker.address_origin_record_is_raw_like(ffi_origin) != 0 {
        os.LogStr("Error: ffi return origin was incorrectly classified as raw-like");
        os.Exit(1);
    }

    mut sandbox_origin := typechecker.address_origin_record_for_sandbox_value("sandbox_ctx", "node", ctx);
    if typechecker.address_origin_record_is_sandbox(sandbox_origin) != 1 {
        os.LogStr("Error: sandbox value origin was not classified as sandbox");
        os.Exit(1);
    }
    if typechecker.address_origin_record_is_sandbox_value(sandbox_origin) != 1 {
        os.LogStr("Error: sandbox value origin was not classified as sandbox value");
        os.Exit(1);
    }
    if typechecker.address_origin_record_is_external_like(sandbox_origin) != 1 {
        os.LogStr("Error: sandbox value origin was not classified as external-like");
        os.Exit(1);
    }
    if typechecker.address_origin_record_is_raw_unknown(sandbox_origin) != 0 {
        os.LogStr("Error: sandbox value origin was incorrectly classified as raw_unknown");
        os.Exit(1);
    }

    mut raw_unknown_origin := typechecker.address_origin_record_for_raw_unknown_cast("opaque_ptr", "*Step51AddressNode", ctx);
    if typechecker.address_origin_record_is_raw_unknown(raw_unknown_origin) != 1 {
        os.LogStr("Error: raw_unknown cast origin was not classified as raw_unknown");
        os.Exit(1);
    }
    if typechecker.address_origin_record_is_raw_unknown_cast(raw_unknown_origin) != 1 {
        os.LogStr("Error: raw_unknown cast origin was not classified as raw_unknown cast");
        os.Exit(1);
    }
    if typechecker.address_origin_record_is_raw_like(raw_unknown_origin) != 1 {
        os.LogStr("Error: raw_unknown cast origin was not classified as raw-like");
        os.Exit(1);
    }
    if typechecker.address_origin_record_is_external_like(raw_unknown_origin) != 0 {
        os.LogStr("Error: raw_unknown cast origin was incorrectly classified as external-like");
        os.Exit(1);
    }

    mut arena_debug := typechecker.address_origin_record_debug_string(arena_read_origin, ctx);
    if std.str_find(arena_debug, "arena.read:ctx[node_idx]") == 0 - 1 {
        os.LogStr("Error: arena read debug string missing source label");
        os.LogStr(arena_debug);
        os.Exit(1);
    }

    mut raw_debug := typechecker.address_origin_record_debug_string(raw_unknown_origin, ctx);
    if std.str_find(raw_debug, "raw_unknown.cast:opaque_ptr:*Step51AddressNode") == 0 - 1 {
        os.LogStr("Error: raw_unknown debug string missing source label");
        os.LogStr(raw_debug);
        os.Exit(1);
    }

    os.LogStr("SUCCESS: source address-origin metadata helpers verified!");
}
