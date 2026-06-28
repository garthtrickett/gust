import "typechecker.gst" as typechecker;
import "ast.gst" as ast;

func main() {
    mut ctx := os.ArenaNew();
    defer ctx.Free();

    mut t_int_51g6: ast.Type[ctx];
    t_int_51g6.tag = 0;

    mut safe_origin_51g6: typechecker.AddressOriginMetadata;
    typechecker.init_address_origin_safe_arena(&safe_origin_51g6);

    mut raw_origin_51g6: typechecker.AddressOriginMetadata;
    typechecker.init_address_origin_raw_derived(&raw_origin_51g6);

    mut sandbox_origin_51g6: typechecker.AddressOriginMetadata;
    typechecker.init_address_origin_sandbox_derived(&sandbox_origin_51g6);

    mut unknown_origin_51g6: typechecker.AddressOriginMetadata;
    typechecker.init_address_origin_unknown(&unknown_origin_51g6);

    if typechecker.step51g_address_origin_is_raw_or_sandbox_derived(safe_origin_51g6) != 0 {
        os.LogStr("Error: Step 5.1G boundary spine classified safe arena as raw/sandbox-derived");
        os.Exit(1);
    }
    if typechecker.step51g_address_origin_requires_unsafe_boundary(safe_origin_51g6) != 0 {
        os.LogStr("Error: Step 5.1G boundary spine required unsafe for safe arena origin");
        os.Exit(1);
    }
    if typechecker.step51g_address_origin_is_raw_or_sandbox_derived(raw_origin_51g6) != 1 {
        os.LogStr("Error: Step 5.1G boundary spine did not classify raw-derived origin");
        os.Exit(1);
    }
    if typechecker.step51g_address_origin_requires_unsafe_boundary(raw_origin_51g6) != 1 {
        os.LogStr("Error: Step 5.1G boundary spine did not require unsafe for raw-derived origin");
        os.Exit(1);
    }
    if typechecker.step51g_address_origin_is_raw_or_sandbox_derived(sandbox_origin_51g6) != 1 {
        os.LogStr("Error: Step 5.1G boundary spine did not classify sandbox-derived origin");
        os.Exit(1);
    }
    if typechecker.step51g_address_origin_requires_unsafe_boundary(sandbox_origin_51g6) != 1 {
        os.LogStr("Error: Step 5.1G boundary spine did not require unsafe for sandbox-derived origin");
        os.Exit(1);
    }
    if typechecker.step51g_address_origin_is_raw_or_sandbox_derived(unknown_origin_51g6) != 0 {
        os.LogStr("Error: Step 5.1G boundary spine classified unknown origin as raw/sandbox-derived");
        os.Exit(1);
    }
    if typechecker.step51g_address_origin_requires_unsafe_boundary(unknown_origin_51g6) != 0 {
        os.LogStr("Error: Step 5.1G boundary spine required unsafe for unknown-only origin before deferred unknown enforcement");
        os.Exit(1);
    }

    if typechecker.address_origin_is_raw_or_sandbox_derived(safe_origin_51g6) != typechecker.step51g_address_origin_is_raw_or_sandbox_derived(safe_origin_51g6) {
        os.LogStr("Error: legacy origin raw/sandbox helper diverged from Step 5.1G spine for safe origin");
        os.Exit(1);
    }
    if typechecker.address_origin_is_raw_or_sandbox_derived(raw_origin_51g6) != typechecker.step51g_address_origin_is_raw_or_sandbox_derived(raw_origin_51g6) {
        os.LogStr("Error: legacy origin raw/sandbox helper diverged from Step 5.1G spine for raw origin");
        os.Exit(1);
    }
    if typechecker.address_origin_is_raw_or_sandbox_derived(sandbox_origin_51g6) != typechecker.step51g_address_origin_is_raw_or_sandbox_derived(sandbox_origin_51g6) {
        os.LogStr("Error: legacy origin raw/sandbox helper diverged from Step 5.1G spine for sandbox origin");
        os.Exit(1);
    }
    if typechecker.address_origin_is_raw_or_sandbox_derived(unknown_origin_51g6) != typechecker.step51g_address_origin_is_raw_or_sandbox_derived(unknown_origin_51g6) {
        os.LogStr("Error: legacy origin raw/sandbox helper diverged from Step 5.1G spine for unknown origin");
        os.Exit(1);
    }

    if typechecker.address_origin_requires_unsafe_boundary(safe_origin_51g6) != typechecker.step51g_address_origin_requires_unsafe_boundary(safe_origin_51g6) {
        os.LogStr("Error: legacy origin unsafe-boundary helper diverged from Step 5.1G spine for safe origin");
        os.Exit(1);
    }
    if typechecker.address_origin_requires_unsafe_boundary(raw_origin_51g6) != typechecker.step51g_address_origin_requires_unsafe_boundary(raw_origin_51g6) {
        os.LogStr("Error: legacy origin unsafe-boundary helper diverged from Step 5.1G spine for raw origin");
        os.Exit(1);
    }
    if typechecker.address_origin_requires_unsafe_boundary(sandbox_origin_51g6) != typechecker.step51g_address_origin_requires_unsafe_boundary(sandbox_origin_51g6) {
        os.LogStr("Error: legacy origin unsafe-boundary helper diverged from Step 5.1G spine for sandbox origin");
        os.Exit(1);
    }
    if typechecker.address_origin_requires_unsafe_boundary(unknown_origin_51g6) != typechecker.step51g_address_origin_requires_unsafe_boundary(unknown_origin_51g6) {
        os.LogStr("Error: legacy origin unsafe-boundary helper diverged from Step 5.1G spine for unknown origin");
        os.Exit(1);
    }

    mut safe_prov_51g6 := typechecker.expression_provenance_safe_arena(t_int_51g6, ctx);
    mut raw_prov_51g6 := typechecker.expression_provenance_raw_derived(t_int_51g6, ctx);
    mut sandbox_prov_51g6 := typechecker.expression_provenance_sandbox_derived(t_int_51g6, ctx);
    mut unknown_prov_51g6 := typechecker.expression_provenance_unknown(t_int_51g6, ctx);

    if typechecker.step51g_expression_provenance_requires_unsafe_boundary(safe_prov_51g6) != 0 {
        os.LogStr("Error: Step 5.1G expression boundary helper required unsafe for safe arena provenance");
        os.Exit(1);
    }
    if typechecker.step51g_expression_provenance_requires_unsafe_boundary(raw_prov_51g6) != 1 {
        os.LogStr("Error: Step 5.1G expression boundary helper did not require unsafe for raw-derived provenance");
        os.Exit(1);
    }
    if typechecker.step51g_expression_provenance_requires_unsafe_boundary(sandbox_prov_51g6) != 1 {
        os.LogStr("Error: Step 5.1G expression boundary helper did not require unsafe for sandbox-derived provenance");
        os.Exit(1);
    }
    if typechecker.step51g_expression_provenance_requires_unsafe_boundary(unknown_prov_51g6) != 0 {
        os.LogStr("Error: Step 5.1G expression boundary helper required unsafe for unknown-only provenance before deferred unknown enforcement");
        os.Exit(1);
    }
    if typechecker.step51g_expression_provenance_is_raw_or_sandbox_derived(safe_prov_51g6) != 0 {
        os.LogStr("Error: Step 5.1G expression raw/sandbox helper classified safe provenance");
        os.Exit(1);
    }
    if typechecker.step51g_expression_provenance_is_raw_or_sandbox_derived(raw_prov_51g6) != 1 {
        os.LogStr("Error: Step 5.1G expression raw/sandbox helper did not classify raw-derived provenance");
        os.Exit(1);
    }
    if typechecker.step51g_expression_provenance_is_raw_or_sandbox_derived(sandbox_prov_51g6) != 1 {
        os.LogStr("Error: Step 5.1G expression raw/sandbox helper did not classify sandbox-derived provenance");
        os.Exit(1);
    }
    if typechecker.step51g_expression_provenance_is_raw_or_sandbox_derived(unknown_prov_51g6) != 0 {
        os.LogStr("Error: Step 5.1G expression raw/sandbox helper classified unknown-only provenance");
        os.Exit(1);
    }
    if typechecker.expression_provenance_requires_unsafe_boundary(raw_prov_51g6) != typechecker.step51g_expression_provenance_requires_unsafe_boundary(raw_prov_51g6) {
        os.LogStr("Error: legacy expression boundary helper diverged from Step 5.1G expression spine");
        os.Exit(1);
    }
    if typechecker.expression_provenance_is_raw_or_sandbox_derived(sandbox_prov_51g6) != typechecker.step51g_expression_provenance_is_raw_or_sandbox_derived(sandbox_prov_51g6) {
        os.LogStr("Error: legacy expression raw/sandbox helper diverged from Step 5.1G expression spine");
        os.Exit(1);
    }
    if typechecker.step51g_non_laundering_provenance_requires_unsafe_boundary(raw_prov_51g6, ctx) != 1 {
        os.LogStr("Error: non-laundering provenance boundary helper did not require unsafe for raw provenance");
        os.Exit(1);
    }
    if typechecker.step51g_non_laundering_provenance_requires_unsafe_boundary(unknown_prov_51g6, ctx) != 0 {
        os.LogStr("Error: non-laundering provenance boundary helper required unsafe for unknown-only provenance before deferred unknown enforcement");
        os.Exit(1);
    }
    if typechecker.step51g_non_laundering_provenance_blocks_safe_brand(unknown_prov_51g6, ctx) != 1 {
        os.LogStr("Error: unknown provenance should still be classified as blocking safe branding");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: Step 5.1G unsafe-boundary predicate spine verified!");
}
