// Patch 15.5 MIR-to-C lowering for compiler-owned normal scope-exit cleanup.

import "mir_resource_authority.gst" as authority;
import "mir_resource_value.gst" as resource_mir;
import "mir_scope_exit_cleanup.gst" as cleanup;

type MirScopeExitCleanupCEmission[ctx] struct {
    success: int,
    c_source: str,
    reason_code: str
}

func mir_scope_exit_cleanup_c_emission(success: int, c_source: str, reason_code: str, ctx: &Arena) MirScopeExitCleanupCEmission[ctx] {
    mut emission_cleanup_c: MirScopeExitCleanupCEmission[ctx];
    emission_cleanup_c.success = success;
    emission_cleanup_c.c_source = std.Clone(ctx, c_source);
    emission_cleanup_c.reason_code = std.Clone(ctx, reason_code);
    return emission_cleanup_c;
}

func mir_scope_exit_cleanup_runtime_symbol(entry: cleanup.MirScopeExitCleanup[ctx], authority_table: authority.MirResourceAuthorityTable[ctx], ctx: &Arena) str {
    mut identity_cleanup_runtime := authority.mir_resource_by_id(authority_table, entry.resource_id, ctx);
    if identity_cleanup_runtime.found == 0 { return ""; }
    mut destructor_cleanup_runtime := authority.mir_destructor_for(
        authority_table,
        identity_cleanup_runtime.value.resource_type_id,
        ctx
    );
    if destructor_cleanup_runtime.found == 0 ||
       std.str_eq(destructor_cleanup_runtime.value.destructor_id, entry.destructor_id) == 0
    {
        return "";
    }
    return std.Clone(ctx, destructor_cleanup_runtime.value.runtime_symbol);
}

func mir_scope_exit_cleanup_entry_to_c(entry: cleanup.MirScopeExitCleanup[ctx], resource_table: resource_mir.MirResourceMirTable[ctx], authority_table: authority.MirResourceAuthorityTable[ctx], ctx: &Arena) MirScopeExitCleanupCEmission[ctx] {
    mut carrier_cleanup_c := resource_mir.mir_resource_carrier_by_id(resource_table, entry.carrier_id, ctx);
    mut runtime_cleanup_c := mir_scope_exit_cleanup_runtime_symbol(entry, authority_table, ctx);
    if carrier_cleanup_c.found == 0 || len(carrier_cleanup_c.value.backend_symbol) == 0 ||
       len(runtime_cleanup_c) == 0
    {
        return mir_scope_exit_cleanup_c_emission(0, "", "scope_exit_cleanup_destructor_mismatch", ctx);
    }
    mut source_cleanup_c := "/* compiler scope-exit cleanup scope=";
    source_cleanup_c = std.Concat(source_cleanup_c, entry.scope_id);
    source_cleanup_c = std.Concat(source_cleanup_c, " order=");
    source_cleanup_c = std.Concat(source_cleanup_c, std.FormatInt(entry.execution_order));
    source_cleanup_c = std.Concat(source_cleanup_c, " declaration=");
    source_cleanup_c = std.Concat(source_cleanup_c, entry.owning_declaration);
    source_cleanup_c = std.Concat(source_cleanup_c, " */ ");
    source_cleanup_c = std.Concat(source_cleanup_c, runtime_cleanup_c);
    source_cleanup_c = std.Concat(source_cleanup_c, "(&");
    source_cleanup_c = std.Concat(source_cleanup_c, carrier_cleanup_c.value.backend_symbol);
    source_cleanup_c = std.Concat(source_cleanup_c, ");");
    return mir_scope_exit_cleanup_c_emission(1, source_cleanup_c, "scope_exit_cleanup_c_emitted", ctx);
}

func mir_scope_exit_cleanup_to_c_source(plan: cleanup.MirScopeExitCleanupPlan[ctx], scope_table: cleanup.MirResourceScopeTable[ctx], resource_table: resource_mir.MirResourceMirTable[ctx], authority_table: authority.MirResourceAuthorityTable[ctx], ctx: &Arena) MirScopeExitCleanupCEmission[ctx] {
    mut validation_cleanup_c := cleanup.mir_scope_exit_cleanup_validate(
        plan,
        scope_table,
        resource_table,
        authority_table,
        ctx
    );
    if validation_cleanup_c.valid == 0 {
        return mir_scope_exit_cleanup_c_emission(0, "", validation_cleanup_c.reason_code, ctx);
    }
    mut output_cleanup_c := "/* compiler-owned normal scope-exit cleanup MIR */\n";
    mut cleanup_c_index := 0;
    while cleanup_c_index < cleanup.mir_scope_exit_cleanup_entry_count(plan, ctx) {
        mut cleanup_c_entry := cleanup.mir_scope_exit_cleanup_entry_at(plan, cleanup_c_index, ctx);
        mut cleanup_c_emission := mir_scope_exit_cleanup_entry_to_c(
            cleanup_c_entry,
            resource_table,
            authority_table,
            ctx
        );
        if cleanup_c_emission.success == 0 { return cleanup_c_emission; }
        output_cleanup_c = std.Concat(output_cleanup_c, cleanup_c_emission.c_source);
        output_cleanup_c = std.Concat(output_cleanup_c, "\n");
        cleanup_c_index = cleanup_c_index + 1;
    }
    return mir_scope_exit_cleanup_c_emission(1, output_cleanup_c, "scope_exit_cleanup_c_emitted", ctx);
}

func mir_scope_exit_cleanup_lowering_witness(plan: cleanup.MirScopeExitCleanupPlan[ctx], scope_table: cleanup.MirResourceScopeTable[ctx], resource_table: resource_mir.MirResourceMirTable[ctx], authority_table: authority.MirResourceAuthorityTable[ctx], ctx: &Arena) str {
    mut validation_cleanup_witness := cleanup.mir_scope_exit_cleanup_validate(
        plan,
        scope_table,
        resource_table,
        authority_table,
        ctx
    );
    if validation_cleanup_witness.valid == 0 {
        mut rejected_cleanup_witness := "scope_exit_cleanup_lowering_witness: rejected reason=";
        rejected_cleanup_witness = std.Concat(rejected_cleanup_witness, validation_cleanup_witness.reason_code);
        rejected_cleanup_witness = std.Concat(rejected_cleanup_witness, "\n");
        return std.Clone(ctx, rejected_cleanup_witness);
    }
    mut output_cleanup_witness := "scope_exit_cleanup_lowering_witness: accepted\n";
    mut lowering_cleanup_index := 0;
    while lowering_cleanup_index < cleanup.mir_scope_exit_cleanup_entry_count(plan, ctx) {
        mut lowering_cleanup_entry := cleanup.mir_scope_exit_cleanup_entry_at(plan, lowering_cleanup_index, ctx);
        mut lowering_cleanup_runtime := mir_scope_exit_cleanup_runtime_symbol(
            lowering_cleanup_entry,
            authority_table,
            ctx
        );
        mut lowering_cleanup_row := "scope_exit_cleanup_lowering: scope=";
        lowering_cleanup_row = std.Concat(lowering_cleanup_row, lowering_cleanup_entry.scope_id);
        lowering_cleanup_row = std.Concat(lowering_cleanup_row, " resource=");
        lowering_cleanup_row = std.Concat(lowering_cleanup_row, lowering_cleanup_entry.resource_id);
        lowering_cleanup_row = std.Concat(lowering_cleanup_row, " action=invoke_destructor");
        lowering_cleanup_row = std.Concat(lowering_cleanup_row, " runtime_symbol=");
        lowering_cleanup_row = std.Concat(lowering_cleanup_row, lowering_cleanup_runtime);
        lowering_cleanup_row = std.Concat(lowering_cleanup_row, " order=");
        lowering_cleanup_row = std.Concat(lowering_cleanup_row, std.FormatInt(lowering_cleanup_entry.execution_order));
        lowering_cleanup_row = std.Concat(lowering_cleanup_row, " destructor=");
        lowering_cleanup_row = std.Concat(lowering_cleanup_row, lowering_cleanup_entry.destructor_id);
        lowering_cleanup_row = std.Concat(lowering_cleanup_row, " source=");
        lowering_cleanup_row = std.Concat(lowering_cleanup_row, lowering_cleanup_entry.source_location);
        lowering_cleanup_row = std.Concat(lowering_cleanup_row, " effect=");
        lowering_cleanup_row = std.Concat(lowering_cleanup_row, lowering_cleanup_entry.observable_effect);
        lowering_cleanup_row = std.Concat(lowering_cleanup_row, "\n");
        output_cleanup_witness = std.Concat(output_cleanup_witness, lowering_cleanup_row);
        lowering_cleanup_index = lowering_cleanup_index + 1;
    }
    return std.Clone(ctx, output_cleanup_witness);
}