import "typechecker.gst" as typechecker;
import "ast.gst" as ast;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut t_int_51g := typechecker.make_type_int();

    mut safe_origin_51g: typechecker.AddressOriginMetadata;
    typechecker.init_address_origin_safe_arena(&safe_origin_51g);
    if typechecker.step51g_address_origin_is_safe_arena_only(safe_origin_51g) != 1 {
        os.LogStr("Error: safe arena origin was not classified as trusted safe arena");
        os.Exit(1);
    }
    if typechecker.step51g_address_origin_blocks_safe_brand(safe_origin_51g) != 0 {
        os.LogStr("Error: safe arena origin unexpectedly blocked safe branding");
        os.Exit(1);
    }

    mut raw_origin_51g: typechecker.AddressOriginMetadata;
    typechecker.init_address_origin_raw_derived(&raw_origin_51g);
    if typechecker.step51g_address_origin_blocks_safe_brand(raw_origin_51g) != 1 {
        os.LogStr("Error: raw-derived origin did not block safe branding");
        os.Exit(1);
    }

    mut sandbox_origin_51g: typechecker.AddressOriginMetadata;
    typechecker.init_address_origin_sandbox_derived(&sandbox_origin_51g);
    if typechecker.step51g_address_origin_blocks_safe_brand(sandbox_origin_51g) != 1 {
        os.LogStr("Error: sandbox-derived origin did not block safe branding");
        os.Exit(1);
    }

    mut unknown_origin_51g: typechecker.AddressOriginMetadata;
    typechecker.init_address_origin_unknown(&unknown_origin_51g);
    if typechecker.step51g_address_origin_blocks_safe_brand(unknown_origin_51g) != 1 {
        os.LogStr("Error: unknown origin did not block safe branding");
        os.Exit(1);
    }

    mut joined_safe_safe_51g := typechecker.step51g_join_address_origin(safe_origin_51g, safe_origin_51g);
    if typechecker.step51g_address_origin_is_safe_arena_only(joined_safe_safe_51g) != 1 {
        os.LogStr("Error: safe+safe origin join did not remain safe arena only");
        os.Exit(1);
    }

    mut joined_safe_raw_51g := typechecker.step51g_join_address_origin(safe_origin_51g, raw_origin_51g);
    if typechecker.step51g_address_origin_blocks_safe_brand(joined_safe_raw_51g) != 1 {
        os.LogStr("Error: safe+raw origin join did not block safe branding");
        os.Exit(1);
    }
    if joined_safe_raw_51g.is_raw_derived != 1 {
        os.LogStr("Error: safe+raw origin join did not preserve raw-derived metadata");
        os.Exit(1);
    }

    mut joined_raw_sandbox_51g := typechecker.step51g_join_address_origin(raw_origin_51g, sandbox_origin_51g);
    if joined_raw_sandbox_51g.is_raw_derived != 1 {
        os.LogStr("Error: raw+sandbox origin join lost raw-derived metadata");
        os.Exit(1);
    }
    if joined_raw_sandbox_51g.is_sandbox_derived != 1 {
        os.LogStr("Error: raw+sandbox origin join lost sandbox-derived metadata");
        os.Exit(1);
    }

    mut safe_prov_51g: typechecker.ExpressionProvenance[ctx];
    safe_prov_51g.resolved_type = t_int_51g;
    safe_prov_51g.address_origin = safe_origin_51g;
    safe_prov_51g.legacy_origins = typechecker.set_init(ctx);
    if typechecker.step51g_expression_provenance_allows_safe_brand(safe_prov_51g, ctx) != 1 {
        os.LogStr("Error: safe provenance did not allow safe branding");
        os.Exit(1);
    }

    mut raw_prov_51g: typechecker.ExpressionProvenance[ctx];
    raw_prov_51g.resolved_type = t_int_51g;
    raw_prov_51g.address_origin = raw_origin_51g;
    raw_prov_51g.legacy_origins = typechecker.set_init(ctx);
    if typechecker.step51g_expression_provenance_blocks_safe_brand(raw_prov_51g, ctx) != 1 {
        os.LogStr("Error: raw provenance did not block safe branding");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: Step 5.1G provenance-origin spine helpers verified!");
}
