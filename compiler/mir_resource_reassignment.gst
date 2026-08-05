// Patch 15.4 compiler-owned resource reassignment semantics.
//
// Reassignment is a replacement transaction. The compiler names the old and
// replacement identities, the shared mutable storage, the old-value cleanup
// obligation, and the selected destruction order. Backends consume this table
// mechanically and may not infer replacement from source or storage names.

import "mir_resource_authority.gst" as authority;
import "mir_resource_value.gst" as resource_mir;

type MirResourceReassignment[ctx] struct {
    reassignment_id: str,
    form: str,
    resolution_policy: str,
    storage_id: str,
    old_resource_id: str,
    old_value_id: str,
    old_carrier_id: str,
    replacement_resource_id: str,
    replacement_value_id: str,
    replacement_carrier_id: str,
    predecessor_moved_resource_id: str,
    transfer_destination_carrier_id: str,
    cleanup_obligation_id: str,
    destructor_id: str,
    source_location: str,
    control_flow_region: str,
    destruction_order: int,
    mutable_storage: int,
    old_prior_state: str,
    old_resulting_state: str,
    replacement_prior_state: str,
    replacement_resulting_state: str,
    replacement_source_kind: str,
    observable_effect: str
}

type MirResourceReassignmentTable[ctx] struct {
    format: str,
    semantic_authority: str,
    selected_forms: str,
    resolution_policy: str,
    order_policy: str,
    entries: Index[std.Vector[MirResourceReassignment[ctx], ctx], ctx]
}

type MirResourceReassignmentValidation[ctx] struct {
    valid: int,
    reason_code: str
}

type MirResourceReassignmentTransitionValidation[ctx] struct {
    valid: int,
    reason_code: str
}

func mir_resource_reassignment_empty_vector(ctx: &Arena) Index[std.Vector[MirResourceReassignment[ctx], ctx], ctx] {
    mut values: std.Vector[MirResourceReassignment[ctx], ctx] := std.VectorNew(ctx);
    mut values_index: Index[std.Vector[MirResourceReassignment[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(values_index, values);
    return values_index;
}

func mir_resource_reassignment_make_empty_table(ctx: &Arena) MirResourceReassignmentTable[ctx] {
    mut table: MirResourceReassignmentTable[ctx];
    table.format = std.Clone(ctx, "gust.compiler_resource_reassignment.v1");
    table.semantic_authority = std.Clone(ctx, "compiler_owned_replacement_transaction");
    table.selected_forms = std.Clone(ctx, "live_local,reinitialized_moved_local,aggregate_field,conditional,selected_loop");
    table.resolution_policy = std.Clone(ctx, "immediate_destroy,scheduled_cleanup,transfer_before_replacement");
    table.order_policy = std.Clone(ctx, "explicit_monotonic_destruction_order");
    table.entries = mir_resource_reassignment_empty_vector(ctx);
    return table;
}

func mir_resource_reassignment_table_with_entry(table: MirResourceReassignmentTable[ctx], entry: MirResourceReassignment[ctx], ctx: &Arena) MirResourceReassignmentTable[ctx] {
    mut updated := table;
    mut values: std.Vector[MirResourceReassignment[ctx], ctx] := ctx[updated.entries];
    values.Push(entry);
    ctx.Set(updated.entries, values);
    return updated;
}

func mir_resource_reassignment_entry_count(table: MirResourceReassignmentTable[ctx], ctx: &Arena) int {
    mut entries: std.Vector[MirResourceReassignment[ctx], ctx] := ctx[table.entries];
    return len(entries);
}

func mir_resource_reassignment_entry_at(table: MirResourceReassignmentTable[ctx], entry_index: int, ctx: &Arena) MirResourceReassignment[ctx] {
    mut entries: std.Vector[MirResourceReassignment[ctx], ctx] := ctx[table.entries];
    return entries[entry_index];
}

func mir_resource_reassignment_validation(valid: int, reason_code: str, ctx: &Arena) MirResourceReassignmentValidation[ctx] {
    mut result: MirResourceReassignmentValidation[ctx];
    result.valid = valid;
    result.reason_code = std.Clone(ctx, reason_code);
    return result;
}

func mir_resource_reassignment_transition_validation(valid: int, reason_code: str, ctx: &Arena) MirResourceReassignmentTransitionValidation[ctx] {
    mut result: MirResourceReassignmentTransitionValidation[ctx];
    result.valid = valid;
    result.reason_code = std.Clone(ctx, reason_code);
    return result;
}

func mir_resource_reassignment_form_is_selected(form: str) int {
    if std.str_eq(form, "live_local") == 1 { return 1; }
    if std.str_eq(form, "reinitialized_moved_local") == 1 { return 1; }
    if std.str_eq(form, "aggregate_field") == 1 { return 1; }
    if std.str_eq(form, "conditional") == 1 { return 1; }
    if std.str_eq(form, "selected_loop") == 1 { return 1; }
    return 0;
}

func mir_resource_reassignment_resolution_is_selected(policy: str) int {
    if std.str_eq(policy, "immediate_destroy") == 1 { return 1; }
    if std.str_eq(policy, "scheduled_cleanup") == 1 { return 1; }
    if std.str_eq(policy, "transfer_before_replacement") == 1 { return 1; }
    return 0;
}

func mir_validate_resource_reassignment_transition(resolution_policy: str, mutable_storage: int, old_prior_state: str, old_resulting_state: str, replacement_prior_state: str, replacement_resulting_state: str, replacement_source_kind: str, destructor_id: str, transfer_destination_carrier_id: str, destruction_order: int, ctx: &Arena) MirResourceReassignmentTransitionValidation[ctx] {
    if mir_resource_reassignment_resolution_is_selected(resolution_policy) == 0 {
        return mir_resource_reassignment_transition_validation(0, "resource_reassignment_old_live_unresolved", ctx);
    }
    if mutable_storage != 1 {
        return mir_resource_reassignment_transition_validation(0, "resource_reassignment_immutable_storage", ctx);
    }
    if std.str_eq(old_prior_state, "destroyed") == 1 {
        return mir_resource_reassignment_transition_validation(0, "resource_reassignment_after_destroy_without_reinitialization", ctx);
    }
    if std.str_eq(old_prior_state, "live") == 0 {
        return mir_resource_reassignment_transition_validation(0, "resource_reassignment_old_not_live", ctx);
    }
    if std.str_eq(replacement_prior_state, "uninitialized") == 0 ||
       std.str_eq(replacement_resulting_state, "live") == 0
    {
        return mir_resource_reassignment_transition_validation(0, "resource_reassignment_replacement_state_invalid", ctx);
    }
    if std.str_eq(replacement_source_kind, "copy") == 1 {
        return mir_resource_reassignment_transition_validation(0, "resource_reassignment_copy_move_only", ctx);
    }
    if std.str_eq(replacement_source_kind, "fresh_initialize") == 0 &&
       std.str_eq(replacement_source_kind, "move") == 0
    {
        return mir_resource_reassignment_transition_validation(0, "resource_reassignment_replacement_source_invalid", ctx);
    }
    if std.str_eq(resolution_policy, "immediate_destroy") == 1 {
        if len(destructor_id) == 0 || std.str_eq(old_resulting_state, "destroyed") == 0 {
            return mir_resource_reassignment_transition_validation(0, "resource_reassignment_old_destroy_resolution_invalid", ctx);
        }
        if destruction_order <= 0 {
            return mir_resource_reassignment_transition_validation(0, "resource_reassignment_destruction_order_invalid", ctx);
        }
    } else if std.str_eq(resolution_policy, "scheduled_cleanup") == 1 {
        if len(destructor_id) == 0 || std.str_eq(old_resulting_state, "cleanup_scheduled") == 0 {
            return mir_resource_reassignment_transition_validation(0, "resource_reassignment_old_schedule_resolution_invalid", ctx);
        }
        if destruction_order <= 0 {
            return mir_resource_reassignment_transition_validation(0, "resource_reassignment_destruction_order_invalid", ctx);
        }
    } else {
        if len(transfer_destination_carrier_id) == 0 || std.str_eq(old_resulting_state, "moved") == 0 || destruction_order != 0 {
            return mir_resource_reassignment_transition_validation(0, "resource_reassignment_transfer_resolution_invalid", ctx);
        }
    }
    return mir_resource_reassignment_transition_validation(1, "resource_reassignment_transition_valid", ctx);
}

func mir_resource_reassignment_field_is_safe(value: str, allow_empty: int) int {
    if allow_empty == 0 && len(value) == 0 { return 0; }
    if std.str_find(value, "\n") != 0 - 1 { return 0; }
    if std.str_find(value, "\r") != 0 - 1 { return 0; }
    return 1;
}

func mir_resource_reassignment_cleanup_count(table: MirResourceReassignmentTable[ctx], cleanup_id: str, ctx: &Arena) int {
    mut entries: std.Vector[MirResourceReassignment[ctx], ctx] := ctx[table.entries];
    mut count := 0;
    mut entry_index := 0;
    while entry_index < len(entries) {
        if std.str_eq(entries[entry_index].cleanup_obligation_id, cleanup_id) == 1 {
            count = count + 1;
        }
        entry_index = entry_index + 1;
    }
    return count;
}

func mir_resource_reassignment_validate(table: MirResourceReassignmentTable[ctx], resource_table: resource_mir.MirResourceMirTable[ctx], authority_table: authority.MirResourceAuthorityTable[ctx], ctx: &Arena) MirResourceReassignmentValidation[ctx] {
    if std.str_eq(table.format, "gust.compiler_resource_reassignment.v1") == 0 ||
       std.str_eq(table.semantic_authority, "compiler_owned_replacement_transaction") == 0 ||
       std.str_eq(table.order_policy, "explicit_monotonic_destruction_order") == 0
    {
        return mir_resource_reassignment_validation(0, "resource_reassignment_unknown_format", ctx);
    }

    mut entries: std.Vector[MirResourceReassignment[ctx], ctx] := ctx[table.entries];
    mut previous_destruction_order := 0;
    mut entry_index := 0;
    while entry_index < len(entries) {
        mut entry := entries[entry_index];
        if mir_resource_reassignment_field_is_safe(entry.reassignment_id, 0) == 0 ||
           mir_resource_reassignment_field_is_safe(entry.storage_id, 0) == 0 ||
           mir_resource_reassignment_field_is_safe(entry.old_resource_id, 0) == 0 ||
           mir_resource_reassignment_field_is_safe(entry.replacement_resource_id, 0) == 0 ||
           mir_resource_reassignment_field_is_safe(entry.cleanup_obligation_id, 0) == 0 ||
           mir_resource_reassignment_field_is_safe(entry.source_location, 0) == 0 ||
           mir_resource_reassignment_field_is_safe(entry.observable_effect, 0) == 0
        {
            return mir_resource_reassignment_validation(0, "resource_reassignment_metadata_missing", ctx);
        }
        if mir_resource_reassignment_form_is_selected(entry.form) == 0 {
            return mir_resource_reassignment_validation(0, "resource_reassignment_form_unsupported", ctx);
        }
        mut transition_validation := mir_validate_resource_reassignment_transition(
            entry.resolution_policy,
            entry.mutable_storage,
            entry.old_prior_state,
            entry.old_resulting_state,
            entry.replacement_prior_state,
            entry.replacement_resulting_state,
            entry.replacement_source_kind,
            entry.destructor_id,
            entry.transfer_destination_carrier_id,
            entry.destruction_order,
            ctx
        );
        if transition_validation.valid == 0 {
            return mir_resource_reassignment_validation(0, transition_validation.reason_code, ctx);
        }
        if std.str_eq(entry.old_resource_id, entry.replacement_resource_id) == 1 {
            return mir_resource_reassignment_validation(0, "resource_reassignment_duplicate_live_identity", ctx);
        }

        mut old_identity := authority.mir_resource_by_id(authority_table, entry.old_resource_id, ctx);
        mut replacement_identity := authority.mir_resource_by_id(authority_table, entry.replacement_resource_id, ctx);
        if old_identity.found == 0 || replacement_identity.found == 0 {
            return mir_resource_reassignment_validation(0, "resource_reassignment_identity_missing", ctx);
        }
        if std.str_eq(old_identity.value.resource_type_id, replacement_identity.value.resource_type_id) == 0 ||
           std.str_eq(old_identity.value.layout_id, replacement_identity.value.layout_id) == 0 ||
           std.str_eq(old_identity.value.resource_kind, replacement_identity.value.resource_kind) == 0
        {
            return mir_resource_reassignment_validation(0, "resource_reassignment_layout_or_kind_mismatch", ctx);
        }

        mut old_value := resource_mir.mir_resource_value_by_id(resource_table, entry.old_value_id, ctx);
        mut replacement_value := resource_mir.mir_resource_value_by_id(resource_table, entry.replacement_value_id, ctx);
        if old_value.found == 0 || replacement_value.found == 0 ||
           std.str_eq(old_value.value.resource_id, entry.old_resource_id) == 0 ||
           std.str_eq(replacement_value.value.resource_id, entry.replacement_resource_id) == 0
        {
            return mir_resource_reassignment_validation(0, "resource_reassignment_value_identity_mismatch", ctx);
        }

        mut old_carrier := resource_mir.mir_resource_carrier_by_id(resource_table, entry.old_carrier_id, ctx);
        mut replacement_carrier := resource_mir.mir_resource_carrier_by_id(resource_table, entry.replacement_carrier_id, ctx);
        if old_carrier.found == 0 || replacement_carrier.found == 0 ||
           std.str_eq(old_carrier.value.resource_id, entry.old_resource_id) == 0 ||
           std.str_eq(replacement_carrier.value.resource_id, entry.replacement_resource_id) == 0 ||
           std.str_eq(old_carrier.value.storage_id, entry.storage_id) == 0 ||
           std.str_eq(replacement_carrier.value.storage_id, entry.storage_id) == 0
        {
            return mir_resource_reassignment_validation(0, "resource_reassignment_storage_identity_mismatch", ctx);
        }

        if std.str_eq(entry.form, "aggregate_field") == 1 {
            unsafe {
                if old_carrier.value.carrier_kind.tag != 4 || replacement_carrier.value.carrier_kind.tag != 4 {
                    return mir_resource_reassignment_validation(0, "resource_reassignment_aggregate_field_not_selected", ctx);
                }
            }
        }
        if std.str_eq(entry.form, "conditional") == 1 {
            if len(entry.control_flow_region) == 0 ||
               resource_mir.mir_resource_reassignment_control_flow_region_exists(
                   resource_table,
                   entry.control_flow_region,
                   entry.replacement_resource_id,
                   0,
                   ctx
               ) == 0
            {
                return mir_resource_reassignment_validation(0, "resource_reassignment_control_flow_region_missing", ctx);
            }
        }
        if std.str_eq(entry.form, "selected_loop") == 1 {
            if len(entry.control_flow_region) == 0 ||
               resource_mir.mir_resource_reassignment_control_flow_region_exists(
                   resource_table,
                   entry.control_flow_region,
                   entry.replacement_resource_id,
                   1,
                   ctx
               ) == 0
            {
                return mir_resource_reassignment_validation(0, "resource_reassignment_control_flow_region_missing", ctx);
            }
        }
        if std.str_eq(entry.form, "reinitialized_moved_local") == 1 {
            if len(entry.predecessor_moved_resource_id) == 0 ||
               std.str_eq(entry.predecessor_moved_resource_id, entry.old_resource_id) == 1
            {
                return mir_resource_reassignment_validation(0, "resource_reassignment_reinitialization_history_missing", ctx);
            }
            mut predecessor_identity := authority.mir_resource_by_id(authority_table, entry.predecessor_moved_resource_id, ctx);
            if predecessor_identity.found == 0 ||
               resource_mir.mir_resource_storage_has_moved_then_fresh_identity(
                   resource_table,
                   entry.storage_id,
                   entry.predecessor_moved_resource_id,
                   entry.old_resource_id,
                   ctx
               ) == 0
            {
                return mir_resource_reassignment_validation(0, "resource_reassignment_reinitialization_history_missing", ctx);
            }
        }

        if mir_resource_reassignment_cleanup_count(table, entry.cleanup_obligation_id, ctx) != 1 {
            return mir_resource_reassignment_validation(0, "resource_reassignment_duplicate_old_cleanup", ctx);
        }
        if authority.mir_resource_cleanup_matches_resource(
            authority_table,
            entry.cleanup_obligation_id,
            entry.old_resource_id,
            ctx
        ) == 0 {
            return mir_resource_reassignment_validation(0, "resource_reassignment_cleanup_obligation_missing", ctx);
        }

        if resource_mir.mir_resource_reassignment_replacement_source_exists(
            resource_table,
            entry.replacement_resource_id,
            entry.replacement_carrier_id,
            entry.replacement_source_kind,
            ctx
        ) == 0 {
            return mir_resource_reassignment_validation(0, "resource_reassignment_replacement_source_invalid", ctx);
        }

        if std.str_eq(entry.resolution_policy, "immediate_destroy") == 1 {
            if len(entry.destructor_id) == 0 || std.str_eq(entry.destructor_id, old_identity.value.destructor_id) == 0 ||
               std.str_eq(entry.old_resulting_state, "destroyed") == 0
            {
                return mir_resource_reassignment_validation(0, "resource_reassignment_old_destroy_resolution_invalid", ctx);
            }
            if entry.destruction_order <= previous_destruction_order {
                return mir_resource_reassignment_validation(0, "resource_reassignment_destruction_order_invalid", ctx);
            }
            previous_destruction_order = entry.destruction_order;
        } else if std.str_eq(entry.resolution_policy, "scheduled_cleanup") == 1 {
            if len(entry.destructor_id) == 0 || std.str_eq(entry.destructor_id, old_identity.value.destructor_id) == 0 ||
               std.str_eq(entry.old_resulting_state, "cleanup_scheduled") == 0
            {
                return mir_resource_reassignment_validation(0, "resource_reassignment_old_schedule_resolution_invalid", ctx);
            }
            if entry.destruction_order <= previous_destruction_order {
                return mir_resource_reassignment_validation(0, "resource_reassignment_destruction_order_invalid", ctx);
            }
            previous_destruction_order = entry.destruction_order;
        } else {
            mut transfer_destination := resource_mir.mir_resource_carrier_by_id(
                resource_table,
                entry.transfer_destination_carrier_id,
                ctx
            );
            if transfer_destination.found == 0 ||
               std.str_eq(transfer_destination.value.resource_id, entry.old_resource_id) == 0 ||
               std.str_eq(entry.old_resulting_state, "moved") == 0 ||
               entry.destruction_order != 0
            {
                return mir_resource_reassignment_validation(0, "resource_reassignment_transfer_resolution_invalid", ctx);
            }
        }

        if resource_mir.mir_resource_reassignment_old_resolution_exists(
            resource_table,
            entry.old_resource_id,
            entry.old_carrier_id,
            entry.cleanup_obligation_id,
            entry.resolution_policy,
            entry.transfer_destination_carrier_id,
            ctx
        ) == 0 {
            return mir_resource_reassignment_validation(0, "resource_reassignment_old_resolution_not_in_canonical_mir", ctx);
        }

        mut duplicate_index := entry_index + 1;
        while duplicate_index < len(entries) {
            if std.str_eq(entries[duplicate_index].reassignment_id, entry.reassignment_id) == 1 {
                return mir_resource_reassignment_validation(0, "resource_reassignment_duplicate_id", ctx);
            }
            if std.str_eq(entries[duplicate_index].old_resource_id, entry.old_resource_id) == 1 {
                return mir_resource_reassignment_validation(0, "resource_reassignment_old_resolved_more_than_once", ctx);
            }
            if std.str_eq(entries[duplicate_index].replacement_resource_id, entry.replacement_resource_id) == 1 {
                return mir_resource_reassignment_validation(0, "resource_reassignment_duplicate_replacement_identity", ctx);
            }
            duplicate_index = duplicate_index + 1;
        }
        entry_index = entry_index + 1;
    }
    return mir_resource_reassignment_validation(1, "resource_reassignment_table_valid", ctx);
}

func mir_resource_reassignment_append_field(output: str, key: str, value: str, ctx: &Arena) str {
    mut updated := std.Concat(output, key);
    updated = std.Concat(updated, ": ");
    updated = std.Concat(updated, value);
    updated = std.Concat(updated, "\n");
    return std.Clone(ctx, updated);
}

// Reassignment remains a request-local sidecar owned by this defining module.
// Do not embed MirResourceReassignmentTable in the shared resource-MIR request:
// stage one gives module-qualified generic containers distinct identities.
func mir_resource_reassignment_append_to_request(serialized_resource_mir: str, table: MirResourceReassignmentTable[ctx], resource_table: resource_mir.MirResourceMirTable[ctx], authority_table: authority.MirResourceAuthorityTable[ctx], ctx: &Arena) str {
    mut validation := mir_resource_reassignment_validate(table, resource_table, authority_table, ctx);
    if validation.valid == 0 {
        mut invalid := "resource_reassignment_format: invalid\nresource_reassignment_reason: ";
        invalid = std.Concat(invalid, validation.reason_code);
        invalid = std.Concat(invalid, "\n");
        return std.Clone(ctx, invalid);
    }
    mut output := std.Concat(
        serialized_resource_mir,
        mir_serialize_resource_reassignment_for_request(table, resource_table, authority_table, ctx)
    );
    return std.Clone(ctx, output);
}

func mir_serialize_resource_reassignment_for_request(table: MirResourceReassignmentTable[ctx], resource_table: resource_mir.MirResourceMirTable[ctx], authority_table: authority.MirResourceAuthorityTable[ctx], ctx: &Arena) str {
    mut validation := mir_resource_reassignment_validate(table, resource_table, authority_table, ctx);
    if validation.valid == 0 {
        mut invalid := "resource_reassignment_format: invalid\nresource_reassignment_reason: ";
        invalid = std.Concat(invalid, validation.reason_code);
        invalid = std.Concat(invalid, "\n");
        return std.Clone(ctx, invalid);
    }
    mut entries: std.Vector[MirResourceReassignment[ctx], ctx] := ctx[table.entries];
    mut output := "resource_reassignment_format: gust.compiler_resource_reassignment.v1\n";
    output = mir_resource_reassignment_append_field(output, "resource_reassignment_semantic_authority", table.semantic_authority, ctx);
    output = mir_resource_reassignment_append_field(output, "resource_reassignment_selected_forms", table.selected_forms, ctx);
    output = mir_resource_reassignment_append_field(output, "resource_reassignment_resolution_policy", table.resolution_policy, ctx);
    output = mir_resource_reassignment_append_field(output, "resource_reassignment_order_policy", table.order_policy, ctx);
    output = mir_resource_reassignment_append_field(output, "resource_reassignment_count", std.FormatInt(len(entries)), ctx);
    mut entry_index := 0;
    while entry_index < len(entries) {
        mut prefix := std.Concat("resource_reassignment_", std.FormatInt(entry_index));
        output = mir_resource_reassignment_append_field(output, std.Concat(prefix, "_id"), entries[entry_index].reassignment_id, ctx);
        output = mir_resource_reassignment_append_field(output, std.Concat(prefix, "_form"), entries[entry_index].form, ctx);
        output = mir_resource_reassignment_append_field(output, std.Concat(prefix, "_resolution_policy"), entries[entry_index].resolution_policy, ctx);
        output = mir_resource_reassignment_append_field(output, std.Concat(prefix, "_storage_id"), entries[entry_index].storage_id, ctx);
        output = mir_resource_reassignment_append_field(output, std.Concat(prefix, "_old_resource_id"), entries[entry_index].old_resource_id, ctx);
        output = mir_resource_reassignment_append_field(output, std.Concat(prefix, "_old_value_id"), entries[entry_index].old_value_id, ctx);
        output = mir_resource_reassignment_append_field(output, std.Concat(prefix, "_old_carrier_id"), entries[entry_index].old_carrier_id, ctx);
        output = mir_resource_reassignment_append_field(output, std.Concat(prefix, "_replacement_resource_id"), entries[entry_index].replacement_resource_id, ctx);
        output = mir_resource_reassignment_append_field(output, std.Concat(prefix, "_replacement_value_id"), entries[entry_index].replacement_value_id, ctx);
        output = mir_resource_reassignment_append_field(output, std.Concat(prefix, "_replacement_carrier_id"), entries[entry_index].replacement_carrier_id, ctx);
        output = mir_resource_reassignment_append_field(output, std.Concat(prefix, "_predecessor_moved_resource_id"), entries[entry_index].predecessor_moved_resource_id, ctx);
        output = mir_resource_reassignment_append_field(output, std.Concat(prefix, "_transfer_destination_carrier_id"), entries[entry_index].transfer_destination_carrier_id, ctx);
        output = mir_resource_reassignment_append_field(output, std.Concat(prefix, "_cleanup_obligation_id"), entries[entry_index].cleanup_obligation_id, ctx);
        output = mir_resource_reassignment_append_field(output, std.Concat(prefix, "_destructor_id"), entries[entry_index].destructor_id, ctx);
        output = mir_resource_reassignment_append_field(output, std.Concat(prefix, "_source_location"), entries[entry_index].source_location, ctx);
        output = mir_resource_reassignment_append_field(output, std.Concat(prefix, "_control_flow_region"), entries[entry_index].control_flow_region, ctx);
        output = mir_resource_reassignment_append_field(output, std.Concat(prefix, "_destruction_order"), std.FormatInt(entries[entry_index].destruction_order), ctx);
        output = mir_resource_reassignment_append_field(output, std.Concat(prefix, "_mutable_storage"), std.FormatInt(entries[entry_index].mutable_storage), ctx);
        output = mir_resource_reassignment_append_field(output, std.Concat(prefix, "_old_prior_state"), entries[entry_index].old_prior_state, ctx);
        output = mir_resource_reassignment_append_field(output, std.Concat(prefix, "_old_resulting_state"), entries[entry_index].old_resulting_state, ctx);
        output = mir_resource_reassignment_append_field(output, std.Concat(prefix, "_replacement_prior_state"), entries[entry_index].replacement_prior_state, ctx);
        output = mir_resource_reassignment_append_field(output, std.Concat(prefix, "_replacement_resulting_state"), entries[entry_index].replacement_resulting_state, ctx);
        output = mir_resource_reassignment_append_field(output, std.Concat(prefix, "_replacement_source_kind"), entries[entry_index].replacement_source_kind, ctx);
        output = mir_resource_reassignment_append_field(output, std.Concat(prefix, "_observable_effect"), entries[entry_index].observable_effect, ctx);
        entry_index = entry_index + 1;
    }
    return std.Clone(ctx, output);
}

func mir_resource_reassignment_witness(table: MirResourceReassignmentTable[ctx], resource_table: resource_mir.MirResourceMirTable[ctx], authority_table: authority.MirResourceAuthorityTable[ctx], ctx: &Arena) str {
    mut validation := mir_resource_reassignment_validate(table, resource_table, authority_table, ctx);
    if validation.valid == 0 {
        mut rejected := "resource_reassignment_witness: rejected reason=";
        rejected = std.Concat(rejected, validation.reason_code);
        rejected = std.Concat(rejected, "\n");
        return std.Clone(ctx, rejected);
    }
    mut entries: std.Vector[MirResourceReassignment[ctx], ctx] := ctx[table.entries];
    mut output := "resource_reassignment_witness: accepted\n";
    mut entry_index := 0;
    while entry_index < len(entries) {
        mut row := "resource_reassignment: id=";
        row = std.Concat(row, entries[entry_index].reassignment_id);
        row = std.Concat(row, " form=");
        row = std.Concat(row, entries[entry_index].form);
        row = std.Concat(row, " policy=");
        row = std.Concat(row, entries[entry_index].resolution_policy);
        row = std.Concat(row, " old=");
        row = std.Concat(row, entries[entry_index].old_resource_id);
        row = std.Concat(row, " replacement=");
        row = std.Concat(row, entries[entry_index].replacement_resource_id);
        row = std.Concat(row, " storage=");
        row = std.Concat(row, entries[entry_index].storage_id);
        row = std.Concat(row, " cleanup=");
        row = std.Concat(row, entries[entry_index].cleanup_obligation_id);
        row = std.Concat(row, " destructor=");
        row = std.Concat(row, entries[entry_index].destructor_id);
        row = std.Concat(row, " order=");
        row = std.Concat(row, std.FormatInt(entries[entry_index].destruction_order));
        row = std.Concat(row, " old_result=");
        row = std.Concat(row, entries[entry_index].old_resulting_state);
        row = std.Concat(row, " replacement_state=");
        row = std.Concat(row, entries[entry_index].replacement_resulting_state);
        row = std.Concat(row, " effect=");
        row = std.Concat(row, entries[entry_index].observable_effect);
        row = std.Concat(row, "\n");
        output = std.Concat(output, row);
        entry_index = entry_index + 1;
    }
    return std.Clone(ctx, output);
}
