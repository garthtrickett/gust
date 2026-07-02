import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut t_int := typechecker.make_type_int();

    mut safe_origin: typechecker.AddressOriginMetadata;
    typechecker.init_address_origin_safe_arena(&safe_origin);
    if typechecker.step51g_address_origin_is_raw_derived(safe_origin) != 0 {
        os.LogStr("Error: safe origin was incorrectly classified as raw-derived");
        os.Exit(1);
    }
    if typechecker.step51g_address_origin_is_sandbox_derived(safe_origin) != 0 {
        os.LogStr("Error: safe origin was incorrectly classified as sandbox-derived");
        os.Exit(1);
    }

    mut raw_origin: typechecker.AddressOriginMetadata;
    typechecker.init_address_origin_raw_derived(&raw_origin);
    if typechecker.step51g_address_origin_is_raw_derived(raw_origin) != 1 {
        os.LogStr("Error: raw origin was not classified as raw-derived");
        os.Exit(1);
    }
    if typechecker.step51g_address_origin_is_sandbox_derived(raw_origin) != 0 {
        os.LogStr("Error: raw origin was incorrectly classified as sandbox-derived");
        os.Exit(1);
    }
    if typechecker.step51g_address_origin_is_raw_or_sandbox_derived(raw_origin) != 1 {
        os.LogStr("Error: raw origin was not classified as raw-or-sandbox derived");
        os.Exit(1);
    }

    mut sandbox_origin: typechecker.AddressOriginMetadata;
    typechecker.init_address_origin_sandbox_derived(&sandbox_origin);
    if typechecker.step51g_address_origin_is_sandbox_derived(sandbox_origin) != 1 {
        os.LogStr("Error: sandbox origin was not classified as sandbox-derived");
        os.Exit(1);
    }
    if typechecker.step51g_address_origin_is_raw_derived(sandbox_origin) != 0 {
        os.LogStr("Error: sandbox origin was incorrectly classified as raw-derived");
        os.Exit(1);
    }
    if typechecker.step51g_address_origin_is_raw_or_sandbox_derived(sandbox_origin) != 1 {
        os.LogStr("Error: sandbox origin was not classified as raw-or-sandbox derived");
        os.Exit(1);
    }

    mut joined_origin := typechecker.step51g_join_address_origin_preserving_raw_sandbox(raw_origin, sandbox_origin);
    if typechecker.step51g_address_origin_is_raw_derived(joined_origin) != 1 {
        os.LogStr("Error: raw+sandbox join lost raw-derived origin");
        os.Exit(1);
    }
    if typechecker.step51g_address_origin_is_sandbox_derived(joined_origin) != 1 {
        os.LogStr("Error: raw+sandbox join lost sandbox-derived origin");
        os.Exit(1);
    }
    if typechecker.step51g_address_origin_requires_unsafe_boundary(joined_origin) != 1 {
        os.LogStr("Error: raw+sandbox joined origin did not require unsafe boundary");
        os.Exit(1);
    }

    mut joined_origin_debug := typechecker.step51g_address_origin_debug_raw_sandbox(joined_origin, ctx);
    if std.str_find(joined_origin_debug, "raw=1") == 0 - 1 {
        os.LogStr("Error: raw+sandbox origin debug string lost raw=1");
        os.LogStr(joined_origin_debug);
        os.Exit(1);
    }
    if std.str_find(joined_origin_debug, "sandbox=1") == 0 - 1 {
        os.LogStr("Error: raw+sandbox origin debug string lost sandbox=1");
        os.LogStr(joined_origin_debug);
        os.Exit(1);
    }

    mut raw_prov := typechecker.expression_provenance_raw_derived(t_int, ctx);
    typechecker.set_add(raw_prov.legacy_origins, "raw_root_step51", ctx);
    if typechecker.step51g_expression_provenance_is_raw_derived(raw_prov) != 1 {
        os.LogStr("Error: raw provenance was not classified as raw-derived");
        os.Exit(1);
    }
    if typechecker.step51g_expression_provenance_is_sandbox_derived(raw_prov) != 0 {
        os.LogStr("Error: raw provenance was incorrectly classified as sandbox-derived");
        os.Exit(1);
    }

    mut sandbox_prov := typechecker.expression_provenance_sandbox_derived(t_int, ctx);
    typechecker.set_add(sandbox_prov.legacy_origins, "sandbox_root_step51", ctx);
    if typechecker.step51g_expression_provenance_is_sandbox_derived(sandbox_prov) != 1 {
        os.LogStr("Error: sandbox provenance was not classified as sandbox-derived");
        os.Exit(1);
    }
    if typechecker.step51g_expression_provenance_is_raw_derived(sandbox_prov) != 0 {
        os.LogStr("Error: sandbox provenance was incorrectly classified as raw-derived");
        os.Exit(1);
    }

    mut joined_prov := typechecker.step51g_join_expression_provenance_preserving_raw_sandbox(raw_prov, sandbox_prov, ctx);
    if typechecker.step51g_expression_provenance_is_raw_derived(joined_prov) != 1 {
        os.LogStr("Error: raw+sandbox provenance join lost raw-derived metadata");
        os.Exit(1);
    }
    if typechecker.step51g_expression_provenance_is_sandbox_derived(joined_prov) != 1 {
        os.LogStr("Error: raw+sandbox provenance join lost sandbox-derived metadata");
        os.Exit(1);
    }
    if typechecker.step51g_expression_provenance_is_raw_or_sandbox_derived(joined_prov) != 1 {
        os.LogStr("Error: raw+sandbox provenance join was not classified as raw-or-sandbox derived");
        os.Exit(1);
    }
    if typechecker.set_contains(joined_prov.legacy_origins, "raw_root_step51", ctx) != 1 {
        os.LogStr("Error: raw+sandbox provenance join lost raw legacy origin");
        os.Exit(1);
    }
    if typechecker.set_contains(joined_prov.legacy_origins, "sandbox_root_step51", ctx) != 1 {
        os.LogStr("Error: raw+sandbox provenance join lost sandbox legacy origin");
        os.Exit(1);
    }

    mut joined_prov_alias := typechecker.expression_provenance_join_preserving_raw_sandbox(raw_prov, sandbox_prov, ctx);
    if typechecker.step51g_expression_provenance_is_raw_or_sandbox_derived(joined_prov_alias) != 1 {
        os.LogStr("Error: public raw/sandbox preserving provenance join lost derived classification");
        os.Exit(1);
    }

    mut joined_prov_debug := typechecker.step51g_expression_provenance_debug_raw_sandbox(joined_prov, ctx);
    if std.str_find(joined_prov_debug, "raw=1") == 0 - 1 {
        os.LogStr("Error: raw+sandbox provenance debug string lost raw=1");
        os.LogStr(joined_prov_debug);
        os.Exit(1);
    }
    if std.str_find(joined_prov_debug, "sandbox=1") == 0 - 1 {
        os.LogStr("Error: raw+sandbox provenance debug string lost sandbox=1");
        os.LogStr(joined_prov_debug);
        os.Exit(1);
    }

    os.LogStr("SUCCESS: raw/sandbox provenance predicates and preserving joins verified!");
}