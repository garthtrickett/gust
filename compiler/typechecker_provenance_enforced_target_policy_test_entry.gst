import "typechecker.gst" as typechecker;
import "ast.gst" as ast;

func main() {
    mut ctx := os.ArenaNew();
    defer ctx.Free();

    mut t_int_51g5: ast.Type[ctx];
    t_int_51g5.tag = 0;

    mut branded_index_target_51g5 := typechecker.make_type_index("PolicyNode", "ctx", ctx);
    mut unbranded_index_target_51g5 := typechecker.make_type_index("PolicyNode", "", ctx);
    mut branded_ref_target_51g5 := typechecker.make_type_reference(t_int_51g5, "ctx", ctx);
    mut unbranded_ref_target_51g5 := typechecker.make_type_reference(t_int_51g5, "", ctx);

    if typechecker.step51g_non_laundering_type_is_safe_brand_target(branded_index_target_51g5, ctx) != 1 {
        os.LogStr("Error: Step 5.1G target policy did not classify branded Index as safe-brand target");
        os.Exit(1);
    }
    if typechecker.step51g_non_laundering_type_is_safe_brand_target(branded_ref_target_51g5, ctx) != 1 {
        os.LogStr("Error: Step 5.1G target policy did not classify branded Reference as safe-brand target");
        os.Exit(1);
    }
    if typechecker.step51g_non_laundering_type_is_safe_brand_target(unbranded_index_target_51g5, ctx) != 0 {
        os.LogStr("Error: Step 5.1G target policy classified unbranded Index as safe-brand target");
        os.Exit(1);
    }
    if typechecker.step51g_non_laundering_type_is_safe_brand_target(unbranded_ref_target_51g5, ctx) != 0 {
        os.LogStr("Error: Step 5.1G target policy classified unbranded Reference as safe-brand target");
        os.Exit(1);
    }

    mut safe_prov_51g5 := typechecker.expression_provenance_safe_arena(t_int_51g5, ctx);
    mut raw_prov_51g5 := typechecker.expression_provenance_raw_derived(t_int_51g5, ctx);
    mut sandbox_prov_51g5 := typechecker.expression_provenance_sandbox_derived(t_int_51g5, ctx);
    mut unknown_prov_51g5 := typechecker.expression_provenance_unknown(t_int_51g5, ctx);

    if typechecker.step51g_non_laundering_enforced_safe_brand_target_violation(branded_index_target_51g5, safe_prov_51g5, ctx) != 0 {
        os.LogStr("Error: Step 5.1G enforced target policy rejected safe arena provenance");
        os.Exit(1);
    }
    if typechecker.step51g_non_laundering_enforced_safe_brand_target_violation(branded_index_target_51g5, raw_prov_51g5, ctx) != 1 {
        os.LogStr("Error: Step 5.1G enforced target policy did not reject raw-derived provenance");
        os.Exit(1);
    }
    if typechecker.step51g_non_laundering_enforced_safe_brand_target_violation(branded_ref_target_51g5, sandbox_prov_51g5, ctx) != 1 {
        os.LogStr("Error: Step 5.1G enforced target policy did not reject sandbox-derived provenance");
        os.Exit(1);
    }
    if typechecker.step51g_non_laundering_enforced_safe_brand_target_violation(unbranded_index_target_51g5, raw_prov_51g5, ctx) != 0 {
        os.LogStr("Error: Step 5.1G enforced target policy rejected raw provenance for unbranded Index target");
        os.Exit(1);
    }
    if typechecker.step51g_non_laundering_enforced_safe_brand_target_violation(unbranded_ref_target_51g5, sandbox_prov_51g5, ctx) != 0 {
        os.LogStr("Error: Step 5.1G enforced target policy rejected sandbox provenance for unbranded Reference target");
        os.Exit(1);
    }

    if typechecker.step51g_non_laundering_enforced_safe_brand_target_violation(branded_index_target_51g5, unknown_prov_51g5, ctx) != 0 {
        os.LogStr("Error: Step 5.1G enforced target policy rejected unknown provenance before deferred unknown-origin enforcement");
        os.Exit(1);
    }
    if typechecker.step51g_non_laundering_deferred_safe_brand_target_violation(branded_index_target_51g5, unknown_prov_51g5, ctx) != 1 {
        os.LogStr("Error: Step 5.1G deferred target policy did not classify unknown safe-brand target as deferred");
        os.Exit(1);
    }
    if typechecker.step51g_non_laundering_deferred_safe_brand_target_violation(unbranded_index_target_51g5, unknown_prov_51g5, ctx) != 0 {
        os.LogStr("Error: Step 5.1G deferred target policy classified unbranded unknown target as deferred violation");
        os.Exit(1);
    }

    if typechecker.step51g_non_laundering_safe_brand_target_diagnostic_kind(branded_index_target_51g5, safe_prov_51g5, ctx) != 0 {
        os.LogStr("Error: Step 5.1G target diagnostic kind did not classify safe provenance as no violation");
        os.Exit(1);
    }
    if typechecker.step51g_non_laundering_safe_brand_target_diagnostic_kind(branded_index_target_51g5, raw_prov_51g5, ctx) != 1 {
        os.LogStr("Error: Step 5.1G target diagnostic kind did not classify raw-derived provenance as enforced violation");
        os.Exit(1);
    }
    if typechecker.step51g_non_laundering_safe_brand_target_diagnostic_kind(branded_ref_target_51g5, sandbox_prov_51g5, ctx) != 1 {
        os.LogStr("Error: Step 5.1G target diagnostic kind did not classify sandbox-derived provenance as enforced violation");
        os.Exit(1);
    }
    if typechecker.step51g_non_laundering_safe_brand_target_diagnostic_kind(branded_index_target_51g5, unknown_prov_51g5, ctx) != 2 {
        os.LogStr("Error: Step 5.1G target diagnostic kind did not classify unknown branded Index provenance as deferred violation");
        os.Exit(1);
    }
    if typechecker.step51g_non_laundering_safe_brand_target_diagnostic_kind(branded_ref_target_51g5, unknown_prov_51g5, ctx) != 2 {
        os.LogStr("Error: Step 5.1G target diagnostic kind did not classify unknown branded Reference provenance as deferred violation");
        os.Exit(1);
    }
    if typechecker.step51g_non_laundering_safe_brand_target_diagnostic_kind(unbranded_index_target_51g5, raw_prov_51g5, ctx) != 0 {
        os.LogStr("Error: Step 5.1G target diagnostic kind classified unbranded Index raw provenance as a violation");
        os.Exit(1);
    }
    if typechecker.step51g_non_laundering_safe_brand_target_diagnostic_kind(unbranded_ref_target_51g5, unknown_prov_51g5, ctx) != 0 {
        os.LogStr("Error: Step 5.1G target diagnostic kind classified unbranded Reference unknown provenance as a violation");
        os.Exit(1);
    }

    mut report_kind_raw_51g5 := typechecker.step51g_non_laundering_safe_brand_target_diagnostic_kind(branded_index_target_51g5, raw_prov_51g5, ctx);
    if report_kind_raw_51g5 != 1 {
        os.LogStr("Error: Step 5.1G reporter diagnostic kind would not report raw-derived branded target violation");
        os.Exit(1);
    }
    mut report_kind_sandbox_51g5 := typechecker.step51g_non_laundering_safe_brand_target_diagnostic_kind(branded_ref_target_51g5, sandbox_prov_51g5, ctx);
    if report_kind_sandbox_51g5 != 1 {
        os.LogStr("Error: Step 5.1G reporter diagnostic kind would not report sandbox-derived branded target violation");
        os.Exit(1);
    }
    mut report_kind_unknown_51g5 := typechecker.step51g_non_laundering_safe_brand_target_diagnostic_kind(branded_index_target_51g5, unknown_prov_51g5, ctx);
    if report_kind_unknown_51g5 == 1 {
        os.LogStr("Error: Step 5.1G reporter diagnostic kind would report deferred unknown-origin branded target violation");
        os.Exit(1);
    }
    mut report_kind_safe_51g5 := typechecker.step51g_non_laundering_safe_brand_target_diagnostic_kind(branded_ref_target_51g5, safe_prov_51g5, ctx);
    if report_kind_safe_51g5 == 1 {
        os.LogStr("Error: Step 5.1G reporter diagnostic kind would report safe branded target provenance");
        os.Exit(1);
    }
    mut report_kind_unbranded_raw_51g5 := typechecker.step51g_non_laundering_safe_brand_target_diagnostic_kind(unbranded_index_target_51g5, raw_prov_51g5, ctx);
    if report_kind_unbranded_raw_51g5 == 1 {
        os.LogStr("Error: Step 5.1G reporter diagnostic kind would report unbranded raw target provenance");
        os.Exit(1);
    }

    if typechecker.step51g_non_laundering_safe_brand_target_diagnostic_kind_reports(0) != 0 {
        os.LogStr("Error: Step 5.1G target reportability helper reported no-violation diagnostic kind");
        os.Exit(1);
    }
    if typechecker.step51g_non_laundering_safe_brand_target_diagnostic_kind_reports(1) != 1 {
        os.LogStr("Error: Step 5.1G target reportability helper did not report enforced diagnostic kind");
        os.Exit(1);
    }
    if typechecker.step51g_non_laundering_safe_brand_target_diagnostic_kind_reports(2) != 0 {
        os.LogStr("Error: Step 5.1G target reportability helper reported deferred unknown-origin diagnostic kind");
        os.Exit(1);
    }

    if typechecker.step51g_non_laundering_safe_brand_target_should_report(branded_index_target_51g5, raw_prov_51g5, ctx) != 1 {
        os.LogStr("Error: Step 5.1G target should-report helper did not report raw-derived branded target violation");
        os.Exit(1);
    }
    if typechecker.step51g_non_laundering_safe_brand_target_should_report(branded_ref_target_51g5, sandbox_prov_51g5, ctx) != 1 {
        os.LogStr("Error: Step 5.1G target should-report helper did not report sandbox-derived branded target violation");
        os.Exit(1);
    }
    if typechecker.step51g_non_laundering_safe_brand_target_should_report(branded_index_target_51g5, unknown_prov_51g5, ctx) != 0 {
        os.LogStr("Error: Step 5.1G target should-report helper reported deferred unknown-origin branded target violation");
        os.Exit(1);
    }
    if typechecker.step51g_non_laundering_safe_brand_target_should_report(branded_ref_target_51g5, safe_prov_51g5, ctx) != 0 {
        os.LogStr("Error: Step 5.1G target should-report helper reported safe branded target provenance");
        os.Exit(1);
    }
    if typechecker.step51g_non_laundering_safe_brand_target_should_report(unbranded_index_target_51g5, raw_prov_51g5, ctx) != 0 {
        os.LogStr("Error: Step 5.1G target should-report helper reported unbranded raw target provenance");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: Step 5.1G enforced safe-brand target policy verified!");
}
