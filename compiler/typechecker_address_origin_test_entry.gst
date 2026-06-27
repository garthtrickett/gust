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

    os.LogStr("SUCCESS: inert address-origin metadata helpers verified!");
}