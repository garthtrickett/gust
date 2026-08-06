import "mir.gst" as mir;
import "mir_layout.gst" as layout;
import "mir_primitive_layout.gst" as primitive_layout;
import "mir_integer_conversion.gst" as integer_conversion;
import "mir_pointer.gst" as pointer;
import "mir_stack_slot.gst" as stack_slot;
import "mir_memory_access.gst" as memory_access;
import "mir_string_view.gst" as string_view;
import "mir_array_slice.gst" as array_slice;
import "mir_destructor_scheduling.gst" as destructor_scheduling;

// Phase 10 generic native-backend request protocol.
//
// This compiler-owned model serializes one validated canonical whole-program
// MIR bundle reference plus one opaque final-executable intent. It performs no
// filesystem access, process spawning, object emission, linking, publication,
// fallback, or implementation-specific routing.
type MirNativeBackendRequest[ctx] struct {
    target_triple: str,
    object_format: str,
    output_path: str,
    program_mir_bundle_path: str,
    program_bundle: mir.MirProgramBundle[ctx],
    layout_table: layout.MirLayoutTable[ctx],
    integer_conversion_table: integer_conversion.MirIntegerConversionTable[ctx],
    pointer_table: pointer.MirPointerTable[ctx],
    stack_slot_table: stack_slot.MirStackSlotTable[ctx],
    memory_access_table: memory_access.MirMemoryAccessTable[ctx],
    string_view_table: string_view.MirStringViewTable[ctx],
    array_slice_table: array_slice.MirArraySliceTable[ctx],
    destructor_scheduling_table: destructor_scheduling.MirDestructorSchedulingTable[ctx]
}

func mir_native_backend_request_path_is_safe(path: str) int {
    if len(path) == 0 {
        return 0;
    }
    if std.str_find(path, "\n") != 0 - 1 {
        return 0;
    }
    if std.str_find(path, "\r") != 0 - 1 {
        return 0;
    }
    return 1;
}

func mir_native_backend_request_path_is_absolute(path: str) int {
    if mir_native_backend_request_path_is_safe(path) == 0 {
        return 0;
    }

    if std.str_byte_at(path, 0) == 47 {
        return 1;
    }

    if len(path) >= 3 {
        if std.str_byte_at(path, 1) == 58 {
            mut separator := std.str_byte_at(path, 2);
            if separator == 47 || separator == 92 {
                return 1;
            }
        }
    }

    return 0;
}

func mir_native_backend_make_request_with_destructor_scheduling_table(target_triple: str, object_format: str, output_path: str, program_mir_bundle_path: str, program_bundle: mir.MirProgramBundle[ctx], layout_table: layout.MirLayoutTable[ctx], integer_conversion_table: integer_conversion.MirIntegerConversionTable[ctx], pointer_table: pointer.MirPointerTable[ctx], stack_slot_table: stack_slot.MirStackSlotTable[ctx], memory_access_table: memory_access.MirMemoryAccessTable[ctx], string_view_table: string_view.MirStringViewTable[ctx], array_slice_table: array_slice.MirArraySliceTable[ctx], destructor_scheduling_table: destructor_scheduling.MirDestructorSchedulingTable[ctx], ctx: &Arena) MirNativeBackendRequest[ctx] {
    mut request: MirNativeBackendRequest[ctx];
    request.target_triple = std.Clone(ctx, target_triple);
    request.object_format = std.Clone(ctx, object_format);
    request.output_path = std.Clone(ctx, output_path);
    request.program_mir_bundle_path = std.Clone(ctx, program_mir_bundle_path);
    request.program_bundle = program_bundle;
    request.layout_table = layout_table;
    request.integer_conversion_table = integer_conversion_table;
    request.pointer_table = pointer_table;
    request.stack_slot_table = stack_slot_table;
    request.memory_access_table = memory_access_table;
    request.string_view_table = string_view_table;
    request.array_slice_table = array_slice_table;
    request.destructor_scheduling_table = destructor_scheduling_table;
    return request;
}

func mir_native_backend_make_request_with_array_slice_table(target_triple: str, object_format: str, output_path: str, program_mir_bundle_path: str, program_bundle: mir.MirProgramBundle[ctx], layout_table: layout.MirLayoutTable[ctx], integer_conversion_table: integer_conversion.MirIntegerConversionTable[ctx], pointer_table: pointer.MirPointerTable[ctx], stack_slot_table: stack_slot.MirStackSlotTable[ctx], memory_access_table: memory_access.MirMemoryAccessTable[ctx], string_view_table: string_view.MirStringViewTable[ctx], array_slice_table: array_slice.MirArraySliceTable[ctx], ctx: &Arena) MirNativeBackendRequest[ctx] {
    mut destructor_table := destructor_scheduling.mir_destructor_scheduling_make_empty_table(
        target_triple,
        ctx
    );
    return mir_native_backend_make_request_with_destructor_scheduling_table(
        target_triple,
        object_format,
        output_path,
        program_mir_bundle_path,
        program_bundle,
        layout_table,
        integer_conversion_table,
        pointer_table,
        stack_slot_table,
        memory_access_table,
        string_view_table,
        array_slice_table,
        destructor_table,
        ctx
    );
}

func mir_native_backend_make_request_with_string_view_table(target_triple: str, object_format: str, output_path: str, program_mir_bundle_path: str, program_bundle: mir.MirProgramBundle[ctx], layout_table: layout.MirLayoutTable[ctx], integer_conversion_table: integer_conversion.MirIntegerConversionTable[ctx], pointer_table: pointer.MirPointerTable[ctx], stack_slot_table: stack_slot.MirStackSlotTable[ctx], memory_access_table: memory_access.MirMemoryAccessTable[ctx], string_view_table: string_view.MirStringViewTable[ctx], ctx: &Arena) MirNativeBackendRequest[ctx] {
    mut array_table := array_slice.mir_array_slice_make_empty_table(target_triple, ctx);
    return mir_native_backend_make_request_with_array_slice_table(
        target_triple,
        object_format,
        output_path,
        program_mir_bundle_path,
        program_bundle,
        layout_table,
        integer_conversion_table,
        pointer_table,
        stack_slot_table,
        memory_access_table,
        string_view_table,
        array_table,
        ctx
    );
}

func mir_native_backend_make_request_with_typed_memory_tables(target_triple: str, object_format: str, output_path: str, program_mir_bundle_path: str, program_bundle: mir.MirProgramBundle[ctx], layout_table: layout.MirLayoutTable[ctx], integer_conversion_table: integer_conversion.MirIntegerConversionTable[ctx], pointer_table: pointer.MirPointerTable[ctx], stack_slot_table: stack_slot.MirStackSlotTable[ctx], memory_access_table: memory_access.MirMemoryAccessTable[ctx], ctx: &Arena) MirNativeBackendRequest[ctx] {
    mut string_table := string_view.mir_string_view_make_empty_table(
        target_triple,
        ctx
    );
    return mir_native_backend_make_request_with_string_view_table(
        target_triple,
        object_format,
        output_path,
        program_mir_bundle_path,
        program_bundle,
        layout_table,
        integer_conversion_table,
        pointer_table,
        stack_slot_table,
        memory_access_table,
        string_table,
        ctx
    );
}

func mir_native_backend_make_request_with_memory_tables(target_triple: str, object_format: str, output_path: str, program_mir_bundle_path: str, program_bundle: mir.MirProgramBundle[ctx], layout_table: layout.MirLayoutTable[ctx], integer_conversion_table: integer_conversion.MirIntegerConversionTable[ctx], pointer_table: pointer.MirPointerTable[ctx], stack_slot_table: stack_slot.MirStackSlotTable[ctx], ctx: &Arena) MirNativeBackendRequest[ctx] {
    mut memory_access_table := memory_access.mir_memory_access_make_empty_table(
        target_triple,
        ctx
    );
    return mir_native_backend_make_request_with_typed_memory_tables(
        target_triple,
        object_format,
        output_path,
        program_mir_bundle_path,
        program_bundle,
        layout_table,
        integer_conversion_table,
        pointer_table,
        stack_slot_table,
        memory_access_table,
        ctx
    );
}

func mir_native_backend_make_request_with_all_tables(target_triple: str, object_format: str, output_path: str, program_mir_bundle_path: str, program_bundle: mir.MirProgramBundle[ctx], layout_table: layout.MirLayoutTable[ctx], integer_conversion_table: integer_conversion.MirIntegerConversionTable[ctx], pointer_table: pointer.MirPointerTable[ctx], ctx: &Arena) MirNativeBackendRequest[ctx] {
    mut stack_slot_table := stack_slot.mir_stack_slot_table_for_layout(layout_table, ctx);
    return mir_native_backend_make_request_with_memory_tables(
        target_triple,
        object_format,
        output_path,
        program_mir_bundle_path,
        program_bundle,
        layout_table,
        integer_conversion_table,
        pointer_table,
        stack_slot_table,
        ctx
    );
}

func mir_native_backend_make_request_with_layout_and_conversion_tables(target_triple: str, object_format: str, output_path: str, program_mir_bundle_path: str, program_bundle: mir.MirProgramBundle[ctx], layout_table: layout.MirLayoutTable[ctx], integer_conversion_table: integer_conversion.MirIntegerConversionTable[ctx], ctx: &Arena) MirNativeBackendRequest[ctx] {
    mut pointer_table := pointer.mir_pointer_table_for_layout(layout_table, ctx);
    return mir_native_backend_make_request_with_all_tables(
        target_triple,
        object_format,
        output_path,
        program_mir_bundle_path,
        program_bundle,
        layout_table,
        integer_conversion_table,
        pointer_table,
        ctx
    );
}

func mir_native_backend_make_request_with_layout_table(target_triple: str, object_format: str, output_path: str, program_mir_bundle_path: str, program_bundle: mir.MirProgramBundle[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) MirNativeBackendRequest[ctx] {
    mut conversion_table := integer_conversion.mir_integer_conversion_table_for_layout(
        layout_table,
        ctx
    );
    return mir_native_backend_make_request_with_layout_and_conversion_tables(
        target_triple,
        object_format,
        output_path,
        program_mir_bundle_path,
        program_bundle,
        layout_table,
        conversion_table,
        ctx
    );
}

func mir_native_backend_make_request(target_triple: str, object_format: str, output_path: str, program_mir_bundle_path: str, program_bundle: mir.MirProgramBundle[ctx], ctx: &Arena) MirNativeBackendRequest[ctx] {
    mut layout_table := primitive_layout.mir_primitive_layout_table_for_target(
        target_triple,
        ctx
    );
    return mir_native_backend_make_request_with_layout_table(
        target_triple,
        object_format,
        output_path,
        program_mir_bundle_path,
        program_bundle,
        layout_table,
        ctx
    );
}

func mir_native_backend_request_is_valid(request: MirNativeBackendRequest[ctx], ctx: &Arena) int {
    if mir.mir_program_bundle_field_is_safe(request.target_triple, 0) == 0 {
        return 0;
    }
    if mir.mir_program_bundle_field_is_safe(request.object_format, 0) == 0 {
        return 0;
    }
    if mir_native_backend_request_path_is_absolute(request.output_path) == 0 {
        return 0;
    }
    if mir_native_backend_request_path_is_absolute(request.program_mir_bundle_path) == 0 {
        return 0;
    }
    if std.str_eq(request.output_path, request.program_mir_bundle_path) == 1 {
        return 0;
    }
    if mir.mir_program_bundle_is_valid(request.program_bundle, ctx) == 0 {
        return 0;
    }
    if layout.mir_layout_table_is_valid(request.layout_table, ctx) == 0 {
        return 0;
    }
    if request.layout_table.target.decisions_frozen == 0 {
        return 0;
    }
    if std.str_eq(
        request.layout_table.target.target_triple,
        request.target_triple
    ) == 0 {
        return 0;
    }
    if integer_conversion.mir_integer_conversion_table_is_valid(
        request.integer_conversion_table,
        request.layout_table,
        ctx
    ) == 0 {
        return 0;
    }
    if pointer.mir_pointer_table_is_valid(
        request.pointer_table,
        request.layout_table,
        ctx
    ) == 0 {
        return 0;
    }
    if stack_slot.mir_stack_slot_table_is_valid(
        request.stack_slot_table,
        request.layout_table,
        ctx
    ) == 0 {
        return 0;
    }
    if memory_access.mir_memory_access_table_is_legacy_empty(
        request.memory_access_table,
        ctx
    ) == 0 && memory_access.mir_memory_access_table_is_valid(
        request.memory_access_table,
        request.layout_table,
        request.pointer_table,
        request.stack_slot_table,
        ctx
    ) == 0 {
        return 0;
    }
    if string_view.mir_string_view_table_is_legacy_empty(
        request.string_view_table,
        ctx
    ) == 0 && string_view.mir_string_view_table_is_valid(
        request.string_view_table,
        request.layout_table,
        ctx
    ) == 0 {
        return 0;
    }
    if array_slice.mir_array_slice_table_is_legacy_empty(
        request.array_slice_table,
        ctx
    ) == 0 && array_slice.mir_array_slice_table_is_valid(
        request.array_slice_table,
        request.layout_table,
        ctx
    ) == 0 {
        return 0;
    }
    if destructor_scheduling.mir_destructor_scheduling_table_is_legacy_empty(
        request.destructor_scheduling_table,
        ctx
    ) == 0 && destructor_scheduling.mir_destructor_scheduling_table_is_valid(
        request.destructor_scheduling_table,
        request.layout_table,
        ctx
    ) == 0 {
        return 0;
    }
    return 1;
}

func mir_native_backend_request_append_field(output: str, key: str, value: str, ctx: &Arena) str {
    mut updated := std.Concat(output, key);
    updated = std.Concat(updated, ": ");
    updated = std.Concat(updated, value);
    updated = std.Concat(updated, "\n");
    return std.Clone(ctx, updated);
}

func mir_serialize_native_backend_request(request: MirNativeBackendRequest[ctx], ctx: &Arena) str {
    if mir_native_backend_request_is_valid(request, ctx) == 0 {
        return "format: invalid\n";
    }

    mut output := "format: gust.native_backend.request.v1\n";
    output = mir_native_backend_request_append_field(
        output,
        "driver_protocol",
        "gust.native_backend.driver.v1",
        ctx
    );
    output = mir_native_backend_request_append_field(
        output,
        "artifact_kind",
        "native_executable",
        ctx
    );
    output = mir_native_backend_request_append_field(
        output,
        "target_triple",
        request.target_triple,
        ctx
    );
    output = mir_native_backend_request_append_field(
        output,
        "object_format",
        request.object_format,
        ctx
    );
    output = mir_native_backend_request_append_field(
        output,
        "output_path",
        request.output_path,
        ctx
    );
    output = mir_native_backend_request_append_field(
        output,
        "program_mir_bundle_path",
        request.program_mir_bundle_path,
        ctx
    );
    output = std.Concat(
        output,
        layout.mir_serialize_layout_table_for_request(
            request.layout_table,
            ctx
        )
    );
    output = std.Concat(
        output,
        integer_conversion.mir_serialize_integer_conversion_table_for_request(
            request.integer_conversion_table,
            request.layout_table,
            ctx
        )
    );
    output = std.Concat(
        output,
        pointer.mir_serialize_pointer_table_for_request(
            request.pointer_table,
            request.layout_table,
            ctx
        )
    );
    output = std.Concat(
        output,
        stack_slot.mir_serialize_stack_slot_table_for_request(
            request.stack_slot_table,
            request.layout_table,
            ctx
        )
    );
    output = std.Concat(
        output,
        memory_access.mir_serialize_memory_access_table_for_request(
            request.memory_access_table,
            request.layout_table,
            request.pointer_table,
            request.stack_slot_table,
            ctx
        )
    );
    output = std.Concat(
        output,
        string_view.mir_serialize_string_view_table_for_request(
            request.string_view_table,
            request.layout_table,
            ctx
        )
    );
    output = std.Concat(
        output,
        array_slice.mir_serialize_array_slice_table_for_request(
            request.array_slice_table,
            request.layout_table,
            ctx
        )
    );
    output = std.Concat(
        output,
        destructor_scheduling.mir_serialize_destructor_scheduling_table_for_request(
            request.destructor_scheduling_table,
            request.layout_table,
            ctx
        )
    );
    return std.Clone(ctx, output);
}
