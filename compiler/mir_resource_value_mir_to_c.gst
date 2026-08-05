// Phase 15.2 MIR-to-C consumer for canonical resource operations.
//
// This module performs no resource discovery and owns no state machine. Every
// emitted statement is selected from MirResourceOperation and its explicit
// compiler-owned resource/carrier metadata.

import "mir_layout.gst" as layout;
import "mir_resource_authority.gst" as authority;
import "mir_resource_value.gst" as resource_mir;

type MirResourceCEmission[ctx] struct {
    success: int,
    c_source: str,
    reason_code: str
}

func mir_resource_c_emission(success: int, c_source: str, reason_code: str, ctx: &Arena) MirResourceCEmission[ctx] {
    mut result: MirResourceCEmission[ctx];
    result.success = success;
    result.c_source = std.Clone(ctx, c_source);
    result.reason_code = std.Clone(ctx, reason_code);
    return result;
}

func mir_resource_c_carrier_symbol(table: resource_mir.MirResourceMirTable[ctx], carrier_id: str, ctx: &Arena) str {
    mut query := resource_mir.mir_resource_carrier_by_id(table, carrier_id, ctx);
    if query.found == 0 { return ""; }
    return std.Clone(ctx, query.value.backend_symbol);
}

func mir_resource_operation_to_c(operation: resource_mir.MirResourceOperation[ctx], table: resource_mir.MirResourceMirTable[ctx], authority_table: authority.MirResourceAuthorityTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) MirResourceCEmission[ctx] {
    mut validation := resource_mir.mir_resource_mir_table_validate(
        table,
        authority_table,
        layout_table,
        ctx
    );
    if validation.valid == 0 {
        return mir_resource_c_emission(0, "", validation.reason_code, ctx);
    }
    mut source_symbol := mir_resource_c_carrier_symbol(table, operation.source_carrier_id, ctx);
    mut destination_symbol := mir_resource_c_carrier_symbol(table, operation.destination_carrier_id, ctx);
    unsafe {
        if operation.operation_kind.tag == 0 {
            mut declare_statement := "struct GustResourceSlot ";
            declare_statement = std.Concat(declare_statement, destination_symbol);
            declare_statement = std.Concat(declare_statement, " = {0};");
            return mir_resource_c_emission(1, declare_statement, "resource_mir_c_emitted", ctx);
        }
        if operation.operation_kind.tag == 1 {
            mut initialize_statement := destination_symbol;
            initialize_statement = std.Concat(initialize_statement, ".state = GUST_RESOURCE_LIVE;");
            return mir_resource_c_emission(1, initialize_statement, "resource_mir_c_emitted", ctx);
        }
        if operation.operation_kind.tag == 2 {
            mut read_statement := "(void)";
            read_statement = std.Concat(read_statement, source_symbol);
            read_statement = std.Concat(read_statement, ".payload;");
            return mir_resource_c_emission(1, read_statement, "resource_mir_c_emitted", ctx);
        }
        if operation.operation_kind.tag == 3 {
            mut move_statement := destination_symbol;
            move_statement = std.Concat(move_statement, " = ");
            move_statement = std.Concat(move_statement, source_symbol);
            move_statement = std.Concat(move_statement, "; ");
            move_statement = std.Concat(move_statement, source_symbol);
            move_statement = std.Concat(move_statement, ".state = GUST_RESOURCE_MOVED;");
            return mir_resource_c_emission(1, move_statement, "resource_mir_c_emitted", ctx);
        }
        if operation.operation_kind.tag == 4 {
            mut close_value_query := resource_mir.mir_resource_value_by_id(table, operation.value_id, ctx);
            if close_value_query.found == 0 {
                return mir_resource_c_emission(0, "", "resource_mir_value_metadata_missing", ctx);
            }
            mut close_query := authority.mir_close_capability_for(
                authority_table,
                close_value_query.value.resource_type_id,
                ctx
            );
            if close_query.found == 0 {
                return mir_resource_c_emission(0, "", "resource_mir_close_policy_missing", ctx);
            }
            mut close_statement := close_query.value.runtime_symbol;
            close_statement = std.Concat(close_statement, "(&");
            close_statement = std.Concat(close_statement, source_symbol);
            close_statement = std.Concat(close_statement, ");");
            return mir_resource_c_emission(1, close_statement, "resource_mir_c_emitted", ctx);
        }
        if operation.operation_kind.tag == 5 {
            mut cleanup_statement := "gust_resource_schedule_cleanup(\"";
            cleanup_statement = std.Concat(cleanup_statement, operation.cleanup_id);
            cleanup_statement = std.Concat(cleanup_statement, "\", &");
            cleanup_statement = std.Concat(cleanup_statement, source_symbol);
            cleanup_statement = std.Concat(cleanup_statement, ");");
            return mir_resource_c_emission(1, cleanup_statement, "resource_mir_c_emitted", ctx);
        }
        if operation.operation_kind.tag == 6 {
            mut destructor_value_query := resource_mir.mir_resource_value_by_id(table, operation.value_id, ctx);
            if destructor_value_query.found == 0 {
                return mir_resource_c_emission(0, "", "resource_mir_value_metadata_missing", ctx);
            }
            mut destructor_query := authority.mir_destructor_for(
                authority_table,
                destructor_value_query.value.resource_type_id,
                ctx
            );
            if destructor_query.found == 0 {
                return mir_resource_c_emission(0, "", "resource_mir_destructor_policy_missing", ctx);
            }
            mut destructor_statement := destructor_query.value.runtime_symbol;
            destructor_statement = std.Concat(destructor_statement, "(&");
            destructor_statement = std.Concat(destructor_statement, source_symbol);
            destructor_statement = std.Concat(destructor_statement, ");");
            return mir_resource_c_emission(1, destructor_statement, "resource_mir_c_emitted", ctx);
        }
        if operation.operation_kind.tag == 7 {
            mut destroyed_statement := source_symbol;
            destroyed_statement = std.Concat(destroyed_statement, ".state = GUST_RESOURCE_DESTROYED;");
            return mir_resource_c_emission(1, destroyed_statement, "resource_mir_c_emitted", ctx);
        }
    }
    return mir_resource_c_emission(0, "", "resource_mir_unknown_operation", ctx);
}

func mir_resource_mir_to_c_source(table: resource_mir.MirResourceMirTable[ctx], authority_table: authority.MirResourceAuthorityTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) MirResourceCEmission[ctx] {
    mut validation := resource_mir.mir_resource_mir_table_validate(
        table,
        authority_table,
        layout_table,
        ctx
    );
    if validation.valid == 0 {
        return mir_resource_c_emission(0, "", validation.reason_code, ctx);
    }
    mut operations: std.Vector[resource_mir.MirResourceOperation[ctx], ctx] := ctx[table.operations];
    mut output := "/* canonical resource MIR */\n";
    mut index := 0;
    while index < len(operations) {
        mut emission := mir_resource_operation_to_c(
            operations[index],
            table,
            authority_table,
            layout_table,
            ctx
        );
        if emission.success == 0 { return emission; }
        output = std.Concat(output, emission.c_source);
        output = std.Concat(output, "\n");
        index = index + 1;
    }
    return mir_resource_c_emission(1, output, "resource_mir_c_emitted", ctx);
}

func mir_resource_operation_runtime_symbol(operation: resource_mir.MirResourceOperation[ctx], table: resource_mir.MirResourceMirTable[ctx], authority_table: authority.MirResourceAuthorityTable[ctx], ctx: &Arena) str {
    unsafe {
        if operation.operation_kind.tag == 4 {
            mut close_value_query := resource_mir.mir_resource_value_by_id(table, operation.value_id, ctx);
            if close_value_query.found == 0 { return ""; }
            mut close_query := authority.mir_close_capability_for(
                authority_table,
                close_value_query.value.resource_type_id,
                ctx
            );
            if close_query.found == 0 { return ""; }
            return std.Clone(ctx, close_query.value.runtime_symbol);
        }
        if operation.operation_kind.tag == 5 {
            return "gust_resource_schedule_cleanup";
        }
        if operation.operation_kind.tag == 6 {
            mut destructor_value_query := resource_mir.mir_resource_value_by_id(table, operation.value_id, ctx);
            if destructor_value_query.found == 0 { return ""; }
            mut destructor_query := authority.mir_destructor_for(
                authority_table,
                destructor_value_query.value.resource_type_id,
                ctx
            );
            if destructor_query.found == 0 { return ""; }
            return std.Clone(ctx, destructor_query.value.runtime_symbol);
        }
    }
    return "";
}

func mir_resource_operation_lowering_witness(operation: resource_mir.MirResourceOperation[ctx], table: resource_mir.MirResourceMirTable[ctx], authority_table: authority.MirResourceAuthorityTable[ctx], ctx: &Arena) str {
    mut row := "resource_lowering: id=";
    row = std.Concat(row, operation.operation_id);
    row = std.Concat(row, " action=");
    row = std.Concat(row, resource_mir.mir_resource_operation_kind_name(operation.operation_kind));
    row = std.Concat(row, " resource=");
    row = std.Concat(row, operation.resource_id);
    row = std.Concat(row, " source=");
    row = std.Concat(row, operation.source_carrier_id);
    row = std.Concat(row, " destination=");
    row = std.Concat(row, operation.destination_carrier_id);
    row = std.Concat(row, " move_form=");
    unsafe {
        if operation.operation_kind.tag == 3 {
            mut source_query := resource_mir.mir_resource_carrier_by_id(table, operation.source_carrier_id, ctx);
            mut destination_query := resource_mir.mir_resource_carrier_by_id(table, operation.destination_carrier_id, ctx);
            if source_query.found == 1 && destination_query.found == 1 {
                row = std.Concat(row, resource_mir.mir_resource_move_form_name(
                    source_query.value.carrier_kind,
                    destination_query.value.carrier_kind
                ));
            }
        }
    }
    row = std.Concat(row, " runtime_symbol=");
    row = std.Concat(row, mir_resource_operation_runtime_symbol(operation, table, authority_table, ctx));
    row = std.Concat(row, " cleanup=");
    row = std.Concat(row, operation.cleanup_id);
    row = std.Concat(row, "\n");
    return std.Clone(ctx, row);
}

// The parity witness contains both the canonical table and the backend-normalized
// lowering action. It never uses generated C local names to reconstruct identity.
func mir_resource_mir_to_c_witness(table: resource_mir.MirResourceMirTable[ctx], authority_table: authority.MirResourceAuthorityTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) str {
    mut output := resource_mir.mir_resource_mir_witness(
        table,
        authority_table,
        layout_table,
        ctx
    );
    mut operations: std.Vector[resource_mir.MirResourceOperation[ctx], ctx] := ctx[table.operations];
    mut index := 0;
    while index < len(operations) {
        output = std.Concat(
            output,
            mir_resource_operation_lowering_witness(
                operations[index],
                table,
                authority_table,
                ctx
            )
        );
        index = index + 1;
    }
    return std.Clone(ctx, output);
}
