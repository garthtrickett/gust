import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut safe_origin: typechecker.AddressOriginMetadata;
    typechecker.init_address_origin_safe_arena(&safe_origin);
    if typechecker.address_origin_allows_safe_branding(safe_origin) != 1 {
        os.LogStr("Error: safe arena origins must allow safe branding");
        os.Exit(1);
    }
    if typechecker.address_origin_requires_unsafe_boundary(safe_origin) != 0 {
        os.LogStr("Error: safe arena origins must not require unsafe boundaries");
        os.Exit(1);
    }

    mut raw_origin: typechecker.AddressOriginMetadata;
    typechecker.init_address_origin_raw_derived(&raw_origin);
    if typechecker.address_origin_allows_safe_branding(raw_origin) != 0 {
        os.LogStr("Error: raw-derived origins must not allow safe branding");
        os.Exit(1);
    }
    if typechecker.address_origin_requires_unsafe_boundary(raw_origin) != 1 {
        os.LogStr("Error: raw-derived origins must require unsafe boundaries");
        os.Exit(1);
    }
    if typechecker.address_origin_is_raw_or_sandbox_derived(raw_origin) != 1 {
        os.LogStr("Error: raw-derived origins must classify as raw-or-sandbox derived");
        os.Exit(1);
    }

    mut sandbox_origin: typechecker.AddressOriginMetadata;
    typechecker.init_address_origin_sandbox_derived(&sandbox_origin);
    if typechecker.address_origin_allows_safe_branding(sandbox_origin) != 0 {
        os.LogStr("Error: sandbox-derived origins must not allow safe branding");
        os.Exit(1);
    }
    if typechecker.address_origin_requires_unsafe_boundary(sandbox_origin) != 1 {
        os.LogStr("Error: sandbox-derived origins must require unsafe boundaries");
        os.Exit(1);
    }
    if typechecker.address_origin_is_raw_or_sandbox_derived(sandbox_origin) != 1 {
        os.LogStr("Error: sandbox-derived origins must classify as raw-or-sandbox derived");
        os.Exit(1);
    }

    mut unknown_origin: typechecker.AddressOriginMetadata;
    typechecker.init_address_origin_unknown(&unknown_origin);
    if typechecker.address_origin_allows_safe_branding(unknown_origin) != 0 {
        os.LogStr("Error: unknown origins must not allow safe branding");
        os.Exit(1);
    }
    if typechecker.address_origin_requires_unsafe_boundary(unknown_origin) != 0 {
        os.LogStr("Error: unknown origins are inert metadata only and must not enforce unsafe boundaries yet");
        os.Exit(1);
    }

    mut origin_safe_record := typechecker.address_origin_record_make_safe("root.safe", ctx);
    mut origin_local_stack_record := typechecker.address_origin_record_make_local_stack("root.local_stack", ctx);
    mut origin_arena_record := typechecker.address_origin_record_make_arena("root.arena", ctx);
    mut origin_scratchpad_record := typechecker.address_origin_record_make_scratchpad("root.scratchpad", ctx);
    mut origin_ffi_record := typechecker.address_origin_record_make_ffi("root.ffi", ctx);
    mut origin_sandbox_record := typechecker.address_origin_record_make_sandbox("root.sandbox", ctx);
    mut origin_raw_unknown_record := typechecker.address_origin_record_make_raw_unknown("root.raw_unknown", ctx);
    mut origin_borrowed_field_record := typechecker.address_origin_record_make_borrowed_field("root.borrowed_field", ctx);
    mut origin_container_element_record := typechecker.address_origin_record_make_container_element("root.container_element", ctx);

    if std.str_eq(typechecker.address_origin_record_kind_name(origin_safe_record), "safe") == 0 {
        os.LogStr("Error: safe address-origin record kind drifted");
        os.Exit(1);
    }
    if std.str_eq(typechecker.address_origin_record_kind_name(origin_local_stack_record), "local_stack") == 0 {
        os.LogStr("Error: local_stack address-origin record kind drifted");
        os.Exit(1);
    }
    if std.str_eq(typechecker.address_origin_record_kind_name(origin_arena_record), "arena") == 0 {
        os.LogStr("Error: arena address-origin record kind drifted");
        os.Exit(1);
    }
    if std.str_eq(typechecker.address_origin_record_kind_name(origin_scratchpad_record), "scratchpad") == 0 {
        os.LogStr("Error: scratchpad address-origin record kind drifted");
        os.Exit(1);
    }
    if std.str_eq(typechecker.address_origin_record_kind_name(origin_ffi_record), "ffi") == 0 {
        os.LogStr("Error: ffi address-origin record kind drifted");
        os.Exit(1);
    }
    if std.str_eq(typechecker.address_origin_record_kind_name(origin_sandbox_record), "sandbox") == 0 {
        os.LogStr("Error: sandbox address-origin record kind drifted");
        os.Exit(1);
    }
    if std.str_eq(typechecker.address_origin_record_kind_name(origin_raw_unknown_record), "raw_unknown") == 0 {
        os.LogStr("Error: raw_unknown address-origin record kind drifted");
        os.Exit(1);
    }
    if std.str_eq(typechecker.address_origin_record_kind_name(origin_borrowed_field_record), "borrowed_field") == 0 {
        os.LogStr("Error: borrowed_field address-origin record kind drifted");
        os.Exit(1);
    }
    if std.str_eq(typechecker.address_origin_record_kind_name(origin_container_element_record), "container_element") == 0 {
        os.LogStr("Error: container_element address-origin record kind drifted");
        os.Exit(1);
    }

    if typechecker.address_origin_record_is_safe(origin_safe_record) != 1 {
        os.LogStr("Error: safe address-origin classifier failed");
        os.Exit(1);
    }
    if typechecker.address_origin_record_is_safe(origin_arena_record) != 0 {
        os.LogStr("Error: arena address-origin record must not classify as safe");
        os.Exit(1);
    }
    if typechecker.address_origin_record_is_raw_like(origin_raw_unknown_record) != 1 {
        os.LogStr("Error: raw_unknown address-origin classifier failed");
        os.Exit(1);
    }
    if typechecker.address_origin_record_is_raw_like(origin_ffi_record) != 0 {
        os.LogStr("Error: ffi address-origin record must not classify as raw-like");
        os.Exit(1);
    }
    if typechecker.address_origin_record_is_external_like(origin_ffi_record) != 1 {
        os.LogStr("Error: ffi address-origin classifier failed");
        os.Exit(1);
    }
    if typechecker.address_origin_record_is_external_like(origin_sandbox_record) != 1 {
        os.LogStr("Error: sandbox address-origin classifier failed");
        os.Exit(1);
    }
    if typechecker.address_origin_record_is_external_like(origin_safe_record) != 0 {
        os.LogStr("Error: safe address-origin record must not classify as external-like");
        os.Exit(1);
    }

    mut origin_debug_record := typechecker.address_origin_record_debug_string(origin_container_element_record, ctx);
    if std.str_find(origin_debug_record, "container_element") == 0 - 1 {
        os.LogStr("Error: address-origin debug string missing kind");
        os.LogStr(origin_debug_record);
        os.Exit(1);
    }
    if std.str_find(origin_debug_record, "root.container_element") == 0 - 1 {
        os.LogStr("Error: address-origin debug string missing label");
        os.LogStr(origin_debug_record);
        os.Exit(1);
    }

    os.LogStr("SUCCESS: inert address-origin metadata helpers verified!");
}
