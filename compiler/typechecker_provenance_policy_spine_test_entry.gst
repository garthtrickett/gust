import "typechecker.gst" as typechecker;
import "ast.gst" as ast;

func main() {
    mut ctx := os.ArenaNew();
    defer ctx.Free();

    mut t_int_51g4: ast.Type[ctx];
    t_int_51g4.tag = 0;

    mut safe_origin_51g4: typechecker.AddressOriginMetadata;
    typechecker.init_address_origin_safe_arena(&safe_origin_51g4);
    if typechecker.step51g_non_laundering_origin_allows_safe_brand(safe_origin_51g4) != 1 {
        os.LogStr("Error: Step 5.1G policy did not allow safe arena origin");
        os.Exit(1);
    }
    if typechecker.step51g_non_laundering_origin_blocks_safe_brand(safe_origin_51g4) != 0 {
        os.LogStr("Error: Step 5.1G policy blocked safe arena origin");
        os.Exit(1);
    }
    if typechecker.step51g_non_laundering_origin_requires_unsafe_boundary(safe_origin_51g4) != 0 {
        os.LogStr("Error: Step 5.1G policy required unsafe boundary for safe arena origin");
        os.Exit(1);
    }

    mut raw_origin_51g4: typechecker.AddressOriginMetadata;
    typechecker.init_address_origin_raw_derived(&raw_origin_51g4);
    if typechecker.step51g_non_laundering_origin_allows_safe_brand(raw_origin_51g4) != 0 {
        os.LogStr("Error: Step 5.1G policy allowed raw-derived origin");
        os.Exit(1);
    }
    if typechecker.step51g_non_laundering_origin_blocks_safe_brand(raw_origin_51g4) != 1 {
        os.LogStr("Error: Step 5.1G policy did not block raw-derived origin");
        os.Exit(1);
    }
    if typechecker.step51g_non_laundering_origin_requires_unsafe_boundary(raw_origin_51g4) != 1 {
        os.LogStr("Error: Step 5.1G policy did not require unsafe boundary for raw-derived origin");
        os.Exit(1);
    }

    mut sandbox_origin_51g4: typechecker.AddressOriginMetadata;
    typechecker.init_address_origin_sandbox_derived(&sandbox_origin_51g4);
    if typechecker.step51g_non_laundering_origin_blocks_safe_brand(sandbox_origin_51g4) != 1 {
        os.LogStr("Error: Step 5.1G policy did not block sandbox-derived origin");
        os.Exit(1);
    }
    if typechecker.step51g_non_laundering_origin_requires_unsafe_boundary(sandbox_origin_51g4) != 1 {
        os.LogStr("Error: Step 5.1G policy did not require unsafe boundary for sandbox-derived origin");
        os.Exit(1);
    }

    mut unknown_origin_51g4: typechecker.AddressOriginMetadata;
    typechecker.init_address_origin_unknown(&unknown_origin_51g4);
    if typechecker.step51g_non_laundering_origin_blocks_safe_brand(unknown_origin_51g4) != 1 {
        os.LogStr("Error: Step 5.1G policy did not block unknown origin");
        os.Exit(1);
    }
    if typechecker.step51g_non_laundering_origin_requires_unsafe_boundary(unknown_origin_51g4) != 0 {
        os.LogStr("Error: Step 5.1G policy incorrectly required unsafe boundary for unknown-only origin");
        os.Exit(1);
    }

    mut safe_prov_51g4 := typechecker.expression_provenance_safe_arena(t_int_51g4, ctx);
    if typechecker.step51g_non_laundering_provenance_allows_safe_brand(safe_prov_51g4, ctx) != 1 {
        os.LogStr("Error: Step 5.1G provenance policy did not allow safe arena provenance");
        os.Exit(1);
    }
    if typechecker.step51g_non_laundering_provenance_blocks_safe_brand(safe_prov_51g4, ctx) != 0 {
        os.LogStr("Error: Step 5.1G provenance policy blocked safe arena provenance");
        os.Exit(1);
    }
    if typechecker.step51g_non_laundering_provenance_requires_unsafe_boundary(safe_prov_51g4, ctx) != 0 {
        os.LogStr("Error: Step 5.1G provenance policy required unsafe for safe arena provenance");
        os.Exit(1);
    }

    mut raw_prov_51g4 := typechecker.expression_provenance_raw_derived(t_int_51g4, ctx);
    if typechecker.step51g_non_laundering_provenance_allows_safe_brand(raw_prov_51g4, ctx) != 0 {
        os.LogStr("Error: Step 5.1G provenance policy allowed raw-derived provenance");
        os.Exit(1);
    }
    if typechecker.step51g_non_laundering_provenance_blocks_safe_brand(raw_prov_51g4, ctx) != 1 {
        os.LogStr("Error: Step 5.1G provenance policy did not block raw-derived provenance");
        os.Exit(1);
    }
    if typechecker.step51g_non_laundering_provenance_requires_unsafe_boundary(raw_prov_51g4, ctx) != 1 {
        os.LogStr("Error: Step 5.1G provenance policy did not require unsafe for raw-derived provenance");
        os.Exit(1);
    }

    mut sandbox_prov_51g4 := typechecker.expression_provenance_sandbox_derived(t_int_51g4, ctx);
    mut joined_raw_sandbox_51g4 := typechecker.step51g_join_expression_provenance(raw_prov_51g4, sandbox_prov_51g4, ctx);
    if typechecker.step51g_non_laundering_provenance_blocks_safe_brand(joined_raw_sandbox_51g4, ctx) != 1 {
        os.LogStr("Error: Step 5.1G provenance policy did not block raw+sandbox provenance");
        os.Exit(1);
    }
    if typechecker.step51g_non_laundering_provenance_requires_unsafe_boundary(joined_raw_sandbox_51g4, ctx) != 1 {
        os.LogStr("Error: Step 5.1G provenance policy did not require unsafe for raw+sandbox provenance");
        os.Exit(1);
    }

    mut unknown_prov_51g4 := typechecker.expression_provenance_unknown(t_int_51g4, ctx);
    if typechecker.step51g_non_laundering_provenance_blocks_safe_brand(unknown_prov_51g4, ctx) != 1 {
        os.LogStr("Error: Step 5.1G provenance policy did not block unknown provenance");
        os.Exit(1);
    }
    if typechecker.step51g_non_laundering_provenance_requires_unsafe_boundary(unknown_prov_51g4, ctx) != 0 {
        os.LogStr("Error: Step 5.1G provenance policy incorrectly required unsafe for unknown-only provenance");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: Step 5.1G non-laundering policy spine verified!");
}