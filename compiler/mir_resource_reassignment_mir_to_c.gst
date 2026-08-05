// Patch 15.4 MIR-to-C consumer for compiler-owned reassignment transactions.
//
// This module validates the canonical sidecar, then maps each selected
// replacement policy mechanically. It does not discover old ownership,
// replacement identity, cleanup, or destruction order from source names.

import "mir_resource_authority.gst" as authority;
import "mir_resource_reassignment.gst" as reassignment;
import "mir_resource_value.gst" as resource_mir;

type MirResourceReassignmentCEmission[ctx] struct {
    success: int,
    c_source: str,
    reason_code: str
}

func mir_resource_reassignment_c_emission(success: int, c_source: str, reason_code: str, ctx: &Arena) MirResourceReassignmentCEmission[ctx] {
    mut emission: MirResourceReassignmentCEmission[ctx];
    emission.success = success;
    emission.c_source = std.Clone(ctx, c_source);
    emission.reason_code = std.Clone(ctx, reason_code);
    return emission;
}

func mir_resource_reassignment_carrier_symbol(resource_table: resource_mir.MirResourceMirTable[ctx], carrier_id: str, ctx: &Arena) str {
    mut carrier_query := resource_mir.mir_resource_carrier_by_id(resource_table, carrier_id, ctx);
    if carrier_query.found == 0 { return ""; }
    return std.Clone(ctx, carrier_query.value.backend_symbol);
}

func mir_resource_reassignment_runtime_symbol(entry: reassignment.MirResourceReassignment[ctx], resource_table: resource_mir.MirResourceMirTable[ctx], authority_table: authority.MirResourceAuthorityTable[ctx], ctx: &Arena) str {
    if std.str_eq(entry.resolution_policy, "transfer_before_replacement") == 1 { return ""; }
    if std.str_eq(entry.resolution_policy, "scheduled_cleanup") == 1 { return "gust_resource_schedule_cleanup"; }
    mut old_value_query := resource_mir.mir_resource_value_by_id(resource_table, entry.old_value_id, ctx);
    if old_value_query.found == 0 { return ""; }
    mut destructor_query := authority.mir_destructor_for(
        authority_table,
        old_value_query.value.resource_type_id,
        ctx
    );
    if destructor_query.found == 0 { return ""; }
    return std.Clone(ctx, destructor_query.value.runtime_symbol);
}

func mir_resource_reassignment_action_name(policy: str) str {
    if std.str_eq(policy, "immediate_destroy") == 1 { return "destroy_then_replace"; }
    if std.str_eq(policy, "scheduled_cleanup") == 1 { return "schedule_then_replace"; }
    if std.str_eq(policy, "transfer_before_replacement") == 1 { return "transfer_then_replace"; }
    return "unknown_reassignment";
}

func mir_resource_reassignment_entry_to_c(entry: reassignment.MirResourceReassignment[ctx], resource_table: resource_mir.MirResourceMirTable[ctx], authority_table: authority.MirResourceAuthorityTable[ctx], ctx: &Arena) MirResourceReassignmentCEmission[ctx] {
    mut old_symbol := mir_resource_reassignment_carrier_symbol(resource_table, entry.old_carrier_id, ctx);
    mut replacement_symbol := mir_resource_reassignment_carrier_symbol(resource_table, entry.replacement_carrier_id, ctx);
    if len(old_symbol) == 0 || len(replacement_symbol) == 0 {
        return mir_resource_reassignment_c_emission(0, "", "resource_reassignment_storage_identity_mismatch", ctx);
    }

    mut output := "/* canonical resource reassignment ";
    output = std.Concat(output, entry.reassignment_id);
    output = std.Concat(output, " order=");
    output = std.Concat(output, std.FormatInt(entry.destruction_order));
    output = std.Concat(output, " */ ");
    if std.str_eq(entry.resolution_policy, "immediate_destroy") == 1 {
        mut runtime_symbol := mir_resource_reassignment_runtime_symbol(entry, resource_table, authority_table, ctx);
        if len(runtime_symbol) == 0 {
            return mir_resource_reassignment_c_emission(0, "", "resource_reassignment_old_destroy_resolution_invalid", ctx);
        }
        output = std.Concat(output, runtime_symbol);
        output = std.Concat(output, "(&");
        output = std.Concat(output, old_symbol);
        output = std.Concat(output, "); ");
    } else if std.str_eq(entry.resolution_policy, "scheduled_cleanup") == 1 {
        output = std.Concat(output, "gust_resource_schedule_cleanup(\"");
        output = std.Concat(output, entry.cleanup_obligation_id);
        output = std.Concat(output, "\", &");
        output = std.Concat(output, old_symbol);
        output = std.Concat(output, "); ");
    } else {
        mut transfer_symbol := mir_resource_reassignment_carrier_symbol(
            resource_table,
            entry.transfer_destination_carrier_id,
            ctx
        );
        if len(transfer_symbol) == 0 {
            return mir_resource_reassignment_c_emission(0, "", "resource_reassignment_transfer_resolution_invalid", ctx);
        }
        output = std.Concat(output, transfer_symbol);
        output = std.Concat(output, " = ");
        output = std.Concat(output, old_symbol);
        output = std.Concat(output, "; ");
        output = std.Concat(output, old_symbol);
        output = std.Concat(output, ".state = GUST_RESOURCE_MOVED; ");
    }
    output = std.Concat(output, replacement_symbol);
    output = std.Concat(output, ".state = GUST_RESOURCE_LIVE;");
    return mir_resource_reassignment_c_emission(1, output, "resource_reassignment_c_emitted", ctx);
}

func mir_resource_reassignment_to_c_source(table: reassignment.MirResourceReassignmentTable[ctx], resource_table: resource_mir.MirResourceMirTable[ctx], authority_table: authority.MirResourceAuthorityTable[ctx], ctx: &Arena) MirResourceReassignmentCEmission[ctx] {
    mut validation := reassignment.mir_resource_reassignment_validate(table, resource_table, authority_table, ctx);
    if validation.valid == 0 {
        return mir_resource_reassignment_c_emission(0, "", validation.reason_code, ctx);
    }
    mut entry_count := reassignment.mir_resource_reassignment_entry_count(table, ctx);
    mut output := "/* compiler-owned resource reassignment MIR */\n";
    mut entry_index := 0;
    while entry_index < entry_count {
        mut current_entry := reassignment.mir_resource_reassignment_entry_at(table, entry_index, ctx);
        mut entry_emission := mir_resource_reassignment_entry_to_c(
            current_entry,
            resource_table,
            authority_table,
            ctx
        );
        if entry_emission.success == 0 { return entry_emission; }
        output = std.Concat(output, entry_emission.c_source);
        output = std.Concat(output, "\n");
        entry_index = entry_index + 1;
    }
    return mir_resource_reassignment_c_emission(1, output, "resource_reassignment_c_emitted", ctx);
}

func mir_resource_reassignment_lowering_witness(entry: reassignment.MirResourceReassignment[ctx], resource_table: resource_mir.MirResourceMirTable[ctx], authority_table: authority.MirResourceAuthorityTable[ctx], ctx: &Arena) str {
    mut row := "resource_reassignment_lowering: id=";
    row = std.Concat(row, entry.reassignment_id);
    row = std.Concat(row, " action=");
    row = std.Concat(row, mir_resource_reassignment_action_name(entry.resolution_policy));
    row = std.Concat(row, " old=");
    row = std.Concat(row, entry.old_resource_id);
    row = std.Concat(row, " replacement=");
    row = std.Concat(row, entry.replacement_resource_id);
    row = std.Concat(row, " storage=");
    row = std.Concat(row, entry.storage_id);
    row = std.Concat(row, " cleanup=");
    row = std.Concat(row, entry.cleanup_obligation_id);
    row = std.Concat(row, " runtime_symbol=");
    row = std.Concat(row, mir_resource_reassignment_runtime_symbol(entry, resource_table, authority_table, ctx));
    row = std.Concat(row, " order=");
    row = std.Concat(row, std.FormatInt(entry.destruction_order));
    row = std.Concat(row, " old_result=");
    row = std.Concat(row, entry.old_resulting_state);
    row = std.Concat(row, " replacement_state=");
    row = std.Concat(row, entry.replacement_resulting_state);
    row = std.Concat(row, " effect=");
    row = std.Concat(row, entry.observable_effect);
    row = std.Concat(row, "\n");
    return std.Clone(ctx, row);
}

func mir_resource_reassignment_mir_to_c_witness(table: reassignment.MirResourceReassignmentTable[ctx], resource_table: resource_mir.MirResourceMirTable[ctx], authority_table: authority.MirResourceAuthorityTable[ctx], ctx: &Arena) str {
    mut validation := reassignment.mir_resource_reassignment_validate(table, resource_table, authority_table, ctx);
    if validation.valid == 0 {
        mut rejected := "resource_reassignment_lowering_witness: rejected reason=";
        rejected = std.Concat(rejected, validation.reason_code);
        rejected = std.Concat(rejected, "\n");
        return std.Clone(ctx, rejected);
    }
    mut entry_count := reassignment.mir_resource_reassignment_entry_count(table, ctx);
    mut output := "resource_reassignment_lowering_witness: accepted\n";
    mut entry_index := 0;
    while entry_index < entry_count {
        mut current_entry := reassignment.mir_resource_reassignment_entry_at(table, entry_index, ctx);
        output = std.Concat(
            output,
            mir_resource_reassignment_lowering_witness(
                current_entry,
                resource_table,
                authority_table,
                ctx
            )
        );
        entry_index = entry_index + 1;
    }
    return std.Clone(ctx, output);
}