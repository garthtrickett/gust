import "typechecker.gst" as typechecker;
import "ast.gst" as ast;

func main() {
    mut ctx := os.ArenaNew();
    defer ctx.Free();

    mut t_int_51g2: ast.Type[ctx];
    t_int_51g2.tag = 0;

    mut safe_origin_51g2: typechecker.AddressOriginMetadata;
    typechecker.init_address_origin_safe_arena(&safe_origin_51g2);

    mut raw_origin_51g2: typechecker.AddressOriginMetadata;
    typechecker.init_address_origin_raw_derived(&raw_origin_51g2);

    mut sandbox_origin_51g2: typechecker.AddressOriginMetadata;
    typechecker.init_address_origin_sandbox_derived(&sandbox_origin_51g2);

    mut unknown_origin_51g2: typechecker.AddressOriginMetadata;
    typechecker.init_address_origin_unknown(&unknown_origin_51g2);

    if typechecker.address_origin_allows_safe_branding(safe_origin_51g2) != 1 {
        os.LogStr("Error: legacy safe-brand helper no longer accepts safe arena origin");
        os.Exit(1);
    }
    if typechecker.address_origin_allows_safe_branding(raw_origin_51g2) != 0 {
        os.LogStr("Error: legacy safe-brand helper accepted raw-derived origin");
        os.Exit(1);
    }
    if typechecker.address_origin_allows_safe_branding(sandbox_origin_51g2) != 0 {
        os.LogStr("Error: legacy safe-brand helper accepted sandbox-derived origin");
        os.Exit(1);
    }
    if typechecker.address_origin_allows_safe_branding(unknown_origin_51g2) != 0 {
        os.LogStr("Error: legacy safe-brand helper accepted unknown origin");
        os.Exit(1);
    }

    mut joined_legacy_safe_safe_51g2 := typechecker.address_origin_join(safe_origin_51g2, safe_origin_51g2);
    if typechecker.step51g_address_origin_is_safe_arena_only(joined_legacy_safe_safe_51g2) != 1 {
        os.LogStr("Error: legacy join did not delegate safe+safe to Step 5.1G spine");
        os.Exit(1);
    }

    mut joined_legacy_safe_raw_51g2 := typechecker.address_origin_join(safe_origin_51g2, raw_origin_51g2);
    if joined_legacy_safe_raw_51g2.is_raw_derived != 1 {
        os.LogStr("Error: legacy join lost raw-derived metadata after Step 5.1G delegation");
        os.Exit(1);
    }
    if typechecker.address_origin_allows_safe_branding(joined_legacy_safe_raw_51g2) != 0 {
        os.LogStr("Error: legacy join safe+raw unexpectedly allowed safe branding");
        os.Exit(1);
    }

    mut joined_legacy_raw_sandbox_51g2 := typechecker.address_origin_join(raw_origin_51g2, sandbox_origin_51g2);
    if joined_legacy_raw_sandbox_51g2.is_raw_derived != 1 {
        os.LogStr("Error: legacy join raw+sandbox lost raw-derived metadata");
        os.Exit(1);
    }
    if joined_legacy_raw_sandbox_51g2.is_sandbox_derived != 1 {
        os.LogStr("Error: legacy join raw+sandbox lost sandbox-derived metadata");
        os.Exit(1);
    }

    mut safe_prov_51g2: typechecker.ExpressionProvenance[ctx];
    safe_prov_51g2.resolved_type = t_int_51g2;
    safe_prov_51g2.address_origin = safe_origin_51g2;
    safe_prov_51g2.legacy_origins = typechecker.set_init(ctx);
    if typechecker.expression_provenance_allows_safe_branding(safe_prov_51g2) != 1 {
        os.LogStr("Error: legacy expression provenance helper did not allow safe arena provenance");
        os.Exit(1);
    }
    if typechecker.expression_provenance_blocks_safe_branding(safe_prov_51g2) != 0 {
        os.LogStr("Error: legacy expression provenance block helper blocked safe arena provenance");
        os.Exit(1);
    }

    mut raw_prov_51g2: typechecker.ExpressionProvenance[ctx];
    raw_prov_51g2.resolved_type = t_int_51g2;
    raw_prov_51g2.address_origin = raw_origin_51g2;
    raw_prov_51g2.legacy_origins = typechecker.set_init(ctx);
    if typechecker.expression_provenance_allows_safe_branding(raw_prov_51g2) != 0 {
        os.LogStr("Error: legacy expression provenance helper allowed raw-derived provenance");
        os.Exit(1);
    }
    if typechecker.expression_provenance_blocks_safe_branding(raw_prov_51g2) != 1 {
        os.LogStr("Error: legacy expression provenance block helper did not block raw-derived provenance");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: Step 5.1G legacy provenance helpers delegate to canonical origin spine!");
}