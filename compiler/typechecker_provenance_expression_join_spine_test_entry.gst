import "typechecker.gst" as typechecker;
import "ast.gst" as ast;

func main() {
    mut ctx := os.ArenaNew();
    defer ctx.Free();

    mut t_int_51g3: ast.Type[ctx];
    t_int_51g3.tag = 0;

    mut safe_left_51g3 := typechecker.expression_provenance_safe_arena(t_int_51g3, ctx);
    typechecker.set_add(safe_left_51g3.legacy_origins, "safe_left_root", ctx);

    mut safe_right_51g3 := typechecker.expression_provenance_safe_arena(t_int_51g3, ctx);
    typechecker.set_add(safe_right_51g3.legacy_origins, "safe_right_root", ctx);

    mut joined_safe_safe_51g3 := typechecker.step51g_join_expression_provenance(safe_left_51g3, safe_right_51g3, ctx);
    if typechecker.expression_provenance_allows_safe_branding(joined_safe_safe_51g3) != 1 {
        os.LogStr("Error: Step 5.1G expression join did not preserve safe+safe branding");
        os.Exit(1);
    }
    if typechecker.set_contains(joined_safe_safe_51g3.legacy_origins, "safe_left_root", ctx) != 1 {
        os.LogStr("Error: Step 5.1G expression join lost left legacy origin");
        os.Exit(1);
    }
    if typechecker.set_contains(joined_safe_safe_51g3.legacy_origins, "safe_right_root", ctx) != 1 {
        os.LogStr("Error: Step 5.1G expression join lost right legacy origin");
        os.Exit(1);
    }

    mut raw_right_51g3 := typechecker.expression_provenance_raw_derived(t_int_51g3, ctx);
    typechecker.set_add(raw_right_51g3.legacy_origins, "raw_right_root", ctx);

    mut joined_safe_raw_51g3 := typechecker.step51g_join_expression_provenance(safe_left_51g3, raw_right_51g3, ctx);
    if joined_safe_raw_51g3.address_origin.is_raw_derived != 1 {
        os.LogStr("Error: Step 5.1G expression join lost raw-derived address origin");
        os.Exit(1);
    }
    if typechecker.expression_provenance_blocks_safe_branding(joined_safe_raw_51g3) != 1 {
        os.LogStr("Error: Step 5.1G expression join did not block safe branding for safe+raw");
        os.Exit(1);
    }
    if typechecker.set_contains(joined_safe_raw_51g3.legacy_origins, "safe_left_root", ctx) != 1 {
        os.LogStr("Error: Step 5.1G safe+raw expression join lost safe legacy origin");
        os.Exit(1);
    }
    if typechecker.set_contains(joined_safe_raw_51g3.legacy_origins, "raw_right_root", ctx) != 1 {
        os.LogStr("Error: Step 5.1G safe+raw expression join lost raw legacy origin");
        os.Exit(1);
    }

    mut sandbox_right_51g3 := typechecker.expression_provenance_sandbox_derived(t_int_51g3, ctx);
    typechecker.set_add(sandbox_right_51g3.legacy_origins, "sandbox_right_root", ctx);

    mut joined_raw_sandbox_legacy_51g3 := typechecker.expression_provenance_join(raw_right_51g3, sandbox_right_51g3, ctx);
    if joined_raw_sandbox_legacy_51g3.address_origin.is_raw_derived != 1 {
        os.LogStr("Error: legacy expression join lost raw-derived metadata after Step 5.1G delegation");
        os.Exit(1);
    }
    if joined_raw_sandbox_legacy_51g3.address_origin.is_sandbox_derived != 1 {
        os.LogStr("Error: legacy expression join lost sandbox-derived metadata after Step 5.1G delegation");
        os.Exit(1);
    }
    if typechecker.set_contains(joined_raw_sandbox_legacy_51g3.legacy_origins, "raw_right_root", ctx) != 1 {
        os.LogStr("Error: legacy expression join lost raw legacy origin after Step 5.1G delegation");
        os.Exit(1);
    }
    if typechecker.set_contains(joined_raw_sandbox_legacy_51g3.legacy_origins, "sandbox_right_root", ctx) != 1 {
        os.LogStr("Error: legacy expression join lost sandbox legacy origin after Step 5.1G delegation");
        os.Exit(1);
    }

    mut unknown_right_51g3 := typechecker.expression_provenance_unknown(t_int_51g3, ctx);
    mut joined_safe_unknown_legacy_51g3 := typechecker.expression_provenance_join(safe_left_51g3, unknown_right_51g3, ctx);
    if joined_safe_unknown_legacy_51g3.address_origin.is_unknown != 1 {
        os.LogStr("Error: legacy expression join did not preserve unknown address origin");
        os.Exit(1);
    }
    if typechecker.expression_provenance_allows_safe_branding(joined_safe_unknown_legacy_51g3) != 0 {
        os.LogStr("Error: legacy expression join allowed safe branding for safe+unknown");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: Step 5.1G expression provenance join spine verified!");
}