// Phase 14.11 stable diagnostics for aggregate transport across blocks.
//
// Every rejection names the compiler-owned value, its class, its transport
// policy, and the block-argument arity that policy implies, so a diagnostic
// never re-derives a flattening decision from the backend.

import "mir_aggregate_transport.gst" as aggregate;

func mir_aggregate_diagnostic_for_rejection(table: aggregate.MirAggregateTransportTable[ctx], kind: str, source: str, line: int, column: int, value_id: str, block_label: str, ctx: &Arena) str {
    mut rejection := aggregate.mir_aggregate_rejection(kind, ctx);
    mut output := "gust_aggregate_diagnostic: taxonomy=gust.aggregate_transport.diagnostic.v1 reason_code=";
    output = std.Concat(output, rejection.reason_code);
    output = std.Concat(output, " source=");
    output = std.Concat(output, source);
    output = std.Concat(output, " line=");
    output = std.Concat(output, std.FormatInt(line));
    output = std.Concat(output, " column=");
    output = std.Concat(output, std.FormatInt(column));
    output = std.Concat(output, " operation=");
    output = std.Concat(output, kind);
    output = std.Concat(output, " block=");
    output = std.Concat(output, block_label);

    mut block_query := aggregate.mir_aggregate_block(table, block_label, ctx);
    if block_query.found == 1 {
        output = std.Concat(output, " block_arguments=");
        output = std.Concat(output, std.FormatInt(block_query.value.total_block_argument_count));
        output = std.Concat(output, " is_join=");
        output = std.Concat(output, std.FormatInt(block_query.value.is_join));
        output = std.Concat(output, " is_loop_header=");
        output = std.Concat(output, std.FormatInt(block_query.value.is_loop_header));
    } else {
        output = std.Concat(output, " block_arguments=-1 is_join=-1 is_loop_header=-1");
    }

    mut value_query := aggregate.mir_aggregate_value(table, value_id, ctx);
    output = std.Concat(output, " value=");
    if value_query.found == 1 {
        mut value := value_query.value;
        mut components: std.Vector[aggregate.MirAggregateComponent[ctx], ctx] := ctx[value.components];
        output = std.Concat(output, value.value_id);
        output = std.Concat(output, " class=");
        output = std.Concat(output, value.class_name);
        output = std.Concat(output, " type=");
        output = std.Concat(output, value.type_id);
        output = std.Concat(output, " layout=");
        output = std.Concat(output, value.layout_id);
        output = std.Concat(output, " transport=");
        output = std.Concat(output, value.transport_policy);
        output = std.Concat(output, " components=");
        output = std.Concat(output, std.FormatInt(len(components)));
        output = std.Concat(output, " arity=");
        output = std.Concat(output, std.FormatInt(aggregate.mir_aggregate_arity_for_policy(value.transport_policy, len(components))));
        output = std.Concat(output, " variant=");
        output = std.Concat(output, value.variant_name);
        output = std.Concat(output, " movement=");
        output = std.Concat(output, value.movement_kind);
        output = std.Concat(output, " lifetime=");
        output = std.Concat(output, value.lifetime_region);
    } else {
        output = std.Concat(output, value_id);
        output = std.Concat(output, " class=unresolved type=unresolved layout=unresolved transport=unresolved components=-1 arity=-1 variant= movement=unresolved lifetime=unresolved");
    }

    output = std.Concat(output, " detail=compiler-owned aggregate transport validation failed");
    return std.Clone(ctx, output);
}
